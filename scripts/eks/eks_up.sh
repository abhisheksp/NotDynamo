#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CLUSTER_NAME="${NOTDYNAMO_EKS_CLUSTER:-notdynamo-eks}"
REGION="${AWS_REGION:-us-west-2}"
K8S_VERSION=""
NODEGROUP_NAME="notdynamo-ng"
NODE_TYPE="t3.large"
NODES=2
NODES_MIN=2
NODES_MAX=4

usage() {
  cat <<'USAGE'
Usage: eks_up.sh [options]

Creates an EKS cluster for NotDynamo.

Options:
  --name <cluster-name>       Cluster name (default: notdynamo-eks)
  --region <aws-region>       AWS region (default: AWS_REGION or us-west-2)
  --k8s-version <version>     Kubernetes version (default: eksctl default)
  --nodegroup-name <name>     Managed nodegroup name (default: notdynamo-ng)
  --node-type <type>          EC2 instance type (default: t3.large)
  --nodes <n>                 Desired node count (default: 2)
  --nodes-min <n>             Nodegroup min size (default: 2)
  --nodes-max <n>             Nodegroup max size (default: 4)
  --help                      Show this help message
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
    --k8s-version)
      K8S_VERSION="$2"
      shift 2
      ;;
    --nodegroup-name)
      NODEGROUP_NAME="$2"
      shift 2
      ;;
    --node-type)
      NODE_TYPE="$2"
      shift 2
      ;;
    --nodes)
      NODES="$2"
      shift 2
      ;;
    --nodes-min)
      NODES_MIN="$2"
      shift 2
      ;;
    --nodes-max)
      NODES_MAX="$2"
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

for n in "$NODES" "$NODES_MIN" "$NODES_MAX"; do
  if [[ ! "$n" =~ ^[0-9]+$ ]] || (( n < 1 )); then
    echo "node counts must be positive integers" >&2
    exit 1
  fi
done
if (( NODES_MIN > NODES_MAX )); then
  echo "--nodes-min cannot be greater than --nodes-max" >&2
  exit 1
fi
if (( NODES < NODES_MIN || NODES > NODES_MAX )); then
  echo "--nodes must be between --nodes-min and --nodes-max" >&2
  exit 1
fi

require_bin() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

make_tmp_file() {
  local label="$1"
  if mktemp --version >/dev/null 2>&1; then
    mktemp "/tmp/${label}.XXXXXX"
  else
    mktemp -t "$label"
  fi
}

cluster_exists() {
  aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" >/dev/null 2>&1
}

require_bin aws
require_bin eksctl
require_bin kubectl

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "AWS credentials are not configured or not valid." >&2
  echo "Run: aws configure" >&2
  exit 1
fi

if cluster_exists; then
  echo "EKS cluster '$CLUSTER_NAME' already exists in region '$REGION'"
  aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" >/dev/null
  kubectl get nodes -o wide
  exit 0
fi

CONFIG_FILE="$(make_tmp_file notdynamo-eks-config)"
trap 'rm -f "$CONFIG_FILE"' EXIT

{
  echo "apiVersion: eksctl.io/v1alpha5"
  echo "kind: ClusterConfig"
  echo
  echo "metadata:"
  echo "  name: $CLUSTER_NAME"
  echo "  region: $REGION"
  if [[ -n "$K8S_VERSION" ]]; then
    echo "  version: \"$K8S_VERSION\""
  fi
  echo
  echo "tags:"
  echo "  project: notdynamo"
  echo "  lifecycle: ephemeral"
  echo
  echo "managedNodeGroups:"
  echo "  - name: $NODEGROUP_NAME"
  echo "    instanceType: $NODE_TYPE"
  echo "    desiredCapacity: $NODES"
  echo "    minSize: $NODES_MIN"
  echo "    maxSize: $NODES_MAX"
  echo "    volumeSize: 80"
} >"$CONFIG_FILE"

eksctl create cluster -f "$CONFIG_FILE"
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" >/dev/null

kubectl get nodes -o wide

echo

echo "EKS cluster '$CLUSTER_NAME' is ready in '$REGION'."
echo "Next: $ROOT_DIR/scripts/eks/eks_deploy.sh --name $CLUSTER_NAME --region $REGION"
