#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CLUSTER_NAME="${NOTDYNAMO_EKS_CLUSTER:-notdynamo-eks}"
REGION="${AWS_REGION:-us-west-2}"
NAMESPACE="notdynamo"
SERVICE_NAME="notdynamo-data"
SERVICE_PORT=8080

RUN_EXTERNAL=1
RUN_INCLUSTER=1

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

INCLUSTER_PARALLELISM=4
INCLUSTER_COMPLETIONS=4
INCLUSTER_KEEP_JOB=0

usage() {
  cat <<'USAGE'
Usage: eks_bench_matrix.sh [options]

Runs benchmark categories for EKS and writes one matrix summary report.

Categories:
  1) External client via kubectl port-forward (workstation-driven)
  2) In-cluster benchmark job (pod-driven)

Cluster/service options:
  --name <cluster-name>        EKS cluster name (default: notdynamo-eks)
  --region <aws-region>        AWS region (default: AWS_REGION or us-west-2)
  --namespace <ns>             Namespace (default: notdynamo)
  --service <name>             Service name (default: notdynamo-data)
  --service-port <n>           Service port (default: 8080)

Category toggles:
  --skip-external              Skip workstation-driven benchmark
  --skip-incluster             Skip in-cluster benchmark

Common benchmark options:
  --operations <n>             Total operations (default: 200000)
  --keyspace <n>               Keyspace size (default: 20000)
  --threads <n>                Threads (default: 32)
  --read-ratio <0..1>          Read ratio (default: 0.90)
  --distribution <name>        uniform|sequential|zipf (default: uniform)
  --zipf-theta <0..1>          Zipf theta (default: 0.90)
  --value-bytes <n>            Value bytes (default: 256)
  --preload <true|false>       Preload (default: true)
  --connect-timeout-ms <n>     Connect timeout (default: 3000)
  --request-timeout-ms <n>     Request timeout (default: 5000)

In-cluster category options:
  --incluster-parallelism <n>  Job parallelism (default: 4)
  --incluster-completions <n>  Job completions (default: 4)
  --incluster-keep-job         Keep in-cluster benchmark job resources

  --help                       Show help
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
    --skip-external)
      RUN_EXTERNAL=0
      shift
      ;;
    --skip-incluster)
      RUN_INCLUSTER=0
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
    --incluster-parallelism)
      INCLUSTER_PARALLELISM="$2"
      shift 2
      ;;
    --incluster-completions)
      INCLUSTER_COMPLETIONS="$2"
      shift 2
      ;;
    --incluster-keep-job)
      INCLUSTER_KEEP_JOB=1
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

for n in \
  "$SERVICE_PORT" "$OPERATIONS" "$KEYSPACE" "$THREADS" "$VALUE_BYTES" \
  "$CONNECT_TIMEOUT_MS" "$REQUEST_TIMEOUT_MS" "$INCLUSTER_PARALLELISM" "$INCLUSTER_COMPLETIONS"
do
  if [[ ! "$n" =~ ^[0-9]+$ ]] || (( n <= 0 )); then
    echo "numeric options must be positive integers" >&2
    exit 1
  fi
done

if (( RUN_EXTERNAL == 0 && RUN_INCLUSTER == 0 )); then
  echo "at least one category must be enabled" >&2
  exit 1
fi

extract_json_value() {
  local file="$1"
  local expr="$2"
  jq -r "$expr // empty" "$file" 2>/dev/null || true
}

RUN_TS="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_DIR="$ROOT_DIR/reports/benchmarks/aws"
mkdir -p "$REPORT_DIR"

EXTERNAL_JSON="$REPORT_DIR/e2e_http_external_${RUN_TS}.json"
EXTERNAL_MD="$REPORT_DIR/e2e_http_external_${RUN_TS}.md"
INCLUSTER_JSON="$REPORT_DIR/e2e_http_incluster_${RUN_TS}.json"
INCLUSTER_MD="$REPORT_DIR/e2e_http_incluster_${RUN_TS}.md"
MATRIX_JSON="$REPORT_DIR/benchmark_matrix_${RUN_TS}.json"
MATRIX_MD="$REPORT_DIR/benchmark_matrix_${RUN_TS}.md"
MATRIX_LATEST_JSON="$REPORT_DIR/benchmark_matrix_latest.json"
MATRIX_LATEST_MD="$REPORT_DIR/benchmark_matrix_latest.md"

if ! command -v jq >/dev/null 2>&1; then
  echo "missing required command: jq" >&2
  exit 1
fi

EXTERNAL_STATUS="SKIPPED"
EXTERNAL_RC=0
INCLUSTER_STATUS="SKIPPED"
INCLUSTER_RC=0

