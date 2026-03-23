#!/bin/bash
#===============================================================================
# SCRIPT NAME:    deploy-echoserver-ingress-traefik.sh
# DESCRIPTION:    Deploy the echoserver app in namespace echoserver
# AUTHOR:         Sacha Dubois, Fortinet
# CREATED:        2025-03-30
# VERSION:        1.1
#===============================================================================
# CHANGE LOG:
# 2025-03-15 sdubois Initial version
#===============================================================================
[ -f ./functions ] && . ./functions
if [ -f $HOME/.faig.cfg ]; then
   . $HOME/.faig.cfg
else
  echo "ERROR: Config file $HOME/.faig.cfg not available"
  exit
fi


verifyCLIutils
verifyAWScredentials

deleteClassicLoadBalancersInVpc() {
  vpcId="$1"

  aws elb describe-load-balancers \
    --region $AWS_REGION > /tmp/elbs.json 2>/dev/null

  for lb in $(jq -r --arg vpc "$vpcId" '.LoadBalancerDescriptions[]? | select(.VPCId == $vpc) | .LoadBalancerName' /tmp/elbs.json); do
    echo "Delete Classic Load Balancer: $lb"
    aws elb delete-load-balancer \
      --load-balancer-name "$lb" \
      --region $AWS_REGION > /tmp/error.log 2>&1; ret=$?
    [ $ret -ne 0 ] && logMessages /tmp/error.log
  done
}

deleteElbv2LoadBalancersInVpc() {
  vpcId="$1"

  aws elbv2 describe-load-balancers \
    --region $AWS_REGION > /tmp/elbv2.json 2>/dev/null

  for arn in $(jq -r --arg vpc "$vpcId" '.LoadBalancers[]? | select(.VpcId == $vpc) | .LoadBalancerArn' /tmp/elbv2.json); do
    echo "Delete ELBv2 Load Balancer: $arn"
    aws elbv2 delete-load-balancer \
      --load-balancer-arn "$arn" \
      --region $AWS_REGION > /tmp/error.log 2>&1; ret=$?
    [ $ret -ne 0 ] && logMessages /tmp/error.log
  done
}

terminateInstancesInVpc() {
  vpcId="$1"

  aws ec2 describe-instances \
    --region $AWS_REGION \
    --filters Name=vpc-id,Values=$vpcId Name=instance-state-name,Values=pending,running,stopping,stopped \
    > /tmp/instances.json 2>/dev/null

  for iid in $(jq -r '.Reservations[]?.Instances[]?.InstanceId' /tmp/instances.json); do
    echo "Disable EC2 termination protection: $iid"
    aws ec2 modify-instance-attribute \
      --instance-id "$iid" \
      --no-disable-api-termination \
      --region $AWS_REGION > /tmp/error.log 2>&1; ret=$?
    [ $ret -ne 0 ] && logMessages /tmp/error.log

    echo "Terminate EC2 instance: $iid"
    aws ec2 terminate-instances \
      --instance-ids "$iid" \
      --region $AWS_REGION > /tmp/error.log 2>&1; ret=$?
    [ $ret -ne 0 ] && logMessages /tmp/error.log
  done
}

deleteNatGatewaysInVpc() {
  vpcId="$1"

  aws ec2 describe-nat-gateways \
    --region $AWS_REGION \
    --filter Name=vpc-id,Values=$vpcId \
    > /tmp/nat.json 2>/dev/null

  for nat in $(jq -r '.NatGateways[]? | select(.State != "deleted") | .NatGatewayId' /tmp/nat.json); do
    echo "Delete NAT Gateway: $nat"
    aws ec2 delete-nat-gateway \
      --nat-gateway-id "$nat" \
      --region $AWS_REGION > /tmp/error.log 2>&1; ret=$?
    [ $ret -ne 0 ] && logMessages /tmp/error.log
  done

  while true; do
    aws ec2 describe-nat-gateways \
      --region $AWS_REGION \
      --filter Name=vpc-id,Values=$vpcId \
      > /tmp/nat.json 2>/dev/null

    natLeft=$(jq -r '[.NatGateways[]? | select(.State != "deleted")] | length' /tmp/nat.json)
    [ "$natLeft" == "0" ] && break

    echo "Waiting for NAT Gateways to disappear in VPC $vpcId ..."
    sleep 15
  done
}

