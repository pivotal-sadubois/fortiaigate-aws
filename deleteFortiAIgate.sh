#!/bin/bash
#===============================================================================
# SCRIPT NAME:    deleteFortiAIgate.sh
# DESCRIPTION:    Delete FortiAIgate Deployment
# AUTHOR:         Sacha Dubois, Fortinet
# CREATED:        2026-03-11
# VERSION:        0.1
#===============================================================================
# CHANGE LOG:
# 2026-03-11 sdubois Initial version
#===============================================================================
[ -f ./functions ] && . ./functions
if [ -f $HOME/.fortiaigate.cfg ]; then
   . $HOME/.fortiaigate.cfg 
else
  echo "ERROR: Config file $HOME/.fortiaigate.cfg not available"
  exit
fi

echo "deleteFortiAIgate.sh - Deploy FortiAIgate"
echo "by Sacha Dubois, Fortinet"
echo "------------------------------------------------------------------------------------------"

verifyCLIutils
verifyAWScredentials

messageTitle "Cleaning-up AWS EKS Kubernetes Cluster Deployment ($EKS_CLUSTER_NAME)"

LB_ARN=$(aws elbv2 describe-load-balancers --region $AWS_REGION | jq -r '.LoadBalancers[].LoadBalancerArn')
if [ "$LB_ARN" != "" ]; then
  echo " ▪ deleting ALB Load Balancer ($LB_ARN)"
  aws elbv2 delete-load-balancer --load-balancer-arn "$LB_ARN" --region $AWS_REGION > /tmp/error.log 2>&1; ret=$?
  if [ $ret -ne 0 ]; then
    logMessages /tmp/error.log
    echo "ERROR: failed to delete load-balancer"
    echo "       => aws elbv2 delete-load-balancer --load-balancer-arn "$LB_ARN" --region $AWS_REGION"
    exit
  fi

  while aws elbv2 describe-load-balancers \
    --load-balancer-arns "$LB_ARN" \
    --region eu-north-1 >/dev/null 2>&1; do
    sleep 10
  done
else
  echo " ▪ ALB Load Balancer allredy deleted"
fi

nodegroup=$(aws eks list-nodegroups  --cluster-name $EKS_CLUSTER_NAME --region $AWS_REGION  --no-cli-pager 2>/dev/null | jq -r '.nodegroups[]')
if [ "$nodegroup" == "gpu-ondemand-ng" -o "$nodegroup" == "gpu-spot-ng"  ]; then 
  echo " ▪ deleting EKS NodeGroup ($nodegroup)"

  eksctl delete nodegroup \
    --cluster $EKS_CLUSTER_NAME \
    --name $nodegroup \
    --disable-eviction \
    --region $AWS_REGION > /tmp/error.log 2>&1; ret=$?

  if [ $ret -ne 0 ]; then
    logMessages /tmp/error.log
    echo "ERROR: failed to delete NodeGroup"
    echo "       => eksctl delete nodegroup --name $nodegroup --region $AWS_REGION"
    exit
  fi

  NODEGROUP="$EKS_CLUSTER_NAME"

  while true; do
    status=$(aws eks describe-nodegroup \
      --cluster-name "$EKS_CLUSTER_NAME" \
      --nodegroup-name "$NODEGROUP" \
      --region "$AWS_REGION" \
      --query 'nodegroup.status' \
      --output text 2>/dev/null)

    if [ $? -ne 0 ]; then
      break
    fi

    sleep 15
  done
else
  echo " ▪ EKS NodeGroup already deleted"
fi

cluster=$(aws eks list-clusters --region $AWS_REGION 2>/dev/null | jq --arg key "$EKS_CLUSTER_NAME" -r '.clusters[] | select(. == $key)')
if [ "$cluster" == "$EKS_CLUSTER_NAME" ]; then
  echo " ▪ deleting EKS Cluster ($EKS_CLUSTER_NAME)"

  eksctl delete cluster --name "$EKS_CLUSTER_NAME" --region "$AWS_REGIO" > /tmp/error.log 2>&1; ret=$?
  if [ $ret -ne 0 ]; then
    logMessages /tmp/error.log
    echo "ERROR: failed to delete the EKS Cluster"
    echo "       =>  eksctl delete cluster --name $EKS_CLUSTER_NAME --region $AWS_REGIO"
    exit
  fi

  while aws eks describe-cluster --name "$EKS_CLUSTER_NAME" \
    --region "$AWS_REGION" \
    --query 'cluster.status' \
    --output text >/dev/null 2>&1; do
    sleep 20
  done

  echo " ▪ EKS Cluster ($EKS_CLUSTER_NAME) sucessfuly deleted"
else
  echo " ▪ EKS Cluster ($EKS_CLUSTER_NAME) already deleted"
fi

# Cleanup Deployment Files
#rm -f $HOME/.fortiaigate.cfg

exit
stacks=$(aws cloudformation list-stacks --region "$AWS_REGION" \
  --stack-status-filter CREATE_IN_PROGRESS CREATE_FAILED CREATE_COMPLETE ROLLBACK_IN_PROGRESS ROLLBACK_FAILED ROLLBACK_COMPLETE DELETE_IN_PROGRESS DELETE_FAILED UPDATE_IN_PROGRESS UPDATE_COMPLETE_CLEANUP_IN_PROGRESS UPDATE_COMPLETE UPDATE_FAILED UPDATE_ROLLBACK_IN_PROGRESS UPDATE_ROLLBACK_FAILED UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS UPDATE_ROLLBACK_COMPLETE REVIEW_IN_PROGRESS IMPORT_IN_PROGRESS IMPORT_COMPLETE IMPORT_ROLLBACK_IN_PROGRESS IMPORT_ROLLBACK_FAILED IMPORT_ROLLBACK_COMPLETE \
  --query 'StackSummaries[?contains(StackName, `eksctl`)].[StackName,StackStatus]' | jq -r '.[]')
if [ "$stacks" != "" ]; then
  echo "oh, we need to delete the stacks here"
  exit
fi

exit
