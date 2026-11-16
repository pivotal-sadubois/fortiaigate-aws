#!/bin/bash
#===============================================================================
# SCRIPT NAME:    deployFortiAIgate.sh
# DESCRIPTION:    Deploy FortiAIgate Deployment
# AUTHOR:         Sacha Dubois, Fortinet
# CREATED:        2026-03-11
# VERSION:        0.1
#===============================================================================
# CHANGE LOG:
# 2026-03-11 sdubois Initial version
# 2026-10-20 sdubois Added MCP Fileserver Deployment
#===============================================================================

[ -f ./functions ] && . ./functions

echo ""
echo "deployFortiAIgate.sh - Deploy FortiAIgate"
echo "by Adrian Sameli / Sacha Dubois, Fortinet"
messageLine

checkLocalConfig
verifyOrLoginSSO 
verifyEksctlCredentials

verifyCLIutils deploy
verifyAWScredentials

# Verify if an old reservation exists
if [ -f $HOME/.faig/deploy.stat ]; then
  source $HOME/.faig/deploy.stat

  reservation_id=$(aws ec2 describe-capacity-reservations \
    --region "$EKS_REGION" \
    --profile "$AWS_PROFILE" \
    --filters "Name=capacity-reservation-id,Values=$RESERVATION_ID" \
    --query 'CapacityReservations[0].CapacityReservationId' \
    --output text)

  reservation_id=$(aws ec2 describe-capacity-reservations \
    --region "$EKS_REGION" \
    --profile "$AWS_PROFILE" \
    --filters \
      "Name=capacity-reservation-id,Values=$RESERVATION_ID" \
      "Name=state,Values=active" \
    --query 'CapacityReservations[0].CapacityReservationId' \
    --output text)
  [[ "$reservation_id" == "None" ]] && reservation_id=""

  if [ "$reservation_id" != "" ]; then 
    messageTitle "Valid Node Reservation found ($reservation_id) in AWS Region $EKS_REGION"
  else
    multiRegionodeReservation || exit 1
  fi
else
  messageTitle "Search AWS Regions for available GPU Node and Reservate it"
  multiRegionodeReservation || exit 1
fi

# Read lates envuronment variables
source $HOME/.faig/deploy.stat

#echo "EKS_CLUSTER_NAME:$EKS_CLUSTER_NAME"
#echo "EKS_REGION:$EKS_REGION"
#echo "EKS_INSTANCE_TYPE:$EKS_INSTANCE_TYPE"
#echo "RESERVATION_ID:$RESERVATION_ID"
#echo "AZ:$AZ"
#echo "SECOND_AZ:$SECOND_AZ"
#echo "Press Enter to Continue: "; read x

requestACMcertificate "$ROUTE53_HOSTED_ZONE_ID" || exit 1
installEKSCluster || exit 1

#installEFSstorageClass
installALBloadBalancer || exit 1

#deployDemoApp
#deployMCPServerPostgres
#deployMCPServerKubernetes

messageTitle "Install Kubernetes Components"

prepareEFSinfrastructure || exit 1
installEFSCSIDriver || exit 1
installEBSCSIDriver || exit 1

EFS_STORAGE_CLASS=efs-sc-faig EFS_MODE=faig installEFSstorageClass || exit 1
EFS_STORAGE_CLASS=efs-sc      EFS_MODE=shared installEFSstorageClass || exit 1

installNVIDIAdevicePlugin || exit 1
installStorageClassGP3 || exit 1
installFAIGchart || exit 1
installOpenWebUI || exit 1
installMCPFileServer || exit 1

exit

# kubectl -n fortiaigate get ingress