deleteVpcEndpointsInVpc() {
  vpcId="$1"

  aws ec2 describe-vpc-endpoints \
    --region $AWS_REGION \
    --filters Name=vpc-id,Values=$vpcId \
    > /tmp/vpce.json 2>/dev/null

  ids=$(jq -r '.VpcEndpoints[]? | .VpcEndpointId' /tmp/vpce.json | xargs)
  [ -z "$ids" ] && return

  echo "Delete VPC endpoints: $ids"
  aws ec2 delete-vpc-endpoints \
    --vpc-endpoint-ids $ids \
    --region $AWS_REGION > /tmp/error.log 2>&1; ret=$?
  [ $ret -ne 0 ] && logMessages /tmp/error.log
}

deleteFlowLogsInVpc() {
  vpcId="$1"

  aws ec2 describe-flow-logs \
    --region $AWS_REGION \
    --filter Name=resource-id,Values=$vpcId \
    > /tmp/flowlogs.json 2>/dev/null

  ids=$(jq -r '.FlowLogs[]? | .FlowLogId' /tmp/flowlogs.json | xargs)
  [ -z "$ids" ] && return

  echo "Delete Flow Logs: $ids"
  aws ec2 delete-flow-logs \
    --flow-log-ids $ids \
    --region $AWS_REGION > /tmp/error.log 2>&1; ret=$?
  [ $ret -ne 0 ] && logMessages /tmp/error.log
}

detachAndDeleteInternetGateways() {
  vpcId="$1"

  aws ec2 describe-internet-gateways \
    --region $AWS_REGION \
    --filters Name=attachment.vpc-id,Values=$vpcId \
    > /tmp/igw.json 2>/dev/null

  for igw in $(jq -r '.InternetGateways[]? | .InternetGatewayId' /tmp/igw.json); do
    echo "Detach Internet Gateway: $igw from $vpcId"
    aws ec2 detach-internet-gateway \
      --internet-gateway-id "$igw" \
      --vpc-id "$vpcId" \
      --region $AWS_REGION > /tmp/error.log 2>&1; ret=$?
    [ $ret -ne 0 ] && logMessages /tmp/error.log

    echo "Delete Internet Gateway: $igw"
    aws ec2 delete-internet-gateway \
      --internet-gateway-id "$igw" \
      --region $AWS_REGION > /tmp/error.log 2>&1; ret=$?
    [ $ret -ne 0 ] && logMessages /tmp/error.log
  done
}

deleteEgressOnlyInternetGateways() {
  vpcId="$1"

  aws ec2 describe-egress-only-internet-gateways \
    --region $AWS_REGION \
    --filters Name=attachment.vpc-id,Values=$vpcId \
    > /tmp/eigw.json 2>/dev/null

  for eigw in $(jq -r '.EgressOnlyInternetGateways[]? | .EgressOnlyInternetGatewayId' /tmp/eigw.json); do
    echo "Delete Egress-Only Internet Gateway: $eigw"
    aws ec2 delete-egress-only-internet-gateway \
      --egress-only-internet-gateway-id "$eigw" \
      --region $AWS_REGION > /tmp/error.log 2>&1; ret=$?
    [ $ret -ne 0 ] && logMessages /tmp/error.log
  done
}

deleteAvailableNetworkInterfacesInVpc() {
  vpcId="$1"

  aws ec2 describe-network-interfaces \
    --region $AWS_REGION \
    --filters Name=vpc-id,Values=$vpcId \
    > /tmp/eni.json 2>/dev/null

  for eni in $(jq -r '.NetworkInterfaces[]? | select(.Status == "available" and (.RequesterManaged | not)) | .NetworkInterfaceId' /tmp/eni.json); do
    echo "Delete ENI: $eni"
    aws ec2 delete-network-interface \
      --network-interface-id "$eni" \
      --region $AWS_REGION > /tmp/error.log 2>&1; ret=$?
    [ $ret -ne 0 ] && logMessages /tmp/error.log
  done
}

