#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CLUSTER_NAME="${NOTDYNAMO_EKS_CLUSTER:-notdynamo-eks}"
REGION="${AWS_REGION:-us-west-2}"
NAMESPACE="notdynamo"
SERVICE_NAME="notdynamo-data"
SERVICE_PORT=8080
LOCAL_PORT=18080
TIMEOUT_SEC=300
KEY="demo-key"
VALUE="hello-notdynamo-eks"

usage() {
  cat <<'USAGE'
Usage: eks_smoke.sh [options]

Runs smoke test against NotDynamo on EKS by port-forwarding to the cluster service.

Options:
  --name <cluster-name>   EKS cluster name (default: notdynamo-eks)
  --region <aws-region>   AWS region (default: AWS_REGION or us-west-2)
  --namespace <ns>        Namespace (default: notdynamo)
  --service <name>        Service name (default: notdynamo-data)
  --port <n>              Service port (default: 8080)
  --local-port <n>        Local port for port-forward (default: 18080)
  --timeout-sec <n>       Port-forward wait timeout (default: 300)
  --key <key>             Smoke key (default: demo-key)
  --value <value>         Smoke value (default: hello-notdynamo-eks)
  --help                  Show this help message
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
    --service)
      SERVICE_NAME="$2"
      shift 2
      ;;
    --port)
      SERVICE_PORT="$2"
      shift 2
      ;;
    --local-port)
      LOCAL_PORT="$2"
      shift 2
      ;;
    --timeout-sec)
      TIMEOUT_SEC="$2"
      shift 2
      ;;
    --key)
      KEY="$2"
      shift 2
      ;;
    --value)
      VALUE="$2"
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

for n in "$SERVICE_PORT" "$LOCAL_PORT" "$TIMEOUT_SEC"; do
  if [[ ! "$n" =~ ^[0-9]+$ ]] || (( n <= 0 )); then
    echo "--port, --local-port, and --timeout-sec must be positive integers" >&2
    exit 1
  fi
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
require_bin curl

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "AWS credentials are not configured or not valid." >&2
  echo "Run: aws configure" >&2
  exit 1
fi

if ! cluster_exists; then
  echo "EKS cluster '$CLUSTER_NAME' not found in '$REGION'" >&2
  exit 1
fi

CLUSTER_STATUS="$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.status' --output text)"
if [[ "$CLUSTER_STATUS" != "ACTIVE" ]]; then
  echo "EKS cluster '$CLUSTER_NAME' is not ACTIVE (status=$CLUSTER_STATUS)" >&2
  exit 1
fi

aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" >/dev/null

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "namespace '$NAMESPACE' does not exist in cluster '$CLUSTER_NAME'" >&2
  echo "Run: $ROOT_DIR/scripts/eks/eks_deploy.sh --name $CLUSTER_NAME --region $REGION" >&2
  exit 1
fi

if ! kubectl -n "$NAMESPACE" get service "$SERVICE_NAME" >/dev/null 2>&1; then
  echo "service '$SERVICE_NAME' not found in namespace '$NAMESPACE'" >&2
  exit 1
fi

PORT_FORWARD_LOG="/tmp/notdynamo-eks-port-forward.log"
kubectl -n "$NAMESPACE" port-forward "service/${SERVICE_NAME}" "${LOCAL_PORT}:${SERVICE_PORT}" >"$PORT_FORWARD_LOG" 2>&1 &
PF_PID=$!

cleanup() {
  if kill -0 "$PF_PID" >/dev/null 2>&1; then
    kill "$PF_PID" >/dev/null 2>&1 || true
    wait "$PF_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

DEADLINE=$((SECONDS + TIMEOUT_SEC))
BASE_URL="http://127.0.0.1:${LOCAL_PORT}"
echo "Using local endpoint via port-forward: $BASE_URL"

while (( SECONDS < DEADLINE )); do
  if curl -fsS "${BASE_URL}/healthz" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! curl -fsS "${BASE_URL}/healthz" >/dev/null 2>&1; then
  echo "port-forward did not become ready within ${TIMEOUT_SEC}s. See $PORT_FORWARD_LOG" >&2
  exit 1
fi

"$ROOT_DIR/scripts/local/smoke_http.sh" "$BASE_URL" "$KEY" "$VALUE"

echo
echo "EKS smoke test passed for cluster '$CLUSTER_NAME' in '$REGION'."
