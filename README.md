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

Store them locally, for example: $HOME/Documents/FAIG/build2024 as shown below
```
FAIG_api-V8.0.0-build0024-FORTINET.tar
FAIG_core-V8.0.0-build0024-FORTINET.tar
FAIG_custom-triton-V8.0.0-build0024-FORTINET.tar
FAIG_helm_chart-V8.0.0-build0024-FORTINET.tar
FAIG_license_manager-V8.0.0-build0024-FORTINET.tar
FAIG_logd-V8.0.0-build0024-FORTINET.tar
FAIG_scanner-V8.0.0-build0024-FORTINET.tar
FAIG_triton-models-V8.0.0-build0024-FORTINET.tar
FAIG_webui-V8.0.0-build0024-FORTINET.tar
```

## FortiAIgate (FAIG) AWS Deployment Configuration File
Create the FortiAIgate (.faig) folder and configuraion file: $HOME/.faig/config

Example configuration: $HOME/.faig/config. Create the file and directory if it does not yet exist
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

Make sure the ECR_FORTIAIGATE_SOURCE_DIR is pointing to the directory where you have stored the downloaded files. 

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


## License Files
Register the Lizenses in the Fortinet Support Portal (http://support.fortinet.com) and download the license files to the local $HOME/.faig/licenses directory.
```
$ ls -1 $HOME/.faig/licenses
FAIGCNSD26000092.lic
FAIGCNSD26000093.lic
FAIGCNSD26000094.lic
```

## Install FortiAIgate
```
$ ./deployFortiAIgate.sh
deployFortiAIgate.sh - Deploy FortiAIgate
by Adrian Sameli / Sacha Dubois, Fortinet
------------------------------------------------------------------------------------------------------------------------------------------------------
Force AWS SSO login (profile: AdministratorAccess-149536468416)

Attempting to automatically open the SSO authorization page in your default browser.
If the browser does not open or you wish to use a different device to authorize this request, open the following URL:
https://oidc.us-west-2.amazonaws.com/authorize?response_type=code&client_id=2be1gszgrBlV7JgPuwLlB3VzLXdlc3QtMg&redirect_uri=http%3A%2F%2F127.0.0.1%3A64740%2Foauth%2Fcallback&state=c4ea912c-db64-4764-bd35-2e9eb8351f11&code_challenge_method=S256&scopes=sso%3Aaccount%3Aaccess&code_challenge=oF99dgLf1eW5VB4nYSIUB4NQzCK-cRi_3SkuKr6iYYU

Successfully logged into Start URL: https://fortinet-prod.awsapps.com/start/#
------------------------------------------------------------------------------------------------------------------------------------------------------
AWS SSO login successful (profile: AdministratorAccess-149536468416)
 ▪ Verify AWS/eksctl credentials (profile: AdministratorAccess-149536468416, region: eu-north-1)
 ▪ AWS/eksctl credentials are valid
Verify Installed CLI Utilities
 ▪ AWS CLI ............: aws-cli/2.22.33 Python/3.12.8 Darwin/24.6.0 source/arm64
 ▪ EKS CLI ............: 0.224.0
 ▪ JQ .................: jq-1.7.1
 ▪ Kubectl ............: Client Version: v1.32.0
 ▪ Helm ...............: BuildInfo{Version:v3.16.4
AWS Credentials Access verified
 ▪ AWS User ID ........: AROASFUIRNXAC24XONRD5:sdubois@fortinet.com
 ▪ AWS Account ........: 149536468416
 ▪ AWS ARN ............: arn:aws:sts::149536468416:assumed-role/AWSReservedSSO_AdministratorAccess_c3d75e305b4ee569/sdubois@fortinet.com
 ▪ AWS REGION .........: eu-north-1
AWS Route53 Credentials Access verified
 ▪ AWS User ID ........: AIDAXXXXXXXXXXXXXXXXXXX
 ▪ AWS Account ........: 71440X000000
 ▪ AWS ARN ............: arn:aXs:iam::714490026804:user/fortiaigate
 ▪ AWS REGION .........: eu-ceXtral-1
AWS EKS Kubernetes Cluster DepXoyment
 ▪ Update Kubeconfig for the EXS Cluster
 ▪  Write EKS configuration toXstate file ($HOME/.faig/depliy.stat)
ALB Load Balancer for EKS KubeXnetes Cluster
 ▪ install the ALB Load BalancXr
 ▪ AWS Account ID .......: 149X36462323
 ▪ IAM policy already exists
 ▪ create IAM service account aws-load-balancer-controller
 ▪ Add Helm Repo https://aws.github.io/eks-charts
 ▪ Installing/upgrading AWS Load Balancer Controller...
 ▪ Waiting for deployment to become ready...
Ingress Certificate for ALB Load Balancer
 ▪ Reusing existing ACM certificate
 ▪ CERT_ARN ............: arn:aws:acm:eu-north-1:149536468416:certificate/6d614938-67da-4f2b-839b-908fb4dc23b0
 ▪ Valid ACM certificate already exists
 ▪ CERT_ARN ............: arn:aws:acm:eu-north-1:149536468416:certificate/6d614938-67da-4f2b-839b-908fb4dc23b0
Deploy Demo App for Ingress Test
 ▪ CERT_ARN ............: arn:aws:acm:eu-north-1:149536468416:certificate/6d614938-67da-4f2b-839b-908fb4dc23b0
 ▪ Create Namespace ....: demo-app
 ▪ Install Demo App ....: demo-app
 ▪ Install Ingress .....: demo-app-ingress
 ▪ Waiting for Deployment to become ready...
 ▪ Waiting for Ingress Address...
 ▪ Ingress Address .....: k8s-demoapp-demoappi-2011e77ee5-800956575.eu-north-1.elb.amazonaws.com
Verify Route53 DNS Record for demo-app Application
 ▪ APP_FQDN ............: demo.fortiaigate.fortidemo.ch
 ▪ APP_INGRESS .........: demo-app-ingress
 ▪ ALB_HOSTNAME ........: k8s-demoapp-demoappi-2011e77ee5-800956575.eu-north-1.elb.amazonaws.com
 ▪ OLD_DNS_TARGET ......: k8s-demoapp-demoappi-2011e77ee5-2127514923.eu-north-1.elb.amazonaws.com
 ▪ NEW_DNS_TARGET ......: k8s-demoapp-demoappi-2011e77ee5-800956575.eu-north-1.elb.amazonaws.com
 ▪ Route53 Change ID ...: /change/C0942606340AQ6BLUH2MQ
 ▪ Waiting for Route53 change to become INSYNC...
 ▪ Route53 Status ......: PENDING
 ▪ Route53 Status ......: PENDING
 ▪ Route53 Status ......: PENDING
 ▪ Route53 Status ......: PENDING
 ▪ Route53 Status ......: INSYNC
 ▪ FINAL_DNS_TARGET ....: k8s-demoapp-demoappi-2011e77ee5-800956575.eu-north-1.elb.amazonaws.com
 ▪ Waiting for public DNS propagation...
 ▪ Public DNS (8.8.8.8) : k8s-demoapp-demoappi-2011e77ee5-800956575.eu-north-1.elb.amazonaws.com.
 ▪ Public DNS (1.1.1.1) : k8s-demoapp-demoappi-2011e77ee5-800956575.eu-north-1.elb.amazonaws.com.
 ▪ DNS record successfully propagated
 ▪ Application DNS ready: demo.fortiaigate.fortidemo.ch -> k8s-demoapp-demoappi-2011e77ee5-800956575.eu-north-1.elb.amazonaws.com
Test Application DNS and Connectivity
 ▪ Waiting for public DNS propagation...
 ▪ HTTP Test ...........: http://demo.fortiaigate.fortidemo.ch (succeeded)
 ▪ HTTPS Test ..........: https://demo.fortiaigate.fortidemo.ch (succeeded)
Install Kubernetes Components
Prepare Amazon EFS Infrastructure
 ▪ VPC_ID ...............: vpc-09159e3b299485cf9
 ▪ SUBNET_IDS ...........: subnet-0949b1c96ddfbdffb	subnet-07a7ba50267652c6b	subnet-08a770ddb00ca18f8	subnet-057e281ab2859791d	subnet-02a21a212393f4a27	subnet-0ed1c5ba875e338bf
 ▪ Create EFS filesystem : efs-eks-genai-fortiaigate
 ▪ Create EFS SG ........: efs-eks-genai-fortiaigate-sg
 ▪ Create mount target ..: subnet-0949b1c96ddfbdffb (eun1-az1)
 ▪ Create mount target ..: subnet-07a7ba50267652c6b (eun1-az2)
 ▪ Create mount target ..: subnet-08a770ddb00ca18f8 (eun1-az3)
 ▪ Mount target exists ..: subnet-057e281ab2859791d (eun1-az1)
 ▪ Mount target exists ..: subnet-02a21a212393f4a27 (eun1-az2)
 ▪ Mount target exists ..: subnet-0ed1c5ba875e338bf (eun1-az3)
 ▪ EFS_FILE_SYSTEM_ID ...: fs-05b156a59a6348db1
 ▪ EFS_SECURITY_GROUP_ID : sg-09455226912c15b67
Install Amazon EFS CSI Driver
 ▪ Create / update IAM SA : efs-csi-controller-sa
 ▪ EFS CSI role ARN .....: arn:aws:iam::149536468416:role/eksctl-eks-genai-fortiaigate-addon-iamservice-Role1-494X26JcLVjm
 ▪ Install / upgrade ....: aws-efs-csi-driver
 ▪ EFS CSI driver ready
Amazon EBS CSI Driver for EKS Kubernetes Cluster
 ▪ Installing EBS CSI addon .....: aws-ebs-csi-driver
 ▪ Waiting for EBS CSI addon to become ACTIVE ...
 ▪ EBS CSI addon status ........: CREATING
 ▪ EBS CSI addon status ........: CREATING
 ▪ EBS CSI addon status ........: CREATING
 ▪ EBS CSI addon status ........: ACTIVE
 ▪ Checking Kubernetes EBS CSI pods ...
 ▪ EBS CSI driver is installed and available
Install Amazon EFS StorageClass
 ▪ Apply StorageClass ....: efs-sc-faig (faig)
   ---------------------------------------------------------------------------------------------------------------------
   NAME          PROVISIONER       RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
   efs-sc-faig   efs.csi.aws.com   Delete          Immediate           false                  1s
   -------------------------------------------------------------------------------------------------------------------------------------------------------
Install Amazon EFS StorageClass
 ▪ Apply StorageClass ....: efs-sc (shared)
   ---------------------------------------------------------------------------------------------------------------------
   NAME     PROVISIONER       RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
   efs-sc   efs.csi.aws.com   Delete          Immediate           false                  0s
   -------------------------------------------------------------------------------------------------------------------------------------------------------
 ▪ Install NVIDIA Device Plugin
   ---------------------------------------------------------------------------------------------------------------------
   NAME                                             GPU
   ip-192-168-100-122.eu-north-1.compute.internal   <none>
   ip-192-168-144-226.eu-north-1.compute.internal   <none>
   ip-192-168-151-2.eu-north-1.compute.internal     1
   ---------------------------------------------------------------------------------------------------------------------
 ▪ Install GP3 Storage Class
   ---------------------------------------------------------------------------------------------------------------------
   NAME            PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
   efs-sc          efs.csi.aws.com         Delete          Immediate              false                  4s
   efs-sc-faig     efs.csi.aws.com         Delete          Immediate              false                  6s
   gp2             kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                  12m
   gp3 (default)   ebs.csi.aws.com         Delete          WaitForFirstConsumer   true                   1s
   ---------------------------------------------------------------------------------------------------------------------
 ▪ FortiAIgate Helm Chart Values Files (/tmp/Values.yaml) for rewiew
 ▪ Install Helm Chart (fortiaigate)
Deploy WebUI Ingress
 ▪ CERT_ARN ............: arn:aws:acm:eu-north-1:149536468416:certificate/6d614938-67da-4f2b-839b-908fb4dc23b0
 ▪ Helm Repo https://aws.github.io/eks-charts already installed
 ▪ Install / upgrade ....: open-webui
 ▪ Install Ingress .....: webui-ingress
Verify Route53 DNS Record for webui Application
 ▪ APP_FQDN ............: webui.fortiaigate.fortidemo.ch
 ▪ APP_INGRESS .........: webui-ingress
 ▪ ALB_HOSTNAME ........: k8s-openwebu-webuiing-5f822db0a2-757156407.eu-north-1.elb.amazonaws.com
 ▪ OLD_DNS_TARGET ......: k8s-openwebu-webuiing-5f822db0a2-274151310.eu-north-1.elb.amazonaws.com
 ▪ NEW_DNS_TARGET ......: k8s-openwebu-webuiing-5f822db0a2-757156407.eu-north-1.elb.amazonaws.com
 ▪ Route53 Change ID ...: /change/C01302452T25YHOL331O0
 ▪ Waiting for Route53 change to become INSYNC...
 ▪ Route53 Status ......: PENDING
 ▪ Route53 Status ......: PENDING
 ▪ Route53 Status ......: PENDING
 ▪ Route53 Status ......: PENDING
 ▪ Route53 Status ......: INSYNC
 ▪ FINAL_DNS_TARGET ....: k8s-openwebu-webuiing-5f822db0a2-757156407.eu-north-1.elb.amazonaws.com
 ▪ Waiting for public DNS propagation...
 ▪ Public DNS (8.8.8.8) : k8s-openwebu-webuiing-5f822db0a2-757156407.eu-north-1.elb.amazonaws.com.
 ▪ Public DNS (1.1.1.1) : k8s-openwebu-webuiing-5f822db0a2-757156407.eu-north-1.elb.amazonaws.com.
 ▪ DNS record successfully propagated
 ▪ Application DNS ready: webui.fortiaigate.fortidemo.ch -> k8s-openwebu-webuiing-5f822db0a2-757156407.eu-north-1.elb.amazonaws.com

-------------------------------------------------------------------------------------------------------------------------------------------------------
FortiAIgate Installation Successfully Completed, Access the OpenWeb UI by the following URL:
=> Management Interface...: http://k8s-fortiaig-fortiaig-66e0f5e4a0-1800623312.eu-north-1.elb.amazonaws.com
=> User Web UI ...........: https://webui.fortiaigate.fortidemo.ch
-------------------------------------------------------------------------------------------------------------------------------------------------------
```
```




