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

export AWS_REGION="eu-north-1"
export EKG_CLUSTER_NAME="ekg-genai-fortiaigate"

[ -f ./functions ] && . ./functions

# Make sure AWS Access credentials are set
if [ -z "$AWS_ACCESS_KEY_ID" -o -z "$AWS_SECRET_ACCESS_KEY" -o -z "$AWS_SESSION_TOKEN" ]; then
  echo "ERROR: AWS Access Credentials are not set, please set them as follows: "
  echo '       export AWS_ACCESS_KEY_ID="XXXXXXXXXXXXXXXXXXXX"'
  echo '       export AWS_SECRET_ACCESS_KEY="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"'
  echo '       export AWS_SESSION_TOKEN="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX..."'
  exit 1
fi

echo "deployFortiAIgate.sh - Demo Self Testing Suite"
echo "by Sacha Dubois, Fortinet"
echo "------------------------------------------------------------------------------------------"

verifyCLIutils
verifyAWScredentials

exit
# 8–10 Very likely to succeed
# 5–7 Might work
# 1–4 High chance of failure
spotscore=$(verifySpotPlacementScrores $AWS_REGION)

messageTitle "AWS EKS Kubernetes Cluster Deployment"
cluster=$(aws eks list-clusters --region $AWS_REGION | jq --arg key "$EKG_CLUSTER_NAME" -r '.clusters[] | select(. == $key)') 
if [ "$cluster" != "$EKG_CLUSTER_NAME" ]; then 
  eksctl create cluster --name "$EKG_CLUSTER_NAME" --region $AWS_REGION --without-nodegroup > /tmp/error.log 2>&1; ret=$?
  if [ $ret -ne 0 ]; then 
    logMessages /tmp/error.log
    echo "ERROR: Cluster creatation failed"
    exit
  fi
else
  stt=$(aws eks describe-cluster --name $EKG_CLUSTER_NAME --region $AWS_REGION --query "cluster.status" --output text --no-cli-pager)
  if [ "$stt" == "ACTIVE" ]; then 
    echo " ▪ EKS Cluster '$EKG_CLUSTER_NAME' already installed with status ($stt)"
  else
    echo "ERROR: Cluster is currently in ($stt) state. Please fix or remove the cluster to proceede"
    exit
  fi
fi

if [ $spotscore -lt 6 ]; then 
  export EKG_NODEGROUP_TYPE=gpu-ondemand-ng
  echo " ▪ To few gpu-spot-ng availability zones in Region: $AWS_REGION, deployeing gpu-ondemand-ng instead"
else
  export EKG_NODEGROUP_TYPE=gpu-spot-ng
  echo " ▪ Trying to go with gpu-ondemand-ng NodeGroups"
fi

# Write configuration to file
echo "export EKG_CLUSTER_NAME=$EKG_CLUSTER_NAME"       >  $HOME/.fortiaigate.cfg
echo "export EKG_NODEGROUP_TYPE=$EKG_NODEGROUP_TYPE"   >> $HOME/.fortiaigate.cfg
echo "export AWS_REGION=$AWS_REGION"                   >> $HOME/.fortiaigate.cfg

nodegroups=$(aws eks list-nodegroups  --cluster-name $EKG_CLUSTER_NAME --region $AWS_REGION  --no-cli-pager | jq -r '.nodegroups[]')
if [ "$nodegroups" == "" ]; then 
  echo " ▪ Creating EKS NodeGroup type $EKG_NODEGROUP_TYPE"
  sed -e "s/CLUSTER/$EKG_CLUSTER_NAME/g" -e "s/REGION/$AWS_REGION/g"  files/${EKG_NODEGROUP_TYPE}-template.yaml > /tmp/${EKG_NODEGROUP_TYPE}.yaml
  eksctl create nodegroup --config-file /tmp/${EKG_NODEGROUP_TYPE}.yaml > /tmp/error.log 2>&1; ret=$?
  if [ $ret -ne 0 ]; then 
    logMessages /tmp/error.log
    echo "ERROR: NodeGroup creatation failed"
    exit
  fi
else
  echo " ▪ EKS NodeGroup for cluster '$EKG_CLUSTER_NAME' already installed"
fi

echo "aws eks list-nodegroups   --cluster-name ekg-genai-fortiaigate   --region eu-west-2   --no-cli-pager"
  

exit


echo "eksctl create nodegroup --config-file files/gpu-spot-ng.yaml"
eksctl create nodegroup --config-file files/gpu-spot-ng.yaml 

# Show Stacks
aws cloudformation list-stacks \
  --region $AWS_REGION \
  --stack-status-filter CREATE_IN_PROGRESS CREATE_FAILED CREATE_COMPLETE ROLLBACK_IN_PROGRESS ROLLBACK_FAILED ROLLBACK_COMPLETE DELETE_IN_PROGRESS DELETE_FAILED UPDATE_IN_PROGRESS UPDATE_COMPLETE_CLEANUP_IN_PROGRESS UPDATE_COMPLETE UPDATE_FAILED UPDATE_ROLLBACK_IN_PROGRESS UPDATE_ROLLBACK_FAILED UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS UPDATE_ROLLBACK_COMPLETE REVIEW_IN_PROGRESS IMPORT_IN_PROGRESS IMPORT_COMPLETE IMPORT_ROLLBACK_IN_PROGRESS IMPORT_ROLLBACK_FAILED IMPORT_ROLLBACK_COMPLETE


