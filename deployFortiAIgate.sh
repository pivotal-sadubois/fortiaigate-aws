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
#===============================================================================
AWS_REGION="eu-north-1"
EKG_CLUSTER_NAME="eks-genai-fortiaigate"
HOSTED_ZONE_ID="Z0879508I5VL4COU30EV"

[ -f ./functions ] && . ./functions

# Make sure AWS Access credentials are set
if [ -z "$AWS_ACCESS_KEY_ID" -o -z "$AWS_SECRET_ACCESS_KEY" -o -z "$AWS_SESSION_TOKEN" ]; then
  echo "ERROR: AWS Access Credentials are not set, please set them as follows: "
  echo '       export AWS_ACCESS_KEY_ID="XXXXXXXXXXXXXXXXXXXX"'
  echo '       export AWS_SECRET_ACCESS_KEY="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"'
  echo '       export AWS_SESSION_TOKEN="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX..."'
  exit 1
fi

echo "deployFortiAIgate.sh - Deploy FortiAIgate"
echo "by Sacha Dubois, Fortinet"
echo "------------------------------------------------------------------------------------------"

verifyCLIutils
verifyAWScredentials

installEKSCluster
installNodeGroup
installALBloadBalancer
installIngressCertificate $HOSTED_ZONE_ID
deployDemoApp

exit

# kubectl -n fortiaigate get ingress


