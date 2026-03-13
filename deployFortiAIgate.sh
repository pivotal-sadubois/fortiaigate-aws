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
echo "by Sacha Dubois, Fortinet"
echo "------------------------------------------------------------------------------------------"

checkLocalConfig
verifyCLIutils
verifyAWScredentials
verifyAWSRoute53credentials

installEKSCluster
installNodeGroup
installEFSstorageClass
installALBloadBalancer
installIngressCertificate "$ROUT53_HOSTED_ZONE_ID"

deployDemoApp
updateAppDNS "demo-app" "demo.$ROUT53_DOMAIN" "$ROUT53_HOSTED_ZONE_ID"
testAppDNS "demo.$ROUT53_DOMAIN"


exit

# kubectl -n fortiaigate get ingress


