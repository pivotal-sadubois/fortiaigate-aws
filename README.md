# FortiAIGate – Automated AWS Deployment

This project provides a fully automated deployment of **FortiAIGate** on AWS.

It builds a complete environment including:

- Amazon EKS Kubernetes cluster
- GPU-enabled worker nodes for AI inference (Triton)
- Persistent storage (EBS + EFS)
- Load-balanced HTTPS access via ALB
- Container image distribution via ECR

The deployment is designed to be **repeatable, script-driven, and unattended**.

---

## AWS Services Used

The deployment relies on the following AWS services:

- **Amazon EKS (Elastic Kubernetes Service)**  
  Managed Kubernetes control plane

- **Amazon EC2**  
  Worker nodes (CPU + GPU instances)

- **Amazon EBS (Elastic Block Store)**  
  Persistent block storage (e.g., `gp3` volumes for stateful workloads)

- **Amazon EFS (Elastic File System)**  
  Shared storage (RWX) for multi-pod access

- **Elastic Load Balancer (ALB)**  
  Ingress and HTTPS termination for applications

- **Amazon ECR (Elastic Container Registry)**  
  Storage for FortiAIGate container images

- **Amazon Route 53**  
  DNS management for application endpoints

- **AWS Certificate Manager (ACM)**  
  TLS certificates for HTTPS endpoints

---

## Prerequisites

Before starting, ensure the following:

- macOS or Linux system with CLI access
- AWS CLI configured with a valid profile
- `eksctl`, `kubectl`, `jq`, and `skopeo` installed
- AWS SSO or IAM access with sufficient permissions
- A Route53 hosted zone (or subdomain delegation)

---

## Preparation

### Clone the Repository

```
bash
FAIG_WORKINGDIR="$HOME/workspace"
mkdir -p "$FAIG_WORKINGDIR"
cd "$FAIG_WORKINGDIR"

git clone https://github.com/<your-org>/fortiaigate-aws.git
cd fortiaigate-aws
```

### Download FortiAIGate Release Files
Download the FortiAIGate release tar files from:
- https://support.fortinet.com
- https://info.fortinet.com

Store them locally, for example: $HOME/Documents/FAIG/build2020 as shown below
```
FAIG_api-V8.0.0-build0020-FORTINET.tar
FAIG_core-V8.0.0-build0020-FORTINET.tar
FAIG_custom-triton-V8.0.0-build0020-FORTINET.tar
FAIG_helm_chart-V8.0.0-build0020-FORTINET.tar
FAIG_license_manager-V8.0.0-build0020-FORTINET.tar
FAIG_logd-V8.0.0-build0020-FORTINET.tar
FAIG_scanner-V8.0.0-build0020-FORTINET.tar
FAIG_triton-models-V8.0.0-build0020-FORTINET.tar
FAIG_webui-V8.0.0-build0020-FORTINET.tar
```

## Create Configuration File
Create the FortiAIgate (.faig) folder and configuraion file: $HOME/.faig/config

Create a configuration directory and file:
```
mkdir -p $HOME/.faig
vi $HOME/.faig/config
```
Example configuration: $HOME/.faig/config
```
AWS_REGION=eu-north-1
EKS_CLUSTER_NAME="eks-genai-fortiaigate"
EKS_ODMD_NG_NODES=1
EKS_SPOT_NG_NODES=3

# EFS Storage Class 
EFS_STORAGE_CLASS="efs-sc-faig"

# AWS Access Credentials
AWS_PROFILE="AdministratorAccess-149536468416"

# AWS Rout54 Access Credentials
ROUTE53_DNS_UPDATES="true"
ROUTE53_HOSTED_ZONE_ID="Z0879508I5VL4COU30EV"
ROUTE53_DOMAIN="fortiaigate.fortidemo.ch"
ROUTE53_REGION="eu-central-1"

# FortiAiGate (FAIG) Configuration
FAIG_LICENSE_DIR=$HOME/.faig/licenses

# AWS RCR Repository Configuration
ECR_FORTIAIGATE_TAG=build0024
ECR_FORTIAIGATE_SOURCE_DIR="$HOME/Documents/FAIG/$ECR_FORTIAIGATE_TAG"
ECR_REGION=$AWS_REGION
```