if (( RUN_EXTERNAL == 1 )); then
  set +e
  "$ROOT_DIR/scripts/eks/eks_bench_http.sh" \
    --name "$CLUSTER_NAME" \
    --region "$REGION" \
    --namespace "$NAMESPACE" \
    --service "$SERVICE_NAME" \
    --service-port "$SERVICE_PORT" \
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
    --output-file "$EXTERNAL_JSON" \
    --human-report-file "$EXTERNAL_MD"
  EXTERNAL_RC=$?
  set -e
  if [[ -f "$EXTERNAL_JSON" ]]; then
    EXTERNAL_STATUS="$(extract_json_value "$EXTERNAL_JSON" '.status')"
    if [[ -z "$EXTERNAL_STATUS" ]]; then
      EXTERNAL_STATUS="UNKNOWN"
    fi
  elif (( EXTERNAL_RC != 0 )); then
    EXTERNAL_STATUS="FAIL"
  fi
fi

if (( RUN_INCLUSTER == 1 )); then
  INCLUSTER_ARGS=(
    --name "$CLUSTER_NAME"
    --region "$REGION"
    --namespace "$NAMESPACE"
    --service "$SERVICE_NAME"
    --service-port "$SERVICE_PORT"
    --operations "$OPERATIONS"
    --keyspace "$KEYSPACE"
    --threads "$THREADS"
    --read-ratio "$READ_RATIO"
    --distribution "$DISTRIBUTION"
    --zipf-theta "$ZIPF_THETA"
    --value-bytes "$VALUE_BYTES"
    --preload "$PRELOAD"
    --connect-timeout-ms "$CONNECT_TIMEOUT_MS"
    --request-timeout-ms "$REQUEST_TIMEOUT_MS"
    --parallelism "$INCLUSTER_PARALLELISM"
    --completions "$INCLUSTER_COMPLETIONS"
    --output-file "$INCLUSTER_JSON"
    --human-report-file "$INCLUSTER_MD"
  )
  if (( INCLUSTER_KEEP_JOB == 1 )); then
    INCLUSTER_ARGS+=(--keep-job)
  fi

  set +e
  "$ROOT_DIR/scripts/eks/eks_bench_job_up.sh" "${INCLUSTER_ARGS[@]}"
  INCLUSTER_RC=$?
  set -e
  if [[ -f "$INCLUSTER_JSON" ]]; then
    INCLUSTER_STATUS="$(extract_json_value "$INCLUSTER_JSON" '.status')"
    if [[ -z "$INCLUSTER_STATUS" ]]; then
      INCLUSTER_STATUS="UNKNOWN"
    fi
  elif (( INCLUSTER_RC != 0 )); then
    INCLUSTER_STATUS="FAIL"
  fi
fi

OVERALL_STATUS="PASS"
for status in "$EXTERNAL_STATUS" "$INCLUSTER_STATUS"; do
  case "$status" in
    FAIL|UNKNOWN)
      OVERALL_STATUS="FAIL"
      break
      ;;
    WARN)
      if [[ "$OVERALL_STATUS" != "FAIL" ]]; then
        OVERALL_STATUS="WARN"
      fi
      ;;
  esac
done

if (( RUN_EXTERNAL == 1 )) && (( EXTERNAL_RC != 0 )) && [[ "$EXTERNAL_STATUS" != "FAIL" ]]; then
  OVERALL_STATUS="FAIL"
fi
if (( RUN_INCLUSTER == 1 )) && (( INCLUSTER_RC != 0 )) && [[ "$INCLUSTER_STATUS" != "FAIL" ]]; then
  OVERALL_STATUS="FAIL"
fi

EXTERNAL_TPS=""
EXTERNAL_P99=""
EXTERNAL_ERROR_RATE=""
if [[ -f "$EXTERNAL_JSON" ]]; then
  EXTERNAL_TPS="$(extract_json_value "$EXTERNAL_JSON" '.results.throughput_rps')"
  EXTERNAL_P99="$(extract_json_value "$EXTERNAL_JSON" '.results.latency_ms_p99')"
  EXTERNAL_ERROR_RATE="$(extract_json_value "$EXTERNAL_JSON" '.results.error_rate_percent')"
fi

INCLUSTER_TPS=""
INCLUSTER_P99=""
INCLUSTER_ERROR_RATE=""
if [[ -f "$INCLUSTER_JSON" ]]; then
  INCLUSTER_TPS="$(extract_json_value "$INCLUSTER_JSON" '.results.throughput_rps_aggregate')"
  INCLUSTER_P99="$(extract_json_value "$INCLUSTER_JSON" '.results.latency_ms_p99_max_pod')"
  INCLUSTER_ERROR_RATE="$(extract_json_value "$INCLUSTER_JSON" '.results.error_rate_percent')"
