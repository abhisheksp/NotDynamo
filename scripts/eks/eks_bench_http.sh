#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CLUSTER_NAME="${NOTDYNAMO_EKS_CLUSTER:-notdynamo-eks}"
REGION="${AWS_REGION:-us-west-2}"
NAMESPACE="notdynamo"
SERVICE_NAME="notdynamo-data"
SERVICE_PORT=8080
LOCAL_PORT=18080
WAIT_TIMEOUT_SEC=300

OPERATIONS=200000
KEYSPACE=20000
THREADS=32
READ_RATIO=0.90
DISTRIBUTION="uniform"
ZIPF_THETA=0.90
VALUE_BYTES=256
PRELOAD=true
CONNECT_TIMEOUT_MS=3000
REQUEST_TIMEOUT_MS=5000
OUTPUT_FILE=""
HUMAN_REPORT_FILE=""

usage() {
  cat <<'USAGE'
Usage: eks_bench_http.sh [options]

Runs end-to-end HTTP benchmark against EKS-deployed NotDynamo via kubectl port-forward.

Cluster/service options:
  --name <cluster-name>        EKS cluster name (default: notdynamo-eks)
  --region <aws-region>        AWS region (default: AWS_REGION or us-west-2)
  --namespace <ns>             Namespace (default: notdynamo)
  --service <name>             Service name (default: notdynamo-data)
  --service-port <n>           Service port (default: 8080)
  --local-port <n>             Local forwarded port (default: 18080)
  --wait-timeout-sec <n>       Port-forward readiness timeout (default: 300)

Benchmark options:
  --operations <n>             Total operations (default: 200000)
  --keyspace <n>               Keyspace size (default: 20000)
  --threads <n>                Concurrent threads (default: 32)
  --read-ratio <0..1>          Fraction of reads (default: 0.90)
  --distribution <name>        uniform|sequential|zipf (default: uniform)
  --zipf-theta <0..1>          Zipf theta when distribution=zipf (default: 0.90)
  --value-bytes <n>            PUT payload bytes (default: 256)
  --preload <true|false>       Preload keyspace before benchmark (default: true)
  --connect-timeout-ms <n>     HTTP connect timeout (default: 3000)
  --request-timeout-ms <n>     Per-request timeout (default: 5000)
  --output-file <path>         Benchmark report file path
  --human-report-file <path>   Human-readable Markdown report file path
  --help                       Show this help message
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
    --service-port)
      SERVICE_PORT="$2"
      shift 2
      ;;
    --local-port)
      LOCAL_PORT="$2"
      shift 2
      ;;
    --wait-timeout-sec)
      WAIT_TIMEOUT_SEC="$2"
      shift 2
      ;;
    --operations)
      OPERATIONS="$2"
      shift 2
      ;;
    --keyspace)
      KEYSPACE="$2"
      shift 2
      ;;
    --threads)
      THREADS="$2"
      shift 2
      ;;
    --read-ratio)
      READ_RATIO="$2"
      shift 2
      ;;
    --distribution)
      DISTRIBUTION="$2"
      shift 2
      ;;
    --zipf-theta)
      ZIPF_THETA="$2"
      shift 2
      ;;
    --value-bytes)
      VALUE_BYTES="$2"
      shift 2
      ;;
    --preload)
      PRELOAD="$2"
      shift 2
      ;;
    --connect-timeout-ms)
      CONNECT_TIMEOUT_MS="$2"
      shift 2
      ;;
    --request-timeout-ms)
      REQUEST_TIMEOUT_MS="$2"
      shift 2
      ;;
    --output-file)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --human-report-file)
      HUMAN_REPORT_FILE="$2"
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

for n in "$SERVICE_PORT" "$LOCAL_PORT" "$WAIT_TIMEOUT_SEC" "$OPERATIONS" "$KEYSPACE" "$THREADS" "$VALUE_BYTES" "$CONNECT_TIMEOUT_MS" "$REQUEST_TIMEOUT_MS"; do
  if [[ ! "$n" =~ ^[0-9]+$ ]] || (( n <= 0 )); then
    echo "numeric options must be positive integers" >&2
    exit 1
  fi
done

if [[ "$DISTRIBUTION" != "uniform" && "$DISTRIBUTION" != "sequential" && "$DISTRIBUTION" != "zipf" ]]; then
  echo "--distribution must be one of: uniform, sequential, zipf" >&2
  exit 1
fi

case "$PRELOAD" in
  true|false)
    ;;
  *)
    echo "--preload must be true or false" >&2
    exit 1
    ;;
esac

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

aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" >/dev/null

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "namespace '$NAMESPACE' does not exist in cluster '$CLUSTER_NAME'" >&2
  exit 1
fi
if ! kubectl -n "$NAMESPACE" get service "$SERVICE_NAME" >/dev/null 2>&1; then
  echo "service '$SERVICE_NAME' not found in namespace '$NAMESPACE'" >&2
  exit 1
fi

PORT_FORWARD_LOG="/tmp/notdynamo-eks-bench-port-forward.log"
kubectl -n "$NAMESPACE" port-forward "service/${SERVICE_NAME}" "${LOCAL_PORT}:${SERVICE_PORT}" >"$PORT_FORWARD_LOG" 2>&1 &
PF_PID=$!

cleanup() {
  if kill -0 "$PF_PID" >/dev/null 2>&1; then
    kill "$PF_PID" >/dev/null 2>&1 || true
    wait "$PF_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

DEADLINE=$((SECONDS + WAIT_TIMEOUT_SEC))
BASE_URL="http://127.0.0.1:${LOCAL_PORT}"

while (( SECONDS < DEADLINE )); do
  if curl -fsS "${BASE_URL}/healthz" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! curl -fsS "${BASE_URL}/healthz" >/dev/null 2>&1; then
  echo "port-forward did not become ready within ${WAIT_TIMEOUT_SEC}s. See $PORT_FORWARD_LOG" >&2
  exit 1
fi

if [[ -z "$OUTPUT_FILE" ]]; then
  TIMESTAMP_TAG="$(date -u +%Y%m%dT%H%M%SZ)"
  OUTPUT_FILE="$ROOT_DIR/reports/benchmarks/aws/e2e_http_${TIMESTAMP_TAG}.json"
fi
if [[ -z "$HUMAN_REPORT_FILE" ]]; then
  if [[ "$OUTPUT_FILE" == *.json ]]; then
    HUMAN_REPORT_FILE="${OUTPUT_FILE%.json}.md"
  else
    HUMAN_REPORT_FILE="${OUTPUT_FILE}.md"
  fi
fi
mkdir -p "$(dirname "$OUTPUT_FILE")"
mkdir -p "$(dirname "$HUMAN_REPORT_FILE")"

"$ROOT_DIR/scripts/bench/run_e2e_http_profile.sh" \
  --base-url "$BASE_URL" \
  --operations "$OPERATIONS" \
  --keyspace "$KEYSPACE" \
  --threads "$THREADS" \
  --read-ratio "$READ_RATIO" \
  --distribution "$DISTRIBUTION" \
  --zipf-theta "$ZIPF_THETA" \
  --value-bytes "$VALUE_BYTES" \
  --preload "$PRELOAD" \
  --connect-timeout-ms "$CONNECT_TIMEOUT_MS" \
  --request-timeout-ms "$REQUEST_TIMEOUT_MS" \
  --output-file "$OUTPUT_FILE" \
  --human-report-file "$HUMAN_REPORT_FILE"

echo "EKS E2E benchmark complete."
echo "JSON report: $OUTPUT_FILE"
echo "Human report: $HUMAN_REPORT_FILE"
