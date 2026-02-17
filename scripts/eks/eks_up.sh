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
API_ENDPOINT_MODE="restricted"
API_PUBLIC_CIDR="${EKS_PUBLIC_CIDR:-}"
EBS_CSI_ADDON_NAME="aws-ebs-csi-driver"
EBS_CSI_IAM_ROLE_NAME="${CLUSTER_NAME}-ebs-csi-role"
EBS_CSI_POLICY_ARN="arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
MAX_DAILY_COST_USD="${NOTDYNAMO_MAX_DAILY_COST_USD:-20}"
ALLOW_OVER_BUDGET="false"
NODE_HOURLY_USD=""
EKS_CONTROL_PLANE_HOURLY_USD="0.10"
EBS_GP3_GB_MONTH_USD="0.08"
NODE_VOLUME_GIB=80

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
  --public-api                Leave API endpoint publicly reachable (not recommended)
  --private-api-only          Disable public API endpoint (requires VPC/VPN access)
  --public-cidr <cidr>        Allowed public API CIDR when restricted mode (default: caller-ip/32)
  --max-daily-usd <amount>    Max allowed estimated daily AWS cost (default: 20)
  --node-hourly-usd <amount>  Override node instance hourly price estimate
  --allow-over-budget         Bypass budget guard (requires explicit user approval)
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
    --public-api)
      API_ENDPOINT_MODE="public"
      shift
      ;;
    --private-api-only)
      API_ENDPOINT_MODE="private"
      shift
      ;;
    --public-cidr)
      API_PUBLIC_CIDR="$2"
      shift 2
      ;;
    --max-daily-usd)
      MAX_DAILY_COST_USD="$2"
      shift 2
      ;;
    --node-hourly-usd)
      NODE_HOURLY_USD="$2"
      shift 2
      ;;
    --allow-over-budget)
      ALLOW_OVER_BUDGET="true"
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

is_positive_number() {
  awk -v value="$1" 'BEGIN { exit !(value ~ /^[0-9]+([.][0-9]+)?$/ && value > 0) }'
}

if ! is_positive_number "$MAX_DAILY_COST_USD"; then
  echo "--max-daily-usd must be a positive number" >&2
  exit 1
fi
if [[ -n "$NODE_HOURLY_USD" ]] && ! is_positive_number "$NODE_HOURLY_USD"; then
  echo "--node-hourly-usd must be a positive number" >&2
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

wait_for_nodegroup_ready() {
  local stack_name="eksctl-${CLUSTER_NAME}-nodegroup-${NODEGROUP_NAME}"
  local status=""
  local attempts=0
  local max_attempts=60

  echo "waiting for nodegroup stack '$stack_name' to become ready..."
  while (( attempts < max_attempts )); do
    status="$(aws cloudformation describe-stacks \
      --stack-name "$stack_name" \
      --region "$REGION" \
      --query 'Stacks[0].StackStatus' \
      --output text 2>/dev/null || true)"

    case "$status" in
      CREATE_COMPLETE|UPDATE_COMPLETE)
        echo "nodegroup stack is ready ($status)."
        return 0
        ;;
      CREATE_IN_PROGRESS|UPDATE_IN_PROGRESS|UPDATE_COMPLETE_CLEANUP_IN_PROGRESS|"")
        sleep 15
        ;;
      *FAILED*|*ROLLBACK*)
        echo "nodegroup stack entered failure state: $status" >&2
        aws cloudformation describe-stack-events \
          --stack-name "$stack_name" \
          --region "$REGION" \
          --max-items 20 \
          --output table || true
        return 1
        ;;
      *)
        sleep 15
        ;;
    esac

    attempts=$((attempts + 1))
  done

  echo "timed out waiting for nodegroup stack '$stack_name'." >&2
  return 1
}

