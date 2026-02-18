#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CLUSTER_NAME="${NOTDYNAMO_EKS_CLUSTER:-notdynamo-eks}"
REGION="${AWS_REGION:-us-west-2}"
NAMESPACE="notdynamo"
SERVICE_NAME="notdynamo-data"
SERVICE_PORT=8080
ENDPOINT_MODE="port-forward"
LOCAL_PORT=18080
WAIT_TIMEOUT_SEC=300
LB_WAIT_TIMEOUT_SEC=900
LB_SCHEME="internet-facing"
LB_TYPE="nlb"
LB_HOST_OVERRIDE=""
LB_MANAGE_SERVICE=1
LB_KEEP_SERVICE_LB=0

LB_TYPE_ANNOTATION_KEY="service.beta.kubernetes.io/aws-load-balancer-type"
LB_SCHEME_ANNOTATION_KEY="service.beta.kubernetes.io/aws-load-balancer-scheme"

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

Runs end-to-end HTTP benchmark against EKS-deployed NotDynamo.

Cluster/service options:
  --name <cluster-name>        EKS cluster name (default: notdynamo-eks)
  --region <aws-region>        AWS region (default: AWS_REGION or us-west-2)
  --namespace <ns>             Namespace (default: notdynamo)
  --service <name>             Service name (default: notdynamo-data)
  --service-port <n>           Service port (default: 8080)
  --endpoint-mode <mode>       port-forward|load-balancer (default: port-forward)
  --local-port <n>             Local forwarded port (default: 18080)
  --wait-timeout-sec <n>       Port-forward readiness timeout (default: 300)
  --lb-wait-timeout-sec <n>    LoadBalancer hostname/IP readiness timeout (default: 900)
  --lb-scheme <scheme>         internet-facing|internal (default: internet-facing)
  --lb-type <type>             nlb|classic (default: nlb)
  --lb-host <host-or-ip>       Override load balancer host/IP (skip service ingress discovery)
  --lb-no-manage-service       Do not patch service type/annotations in load-balancer mode
  --lb-keep-service-lb         Keep service as LoadBalancer after benchmark completion

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
    --endpoint-mode)
      ENDPOINT_MODE="$2"
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
    --lb-wait-timeout-sec)
      LB_WAIT_TIMEOUT_SEC="$2"
      shift 2
      ;;
    --lb-scheme)
      LB_SCHEME="$2"
      shift 2
      ;;
    --lb-type)
      LB_TYPE="$2"
      shift 2
      ;;
    --lb-host)
      LB_HOST_OVERRIDE="$2"
      shift 2
      ;;
    --lb-no-manage-service)
      LB_MANAGE_SERVICE=0
      shift
      ;;
    --lb-keep-service-lb)
      LB_KEEP_SERVICE_LB=1
      shift
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

for n in "$SERVICE_PORT" "$WAIT_TIMEOUT_SEC" "$LB_WAIT_TIMEOUT_SEC" "$OPERATIONS" "$KEYSPACE" "$THREADS" "$VALUE_BYTES" "$CONNECT_TIMEOUT_MS" "$REQUEST_TIMEOUT_MS"; do
  if [[ ! "$n" =~ ^[0-9]+$ ]] || (( n <= 0 )); then
    echo "numeric options must be positive integers" >&2
    exit 1
  fi
done
if [[ ! "$LOCAL_PORT" =~ ^[0-9]+$ ]] || (( LOCAL_PORT <= 0 )); then
  echo "--local-port must be a positive integer" >&2
  exit 1
fi

if [[ "$DISTRIBUTION" != "uniform" && "$DISTRIBUTION" != "sequential" && "$DISTRIBUTION" != "zipf" ]]; then
  echo "--distribution must be one of: uniform, sequential, zipf" >&2
  exit 1
fi
if [[ "$ENDPOINT_MODE" != "port-forward" && "$ENDPOINT_MODE" != "load-balancer" ]]; then
  echo "--endpoint-mode must be one of: port-forward, load-balancer" >&2
  exit 1
fi
if [[ "$LB_SCHEME" != "internet-facing" && "$LB_SCHEME" != "internal" ]]; then
  echo "--lb-scheme must be one of: internet-facing, internal" >&2
  exit 1
fi
if [[ "$LB_TYPE" != "nlb" && "$LB_TYPE" != "classic" ]]; then
  echo "--lb-type must be one of: nlb, classic" >&2
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

