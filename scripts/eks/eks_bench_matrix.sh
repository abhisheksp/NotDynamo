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
EXTERNAL_ENDPOINT_MODE="port-forward"
EXTERNAL_LB_WAIT_TIMEOUT_SEC=900
EXTERNAL_LB_SCHEME="internet-facing"
EXTERNAL_LB_TYPE="nlb"
EXTERNAL_LB_HOST=""
EXTERNAL_LB_MANAGE_SERVICE=1
EXTERNAL_LB_KEEP_SERVICE=0

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
INCLUSTER_SKIP_BUILD=0
INCLUSTER_IMAGE=""
INCLUSTER_BENCH_NODE_LABEL=""
INCLUSTER_BENCH_TAINT_EFFECT="NoSchedule"
MATRIX_JSON_OVERRIDE=""
MATRIX_MD_OVERRIDE=""

usage() {
  cat <<'USAGE'
Usage: eks_bench_matrix.sh [options]

Runs benchmark categories for EKS and writes one matrix summary report.

Categories:
  1) External client via port-forward or LoadBalancer/NLB (workstation-driven)
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
  --external-mode <mode>       port-forward|load-balancer (default: port-forward)
  --external-lb-wait-timeout-sec <n>
                                LB endpoint readiness timeout (default: 900)
  --external-lb-scheme <mode>  internet-facing|internal (default: internet-facing)
  --external-lb-type <type>    nlb|classic (default: nlb)
  --external-lb-host <host>    LB host/IP override (skip ingress discovery)
  --external-lb-no-manage-service
                                Do not patch service type/annotations in LB mode
  --external-lb-keep-service-lb
                                Keep service exposed as LB after benchmark

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
  --incluster-skip-build       Reuse existing benchmark image (requires --incluster-image)
  --incluster-image <image>    Benchmark image for in-cluster category
  --incluster-bench-node-label <key=value>
                               Schedule in-cluster benchmark pods only on nodes with this label
                               and add matching toleration
  --incluster-bench-taint-effect <effect>
                               Toleration effect for benchmark node taint
                               (default: NoSchedule)

Output options:
  --matrix-output-file <path>  Override matrix JSON output file
  --matrix-human-report-file <path>
                               Override matrix Markdown output file

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
    --external-mode)
      EXTERNAL_ENDPOINT_MODE="$2"
      shift 2
      ;;
    --external-lb-wait-timeout-sec)
      EXTERNAL_LB_WAIT_TIMEOUT_SEC="$2"
      shift 2
      ;;
    --external-lb-scheme)
      EXTERNAL_LB_SCHEME="$2"
      shift 2
      ;;
    --external-lb-type)
      EXTERNAL_LB_TYPE="$2"
      shift 2
      ;;
    --external-lb-host)
      EXTERNAL_LB_HOST="$2"
      shift 2
      ;;
    --external-lb-no-manage-service)
      EXTERNAL_LB_MANAGE_SERVICE=0
      shift
      ;;
    --external-lb-keep-service-lb)
      EXTERNAL_LB_KEEP_SERVICE=1
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
    --incluster-skip-build)
      INCLUSTER_SKIP_BUILD=1
      shift
      ;;
    --incluster-image)
      INCLUSTER_IMAGE="$2"
      shift 2
      ;;
    --incluster-bench-node-label)
      INCLUSTER_BENCH_NODE_LABEL="$2"
      shift 2
      ;;
    --incluster-bench-taint-effect)
      INCLUSTER_BENCH_TAINT_EFFECT="$2"
      shift 2
      ;;
    --matrix-output-file)
      MATRIX_JSON_OVERRIDE="$2"
      shift 2
      ;;
    --matrix-human-report-file)
      MATRIX_MD_OVERRIDE="$2"
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

for n in \
  "$SERVICE_PORT" "$OPERATIONS" "$KEYSPACE" "$THREADS" "$VALUE_BYTES" \
  "$CONNECT_TIMEOUT_MS" "$REQUEST_TIMEOUT_MS" "$INCLUSTER_PARALLELISM" "$INCLUSTER_COMPLETIONS" \
  "$EXTERNAL_LB_WAIT_TIMEOUT_SEC"
