#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CLUSTER_NAME="${NOTDYNAMO_EKS_CLUSTER:-notdynamo-eks}"
REGION="${AWS_REGION:-us-west-2}"
NAMESPACE="notdynamo"
SERVICE_NAME="notdynamo-data"
SERVICE_PORT=8080
TIMEOUT_SEC=900
KEY="demo-key"
VALUE="hello-notdynamo-eks"

usage() {
  cat <<'USAGE'
Usage: eks_smoke.sh [options]

Runs smoke test against NotDynamo on EKS LoadBalancer endpoint.

Options:
  --name <cluster-name>   EKS cluster name (default: notdynamo-eks)
  --region <aws-region>   AWS region (default: AWS_REGION or us-west-2)
  --namespace <ns>        Namespace (default: notdynamo)
  --service <name>        Service name (default: notdynamo-data)
  --port <n>              Service port (default: 8080)
  --timeout-sec <n>       Endpoint wait timeout (default: 900)
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

for n in "$SERVICE_PORT" "$TIMEOUT_SEC"; do
  if [[ ! "$n" =~ ^[0-9]+$ ]] || (( n <= 0 )); then
    echo "--port and --timeout-sec must be positive integers" >&2
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

DEADLINE=$((SECONDS + TIMEOUT_SEC))
ENDPOINT=""
while (( SECONDS < DEADLINE )); do
  ENDPOINT="$(kubectl -n "$NAMESPACE" get svc "$SERVICE_NAME" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
  if [[ -n "$ENDPOINT" ]]; then
    break
  fi
  sleep 5
done

if [[ -z "$ENDPOINT" ]]; then
  echo "LoadBalancer hostname not assigned within ${TIMEOUT_SEC}s" >&2
  kubectl -n "$NAMESPACE" get svc "$SERVICE_NAME" -o wide >&2 || true
  exit 1
fi

BASE_URL="http://${ENDPOINT}:${SERVICE_PORT}"
echo "Resolved endpoint: $BASE_URL"

for _ in {1..60}; do
  if curl -fsS "${BASE_URL}/healthz" >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

if ! curl -fsS "${BASE_URL}/healthz" >/dev/null 2>&1; then
  echo "endpoint is reachable but /healthz did not return success: $BASE_URL" >&2
  exit 1
fi

"$ROOT_DIR/scripts/local/smoke_http.sh" "$BASE_URL" "$KEY" "$VALUE"

echo
echo "EKS smoke test passed for cluster '$CLUSTER_NAME' in '$REGION'."
