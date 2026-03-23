#!/bin/bash
#===============================================================================
# SCRIPT NAME:    uploadECR.sh
# DESCRIPTION:    Automated ECR Upload Script (macOS-compatible)
# AUTHOR:         Adrian Sameli / Sacha Dubois, Fortinet
# CREATED:        2026-03-11
# VERSION:        0.1
#===============================================================================
# CHANGE LOG:
# 2026-03-11 sdubois Initial version
#===============================================================================
[ -f ./functions ] && . ./functions
[ -z "$ECR_STAGEDIR" ] && ECR_STAGEDIR=/tmp/faig_$ECR_FORTIAIGATE_TAG

echo ""
echo "uploadECR.sh.sh - Upload FortiAIgate Images to ECR"
echo "by Adrian Sameli / Sacha Dubois, Fortinet"
echo "------------------------------------------------------------------------------------------"

get_ecr_repo() {
  case "$1" in
    api) echo "fortiaigate/api" ;;
    core) echo "fortiaigate/core" ;;
    custom-triton) echo "fortiaigate/custom-triton" ;;
    license_manager) echo "fortiaigate/license_manager" ;;
    logd) echo "fortiaigate/logd" ;;
    scanner) echo "fortiaigate/scanner" ;;
    triton-models) echo "fortiaigate/triton-models" ;;
    webui) echo "fortiaigate/webui" ;;
    *) echo "" ;;
  esac
}

checkLocalConfig 
verifyOrLoginSSO
verifyCLIutils registry
verifyAWScredentials

# ----------------------------------------------------------------------------------------
# Cleaning up ECR Repository - deleting all images that are not tagged ECR_FORTIAIGATE_TAG
# ----------------------------------------------------------------------------------------
tags=$(getImageTags | sort | uniq -c | awk '{ print $2 }')
if [ "$tags" != "" ]; then 
  messageTitle "Cleaning up old FortiAIgate Images from the ECR Repository"
  for tag in $tags; do
    [ "$tag" == "$ECR_FORTIAIGATE_TAG" ] && continue
    deleteImagebyTag $tag
  done
fi

skopeo --version >/dev/null 2>&1; ret=$?
if [ $ret -ne 0 ]; then
  echo "ERROR: skopeo not installed"
  echo "       => brew install skopeo"
  exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity | jq -r '.Account')
ECR_FORTIAIGATE_REPOSITORY="${AWS_ACCOUNT_ID}.dkr.ecr.${ECR_REGION}.amazonaws.com"
SKIP_COMPONENTS=("helm_chart" "helm-chart")

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; }
info() { echo -e "${CYAN}→${NC} $*"; }

if [[ ! -d "$ECR_FORTIAIGATE_SOURCE_DIR" ]]; then
  fail "Directory not found: $ECR_FORTIAIGATE_SOURCE_DIR"; exit 1
fi