do
  if [[ ! "$n" =~ ^[0-9]+$ ]] || (( n <= 0 )); then
    echo "numeric options must be positive integers" >&2
    exit 1
  fi
done
if [[ "$EXTERNAL_ENDPOINT_MODE" != "port-forward" && "$EXTERNAL_ENDPOINT_MODE" != "load-balancer" ]]; then
  echo "--external-mode must be one of: port-forward, load-balancer" >&2
  exit 1
fi
if [[ "$EXTERNAL_LB_SCHEME" != "internet-facing" && "$EXTERNAL_LB_SCHEME" != "internal" ]]; then
  echo "--external-lb-scheme must be one of: internet-facing, internal" >&2
  exit 1
fi
if [[ "$EXTERNAL_LB_TYPE" != "nlb" && "$EXTERNAL_LB_TYPE" != "classic" ]]; then
  echo "--external-lb-type must be one of: nlb, classic" >&2
  exit 1
fi
if [[ "$INCLUSTER_BENCH_TAINT_EFFECT" != "NoSchedule" && "$INCLUSTER_BENCH_TAINT_EFFECT" != "PreferNoSchedule" && "$INCLUSTER_BENCH_TAINT_EFFECT" != "NoExecute" ]]; then
  echo "--incluster-bench-taint-effect must be one of: NoSchedule, PreferNoSchedule, NoExecute" >&2
  exit 1
fi

if (( RUN_EXTERNAL == 0 && RUN_INCLUSTER == 0 )); then
  echo "at least one category must be enabled" >&2
  exit 1
fi
if (( INCLUSTER_SKIP_BUILD == 1 )) && [[ -z "$INCLUSTER_IMAGE" ]]; then
  echo "--incluster-skip-build requires --incluster-image <image>" >&2
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
EXTERNAL_CATEGORY_KEY="external_client_port_forward"
EXTERNAL_CATEGORY_LABEL="External client via port-forward"
if [[ "$EXTERNAL_ENDPOINT_MODE" == "load-balancer" ]]; then
  EXTERNAL_JSON="$REPORT_DIR/e2e_http_external_lb_${RUN_TS}.json"
  EXTERNAL_MD="$REPORT_DIR/e2e_http_external_lb_${RUN_TS}.md"
  EXTERNAL_CATEGORY_KEY="external_client_load_balancer"
  EXTERNAL_CATEGORY_LABEL="External client via LoadBalancer/NLB"
fi
INCLUSTER_JSON="$REPORT_DIR/e2e_http_incluster_${RUN_TS}.json"
INCLUSTER_MD="$REPORT_DIR/e2e_http_incluster_${RUN_TS}.md"
MATRIX_JSON="$REPORT_DIR/benchmark_matrix_${RUN_TS}.json"
MATRIX_MD="$REPORT_DIR/benchmark_matrix_${RUN_TS}.md"
MATRIX_LATEST_JSON="$REPORT_DIR/benchmark_matrix_latest.json"
MATRIX_LATEST_MD="$REPORT_DIR/benchmark_matrix_latest.md"
if [[ -n "$MATRIX_JSON_OVERRIDE" ]]; then
  MATRIX_JSON="$MATRIX_JSON_OVERRIDE"
fi
if [[ -n "$MATRIX_MD_OVERRIDE" ]]; then
  MATRIX_MD="$MATRIX_MD_OVERRIDE"
fi
if [[ -z "$MATRIX_MD_OVERRIDE" && -n "$MATRIX_JSON_OVERRIDE" ]]; then
  if [[ "$MATRIX_JSON" == *.json ]]; then
    MATRIX_MD="${MATRIX_JSON%.json}.md"
  else
    MATRIX_MD="${MATRIX_JSON}.md"
  fi
