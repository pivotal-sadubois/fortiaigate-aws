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
'''
FAIG_api-V8.0.0-build0020-FORTINET.tar
FAIG_core-V8.0.0-build0020-FORTINET.tar
FAIG_custom-triton-V8.0.0-build0020-FORTINET.tar
FAIG_helm_chart-V8.0.0-build0020-FORTINET.tar
FAIG_license_manager-V8.0.0-build0020-FORTINET.tar
FAIG_logd-V8.0.0-build0020-FORTINET.tar
FAIG_scanner-V8.0.0-build0020-FORTINET.tar
FAIG_triton-models-V8.0.0-build0020-FORTINET.tar
FAIG_webui-V8.0.0-build0020-FORTINET.tar
'''

## Create Configuration File
Create the FortiAIgate (.faig) folder and configuraion file: $HOME/.faig/config

Create a configuration directory and file:
'''
mkdir -p $HOME/.faig
vi $HOME/.faig/config
'''
Example configuration: $HOME/.faig/config
'''
AWS_REGION=eu-north-1
EKS_CLUSTER_NAME="eks-genai-fortiaigate"
EKS_ODMD_NG_NODES=1
EKS_SPOT_NG_NODES=3

# EFS Storage Class 
EFS_STORAGE_CLASS="efs-sc-faig"

# AWS Access Credentials
AWS_PROFILE="AdministratorAccess-149536468416"

# AWS Rout54 Access Credentials
ROUT53_DNS_UPDATES="true"
ROUT53_HOSTED_ZONE_ID="Z0879508I5VL4COU30EV"
ROUT53_DOMAIN="fortiaigate.fortidemo.ch"
ROUT53_REGION="eu-central-1"

# FortiAiGate (FAIG) Configuration
FAIG_LICENSE_DIR=$HOME/.faig/licenses

# AWS RCR Repository Configuration
ECR_FORTIAIGATE_TAG=build0020
ECR_FORTIAIGATE_SOURCE_DIR="$HOME/Documents/FAIG/$ECR_FORTIAIGATE_TAG"
ECR_REGION=$AWS_REGION
'''

Make sure the ECR_FORTIAIGATE_SOURCE_DIR is pointing to the directory where you have stored the downloaded files.w