ensure_ebs_csi_addon() {
  local role_arn=""
  local addon_status=""

  echo "ensuring EBS CSI add-on is configured..."
  eksctl utils associate-iam-oidc-provider \
    --cluster "$CLUSTER_NAME" \
    --region "$REGION" \
    --approve >/dev/null

  if ! aws iam get-role --role-name "$EBS_CSI_IAM_ROLE_NAME" >/dev/null 2>&1; then
    eksctl create iamserviceaccount \
      --cluster "$CLUSTER_NAME" \
      --region "$REGION" \
      --namespace kube-system \
      --name ebs-csi-controller-sa \
      --role-name "$EBS_CSI_IAM_ROLE_NAME" \
      --attach-policy-arn "$EBS_CSI_POLICY_ARN" \
      --role-only \
      --approve >/dev/null
  fi

  role_arn="$(aws iam get-role \
    --role-name "$EBS_CSI_IAM_ROLE_NAME" \
    --query 'Role.Arn' \
    --output text)"

  if aws eks describe-addon \
    --cluster-name "$CLUSTER_NAME" \
    --region "$REGION" \
    --addon-name "$EBS_CSI_ADDON_NAME" >/dev/null 2>&1; then
    addon_status="$(aws eks describe-addon \
      --cluster-name "$CLUSTER_NAME" \
      --region "$REGION" \
      --addon-name "$EBS_CSI_ADDON_NAME" \
      --query 'addon.status' \
      --output text || true)"
    if [[ "$addon_status" == "CREATING" || "$addon_status" == "UPDATING" ]]; then
      aws eks wait addon-active \
        --cluster-name "$CLUSTER_NAME" \
        --region "$REGION" \
        --addon-name "$EBS_CSI_ADDON_NAME"
    fi
    aws eks update-addon \
      --cluster-name "$CLUSTER_NAME" \
      --region "$REGION" \
      --addon-name "$EBS_CSI_ADDON_NAME" \
      --service-account-role-arn "$role_arn" \
      --resolve-conflicts OVERWRITE >/dev/null
  else
    aws eks create-addon \
      --cluster-name "$CLUSTER_NAME" \
      --region "$REGION" \
      --addon-name "$EBS_CSI_ADDON_NAME" \
      --service-account-role-arn "$role_arn" \
      --resolve-conflicts OVERWRITE >/dev/null
  fi

  aws eks wait addon-active \
    --cluster-name "$CLUSTER_NAME" \
    --region "$REGION" \
    --addon-name "$EBS_CSI_ADDON_NAME"
}

resolve_public_cidr() {
  if [[ -n "$API_PUBLIC_CIDR" ]]; then
    echo "$API_PUBLIC_CIDR"
    return
  fi

  local ip
  ip="$(curl -fsS https://checkip.amazonaws.com | tr -d '[:space:]' || true)"
  if [[ -z "$ip" ]]; then
    echo "could not determine current public IP for restricted API access." >&2
    echo "provide --public-cidr <cidr> or use --public-api." >&2
    exit 1
  fi
  echo "${ip}/32"
}

resolve_node_hourly_usd() {
  if [[ -n "$NODE_HOURLY_USD" ]]; then
    echo "$NODE_HOURLY_USD"
    return
  fi

  case "$NODE_TYPE" in
    t3.medium) echo "0.0416" ;;
    t3.large) echo "0.0832" ;;
    t3.xlarge) echo "0.1664" ;;
    t3a.medium) echo "0.0376" ;;
    t3a.large) echo "0.0752" ;;
    m6i.large) echo "0.0960" ;;
    m6i.xlarge) echo "0.1920" ;;
    c6i.large) echo "0.0850" ;;
    c6i.xlarge) echo "0.1700" ;;
    *) echo "" ;;
  esac
}