set_service_annotation() {
  local key="$1"
  local value="$2"
  kubectl -n "$NAMESPACE" annotate service "$SERVICE_NAME" "$key=$value" --overwrite >/dev/null
}

clear_service_annotation() {
  local key="$1"
  kubectl -n "$NAMESPACE" annotate service "$SERVICE_NAME" "$key-" >/dev/null 2>&1 || true
}

wait_for_healthz() {
  local base_url="$1"
  local wait_timeout_sec="$2"

  local deadline=$((SECONDS + wait_timeout_sec))
  while (( SECONDS < deadline )); do
    if curl -fsS "${base_url}/healthz" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

wait_for_lb_endpoint() {
  local deadline=$((SECONDS + LB_WAIT_TIMEOUT_SEC))
  local host=""
  local ip=""
  local endpoint=""

  while (( SECONDS < deadline )); do
    host="$(kubectl -n "$NAMESPACE" get service "$SERVICE_NAME" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
    ip="$(kubectl -n "$NAMESPACE" get service "$SERVICE_NAME" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
    endpoint="${host:-$ip}"
    if [[ -n "$endpoint" ]]; then
      printf '%s\n' "$endpoint"
      return 0
    fi
    sleep 5
  done
  return 1
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

cleanup() {
  if [[ -n "${PF_PID:-}" ]] && kill -0 "$PF_PID" >/dev/null 2>&1; then
    kill "$PF_PID" >/dev/null 2>&1 || true
    wait "$PF_PID" >/dev/null 2>&1 || true
  fi

  if (( LB_SERVICE_MUTATED == 1 )) && (( LB_KEEP_SERVICE_LB == 0 )); then
    if [[ -n "$LB_ORIGINAL_SERVICE_TYPE" ]]; then
      kubectl -n "$NAMESPACE" patch service "$SERVICE_NAME" --type merge \
        -p "{\"spec\":{\"type\":\"$LB_ORIGINAL_SERVICE_TYPE\"}}" >/dev/null || true
    fi

    if [[ -n "$LB_ORIGINAL_TYPE_ANNOTATION" ]]; then
      set_service_annotation "$LB_TYPE_ANNOTATION_KEY" "$LB_ORIGINAL_TYPE_ANNOTATION"
    else
      clear_service_annotation "$LB_TYPE_ANNOTATION_KEY"
    fi

    if [[ -n "$LB_ORIGINAL_SCHEME_ANNOTATION" ]]; then
      set_service_annotation "$LB_SCHEME_ANNOTATION_KEY" "$LB_ORIGINAL_SCHEME_ANNOTATION"
    else
      clear_service_annotation "$LB_SCHEME_ANNOTATION_KEY"
    fi
  fi
}
trap cleanup EXIT

PF_PID=""
PORT_FORWARD_LOG="/tmp/notdynamo-eks-bench-port-forward.log"
BASE_URL=""
BENCHMARK_CATEGORY="external-client-port-forward"
MODE_SUFFIX="port_forward"
LB_SERVICE_MUTATED=0
LB_ORIGINAL_SERVICE_TYPE=""
LB_ORIGINAL_TYPE_ANNOTATION=""
LB_ORIGINAL_SCHEME_ANNOTATION=""

if [[ "$ENDPOINT_MODE" == "port-forward" ]]; then
  kubectl -n "$NAMESPACE" port-forward "service/${SERVICE_NAME}" "${LOCAL_PORT}:${SERVICE_PORT}" >"$PORT_FORWARD_LOG" 2>&1 &
  PF_PID=$!
  BASE_URL="http://127.0.0.1:${LOCAL_PORT}"
  BENCHMARK_CATEGORY="external-client-port-forward"
  MODE_SUFFIX="port_forward"

  if ! wait_for_healthz "$BASE_URL" "$WAIT_TIMEOUT_SEC"; then
    echo "port-forward did not become ready within ${WAIT_TIMEOUT_SEC}s. See $PORT_FORWARD_LOG" >&2
    exit 1
  fi
else
  BENCHMARK_CATEGORY="external-client-load-balancer"
  MODE_SUFFIX="load_balancer"

  if (( LB_MANAGE_SERVICE == 1 )); then
    LB_ORIGINAL_SERVICE_TYPE="$(kubectl -n "$NAMESPACE" get service "$SERVICE_NAME" -o jsonpath='{.spec.type}' 2>/dev/null || true)"
    LB_ORIGINAL_TYPE_ANNOTATION="$(kubectl -n "$NAMESPACE" get service "$SERVICE_NAME" -o jsonpath='{.metadata.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-type}' 2>/dev/null || true)"
    LB_ORIGINAL_SCHEME_ANNOTATION="$(kubectl -n "$NAMESPACE" get service "$SERVICE_NAME" -o jsonpath='{.metadata.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-scheme}' 2>/dev/null || true)"

    kubectl -n "$NAMESPACE" patch service "$SERVICE_NAME" --type merge -p '{"spec":{"type":"LoadBalancer"}}' >/dev/null
    set_service_annotation "$LB_SCHEME_ANNOTATION_KEY" "$LB_SCHEME"
    if [[ "$LB_TYPE" == "nlb" ]]; then
      set_service_annotation "$LB_TYPE_ANNOTATION_KEY" "nlb"
    else
      clear_service_annotation "$LB_TYPE_ANNOTATION_KEY"
    fi
    LB_SERVICE_MUTATED=1
  fi

  if [[ -n "$LB_HOST_OVERRIDE" ]]; then
    BASE_URL="http://${LB_HOST_OVERRIDE}:${SERVICE_PORT}"
  else
    LB_ENDPOINT="$(wait_for_lb_endpoint || true)"
    if [[ -z "$LB_ENDPOINT" ]]; then
      echo "LoadBalancer endpoint was not assigned within ${LB_WAIT_TIMEOUT_SEC}s." >&2
      kubectl -n "$NAMESPACE" get service "$SERVICE_NAME" -o wide >&2 || true
      exit 1
    fi
    BASE_URL="http://${LB_ENDPOINT}:${SERVICE_PORT}"
  fi

  if ! wait_for_healthz "$BASE_URL" "$LB_WAIT_TIMEOUT_SEC"; then
    echo "load-balancer endpoint did not become healthy within ${LB_WAIT_TIMEOUT_SEC}s: ${BASE_URL}" >&2
    kubectl -n "$NAMESPACE" get service "$SERVICE_NAME" -o wide >&2 || true
    exit 1
  fi
fi

if [[ -z "$OUTPUT_FILE" ]]; then
  TIMESTAMP_TAG="$(date -u +%Y%m%dT%H%M%SZ)"
  if [[ "$ENDPOINT_MODE" == "load-balancer" ]]; then
    OUTPUT_FILE="$ROOT_DIR/reports/benchmarks/aws/e2e_http_external_lb_${TIMESTAMP_TAG}.json"
  else
    OUTPUT_FILE="$ROOT_DIR/reports/benchmarks/aws/e2e_http_external_${TIMESTAMP_TAG}.json"
  fi
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
  --category "$BENCHMARK_CATEGORY" \
  --context "eks:$CLUSTER_NAME/$NAMESPACE/$SERVICE_NAME/mode=$ENDPOINT_MODE" \
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

EXTERNAL_LATEST_JSON="$(dirname "$OUTPUT_FILE")/e2e_http_external_latest.json"
EXTERNAL_LATEST_MD="$(dirname "$HUMAN_REPORT_FILE")/e2e_http_external_latest.md"
EXTERNAL_MODE_LATEST_JSON="$(dirname "$OUTPUT_FILE")/e2e_http_external_${MODE_SUFFIX}_latest.json"
EXTERNAL_MODE_LATEST_MD="$(dirname "$HUMAN_REPORT_FILE")/e2e_http_external_${MODE_SUFFIX}_latest.md"
cp "$OUTPUT_FILE" "$EXTERNAL_LATEST_JSON"
cp "$HUMAN_REPORT_FILE" "$EXTERNAL_LATEST_MD"
cp "$OUTPUT_FILE" "$EXTERNAL_MODE_LATEST_JSON"
cp "$HUMAN_REPORT_FILE" "$EXTERNAL_MODE_LATEST_MD"

echo "EKS E2E benchmark complete."
echo "Endpoint mode: $ENDPOINT_MODE"
echo "Endpoint URL: $BASE_URL"
echo "JSON report: $OUTPUT_FILE"
echo "Human report: $HUMAN_REPORT_FILE"
echo "External latest JSON: $EXTERNAL_LATEST_JSON"
echo "External latest human report: $EXTERNAL_LATEST_MD"
echo "External mode latest JSON: $EXTERNAL_MODE_LATEST_JSON"
echo "External mode latest human report: $EXTERNAL_MODE_LATEST_MD"