Make sure the ECR_FORTIAIGATE_SOURCE_DIR is pointing to the directory where you have stored the downloaded files. The directory should look something like this:
```
$ ls -1 $ECR_FORTIAIGATE_SOURCE_DIR
FAIG_api-V8.0.0-build0024-FORTINET.tar
FAIG_core-V8.0.0-build0024-FORTINET.tar
FAIG_custom-triton-V8.0.0-build0024-FORTINET.tar
FAIG_helm_chart-V8.0.0-build0024-FORTINET.tar
FAIG_license_manager-V8.0.0-build0024-FORTINET.tar
FAIG_logd-V8.0.0-build0024-FORTINET.tar
FAIG_scanner-V8.0.0-build0024-FORTINET.tar
FAIG_triton-models-V8.0.0-build0024-FORTINET.tar
FAIG_webui-V8.0.0-build0024-FORTINET.tar
FortiAIGate-8.0.0-Release-Notes.pdf
```
If this has been completed, you can use the 'uploadECR.sh' script to upload the images to the AWS ECR registry.

```
$ ./uploadECR.sh

uploadECR.sh.sh - Upload FortiAIgate Images to ECR
by Adrian Sameli / Sacha Dubois, Fortinet
------------------------------------------------------------------------------------------------------------------------------------------------------
Force AWS SSO login (profile: AdministratorAccess-149536468416)
Attempting to automatically open the SSO authorization page in your default browser.
If the browser does not open or you wish to use a different device to authorize this request, open the following URL:

https://oidc.us-west-2.amazonaws.com/authorize?response_type=code&client_id=2be1gszgrBlV7JgPuwLlB3VzLXdlc3QtMg&redirect_uri=http%3A%2F%2F127.0.0.1%3A55061%2Foauth%2Fcallback&state=d369ffef-11df-4d4a-ab73-2663c133ea7e&code_challenge_method=S256&scopes=sso%3Aaccount%3Aaccess&code_challenge=YXtV4TP8SEM-JeTR9qkfgtLlId9B4kQMO1hLCIs-GhA
Successfully logged into Start URL: https://fortinet-prod.awsapps.com/start/#
------------------------------------------------------------------------------------------------------------------------------------------------------
AWS SSO login successful (profile: AdministratorAccess-149536468416)
Verify Installed CLI Utilities
 ▪ AWS CLI ............: aws-cli/2.22.33 Python/3.12.8 Darwin/24.6.0 source/arm64
 ▪ EKS CLI ............: 0.224.0
 ▪ JQ .................: jq-1.7.1
 ▪ skopeo .............: skopeo version 1.17.0
AWS Credentials Access verified
 ▪ AWS User ID ........: AROASFUIRNXAC24XONRD5:sdubois@fortinet.com
 ▪ AWS Account ........: 149536468416
 ▪ AWS ARN ............: arn:aws:sts::149536468416:assumed-role/AWSReservedSSO_AdministratorAccess_c3d75e305b4ee569/sdubois@fortinet.com
 ▪ AWS REGION .........: eu-north-1
Cleaning up old FortiAIgate Images from the ECR Repository

═══════════════════════════════════════════════════════════════
 FortiAIGate ECR Upload
═══════════════════════════════════════════════════════════════
 TAR directory : /Users/sdubois/Documents/FAIG/build0024
 New tag       : build0024
 ECR registry  : 149536468416.dkr.ecr.eu-north-1.amazonaws.com
 AWS region    : eu-north-1
 TAR files     : 9 found
═══════════════════════════════════════════════════════════════

→ Logging in to ECR with skopeo …
Login Succeeded!
✓ ECR login successful

───────────────────────────────────────────────────────────
→ Processing: FAIG_api-V8.0.0-build0024-FORTINET.tar
→ Component:  api → fortiaigate/api
→ Uploading TAR directly to ECR → 149536468416.dkr.ecr.eu-north-1.amazonaws.com/fortiaigate/api:build0024
✓ Pushed: 149536468416.dkr.ecr.eu-north-1.amazonaws.com/fortiaigate/api:build0024

───────────────────────────────────────────────────────────
→ Processing: FAIG_core-V8.0.0-build0024-FORTINET.tar
→ Component:  core → fortiaigate/core
→ Uploading TAR directly to ECR → 149536468416.dkr.ecr.eu-north-1.amazonaws.com/fortiaigate/core:build0024
✓ Pushed: 149536468416.dkr.ecr.eu-north-1.amazonaws.com/fortiaigate/core:build0024

───────────────────────────────────────────────────────────
→ Processing: FAIG_custom-triton-V8.0.0-build0024-FORTINET.tar
→ Component:  custom-triton → fortiaigate/custom-triton
→ Uploading TAR directly to ECR → 149536468416.dkr.ecr.eu-north-1.amazonaws.com/fortiaigate/custom-triton:build0024
✓ Pushed: 149536468416.dkr.ecr.eu-north-1.amazonaws.com/fortiaigate/custom-triton:build0024

⚠ SKIP  FAIG_helm_chart-V8.0.0-build0024-FORTINET.tar  (not a Docker image – Helm chart archive)
───────────────────────────────────────────────────────────
→ Processing: FAIG_license_manager-V8.0.0-build0024-FORTINET.tar
→ Component:  license_manager → fortiaigate/license_manager
→ Uploading TAR directly to ECR → 149536468416.dkr.ecr.eu-north-1.amazonaws.com/fortiaigate/license_manager:build0024
✓ Pushed: 149536468416.dkr.ecr.eu-north-1.amazonaws.com/fortiaigate/license_manager:build0024

───────────────────────────────────────────────────────────
→ Processing: FAIG_logd-V8.0.0-build0024-FORTINET.tar
→ Component:  logd → fortiaigate/logd
→ Uploading TAR directly to ECR → 149536468416.dkr.ecr.eu-north-1.amazonaws.com/fortiaigate/logd:build0024
✓ Pushed: 149536468416.dkr.ecr.eu-north-1.amazonaws.com/fortiaigate/logd:build0024

───────────────────────────────────────────────────────────
→ Processing: FAIG_scanner-V8.0.0-build0024-FORTINET.tar
→ Component:  scanner → fortiaigate/scanner
→ Uploading TAR directly to ECR → 149536468416.dkr.ecr.eu-north-1.amazonaws.com/fortiaigate/scanner:build0024
✓ Pushed: 149536468416.dkr.ecr.eu-north-1.amazonaws.com/fortiaigate/scanner:build0024

───────────────────────────────────────────────────────────
→ Processing: FAIG_triton-models-V8.0.0-build0024-FORTINET.tar
→ Component:  triton-models → fortiaigate/triton-models
→ Uploading TAR directly to ECR → 149536468416.dkr.ecr.eu-north-1.amazonaws.com/fortiaigate/triton-models:build0024
✓ Pushed: 149536468416.dkr.ecr.eu-north-1.amazonaws.com/fortiaigate/triton-models:build0024

───────────────────────────────────────────────────────────
→ Processing: FAIG_webui-V8.0.0-build0024-FORTINET.tar
→ Component:  webui → fortiaigate/webui
→ Uploading TAR directly to ECR → 149536468416.dkr.ecr.eu-north-1.amazonaws.com/fortiaigate/webui:build0024
✓ Pushed: 149536468416.dkr.ecr.eu-north-1.amazonaws.com/fortiaigate/webui:build0024

═══════════════════════════════════════════════════════════════
 Upload Summary
═══════════════════════════════════════════════════════════════
 Total TAR files : 9
 Pushed OK       : 8
 Skipped         : 1
 Failed          : 0
═══════════════════════════════════════════════════════════════

✓ All images uploaded to ECR with tag: build0024
 ▪  Write ECR configuration to state file ($HOME/.faig/ecr-upload.stat)
```


## Place FortiAIgate License Files
```
$ ls -1 $HOME/.faig/licenses
FAIGCNSD26000092.lic
FAIGCNSD26000093.lic
FAIGCNSD26000094.lic
```