deleteSubnetsInVpc() {
  vpcId="$1"

  aws ec2 describe-subnets \
    --region $AWS_REGION \
    --filters Name=vpc-id,Values=$vpcId \
    > /tmp/subnets.json 2>/dev/null

  for subnet in $(jq -r '.Subnets[]? | .SubnetId' /tmp/subnets.json); do
    echo "Delete Subnet: $subnet"
    aws ec2 delete-subnet \
      --subnet-id "$subnet" \
      --region $AWS_REGION > /tmp/error.log 2>&1; ret=$?
    [ $ret -ne 0 ] && logMessages /tmp/error.log
  done
}

deleteNonMainRouteTablesInVpc() {
  vpcId="$1"

  aws ec2 describe-route-tables \
    --region $AWS_REGION \
    --filters Name=vpc-id,Values=$vpcId \
    > /tmp/rtb.json 2>/dev/null

  for rtb in $(jq -r '.RouteTables[]? | select(([.Associations[]?.Main] | any) | not) | .RouteTableId' /tmp/rtb.json); do
    echo "Delete Route Table: $rtb"
    aws ec2 delete-route-table \
      --route-table-id "$rtb" \
      --region $AWS_REGION > /tmp/error.log 2>&1; ret=$?
    [ $ret -ne 0 ] && logMessages /tmp/error.log
  done
}

deleteNonDefaultSecurityGroupsInVpc() {
  vpcId="$1"

  aws ec2 describe-security-groups \
    --region $AWS_REGION \
    --filters Name=vpc-id,Values=$vpcId \
    > /tmp/sg.json 2>/dev/null

  for sg in $(jq -r '.SecurityGroups[]? | select(.GroupName != "default") | .GroupId' /tmp/sg.json); do
    echo "Delete Security Group: $sg"
    aws ec2 delete-security-group \
      --group-id "$sg" \
      --region $AWS_REGION > /tmp/error.log 2>&1; ret=$?
    [ $ret -ne 0 ] && logMessages /tmp/error.log
  done
}

deleteNonDefaultNetworkAclsInVpc() {
  vpcId="$1"

  aws ec2 describe-network-acls \
    --region $AWS_REGION \
    --filters Name=vpc-id,Values=$vpcId \
    > /tmp/nacl.json 2>/dev/null

  for nacl in $(jq -r '.NetworkAcls[]? | select(.IsDefault == false) | .NetworkAclId' /tmp/nacl.json); do
    echo "Delete Network ACL: $nacl"
    aws ec2 delete-network-acl \
      --network-acl-id "$nacl" \
      --region $AWS_REGION > /tmp/error.log 2>&1; ret=$?
    [ $ret -ne 0 ] && logMessages /tmp/error.log
  done
}

findVpcInFailedStack() {
  stack="$1"

  aws cloudformation list-stack-resources \
    --stack-name "$stack" \
    --region $AWS_REGION > /tmp/stack-resources.json 2>/dev/null

  jq -r '.StackResourceSummaries[]? | select(.ResourceType == "AWS::EC2::VPC") | .PhysicalResourceId' /tmp/stack-resources.json | head -1
}

deleteVpcDependencies() {
  vpcId="$1"

  echo "Resolve dependencies for VPC: $vpcId"

  deleteClassicLoadBalancersInVpc "$vpcId"
  deleteElbv2LoadBalancersInVpc "$vpcId"
  terminateInstancesInVpc "$vpcId"
  deleteFlowLogsInVpc "$vpcId"
  deleteVpcEndpointsInVpc "$vpcId"
  deleteNatGatewaysInVpc "$vpcId"

  deleteEfsFileSystemsInVpc "$vpcId"

  deleteAvailableNetworkInterfacesInVpc "$vpcId"
  deleteSubnetsInVpc "$vpcId"
  deleteNonMainRouteTablesInVpc "$vpcId"
  deleteNonDefaultSecurityGroupsInVpc "$vpcId"
  deleteNonDefaultNetworkAclsInVpc "$vpcId"
  detachAndDeleteInternetGateways "$vpcId"
  deleteEgressOnlyInternetGateways "$vpcId"

  echo "VPC dependency cleanup finished for: $vpcId"
}

