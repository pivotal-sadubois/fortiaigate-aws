#!/bin/bash
set -euo pipefail
#===============================================================================
# SCRIPT NAME:    deleteECR.sh
# DESCRIPTION:    Delete ECR Repository images by TAG
# AUTHOR:         Sacha Dubois, Fortinet
# CREATED:        2026-03-11
# VERSION:        0.1
#===============================================================================
# CHANGE LOG:
# 2026-03-11 sdubois Initial version
#===============================================================================
[ -f ./functions ] && . ./functions
if [ -f $HOME/.faig/ecr-upload.stat ]; then
   . $HOME/.faig/ecr-upload.stat
else
  echo "ERROR: Config file $HOME/.faig/ecr-upload.stat not available"
  exit
fi

ECR_STAGEDIR=/tmp/faig_$ECR_FORTIAIGATE_TAG

echo ""
echo "deleteECR.sh.sh - Upload FortiAIgate Images to ECR"
echo "by Adrian Sameli / Sacha Dubois, Fortinet"
echo "------------------------------------------------------------------------------------------"

checkLocalConfig
verifyOrLoginSSO
verifyCLIutils registry
verifyAWScredentials

aws ecr describe-repositories \
  --region "$ECR_REGION" \
  --profile "$AWS_PROFILE" \
  --query 'repositories[?starts_with(repositoryName, `fortiaigate/`)].repositoryName' \
  --output table

echo -n "Do you really want to delete the S3 Bucket ? {y/n]: "; read x

if [ "$x" == "y" -o "$x" == "Y" ]; then 
aws ecr describe-repositories \
  --region "$ECR_REGION" \
  --profile "$AWS_PROFILE" \
  --query 'repositories[?starts_with(repositoryName, `fortiaigate/`)].repositoryName' \
  --output text | tr '\t' '\n' | while read repo; do
    echo "Deleting ECR repository: $repo"
    aws ecr delete-repository \
      --repository-name "$repo" \
      --region "$ECR_REGION" \
      --profile "$AWS_PROFILE" \
      --force
done
else
  echo "S3 Bucket NOT deleted"
fi
