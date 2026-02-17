#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CLUSTER_NAME="${NOTDYNAMO_EKS_CLUSTER:-notdynamo-eks}"
REGION="${AWS_REGION:-us-west-2}"
NAMESPACE="notdynamo"
JOB_NAME=""
SELECTOR="app=notdynamo-bench"

usage() {
  cat <<'USAGE'
Usage: eks_bench_job_down.sh [options]

Deletes in-cluster benchmark job resources created by eks_bench_job_up.sh.

Options:
  --name <cluster-name>    EKS cluster name (default: notdynamo-eks)
  --region <aws-region>    AWS region (default: AWS_REGION or us-west-2)
  --namespace <ns>         Namespace (default: notdynamo)
  --job-name <name>        Delete a specific job by name
  --selector <label=val>   Label selector when deleting jobs (default: app=notdynamo-bench)
  --help                   Show help
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
    --job-name)
      JOB_NAME="$2"
      shift 2
      ;;
    --selector)
      SELECTOR="$2"
      shift 2
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
require_bin kubectl

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "AWS credentials are not configured or not valid." >&2
  echo "Run: aws configure" >&2
  exit 1
fi

if ! cluster_exists; then
  echo "EKS cluster '$CLUSTER_NAME' not found in '$REGION'" >&2
  exit 1
fi

aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" >/dev/null

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "namespace '$NAMESPACE' does not exist in cluster '$CLUSTER_NAME'" >&2
  exit 1
fi

if [[ -n "$JOB_NAME" ]]; then
  kubectl -n "$NAMESPACE" delete job "$JOB_NAME" --ignore-not-found
  echo "Deleted benchmark job (if present): $JOB_NAME"
  exit 0
fi

kubectl -n "$NAMESPACE" delete job -l "$SELECTOR" --ignore-not-found
echo "Deleted benchmark jobs with selector: $SELECTOR"