disableTerminationProtectionIfNeeded() {
  stack="$1"

  ptc=$(aws cloudformation describe-stacks \
    --stack-name "$stack" \
    --region $AWS_REGION \
    --query "Stacks[0].EnableTerminationProtection" \
    --output text 2>/dev/null)

  [ "$ptc" == "None" ] && ptc="False"

  echo "STACK: $stack Protected: $ptc"

  if [ "$ptc" == "True" ]; then
    aws cloudformation update-termination-protection \
      --stack-name "$stack" \
      --no-enable-termination-protection \
      --region $AWS_REGION \
      --no-cli-pager > /tmp/error.log 2>&1; ret=$?

    if [ $ret -ne 0 ]; then
      logMessages /tmp/error.log
      echo "ERROR: Failed to disable termination protection on stack $stack"
      exit 1
    fi
  fi
}

deleteStackAndRepairIfNeeded() {
  stack="$1"

  while true; do
    stt=$(aws cloudformation describe-stacks \
      --stack-name "$stack" \
      --region $AWS_REGION \
      --query "Stacks[0].StackStatus" \
      --output text 2>/dev/null)
    ret=$?

    if [ $ret -ne 0 ]; then
      echo "STACK: $stack is gone"
      break
    fi

    echo "STACK: $stack STT:$stt"

    if [ "$stt" == "DELETE_COMPLETE" ]; then
      break
    fi

    if [ "$stt" == "DELETE_IN_PROGRESS" ]; then
      sleep 15
      continue
    fi

    if [ "$stt" == "DELETE_FAILED" ]; then
      vpcId=$(findVpcInFailedStack "$stack")

      if [ -n "$vpcId" -a "$vpcId" != "null" ]; then
        echo "DELETE_FAILED stack $stack has VPC dependency: $vpcId"
        deleteVpcDependencies "$vpcId"
      else
        echo "DELETE_FAILED stack $stack but no VPC resource was found"
        aws cloudformation describe-stack-events \
          --stack-name "$stack" \
          --region $AWS_REGION \
          --no-cli-pager \
          --query "StackEvents[?ResourceStatus=='DELETE_FAILED'].[Timestamp,LogicalResourceId,ResourceType,ResourceStatusReason]" \
          --output table
        exit 1
      fi
    fi

    aws cloudformation delete-stack \
      --stack-name "$stack" \
      --region $AWS_REGION \
      --no-cli-pager > /tmp/error.log 2>&1; ret=$?

    if [ $ret -ne 0 ]; then
      logMessages /tmp/error.log
      echo "ERROR: Failed to delete stack $stack"
      exit 1
    fi

    sleep 10
  done
}

deleteAllStacks() {
  aws cloudformation list-stacks \
    --region $AWS_REGION \
    --stack-status-filter CREATE_IN_PROGRESS CREATE_FAILED CREATE_COMPLETE ROLLBACK_IN_PROGRESS ROLLBACK_FAILED ROLLBACK_COMPLETE DELETE_IN_PROGRESS DELETE_FAILED UPDATE_IN_PROGRESS UPDATE_COMPLETE_CLEANUP_IN_PROGRESS UPDATE_COMPLETE UPDATE_FAILED UPDATE_ROLLBACK_IN_PROGRESS UPDATE_ROLLBACK_FAILED UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS UPDATE_ROLLBACK_COMPLETE REVIEW_IN_PROGRESS IMPORT_IN_PROGRESS IMPORT_COMPLETE IMPORT_ROLLBACK_IN_PROGRESS IMPORT_ROLLBACK_FAILED IMPORT_ROLLBACK_COMPLETE \
    > /tmp/output.json 2>/dev/null

  for stack in $(jq -r '.StackSummaries[]?.StackName' /tmp/output.json); do
    stt=$(jq -r --arg key "$stack" '.StackSummaries[] | select(.StackName == $key).StackStatus' /tmp/output.json)

    [ "$stt" == "DELETE_COMPLETE" -o "$stt" == "DELETE_IN_PROGRESS" ] && continue

    echo "STACK: $stack STT:$stt"
    messageTitle "Cleaning up Stack: $stack ($stt)"

    disableTerminationProtectionIfNeeded "$stack"
    deleteStackAndRepairIfNeeded "$stack"
  done
}