fi

EXTERNAL_JSON_REL=""
EXTERNAL_MD_REL=""
INCLUSTER_JSON_REL=""
INCLUSTER_MD_REL=""
if [[ -f "$EXTERNAL_JSON" ]]; then
  EXTERNAL_JSON_REL="${EXTERNAL_JSON#$ROOT_DIR/}"
fi
if [[ -f "$EXTERNAL_MD" ]]; then
  EXTERNAL_MD_REL="${EXTERNAL_MD#$ROOT_DIR/}"
fi
if [[ -f "$INCLUSTER_JSON" ]]; then
  INCLUSTER_JSON_REL="${INCLUSTER_JSON#$ROOT_DIR/}"
fi
if [[ -f "$INCLUSTER_MD" ]]; then
  INCLUSTER_MD_REL="${INCLUSTER_MD#$ROOT_DIR/}"
fi

EXTERNAL_MD_DISPLAY=""
INCLUSTER_MD_DISPLAY=""
if [[ -n "$EXTERNAL_MD_REL" ]]; then
  EXTERNAL_MD_DISPLAY="\`$EXTERNAL_MD_REL\`"
fi
if [[ -n "$INCLUSTER_MD_REL" ]]; then
  INCLUSTER_MD_DISPLAY="\`$INCLUSTER_MD_REL\`"
fi

cat >"$MATRIX_JSON" <<JSON
{
  "benchmark": "eks_benchmark_matrix",
  "status": "$OVERALL_STATUS",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "cluster_name": "$CLUSTER_NAME",
  "region": "$REGION",
  "namespace": "$NAMESPACE",
  "categories": {
    "external_client_port_forward": {
      "enabled": "$RUN_EXTERNAL",
      "status": "$EXTERNAL_STATUS",
      "exit_code": "$EXTERNAL_RC",
      "report_json": "$EXTERNAL_JSON_REL",
      "report_md": "$EXTERNAL_MD_REL",
      "throughput_rps": "$EXTERNAL_TPS",
      "latency_ms_p99": "$EXTERNAL_P99",
      "error_rate_percent": "$EXTERNAL_ERROR_RATE"
    },
    "in_cluster_job": {
      "enabled": "$RUN_INCLUSTER",
      "status": "$INCLUSTER_STATUS",
      "exit_code": "$INCLUSTER_RC",
      "report_json": "$INCLUSTER_JSON_REL",
      "report_md": "$INCLUSTER_MD_REL",
      "throughput_rps_aggregate": "$INCLUSTER_TPS",
      "latency_ms_p99_max_pod": "$INCLUSTER_P99",
      "error_rate_percent": "$INCLUSTER_ERROR_RATE"
    }
  }
}
JSON

{
  echo "# NotDynamo EKS Benchmark Matrix"
  echo
  echo "- Status: **$OVERALL_STATUS**"
  echo "- Timestamp (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "- Cluster: \`$CLUSTER_NAME\`"
  echo "- Region: \`$REGION\`"
  echo "- Namespace: \`$NAMESPACE\`"
  echo
  echo "## Categories"
  echo
  echo "| Category | Enabled | Status | Throughput (rps) | p99 (ms) | Error rate (%) | Report |"
  echo "|---|---|---|---|---|---|---|"
  echo "| External client via port-forward | $RUN_EXTERNAL | $EXTERNAL_STATUS | ${EXTERNAL_TPS:-} | ${EXTERNAL_P99:-} | ${EXTERNAL_ERROR_RATE:-} | $EXTERNAL_MD_DISPLAY |"
  echo "| In-cluster benchmark job | $RUN_INCLUSTER | $INCLUSTER_STATUS | ${INCLUSTER_TPS:-} | ${INCLUSTER_P99:-} | ${INCLUSTER_ERROR_RATE:-} | $INCLUSTER_MD_DISPLAY |"
} >"$MATRIX_MD"

cp "$MATRIX_JSON" "$MATRIX_LATEST_JSON"
cp "$MATRIX_MD" "$MATRIX_LATEST_MD"

echo "EKS benchmark matrix complete."
echo "JSON summary: $MATRIX_JSON"
echo "Markdown summary: $MATRIX_MD"
echo "Latest JSON: $MATRIX_LATEST_JSON"
echo "Latest Markdown: $MATRIX_LATEST_MD"

if [[ "$OVERALL_STATUS" == "FAIL" ]]; then
  exit 1
fi