fi
if [[ -z "$MATRIX_JSON_OVERRIDE" && -n "$MATRIX_MD_OVERRIDE" ]]; then
  if [[ "$MATRIX_MD" == *.md ]]; then
    MATRIX_JSON="${MATRIX_MD%.md}.json"
  else
    MATRIX_JSON="${MATRIX_MD}.json"
  fi
fi
mkdir -p "$(dirname "$MATRIX_JSON")"
mkdir -p "$(dirname "$MATRIX_MD")"

if ! command -v jq >/dev/null 2>&1; then
  echo "missing required command: jq" >&2
  exit 1
fi

EXTERNAL_STATUS="SKIPPED"
EXTERNAL_RC=0
INCLUSTER_STATUS="SKIPPED"
INCLUSTER_RC=0

if (( RUN_EXTERNAL == 1 )); then
  EXTERNAL_ARGS=(
    --name "$CLUSTER_NAME"
    --region "$REGION"
    --namespace "$NAMESPACE"
    --service "$SERVICE_NAME"
    --service-port "$SERVICE_PORT"
    --endpoint-mode "$EXTERNAL_ENDPOINT_MODE"
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
    --output-file "$EXTERNAL_JSON"
    --human-report-file "$EXTERNAL_MD"
  )
  if [[ "$EXTERNAL_ENDPOINT_MODE" == "load-balancer" ]]; then
    EXTERNAL_ARGS+=(
      --lb-wait-timeout-sec "$EXTERNAL_LB_WAIT_TIMEOUT_SEC"
      --lb-scheme "$EXTERNAL_LB_SCHEME"
      --lb-type "$EXTERNAL_LB_TYPE"
    )
    if [[ -n "$EXTERNAL_LB_HOST" ]]; then
      EXTERNAL_ARGS+=(--lb-host "$EXTERNAL_LB_HOST")
    fi
    if (( EXTERNAL_LB_MANAGE_SERVICE == 0 )); then
      EXTERNAL_ARGS+=(--lb-no-manage-service)
    fi
    if (( EXTERNAL_LB_KEEP_SERVICE == 1 )); then
      EXTERNAL_ARGS+=(--lb-keep-service-lb)
    fi
  fi

  set +e
  "$ROOT_DIR/scripts/eks/eks_bench_http.sh" "${EXTERNAL_ARGS[@]}"
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
  if (( INCLUSTER_SKIP_BUILD == 1 )); then
    INCLUSTER_ARGS+=(--skip-build)
  fi
  if [[ -n "$INCLUSTER_IMAGE" ]]; then
    INCLUSTER_ARGS+=(--image "$INCLUSTER_IMAGE")
  fi
  if [[ -n "$INCLUSTER_BENCH_NODE_LABEL" ]]; then
    INCLUSTER_ARGS+=(
      --bench-node-label "$INCLUSTER_BENCH_NODE_LABEL"
      --bench-taint-effect "$INCLUSTER_BENCH_TAINT_EFFECT"
    )
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
INCLUSTER_TELEM_HINT=""
INCLUSTER_TELEM_CPU_RATIO=""
if [[ -f "$INCLUSTER_JSON" ]]; then
  INCLUSTER_TPS="$(extract_json_value "$INCLUSTER_JSON" '.results.throughput_rps_aggregate')"
  INCLUSTER_P99="$(extract_json_value "$INCLUSTER_JSON" '.results.latency_ms_p99_max_pod')"
  INCLUSTER_ERROR_RATE="$(extract_json_value "$INCLUSTER_JSON" '.results.error_rate_percent')"
  INCLUSTER_TELEM_HINT="$(extract_json_value "$INCLUSTER_JSON" '.telemetry.signals.attribution_hint')"
  INCLUSTER_TELEM_CPU_RATIO="$(extract_json_value "$INCLUSTER_JSON" '.telemetry.signals.generator_to_service_cpu_ratio')"
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
  "external_mode": "$EXTERNAL_ENDPOINT_MODE",
  "incluster_skip_build": "$INCLUSTER_SKIP_BUILD",
  "incluster_image": "$INCLUSTER_IMAGE",
  "incluster_bench_node_label": "$INCLUSTER_BENCH_NODE_LABEL",
  "incluster_bench_taint_effect": "$INCLUSTER_BENCH_TAINT_EFFECT",
  "categories": {
    "${EXTERNAL_CATEGORY_KEY}": {
      "enabled": "$RUN_EXTERNAL",
      "status": "$EXTERNAL_STATUS",
      "exit_code": "$EXTERNAL_RC",
      "report_json": "$EXTERNAL_JSON_REL",
      "report_md": "$EXTERNAL_MD_REL",
      "throughput_rps": "$EXTERNAL_TPS",
      "latency_ms_p99": "$EXTERNAL_P99",
      "error_rate_percent": "$EXTERNAL_ERROR_RATE",
      "endpoint_mode": "$EXTERNAL_ENDPOINT_MODE",
      "lb_scheme": "$EXTERNAL_LB_SCHEME",
      "lb_type": "$EXTERNAL_LB_TYPE",
      "lb_manage_service": "$EXTERNAL_LB_MANAGE_SERVICE"
    },
    "in_cluster_job": {
      "enabled": "$RUN_INCLUSTER",
      "status": "$INCLUSTER_STATUS",
      "exit_code": "$INCLUSTER_RC",
      "skip_build": "$INCLUSTER_SKIP_BUILD",
      "image": "$INCLUSTER_IMAGE",
      "bench_node_label": "$INCLUSTER_BENCH_NODE_LABEL",
      "bench_taint_effect": "$INCLUSTER_BENCH_TAINT_EFFECT",
      "report_json": "$INCLUSTER_JSON_REL",
      "report_md": "$INCLUSTER_MD_REL",
      "throughput_rps_aggregate": "$INCLUSTER_TPS",
      "latency_ms_p99_max_pod": "$INCLUSTER_P99",
      "error_rate_percent": "$INCLUSTER_ERROR_RATE",
      "telemetry_attribution_hint": "$INCLUSTER_TELEM_HINT",
      "telemetry_generator_to_service_cpu_ratio": "$INCLUSTER_TELEM_CPU_RATIO"
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
  echo "- External mode: \`$EXTERNAL_ENDPOINT_MODE\`"
  if (( INCLUSTER_SKIP_BUILD == 1 )); then
    echo "- In-cluster image reuse: \`$INCLUSTER_IMAGE\`"
  fi
  if [[ -n "$INCLUSTER_BENCH_NODE_LABEL" ]]; then
    echo "- In-cluster benchmark node label: \`$INCLUSTER_BENCH_NODE_LABEL\` (\`$INCLUSTER_BENCH_TAINT_EFFECT\`)"
  fi
  echo
  echo "## Categories"
  echo
  echo "| Category | Enabled | Status | Throughput (rps) | p99 (ms) | Error rate (%) | Report |"
  echo "|---|---|---|---|---|---|---|"
  echo "| $EXTERNAL_CATEGORY_LABEL | $RUN_EXTERNAL | $EXTERNAL_STATUS | ${EXTERNAL_TPS:-} | ${EXTERNAL_P99:-} | ${EXTERNAL_ERROR_RATE:-} | $EXTERNAL_MD_DISPLAY |"
  echo "| In-cluster benchmark job | $RUN_INCLUSTER | $INCLUSTER_STATUS | ${INCLUSTER_TPS:-} | ${INCLUSTER_P99:-} | ${INCLUSTER_ERROR_RATE:-} | $INCLUSTER_MD_DISPLAY |"
  if [[ -n "$INCLUSTER_TELEM_HINT" || -n "$INCLUSTER_TELEM_CPU_RATIO" ]]; then
    echo
    echo "## In-Cluster Telemetry Signals"
    echo
    echo "| Signal | Value |"
    echo "|---|---|"
    echo "| Attribution hint | ${INCLUSTER_TELEM_HINT:-} |"
    echo "| Generator/Service CPU ratio | ${INCLUSTER_TELEM_CPU_RATIO:-} |"
  fi
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
