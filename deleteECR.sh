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
if [ -f $HOME/.faig.cfg ]; then
   . $HOME/.faig.cfg
else
  echo "ERROR: Config file $HOME/.faig.cfg not available"
  exit
fi

STAGEDIR=/tmp/faig_$ECR_FORTIAIGATE_TAG


echo ""
echo "deleteECR.sh.sh - Upload FortiAIgate Images to ECR"
echo "by Adrian Sameli / Sacha Dubois, Fortinet"
echo "------------------------------------------------------------------------------------------"

checkLocalConfig
verifyOrLoginSSO
verifyCLIutils registry
verifyAWScredentials

#deleteImagebyTag