ECR_FORTIAIGATE_TAR_FILES=( "$ECR_FORTIAIGATE_SOURCE_DIR"/FAIG_*.tar )
if [[ ${#ECR_FORTIAIGATE_TAR_FILES[@]} -eq 0 || ! -f "${ECR_FORTIAIGATE_TAR_FILES[0]}" ]]; then
  fail "No FAIG_*.tar files found in $ECR_FORTIAIGATE_SOURCE_DIR"; exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo " FortiAIGate ECR Upload"
echo "═══════════════════════════════════════════════════════════════"
echo " TAR directory : $ECR_FORTIAIGATE_SOURCE_DIR"
echo " New tag       : $ECR_FORTIAIGATE_TAG"
echo " ECR registry  : $ECR_FORTIAIGATE_REPOSITORY"
echo " AWS region    : $ECR_REGION"
echo " TAR files     : ${#ECR_FORTIAIGATE_TAR_FILES[@]} found"
echo "═══════════════════════════════════════════════════════════════"
echo ""

info "Logging in to ECR with skopeo …"
aws ecr get-login-password --region "$ECR_REGION" | \
skopeo login --username AWS \
  --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${ECR_REGION}.amazonaws.com"; ret=$?
if [ $ret -ne 0 ]; then
  fail "ECR login failed"
  exit 1
else
  ok "ECR login successful"
fi
echo ""

TOTAL=0; SUCCESS=0; SKIPPED=0; FAILED=0

for TAR_PATH in "${ECR_FORTIAIGATE_TAR_FILES[@]}"; do
  TOTAL=$((TOTAL + 1))
  TAR_FILE=$(basename "$TAR_PATH")
  COMPONENT=$(echo "$TAR_FILE" | sed -E 's/^FAIG_//; s/-V[0-9]+\.[0-9]+\.[0-9]+-build[0-9]+-FORTINET\.tar$//')

  SKIP=false
  for S in "${SKIP_COMPONENTS[@]}"; do
    if [[ "$COMPONENT" == "$S" ]]; then
      SKIP=true
      break
    fi
  done
  if $SKIP; then
    warn "SKIP  $TAR_FILE  (not a Docker image – Helm chart archive)"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  ECR_REPO="$(get_ecr_repo "$COMPONENT")"
  if [[ -z "$ECR_REPO" ]]; then
    fail "UNKNOWN component '$COMPONENT' from $TAR_FILE – add it to get_ecr_repo()"
    FAILED=$((FAILED + 1))
    continue
  fi

  echo "───────────────────────────────────────────────────────────"
  info "Processing: $TAR_FILE"
  info "Component:  $COMPONENT → $ECR_REPO"

  aws ecr describe-repositories --repository-names "$ECR_REPO" \
    --region "$ECR_REGION" >/dev/null 2>&1 \
  || {
    info "Creating ECR repository: $ECR_REPO"
    aws ecr create-repository --repository-name "$ECR_REPO" \
      --region "$ECR_REGION" >/dev/null
  }

  ECR_IMAGE_TAG="${ECR_FORTIAIGATE_REPOSITORY}/${ECR_REPO}:${ECR_FORTIAIGATE_TAG}"
  info "Uploading TAR directly to ECR → $ECR_IMAGE_TAG"

  if skopeo copy \
      "docker-archive:${TAR_PATH}" \
      "docker://${ECR_IMAGE_TAG}" \
      >/tmp/error.log 2>&1
  then
    ok "Pushed: $ECR_IMAGE_TAG"
    SUCCESS=$((SUCCESS + 1))
  else
    fail "Push failed for $ECR_IMAGE_TAG"
    logMessages /tmp/error.log
    FAILED=$((FAILED + 1))
  fi
  echo ""
done

echo "═══════════════════════════════════════════════════════════════"
echo " Upload Summary"
echo "═══════════════════════════════════════════════════════════════"
echo " Total TAR files : $TOTAL"
echo -e " ${GREEN}Pushed OK${NC}       : $SUCCESS"
echo -e " ${YELLOW}Skipped${NC}         : $SKIPPED"
echo -e " ${RED}Failed${NC}          : $FAILED"
echo "═══════════════════════════════════════════════════════════════"

if [[ $FAILED -gt 0 ]]; then
  echo ""
  fail "Some uploads failed. Check output above."
  exit 1
fi

echo ""
ok "All images uploaded to ECR with tag: $ECR_FORTIAIGATE_TAG"

echo " ▪  Write ECR configuration to state file (\$HOME/.faig-ecr-upload.stat)"
echo "export ECR_FORTIAIGATE_REPOSITORY=$ECR_FORTIAIGATE_REPOSITORY"       >  $HOME/.faig-ecr-upload.stat
echo "export ECR_FORTIAIGATE_TAG=$ECR_FORTIAIGATE_TAG"                     >> $HOME/.faig-ecr-upload.stat
echo "export ECR_FORTIAIGATE_SOURCE_DIR=$ECR_FORTIAIGATE_SOURCE_DIR"       >> $HOME/.faig-ecr-upload.stat
echo "export ECR_REGION=$ECR_REGION"                                       >> $HOME/.faig-ecr-upload.stat



exit
