#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CLUSTER_NAME="${NOTDYNAMO_EKS_CLUSTER:-notdynamo-eks}"
REGION="${AWS_REGION:-us-west-2}"
NAMESPACE="notdynamo"
IMAGE_REPO="notdynamo/notdynamo"
DELETE_ECR_REPO=0

usage() {
  cat <<'USAGE'
Usage: eks_down.sh [options]

Deletes NotDynamo application resources and EKS cluster.

Options:
  --name <cluster-name>    EKS cluster name (default: notdynamo-eks)
  --region <aws-region>    AWS region (default: AWS_REGION or us-west-2)
  --namespace <ns>         Namespace to delete first (default: notdynamo)
  --image-repo <repo>      ECR repository (default: notdynamo/notdynamo)
  --delete-ecr-repo        Also delete ECR repo (force)
  --help                   Show this help message
USAGE
}

while (( $# > 0 )); do
  case "$1" in
    --name)
      CLUSTER_NAME="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --image-repo)
      IMAGE_REPO="$2"
      shift 2
      ;;
    --delete-ecr-repo)
      DELETE_ECR_REPO=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_bin() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

cluster_exists() {
  aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" >/dev/null 2>&1
}

require_bin aws
require_bin eksctl

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "AWS credentials are not configured or not valid." >&2
  echo "Run: aws configure" >&2
  exit 1
fi

if cluster_exists; then
  if command -v kubectl >/dev/null 2>&1; then
    aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" >/dev/null || true
    kubectl delete namespace "$NAMESPACE" --ignore-not-found --wait=true --timeout=10m || true
  fi

  eksctl delete cluster --name "$CLUSTER_NAME" --region "$REGION" --wait
  echo "Deleted EKS cluster '$CLUSTER_NAME' in '$REGION'."
else
  echo "EKS cluster '$CLUSTER_NAME' not found in '$REGION'."
fi

if (( DELETE_ECR_REPO == 1 )); then
  if aws ecr describe-repositories --region "$REGION" --repository-names "$IMAGE_REPO" >/dev/null 2>&1; then
    aws ecr delete-repository --region "$REGION" --repository-name "$IMAGE_REPO" --force >/dev/null
    echo "Deleted ECR repository '$IMAGE_REPO' in '$REGION'."
  else
    echo "ECR repository '$IMAGE_REPO' not found in '$REGION'."
  fi
fi

echo
echo "Teardown complete."
if (( DELETE_ECR_REPO == 0 )); then
  echo "Note: ECR repository '$IMAGE_REPO' was kept. Use --delete-ecr-repo to remove it."
fi
echo "To run local benchmarks next: $ROOT_DIR/scripts/bench/run_local_canonical_profile.sh"
