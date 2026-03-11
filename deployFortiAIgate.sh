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

echo "deployFortiAIgate.sh - Deploy FortiAIgate"
echo "by Sacha Dubois, Fortinet"
echo "------------------------------------------------------------------------------------------"

verifyCLIutils
verifyAWScredentials

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

messageTitle "Update Kubeconfig for the EKS Cluster"
aws eks update-kubeconfig --name $EKG_CLUSTER_NAME --region $AWS_REGION


exit

