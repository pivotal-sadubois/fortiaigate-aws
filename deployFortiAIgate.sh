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
verifyAWSRoute53credentials

installEKSCluster
#installNodeGroup
#installEFSstorageClass
installALBloadBalancer
installIngressCertificate "$ROUT53_HOSTED_ZONE_ID"

deployDemoApp
updateAppDNS "demo-app" "demo-app" "demo.$ROUT53_DOMAIN" "$ROUT53_HOSTED_ZONE_ID"
testAppDNS "demo.$ROUT53_DOMAIN"

messageTitle "Install Kubernetes Components"

prepareEFSinfrastructure
installEFSCSIDriver
installEBSCSIDriver

EFS_STORAGE_CLASS=efs-sc-faig EFS_MODE=faig installEFSstorageClass
EFS_STORAGE_CLASS=efs-sc      EFS_MODE=shared installEFSstorageClass

installNVIDIAdevicePlugin
installStorageClassGP3
installFAIGchart

installOpenWebUI


exit

# kubectl -n fortiaigate get ingress