estimate_and_enforce_budget() {
  local node_hourly
  node_hourly="$(resolve_node_hourly_usd)"
  if [[ -z "$node_hourly" ]]; then
    echo "unable to estimate hourly price for node type '$NODE_TYPE'." >&2
    echo "provide --node-hourly-usd <amount> to continue safely." >&2
    exit 1
  fi

  local hourly_cap
  local node_hourly_total
  local ebs_hourly_total
  local estimated_hourly
  local estimated_daily

  hourly_cap="$(awk -v daily="$MAX_DAILY_COST_USD" 'BEGIN { printf "%.6f", daily / 24.0 }')"
  node_hourly_total="$(awk -v price="$node_hourly" -v n="$NODES_MAX" 'BEGIN { printf "%.6f", price * n }')"
  ebs_hourly_total="$(awk -v n="$NODES_MAX" -v gib="$NODE_VOLUME_GIB" -v rate="$EBS_GP3_GB_MONTH_USD" 'BEGIN { printf "%.6f", (n * gib * rate) / 730.0 }')"
  estimated_hourly="$(awk -v cp="$EKS_CONTROL_PLANE_HOURLY_USD" -v nodes="$node_hourly_total" -v ebs="$ebs_hourly_total" 'BEGIN { printf "%.6f", cp + nodes + ebs }')"
  estimated_daily="$(awk -v hourly="$estimated_hourly" 'BEGIN { printf "%.6f", hourly * 24.0 }')"

  echo "estimated max hourly cost (using nodes-max=$NODES_MAX): \$${estimated_hourly}/hour"
  echo "estimated max daily cost: \$${estimated_daily}/day (budget cap: \$${MAX_DAILY_COST_USD}/day)"

  if awk -v est="$estimated_hourly" -v cap="$hourly_cap" 'BEGIN { exit !(est > cap) }'; then
    if [[ "$ALLOW_OVER_BUDGET" != "true" ]]; then
      echo "estimated cost exceeds configured budget cap." >&2
      echo "refusing to create cluster without explicit override." >&2
      echo "if you have explicit approval, re-run with --allow-over-budget." >&2
      exit 1
    fi
    echo "warning: budget cap exceeded, proceeding because --allow-over-budget was provided."
  fi
}

require_bin aws
require_bin eksctl
require_bin kubectl
if [[ "$API_ENDPOINT_MODE" == "restricted" ]]; then
  require_bin curl
fi

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "AWS credentials are not configured or not valid." >&2
  echo "Run: aws configure" >&2
  exit 1
fi

estimate_and_enforce_budget

if cluster_exists; then
  echo "EKS cluster '$CLUSTER_NAME' already exists in region '$REGION'"
  aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" >/dev/null
  ensure_ebs_csi_addon
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
  echo "managedNodeGroups:"
  echo "  - name: $NODEGROUP_NAME"
  echo "    instanceType: $NODE_TYPE"
  echo "    desiredCapacity: $NODES"
  echo "    minSize: $NODES_MIN"
  echo "    maxSize: $NODES_MAX"
  echo "    volumeSize: $NODE_VOLUME_GIB"

  if [[ "$API_ENDPOINT_MODE" == "public" ]]; then
    echo
    echo "vpc:"
    echo "  clusterEndpoints:"
    echo "    publicAccess: true"
    echo "    privateAccess: true"
  elif [[ "$API_ENDPOINT_MODE" == "private" ]]; then
    echo
    echo "vpc:"
    echo "  clusterEndpoints:"
    echo "    publicAccess: false"
    echo "    privateAccess: true"
  else
    PUBLIC_CIDR="$(resolve_public_cidr)"
    echo
    echo "vpc:"
    echo "  clusterEndpoints:"
    echo "    publicAccess: true"
    echo "    privateAccess: true"
    echo "  publicAccessCIDRs:"
    echo "    - \"$PUBLIC_CIDR\""
  fi
} >"$CONFIG_FILE"

eksctl create cluster -f "$CONFIG_FILE"
wait_for_nodegroup_ready
aws eks wait nodegroup-active \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name "$NODEGROUP_NAME" \
  --region "$REGION"
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" >/dev/null
ensure_ebs_csi_addon

kubectl get nodes -o wide

echo

echo "EKS cluster '$CLUSTER_NAME' is ready in '$REGION'."
echo "Next: $ROOT_DIR/scripts/eks/eks_deploy.sh --name $CLUSTER_NAME --region $REGION"
