#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CLUSTER_NAME="${NOTDYNAMO_EKS_CLUSTER:-notdynamo-eks}"
REGION="${AWS_REGION:-us-west-2}"
NODEGROUP_NAME="notdynamo-benchmark-ng"
NODE_TYPE="t3.medium"
NODES=2
NODES_MIN=2
NODES_MAX=2
BENCH_NODE_LABEL="notdynamo.io/workload=benchmark"
BENCH_NODE_TAINT="notdynamo.io/workload=benchmark:NoSchedule"
WAIT_TIMEOUT_SEC=900

usage() {
  cat <<'USAGE'
Usage: eks_bench_nodegroup_up.sh [options]

Create (or scale) a dedicated EKS nodegroup for benchmark-generator pods.
Nodes are labeled and tainted so benchmark workloads can be isolated from data/control-plane pods.

Options:
  --name <cluster-name>          EKS cluster name (default: notdynamo-eks)
  --region <aws-region>          AWS region (default: AWS_REGION or us-west-2)
  --nodegroup-name <name>        Nodegroup name (default: notdynamo-benchmark-ng)
  --node-type <instance-type>    Node instance type (default: t3.medium)
  --nodes <n>                    Desired node count (default: 2)
  --nodes-min <n>                Min node count (default: 2)
  --nodes-max <n>                Max node count (default: 2)
  --bench-node-label <key=value> Label added to benchmark nodes
                                 (default: notdynamo.io/workload=benchmark)
  --bench-node-taint <k=v:effect>
                                 Taint added to benchmark nodes
                                 (default: notdynamo.io/workload=benchmark:NoSchedule)
  --wait-timeout-sec <n>         Node readiness wait timeout (default: 900)
  --help                         Show help
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
    --bench-node-label)
      BENCH_NODE_LABEL="$2"
      shift 2
      ;;
    --bench-node-taint)
      BENCH_NODE_TAINT="$2"
      shift 2
      ;;
    --wait-timeout-sec)
      WAIT_TIMEOUT_SEC="$2"
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

for n in "$NODES" "$NODES_MIN" "$NODES_MAX" "$WAIT_TIMEOUT_SEC"; do
  if [[ ! "$n" =~ ^[0-9]+$ ]] || (( n <= 0 )); then
    echo "node counts and wait timeout must be positive integers" >&2
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
if [[ "$BENCH_NODE_LABEL" != *=* ]]; then
  echo "--bench-node-label must be in key=value format" >&2
  exit 1
fi
if [[ "$BENCH_NODE_TAINT" != *=*:* ]]; then
  echo "--bench-node-taint must be in key=value:effect format" >&2
  exit 1
fi

LABEL_KEY="${BENCH_NODE_LABEL%%=*}"
LABEL_VALUE="${BENCH_NODE_LABEL#*=}"
if [[ -z "$LABEL_KEY" || -z "$LABEL_VALUE" ]]; then
  echo "--bench-node-label requires non-empty key and value" >&2
  exit 1
fi
LABEL_SELECTOR="${LABEL_KEY}=${LABEL_VALUE}"

TAINT_LEFT="${BENCH_NODE_TAINT%%:*}"
TAINT_EFFECT="${BENCH_NODE_TAINT##*:}"
TAINT_KEY="${TAINT_LEFT%%=*}"
TAINT_VALUE="${TAINT_LEFT#*=}"
if [[ -z "$TAINT_KEY" || -z "$TAINT_VALUE" || -z "$TAINT_EFFECT" ]]; then
  echo "--bench-node-taint requires non-empty key, value, and effect" >&2
  exit 1
fi

require_bin() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

cluster_exists() {
  aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" >/dev/null 2>&1
}

nodegroup_exists() {
  aws eks describe-nodegroup \
    --cluster-name "$CLUSTER_NAME" \
    --region "$REGION" \
    --nodegroup-name "$NODEGROUP_NAME" >/dev/null 2>&1
}

require_bin aws
require_bin eksctl
require_bin kubectl
require_bin jq

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "AWS credentials are not configured or not valid." >&2
  echo "Run: aws configure" >&2
  exit 1
fi

if ! cluster_exists; then
  echo "EKS cluster '$CLUSTER_NAME' not found in region '$REGION'" >&2
  exit 1
fi

if nodegroup_exists; then
  echo "nodegroup '$NODEGROUP_NAME' already exists; scaling to desired target..."
  eksctl scale nodegroup \
    --cluster "$CLUSTER_NAME" \
    --region "$REGION" \
    --name "$NODEGROUP_NAME" \
    --nodes "$NODES" \
    --nodes-min "$NODES_MIN" \
    --nodes-max "$NODES_MAX" \
    --wait >/dev/null
else
  echo "creating benchmark nodegroup '$NODEGROUP_NAME'..."
  CONFIG_FILE="$(mktemp /tmp/notdynamo-bench-nodegroup.XXXXXX.yaml)"
  trap 'rm -f "$CONFIG_FILE"' EXIT
  cat >"$CONFIG_FILE" <<YAML
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: $CLUSTER_NAME
  region: $REGION
managedNodeGroups:
  - name: $NODEGROUP_NAME
    instanceType: $NODE_TYPE
    desiredCapacity: $NODES
    minSize: $NODES_MIN
    maxSize: $NODES_MAX
    labels:
      "$LABEL_KEY": "$LABEL_VALUE"
    taints:
      - key: "$TAINT_KEY"
        value: "$TAINT_VALUE"
        effect: "$TAINT_EFFECT"
YAML
  eksctl create nodegroup -f "$CONFIG_FILE"
fi

aws eks wait nodegroup-active \
  --cluster-name "$CLUSTER_NAME" \
  --region "$REGION" \
  --nodegroup-name "$NODEGROUP_NAME"

aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" >/dev/null

kubectl wait --for=condition=Ready node -l "$LABEL_SELECTOR" --timeout="${WAIT_TIMEOUT_SEC}s" >/dev/null

NODES_JSON="$(kubectl get nodes -l "$LABEL_SELECTOR" -o json)"
HAS_TAINT="$(jq -r \
  --arg k "$TAINT_KEY" \
  --arg v "$TAINT_VALUE" \
  --arg e "$TAINT_EFFECT" \
  'if (.items | length) == 0 then "false" else (all(.items[]; any((.spec.taints // [])[]?; .key==$k and .value==$v and .effect==$e))) end' <<<"$NODES_JSON")"
if [[ "$HAS_TAINT" != "true" ]]; then
  echo "warning: one or more benchmark nodes do not have expected taint '$BENCH_NODE_TAINT'" >&2
fi

echo "benchmark nodegroup is ready."
echo "cluster: $CLUSTER_NAME"
echo "region: $REGION"
echo "nodegroup: $NODEGROUP_NAME"
echo "label selector: $LABEL_SELECTOR"
echo "expected taint: $BENCH_NODE_TAINT"
echo
kubectl get nodes -l "$LABEL_SELECTOR" -o wide
