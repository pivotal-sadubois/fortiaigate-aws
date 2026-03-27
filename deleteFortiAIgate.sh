#!/bin/bash
#===============================================================================
# SCRIPT NAME:    deleteFortiAIgate.sh
# DESCRIPTION:    Delete FortiAIgate Deployment
# AUTHOR:         Sacha Dubois, Fortinet
# CREATED:        2026-03-11
# VERSION:        0.2
#===============================================================================
# CHANGE LOG:
# 2026-03-11 sdubois Initial version
# 2026-03-14 sdubois Wait for cluster stack and repair DELETE_FAILED if needed
#===============================================================================
[ -f ./functions ] && . ./functions
if [ -f $HOME/.faig/config ]; then
   . $HOME/.faig/config
else
  echo "ERROR: Config file $HOME/.faig/config not available"
  exit
fi

echo ""
echo "deleteFortiAIgate.sh - Delete FortiAIgate"
echo "by Adrian Sameli / Sacha Dubois, Fortinet"
messageLine

checkLocalConfig
verifyOrLoginSSO
verifyEksctlCredentials
verifyCLIutils
verifyAWScredentials
verifyAWSRoute53credentials

messageTitle "Uninstall Open WebUI Packages"
helm delete open-webui -n open-webui  > /dev/null 2>&1
kubectl delete ns open-webui > /dev/null 2>&1
waitForNamespaceDeletion open-webui

messageTitle "Uninstall FortiAIgate Packages"
helm delete fortiaigate -n fortiaigate > /dev/null 2>&1
kubectl delete ns fortiaigate > /dev/null 2>&1
waitForNamespaceDeletion fortiaigate

messageTitle "Cleaning-up AWS EKS Kubernetes Cluster Deployment ($EKS_CLUSTER_NAME)"

# ------------------------------------------------------------------------------------------
# Step 1 - Delete application-facing resources first
# ------------------------------------------------------------------------------------------
deleteELBv2LoadBalancer
#deleteEKSnodeGroup
deleteEFSstorage

# ------------------------------------------------------------------------------------------
# Step 2 - Delete EKS cluster
# ------------------------------------------------------------------------------------------
deleteEKScluster
waitForEKSclusterDeletion

# ------------------------------------------------------------------------------------------
# Step 3 - Wait for cluster CloudFormation stack and repair if needed
# ------------------------------------------------------------------------------------------
waitForClusterStackDeletion
repairClusterStackIfNeeded

# ------------------------------------------------------------------------------------------
# Step 4 - Wait for AWS VPC resources to settle
# ------------------------------------------------------------------------------------------
waitForVpcResourcesToSettle

# ------------------------------------------------------------------------------------------
# Step 5 - Wait for cluster CloudFormation stack and repair if needed
# ------------------------------------------------------------------------------------------
waitForClusterStackDeletion
repairClusterStackIfNeeded
waitForClusterStackDeletion
deleteAllStacks

# Cleanup deployment state file only
rm -f $HOME/.fortiaigate.stat

exit
