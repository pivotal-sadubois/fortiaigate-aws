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

echo ""
echo "deleteFortiAIgate.sh - Deploy FortiAIgate"
echo "by Sacha Dubois, Fortinet"
echo "------------------------------------------------------------------------------------------"

checkLocalConfig
verifyCLIutils
verifyAWScredentials
verifyAWSRoute53credentials

messageTitle "Cleaning-up AWS EKS Kubernetes Cluster Deployment ($EKS_CLUSTER_NAME)"

deleteELBv2LoadBalancer
deleteEKSnodeGroup
deleteEFSstorage
deleteEKScluster

# Cleanup Deployment Files
rm -f $HOME/.fortiaigate.cfg

exit