deleteEfsAccessPointsInFileSystem() {
  fsId="$1"

  aws efs describe-access-points \
    --region $AWS_REGION \
    --file-system-id "$fsId" \
    > /tmp/efs-ap.json 2>/dev/null

  for ap in $(jq -r '.AccessPoints[]? | .AccessPointId' /tmp/efs-ap.json); do
    echo "Delete EFS Access Point: $ap"
    aws efs delete-access-point \
      --access-point-id "$ap" \
      --region $AWS_REGION > /tmp/error.log 2>&1; ret=$?
    [ $ret -ne 0 ] && logMessages /tmp/error.log
  done

  while true; do
    aws efs describe-access-points \
      --region $AWS_REGION \
      --file-system-id "$fsId" \
      > /tmp/efs-ap.json 2>/dev/null

    apLeft=$(jq -r '[.AccessPoints[]?] | length' /tmp/efs-ap.json)
    [ "$apLeft" == "0" ] && break

    echo "Waiting for EFS Access Points to disappear for filesystem $fsId ..."
    sleep 10
  done
}

deleteEfsMountTargetsInVpc() {
  fsId="$1"
  vpcId="$2"

  aws efs describe-mount-targets \
    --file-system-id "$fsId" \
    --region $AWS_REGION \
    > /tmp/efs-mt.json 2>/dev/null

  for mt in $(jq -r --arg vpc "$vpcId" '.MountTargets[]? | select(.VpcId == $vpc) | .MountTargetId' /tmp/efs-mt.json); do
    echo "Delete EFS Mount Target: $mt"
    aws efs delete-mount-target \
      --mount-target-id "$mt" \
      --region $AWS_REGION > /tmp/error.log 2>&1; ret=$?
    [ $ret -ne 0 ] && logMessages /tmp/error.log
  done

  while true; do
    aws efs describe-mount-targets \
      --file-system-id "$fsId" \
      --region $AWS_REGION \
      > /tmp/efs-mt.json 2>/dev/null

    mtLeft=$(jq -r --arg vpc "$vpcId" '[.MountTargets[]? | select(.VpcId == $vpc)] | length' /tmp/efs-mt.json)
    [ "$mtLeft" == "0" ] && break

    echo "Waiting for EFS Mount Targets to disappear for filesystem $fsId ..."
    sleep 10
  done
}

deleteEfsFileSystemsInVpc() {
  vpcId="$1"

  aws efs describe-file-systems \
    --region $AWS_REGION \
    > /tmp/efs-fs.json 2>/dev/null

  for fsId in $(jq -r '.FileSystems[]? | .FileSystemId' /tmp/efs-fs.json); do

    aws efs describe-mount-targets \
      --file-system-id "$fsId" \
      --region $AWS_REGION \
      > /tmp/efs-mt.json 2>/dev/null

    fsInVpc=$(jq -r --arg vpc "$vpcId" '[.MountTargets[]? | select(.VpcId == $vpc)] | length' /tmp/efs-mt.json)

    [ "$fsInVpc" == "0" ] && continue

    echo "Delete EFS dependencies for filesystem: $fsId"

    deleteEfsAccessPointsInFileSystem "$fsId"
    deleteEfsMountTargetsInVpc "$fsId" "$vpcId"

    echo "Delete EFS File System: $fsId"
    aws efs delete-file-system \
      --file-system-id "$fsId" \
      --region $AWS_REGION > /tmp/error.log 2>&1; ret=$?
    [ $ret -ne 0 ] && logMessages /tmp/error.log
  done
}

deleteAllStacks

echo "Manually see all stacks and their status"
echo "=> aws cloudformation list-stacks --region $AWS_REGION | jq -r '.StackSummaries[] | select(.StackStatus == \"DELETE_FAILED\")'"

# aws cloudformation list-stacks --region $AWS_REGION | jq -r '.StackSummaries[] | select(.StackStatus == "DELETE_FAILED")'

exit 0
