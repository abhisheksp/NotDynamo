#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CLUSTER_NAME="${NOTDYNAMO_EKS_CLUSTER:-notdynamo-eks}"
REGION="${AWS_REGION:-us-west-2}"
NAMESPACE="notdynamo"
SERVICE_NAME="notdynamo-data"
SERVICE_PORT=8080
BASE_URL=""
WAIT_TIMEOUT_SEC=1800

KEYSPACE=20000
VALUE_BYTES=256
READ_RATIO=0.90
DISTRIBUTION="uniform"
PRELOAD=false
SKIP_MAIN=false
K6_VUS=32
K6_DURATION="120s"
K6_SETUP_TIMEOUT="10m"
REQUEST_TIMEOUT_MS=5000
PRELOAD_RETRIES=3
PRELOAD_RETRY_SLEEP_MS=5

JOB_NAME_BASE="notdynamo-bench-k6"
PARALLELISM=4
COMPLETIONS=4
TTL_SECONDS_AFTER_FINISHED=900
KEEP_JOB=0
BENCH_NODE_LABEL=""
BENCH_TAINT_EFFECT="NoSchedule"
DATA_POD_SELECTOR="app=notdynamo-data"
TELEMETRY_SAMPLE_ATTEMPTS=15
TELEMETRY_SAMPLE_INTERVAL_SEC=2
KUBECTL_API_TIMEOUT="20s"

IMAGE="grafana/k6:0.49.0"

OUTPUT_FILE=""
HUMAN_REPORT_FILE=""
EKS_ENDPOINT=""
EKS_CA_FILE=""

usage() {
  cat <<'USAGE'
Usage: eks_bench_job_k6_up.sh [options]

Runs E2E HTTP benchmark from inside EKS as a Kubernetes Job using k6,
then writes JSON + Markdown reports.

Cluster/service options:
  --name <cluster-name>          EKS cluster name (default: notdynamo-eks)
  --region <aws-region>          AWS region (default: AWS_REGION or us-west-2)
  --namespace <ns>               Namespace (default: notdynamo)
  --service <name>               Service name (default: notdynamo-data)
  --service-port <n>             Service port (default: 8080)
  --base-url <url>               Override in-cluster base URL
  --wait-timeout-sec <n>         Job completion timeout (default: 1800)

k6 workload options:
  --keyspace <n>                 Keyspace size (default: 20000)
  --value-bytes <n>              PUT payload bytes (default: 256)
  --read-ratio <0..1>            Read ratio (default: 0.90)
  --distribution <name>          uniform|sequential (default: uniform)
  --preload <true|false>         Preload keyspace in setup() (default: false)
  --skip-main <true|false>       Skip main benchmark loop (default: false)
  --vus <n>                      k6 VUs per pod (default: 32)
  --duration <value>             k6 duration per pod (default: 120s)
  --setup-timeout <value>        k6 setup timeout (default: 10m)
  --request-timeout-ms <n>       HTTP request timeout (default: 5000)
  --preload-retries <n>          Retries per preload key (default: 3)
  --preload-retry-sleep-ms <n>   Backoff base for preload retries (default: 5)

Job options:
  --job-name <name>              Job name prefix (default: notdynamo-bench-k6)
  --parallelism <n>              Job parallelism (default: 4)
  --completions <n>              Job completions (default: 4)
  --ttl-seconds-after-finished <n>
                                 Job TTL after completion (default: 900)
  --keep-job                     Do not delete job/configmap after report generation
  --bench-node-label <key=value> Schedule benchmark pods only on nodes with this label and
                                 add matching toleration (key=value)
  --bench-taint-effect <effect>  Toleration effect for benchmark node taint
                                 (default: NoSchedule)
  --data-pod-selector <selector> Label selector for data/service pods used in telemetry
                                 (default: app=notdynamo-data)
  --telemetry-sample-attempts <n>
                                 Attempts to sample pod metrics while job is running
                                 (default: 15)
  --telemetry-sample-interval-sec <n>
                                 Sleep between telemetry samples (default: 2)

Image/report options:
  --image <image-ref>            k6 image (default: grafana/k6:0.49.0)
  --output-file <path>           Output JSON report path
  --human-report-file <path>     Output Markdown report path
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
    --base-url)
      BASE_URL="$2"
      shift 2
      ;;
    --wait-timeout-sec)
      WAIT_TIMEOUT_SEC="$2"
      shift 2
      ;;
    --keyspace)
      KEYSPACE="$2"
      shift 2
      ;;
    --value-bytes)
      VALUE_BYTES="$2"
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
    --preload)
      PRELOAD="$2"
      shift 2
      ;;
    --skip-main)
      SKIP_MAIN="$2"
      shift 2
      ;;
    --vus)
      K6_VUS="$2"
      shift 2
      ;;
    --duration)
      K6_DURATION="$2"
      shift 2
      ;;
    --setup-timeout)
      K6_SETUP_TIMEOUT="$2"
      shift 2
      ;;
    --request-timeout-ms)
      REQUEST_TIMEOUT_MS="$2"
      shift 2
      ;;
    --preload-retries)
      PRELOAD_RETRIES="$2"
      shift 2
      ;;
    --preload-retry-sleep-ms)
      PRELOAD_RETRY_SLEEP_MS="$2"
      shift 2
      ;;
    --job-name)
      JOB_NAME_BASE="$2"
      shift 2
      ;;
    --parallelism)
      PARALLELISM="$2"
      shift 2
      ;;
    --completions)
      COMPLETIONS="$2"
      shift 2
      ;;
    --ttl-seconds-after-finished)
      TTL_SECONDS_AFTER_FINISHED="$2"
      shift 2
      ;;
    --keep-job)
      KEEP_JOB=1
      shift
      ;;
    --bench-node-label)
      BENCH_NODE_LABEL="$2"
      shift 2
      ;;
    --bench-taint-effect)
      BENCH_TAINT_EFFECT="$2"
      shift 2
      ;;
    --data-pod-selector)
      DATA_POD_SELECTOR="$2"
      shift 2
      ;;
    --telemetry-sample-attempts)
      TELEMETRY_SAMPLE_ATTEMPTS="$2"
      shift 2
      ;;
    --telemetry-sample-interval-sec)
      TELEMETRY_SAMPLE_INTERVAL_SEC="$2"
      shift 2
      ;;
    --image)
      IMAGE="$2"
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

for n in "$SERVICE_PORT" "$WAIT_TIMEOUT_SEC" "$KEYSPACE" "$VALUE_BYTES" "$K6_VUS" "$REQUEST_TIMEOUT_MS" "$PRELOAD_RETRIES" "$PRELOAD_RETRY_SLEEP_MS" "$PARALLELISM" "$COMPLETIONS" "$TTL_SECONDS_AFTER_FINISHED" "$TELEMETRY_SAMPLE_ATTEMPTS" "$TELEMETRY_SAMPLE_INTERVAL_SEC"; do
  if [[ ! "$n" =~ ^[0-9]+$ ]] || (( n <= 0 )); then
    echo "numeric options must be positive integers" >&2
    exit 1
  fi
done

if ! awk -v v="$READ_RATIO" 'BEGIN { exit !(v >= 0.0 && v <= 1.0) }'; then
  echo "--read-ratio must be between 0 and 1" >&2
  exit 1
fi

if [[ "$DISTRIBUTION" != "uniform" && "$DISTRIBUTION" != "sequential" ]]; then
  echo "--distribution must be one of: uniform, sequential" >&2
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

case "$SKIP_MAIN" in
  true|false)
    ;;
  *)
    echo "--skip-main must be true or false" >&2
    exit 1
    ;;
esac

if [[ -n "$BENCH_NODE_LABEL" && "$BENCH_NODE_LABEL" != *=* ]]; then
  echo "--bench-node-label must be in key=value format" >&2
  exit 1
fi

BENCH_NODE_LABEL_KEY=""
BENCH_NODE_LABEL_VALUE=""
if [[ -n "$BENCH_NODE_LABEL" ]]; then
  BENCH_NODE_LABEL_KEY="${BENCH_NODE_LABEL%%=*}"
  BENCH_NODE_LABEL_VALUE="${BENCH_NODE_LABEL#*=}"
  if [[ -z "$BENCH_NODE_LABEL_KEY" || -z "$BENCH_NODE_LABEL_VALUE" ]]; then
    echo "--bench-node-label requires non-empty key and value" >&2
    exit 1
  fi
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

cleanup_direct_kctl() {
  if [[ -n "${EKS_CA_FILE:-}" && -f "$EKS_CA_FILE" ]]; then
    rm -f "$EKS_CA_FILE"
  fi
}

decode_b64_to_file() {
  local b64="$1"
  local out="$2"
  if base64 --help 2>/dev/null | rg -q -- '--decode'; then
    printf '%s' "$b64" | base64 --decode >"$out"
  else
    printf '%s' "$b64" | base64 -D >"$out"
  fi
}

setup_direct_kctl() {
  local cluster_json
  local ca_data
  cluster_json="$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --output json)"
  EKS_ENDPOINT="$(jq -r '.cluster.endpoint // empty' <<<"$cluster_json")"
  ca_data="$(jq -r '.cluster.certificateAuthority.data // empty' <<<"$cluster_json")"

  if [[ -z "$EKS_ENDPOINT" || -z "$ca_data" ]]; then
    echo "failed to resolve EKS endpoint/certificate for cluster '$CLUSTER_NAME'" >&2
    exit 1
  fi

  EKS_CA_FILE="$(mktemp -t notdynamo-eks-ca.XXXXXX)"
  decode_b64_to_file "$ca_data" "$EKS_CA_FILE"
}

kctl() {
  local attempt=1
  local max_attempts=6
  local sleep_sec=1
  local token=""
  local err_msg=""
  local rc=1
  local out_file=""
  local err_file=""

  while (( attempt <= max_attempts )); do
    token="$(aws eks get-token --cluster-name "$CLUSTER_NAME" --region "$REGION" --output json 2>/dev/null | jq -r '.status.token // empty' 2>/dev/null || true)"
    if [[ -z "$token" ]]; then
      err_msg="failed to acquire EKS auth token for cluster '$CLUSTER_NAME'"
      rc=1
    else
      out_file="$(mktemp -t notdynamo-kctl-out.XXXXXX)"
      err_file="$(mktemp -t notdynamo-kctl-err.XXXXXX)"
      if kubectl \
        --server="$EKS_ENDPOINT" \
        --certificate-authority="$EKS_CA_FILE" \
        --token="$token" \
        --request-timeout="$KUBECTL_API_TIMEOUT" \
        "$@" >"$out_file" 2>"$err_file"; then
        cat "$out_file"
        rm -f "$out_file" "$err_file"
        return 0
      fi
      rc=$?
      err_msg="$(cat "$err_file" 2>/dev/null || true)"
      rm -f "$out_file" "$err_file"
      if [[ -z "$err_msg" ]]; then
        err_msg="kubectl command failed with exit code $rc"
      fi
    fi

    if (( attempt >= max_attempts )); then
      echo "$err_msg" >&2
      return "$rc"
    fi

    if printf '%s' "$err_msg" | rg -qi 'context deadline exceeded|timed out|i/o timeout|TLS handshake timeout|unable to connect to the server|connection refused|connection reset by peer|request canceled|EOF|temporarily unavailable|you must be logged in to the server|unauthorized|expiredtoken'; then
      sleep "$sleep_sec"
      if (( sleep_sec < 5 )); then
        sleep_sec=$((sleep_sec + 1))
      fi
      attempt=$((attempt + 1))
      continue
    fi

    echo "$err_msg" >&2
    return "$rc"
  done
}

sanitize_k8s_name() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
}

build_job_name() {
  local base="$1"
  local suffix="$2"
  local max_base_len=$((63 - ${#suffix} - 1))
  if (( max_base_len < 1 )); then
    echo "$suffix"
    return
  fi
  if (( ${#base} > max_base_len )); then
    base="${base:0:max_base_len}"
    base="${base%-}"
  fi
  echo "${base}-${suffix}"
}

is_uint() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

is_num() {
  [[ "$1" =~ ^-?[0-9]+([.][0-9]+)?$ ]]
}

sum_dec() {
  awk -v a="$1" -v b="$2" 'BEGIN { printf "%.6f", (a + 0) + (b + 0) }'
}

max_dec() {
  awk -v a="$1" -v b="$2" 'BEGIN { if ((a + 0) >= (b + 0)) printf "%.6f", (a + 0); else printf "%.6f", (b + 0) }'
}

fmt_dec() {
  local value="$1"
  local digits="$2"
  awk -v a="$value" -v d="$digits" 'BEGIN { printf "%.*f", d, (a + 0) }'
}

fmt_int() {
  local value="$1"
  awk -v a="$value" 'BEGIN { printf "%.0f", (a + 0) }'
}

extract_metric() {
  local file="$1"
  local key="$2"
  if [[ ! -f "$file" ]]; then
    return 0
  fi
  (rg "^${key}=" "$file" | tail -n1 | cut -d'=' -f2-) || true
}

add_error_sample() {
  local sample="$1"
  local sample_file="$2"
  if [[ -z "$sample" ]]; then
    return
  fi
  if rg -Fxq "$sample" "$sample_file" >/dev/null 2>&1; then
    return
  fi
  local count
  count="$(wc -l < "$sample_file" | tr -d '[:space:]')"
  if [[ -z "$count" ]]; then
    count=0
  fi
  if (( count >= 8 )); then
    return
  fi
  echo "$sample" >>"$sample_file"
}

capture_pod_placement() {
  local out_file="$1"
  {
    echo "# benchmark_pods"
    kctl -n "$NAMESPACE" get pods -l "job-name=$RUN_JOB_NAME" -o wide 2>/dev/null || true
    echo
    echo "# data_pods"
    kctl -n "$NAMESPACE" get pods -l "$DATA_POD_SELECTOR" -o wide 2>/dev/null || true
  } >"$out_file"
}

capture_pod_list() {
  local selector="$1"
  local out_file="$2"
  kctl -n "$NAMESPACE" get pods -l "$selector" \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null \
    | sed '/^$/d' >"$out_file" || true
}

write_top_group_summary() {
  local top_file="$1"
  local pod_list_file="$2"
  local out_file="$3"
  if [[ ! -s "$top_file" || ! -s "$pod_list_file" ]]; then
    cat >"$out_file" <<EOF_SUMMARY
pod_count=0
cpu_mcores_sum=0.000
cpu_mcores_avg=0.000
memory_mib_sum=0.000
memory_mib_avg=0.000
EOF_SUMMARY
    return
  fi

  awk '
  function cpu_to_m(v, n) {
    n = v
    if (n ~ /m$/) { sub(/m$/, "", n); return n + 0 }
    return (n + 0) * 1000
  }
  function mem_to_mib(v, n) {
    n = v
    if (n ~ /Ki$/) { sub(/Ki$/, "", n); return (n + 0) / 1024 }
    if (n ~ /Mi$/) { sub(/Mi$/, "", n); return n + 0 }
    if (n ~ /Gi$/) { sub(/Gi$/, "", n); return (n + 0) * 1024 }
    if (n ~ /Ti$/) { sub(/Ti$/, "", n); return (n + 0) * 1048576 }
    return n + 0
  }
  NR == FNR {
    if ($1 != "") wanted[$1] = 1
    next
  }
  {
    name = $1
    if (!(name in wanted)) next
    count++
    cpu_sum += cpu_to_m($2)
    mem_sum += mem_to_mib($3)
  }
  END {
    cpu_avg = (count > 0 ? cpu_sum / count : 0)
    mem_avg = (count > 0 ? mem_sum / count : 0)
    printf "pod_count=%d\n", count
    printf "cpu_mcores_sum=%.3f\n", cpu_sum + 0
    printf "cpu_mcores_avg=%.3f\n", cpu_avg + 0
    printf "memory_mib_sum=%.3f\n", mem_sum + 0
    printf "memory_mib_avg=%.3f\n", mem_avg + 0
  }
  ' "$pod_list_file" "$top_file" >"$out_file"
}

write_nodes_top_summary() {
  local nodes_top_file="$1"
  local out_file="$2"
  if [[ ! -s "$nodes_top_file" ]]; then
    cat >"$out_file" <<EOF_SUMMARY
node_count=0
cpu_mcores_sum=0.000
cpu_percent_max=0.000
memory_mib_sum=0.000
memory_percent_max=0.000
EOF_SUMMARY
    return
  fi

  awk '
  function cpu_to_m(v, n) {
    n = v
    if (n ~ /m$/) { sub(/m$/, "", n); return n + 0 }
    return (n + 0) * 1000
  }
  function mem_to_mib(v, n) {
    n = v
    if (n ~ /Ki$/) { sub(/Ki$/, "", n); return (n + 0) / 1024 }
    if (n ~ /Mi$/) { sub(/Mi$/, "", n); return n + 0 }
    if (n ~ /Gi$/) { sub(/Gi$/, "", n); return (n + 0) * 1024 }
    if (n ~ /Ti$/) { sub(/Ti$/, "", n); return (n + 0) * 1048576 }
    return n + 0
  }
  {
    count++
    cpu_sum += cpu_to_m($2)
    cpu_pct = $3
    gsub(/%/, "", cpu_pct)
    if ((cpu_pct + 0) > cpu_pct_max) cpu_pct_max = cpu_pct + 0
    mem_sum += mem_to_mib($4)
    mem_pct = $5
    gsub(/%/, "", mem_pct)
    if ((mem_pct + 0) > mem_pct_max) mem_pct_max = mem_pct + 0
  }
  END {
    printf "node_count=%d\n", count
    printf "cpu_mcores_sum=%.3f\n", cpu_sum + 0
    printf "cpu_percent_max=%.3f\n", cpu_pct_max + 0
    printf "memory_mib_sum=%.3f\n", mem_sum + 0
    printf "memory_percent_max=%.3f\n", mem_pct_max + 0
  }
  ' "$nodes_top_file" >"$out_file"
}

sample_telemetry_snapshot() {
  local prev_bench_count=0
  local new_bench_count=0
  local file=""

  prev_bench_count="$(extract_metric "$BENCH_TOP_SUMMARY_FILE" "pod_count")"
  if ! is_uint "${prev_bench_count:-}"; then
    prev_bench_count=0
  fi

  for file in "$BENCH_PODS_FILE" "$DATA_PODS_FILE" "$PODS_TOP_FILE" "$PODS_TOP_ERR_FILE" "$BENCH_TOP_SUMMARY_FILE" "$DATA_TOP_SUMMARY_FILE"; do
    if [[ -f "$file" ]]; then
      cp "$file" "${file}.prev"
    fi
  done

  capture_pod_placement "$POD_PLACEMENT_FILE"
  capture_pod_list "job-name=$RUN_JOB_NAME" "$BENCH_PODS_FILE"
  capture_pod_list "$DATA_POD_SELECTOR" "$DATA_PODS_FILE"

  if kctl -n "$NAMESPACE" top pods --no-headers >"$PODS_TOP_FILE" 2>"$PODS_TOP_ERR_FILE"; then
    TELEMETRY_PODS_TOP_AVAILABLE="true"
  fi
  write_top_group_summary "$PODS_TOP_FILE" "$BENCH_PODS_FILE" "$BENCH_TOP_SUMMARY_FILE"
  write_top_group_summary "$PODS_TOP_FILE" "$DATA_PODS_FILE" "$DATA_TOP_SUMMARY_FILE"

  if kctl top nodes --no-headers >"$NODES_TOP_FILE" 2>"$NODES_TOP_ERR_FILE"; then
    TELEMETRY_NODES_TOP_AVAILABLE="true"
  fi
  write_nodes_top_summary "$NODES_TOP_FILE" "$NODES_TOP_SUMMARY_FILE"

  new_bench_count="$(extract_metric "$BENCH_TOP_SUMMARY_FILE" "pod_count")"
  if ! is_uint "${new_bench_count:-}"; then
    new_bench_count=0
  fi

  # Preserve the best non-zero benchmark pod sample; do not let post-completion
  # snapshots overwrite useful in-flight generator telemetry.
  if (( prev_bench_count > 0 && new_bench_count == 0 )); then
    for file in "$BENCH_PODS_FILE" "$DATA_PODS_FILE" "$PODS_TOP_FILE" "$PODS_TOP_ERR_FILE" "$BENCH_TOP_SUMMARY_FILE" "$DATA_TOP_SUMMARY_FILE"; do
      if [[ -f "${file}.prev" ]]; then
        mv "${file}.prev" "$file"
      fi
    done
  else
    for file in "$BENCH_PODS_FILE" "$DATA_PODS_FILE" "$PODS_TOP_FILE" "$PODS_TOP_ERR_FILE" "$BENCH_TOP_SUMMARY_FILE" "$DATA_TOP_SUMMARY_FILE"; do
      rm -f "${file}.prev"
    done
  fi
}

extract_k6_summary() {
  local log_file="$1"
  local out_file="$2"
  awk '
    {
      line = $0
      if (line ~ /__K6_SUMMARY_BEGIN__/) {
        sub(/^.*__K6_SUMMARY_BEGIN__/, "", line)
        capture = 1
        if (length(line) > 0) {
          print line
        }
        next
      }
      if (capture == 1 && line ~ /__K6_SUMMARY_END__/) {
        sub(/__K6_SUMMARY_END__.*$/, "", line)
        if (length(line) > 0) {
          print line
        }
        exit
      }
      if (capture == 1) {
        print line
      }
    }
  ' "$log_file" >"$out_file"
}

require_bin aws
require_bin kubectl
require_bin jq
require_bin rg
trap cleanup_direct_kctl EXIT

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "AWS credentials are not configured or not valid." >&2
  echo "Run: aws configure" >&2
  exit 1
fi

if ! cluster_exists; then
  echo "EKS cluster '$CLUSTER_NAME' not found in '$REGION'" >&2
  exit 1
fi

setup_direct_kctl

if ! kctl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "namespace '$NAMESPACE' does not exist in cluster '$CLUSTER_NAME'" >&2
  exit 1
fi
if ! kctl -n "$NAMESPACE" get service "$SERVICE_NAME" >/dev/null 2>&1; then
  echo "service '$SERVICE_NAME' not found in namespace '$NAMESPACE'" >&2
  exit 1
fi

if [[ -z "$BASE_URL" ]]; then
  BASE_URL="http://${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local:${SERVICE_PORT}"
fi

RUN_TS="$(date -u +%Y%m%dT%H%M%SZ)"
if [[ -z "$OUTPUT_FILE" ]]; then
  OUTPUT_FILE="$ROOT_DIR/reports/benchmarks/aws/e2e_http_incluster_k6_${RUN_TS}.json"
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

LATEST_JSON_FILE="$(dirname "$OUTPUT_FILE")/e2e_http_incluster_k6_latest.json"
LATEST_MD_FILE="$(dirname "$HUMAN_REPORT_FILE")/e2e_http_incluster_k6_latest.md"

SANITIZED_JOB_BASE="$(sanitize_k8s_name "$JOB_NAME_BASE")"
if [[ -z "$SANITIZED_JOB_BASE" ]]; then
  SANITIZED_JOB_BASE="notdynamo-bench-k6"
fi
JOB_SUFFIX="$(date -u +%Y%m%d%H%M%S)"
RUN_JOB_NAME="$(build_job_name "$SANITIZED_JOB_BASE" "$JOB_SUFFIX")"
SCRIPT_CONFIGMAP_NAME="$(build_job_name "${SANITIZED_JOB_BASE}-script" "$JOB_SUFFIX")"

RUN_DIR="$ROOT_DIR/reports/benchmarks/aws/incluster_runs/${RUN_JOB_NAME}"
mkdir -p "$RUN_DIR"
ERROR_SAMPLES_FILE="$RUN_DIR/error_samples.txt"
: >"$ERROR_SAMPLES_FILE"
TELEMETRY_DIR="$RUN_DIR/telemetry"
mkdir -p "$TELEMETRY_DIR"
POD_PLACEMENT_FILE="$RUN_DIR/pod_placement.txt"
BENCH_PODS_FILE="$TELEMETRY_DIR/bench_pods.txt"
DATA_PODS_FILE="$TELEMETRY_DIR/data_pods.txt"
PODS_TOP_FILE="$TELEMETRY_DIR/pods_top_snapshot.txt"
PODS_TOP_ERR_FILE="$TELEMETRY_DIR/pods_top_snapshot.err"
NODES_TOP_FILE="$TELEMETRY_DIR/nodes_top_snapshot.txt"
NODES_TOP_ERR_FILE="$TELEMETRY_DIR/nodes_top_snapshot.err"
BENCH_TOP_SUMMARY_FILE="$TELEMETRY_DIR/bench_top_summary.txt"
DATA_TOP_SUMMARY_FILE="$TELEMETRY_DIR/data_top_summary.txt"
NODES_TOP_SUMMARY_FILE="$TELEMETRY_DIR/nodes_top_summary.txt"

TELEMETRY_SAMPLE_COUNT=0
TELEMETRY_PODS_TOP_AVAILABLE="false"
TELEMETRY_NODES_TOP_AVAILABLE="false"

kctl -n "$NAMESPACE" create configmap "$SCRIPT_CONFIGMAP_NAME" \
  --from-file=bench.js="$ROOT_DIR/scripts/eks/k6_e2e_http.js" \
  --dry-run=client -o yaml | kctl apply -f - >/dev/null
kctl -n "$NAMESPACE" label configmap "$SCRIPT_CONFIGMAP_NAME" \
  app=notdynamo-bench benchmark-category=in-cluster benchmark-driver=k6 --overwrite >/dev/null

JOB_MANIFEST="$RUN_DIR/job.yaml"
SCHEDULING_BLOCK=""
if [[ -n "$BENCH_NODE_LABEL_KEY" ]]; then
  SCHEDULING_BLOCK="$(cat <<YAML
      nodeSelector:
        "$BENCH_NODE_LABEL_KEY": "$BENCH_NODE_LABEL_VALUE"
      tolerations:
        - key: "$BENCH_NODE_LABEL_KEY"
          operator: "Equal"
          value: "$BENCH_NODE_LABEL_VALUE"
          effect: "$BENCH_TAINT_EFFECT"
YAML
)"
fi

cat >"$JOB_MANIFEST" <<YAML
apiVersion: batch/v1
kind: Job
metadata:
  name: $RUN_JOB_NAME
  namespace: $NAMESPACE
  labels:
    app: notdynamo-bench
    benchmark-category: in-cluster
    benchmark-driver: k6
spec:
  ttlSecondsAfterFinished: $TTL_SECONDS_AFTER_FINISHED
  backoffLimit: 0
  parallelism: $PARALLELISM
  completions: $COMPLETIONS
  template:
    metadata:
      labels:
        app: notdynamo-bench
        benchmark-category: in-cluster
        benchmark-driver: k6
    spec:
      restartPolicy: Never
$SCHEDULING_BLOCK
      volumes:
        - name: bench-script
          configMap:
            name: $SCRIPT_CONFIGMAP_NAME
      containers:
        - name: k6
          image: $IMAGE
          imagePullPolicy: IfNotPresent
          command: ["/bin/sh", "-ec"]
          args:
            - |
              k6 run --quiet --summary-export=/tmp/summary.json /scripts/bench.js
              status=\$?
              echo "__K6_SUMMARY_BEGIN__"
              if [ -f /tmp/summary.json ]; then cat /tmp/summary.json; echo; fi
              echo "__K6_SUMMARY_END__"
              exit \$status
          env:
            - name: BASE_URL
              value: "$BASE_URL"
            - name: KEYSPACE
              value: "$KEYSPACE"
            - name: VALUE_BYTES
              value: "$VALUE_BYTES"
            - name: READ_RATIO
              value: "$READ_RATIO"
            - name: DISTRIBUTION
              value: "$DISTRIBUTION"
            - name: PRELOAD
              value: "$PRELOAD"
            - name: SKIP_MAIN
              value: "$SKIP_MAIN"
            - name: K6_VUS
              value: "$K6_VUS"
            - name: K6_DURATION
              value: "$K6_DURATION"
            - name: SETUP_TIMEOUT
              value: "$K6_SETUP_TIMEOUT"
            - name: REQUEST_TIMEOUT_MS
              value: "$REQUEST_TIMEOUT_MS"
            - name: PRELOAD_RETRIES
              value: "$PRELOAD_RETRIES"
            - name: PRELOAD_RETRY_SLEEP_MS
              value: "$PRELOAD_RETRY_SLEEP_MS"
          volumeMounts:
            - name: bench-script
              mountPath: /scripts
              readOnly: true
YAML

kctl apply -f "$JOB_MANIFEST" >/dev/null

JOB_COMPLETED="false"
JOB_FAILED="false"
WAIT_ELAPSED_SEC=0
WAIT_STEP_SEC=2

while (( WAIT_ELAPSED_SEC < WAIT_TIMEOUT_SEC )); do
  if (( TELEMETRY_SAMPLE_COUNT < TELEMETRY_SAMPLE_ATTEMPTS )); then
    sample_telemetry_snapshot
    TELEMETRY_SAMPLE_COUNT=$((TELEMETRY_SAMPLE_COUNT + 1))
  fi

  JOB_STATUS_JSON="$(kctl -n "$NAMESPACE" get job "$RUN_JOB_NAME" -o json 2>/dev/null || true)"
  if [[ -n "$JOB_STATUS_JSON" ]]; then
    JOB_SUCCEEDED_COUNT="$(jq -r '.status.succeeded // 0' <<<"$JOB_STATUS_JSON" 2>/dev/null || echo 0)"
    JOB_FAILED_COUNT="$(jq -r '.status.failed // 0' <<<"$JOB_STATUS_JSON" 2>/dev/null || echo 0)"
    if is_uint "${JOB_SUCCEEDED_COUNT:-}" && (( JOB_SUCCEEDED_COUNT > 0 )); then
      JOB_COMPLETED="true"
      break
    fi
    if is_uint "${JOB_FAILED_COUNT:-}" && (( JOB_FAILED_COUNT > 0 )); then
      JOB_FAILED="true"
      break
    fi
  fi
  sleep "$WAIT_STEP_SEC"
  WAIT_ELAPSED_SEC=$((WAIT_ELAPSED_SEC + WAIT_STEP_SEC))
done

if (( TELEMETRY_SAMPLE_COUNT == 0 )); then
  sample_telemetry_snapshot
  TELEMETRY_SAMPLE_COUNT=1
fi

PODS_RAW="$(kctl -n "$NAMESPACE" get pods -l "job-name=$RUN_JOB_NAME" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' || true)"

POD_COUNT=0
POD_METRIC_FAILURES=0
SUM_OPERATIONS="0.000000"
SUM_SUCCESS_COUNT="0.000000"
SUM_ERROR_COUNT="0.000000"
SUM_READ_COUNT="0.000000"
SUM_WRITE_COUNT="0.000000"
SUM_READ_NOT_FOUND_COUNT="0.000000"
SUM_PRELOAD_ATTEMPTED="0.000000"
SUM_PRELOAD_SUCCESS="0.000000"
SUM_PRELOAD_FAILED="0.000000"
SUM_THROUGHPUT_RPS="0.000000"
SUM_SUCCESS_THROUGHPUT_RPS="0.000000"
MAX_P50_MS="0.000000"
MAX_P95_MS="0.000000"
MAX_P99_MS="0.000000"

while IFS= read -r POD_NAME; do
  if [[ -z "$POD_NAME" ]]; then
    continue
  fi
  POD_COUNT=$((POD_COUNT + 1))
  LOG_FILE="$RUN_DIR/${POD_NAME}.log"
  SUMMARY_FILE="$RUN_DIR/${POD_NAME}.summary.json"

  if ! kctl -n "$NAMESPACE" logs "$POD_NAME" >"$LOG_FILE" 2>"$RUN_DIR/${POD_NAME}.err"; then
    POD_METRIC_FAILURES=$((POD_METRIC_FAILURES + 1))
    continue
  fi

  extract_k6_summary "$LOG_FILE" "$SUMMARY_FILE"
  if [[ ! -s "$SUMMARY_FILE" ]]; then
    POD_METRIC_FAILURES=$((POD_METRIC_FAILURES + 1))
    add_error_sample "missing_k6_summary:$POD_NAME" "$ERROR_SAMPLES_FILE"
    continue
  fi

  if ! jq -e . "$SUMMARY_FILE" >/dev/null 2>&1; then
    POD_METRIC_FAILURES=$((POD_METRIC_FAILURES + 1))
    add_error_sample "invalid_k6_summary_json:$POD_NAME" "$ERROR_SAMPLES_FILE"
    continue
  fi

  OPS_POD="$(jq -r '.metrics.http_reqs.count // .metrics.http_reqs.values.count // .metrics.iterations.count // .metrics.iterations.values.count // 0' "$SUMMARY_FILE")"
  THROUGHPUT="$(jq -r '.metrics.http_reqs.rate // .metrics.http_reqs.values.rate // 0' "$SUMMARY_FILE")"
  SUCCESS_THROUGHPUT="$(jq -r '.metrics.op_success.rate // .metrics.op_success.values.rate // 0' "$SUMMARY_FILE")"
  P50="$(jq -r '.metrics.http_req_duration["p(50)"] // .metrics.http_req_duration.values["p(50)"] // .metrics.http_req_duration.med // .metrics.http_req_duration.values.med // 0' "$SUMMARY_FILE")"
  P95="$(jq -r '.metrics.http_req_duration["p(95)"] // .metrics.http_req_duration.values["p(95)"] // 0' "$SUMMARY_FILE")"
  P99="$(jq -r '.metrics.http_req_duration["p(99)"] // .metrics.http_req_duration.values["p(99)"] // 0' "$SUMMARY_FILE")"

  SUCCESS_COUNT_POD="$(jq -r '.metrics.op_success.count // .metrics.op_success.values.count // 0' "$SUMMARY_FILE")"
  ERROR_COUNT_POD="$(jq -r '.metrics.op_error.count // .metrics.op_error.values.count // 0' "$SUMMARY_FILE")"
  READ_COUNT_POD="$(jq -r '.metrics.read_count.count // .metrics.read_count.values.count // 0' "$SUMMARY_FILE")"
  WRITE_COUNT_POD="$(jq -r '.metrics.write_count.count // .metrics.write_count.values.count // 0' "$SUMMARY_FILE")"
  READ_NOT_FOUND_COUNT_POD="$(jq -r '.metrics.read_not_found.count // .metrics.read_not_found.values.count // 0' "$SUMMARY_FILE")"
  PRELOAD_ATTEMPT_POD="$(jq -r '.metrics.preload_attempt.count // .metrics.preload_attempt.values.count // 0' "$SUMMARY_FILE")"
  PRELOAD_SUCCESS_POD="$(jq -r '.metrics.preload_success.count // .metrics.preload_success.values.count // 0' "$SUMMARY_FILE")"
  PRELOAD_FAILED_POD="$(jq -r '.metrics.preload_failed.count // .metrics.preload_failed.values.count // 0' "$SUMMARY_FILE")"

  for value in "$OPS_POD" "$THROUGHPUT" "$SUCCESS_THROUGHPUT" "$P50" "$P95" "$P99" "$SUCCESS_COUNT_POD" "$ERROR_COUNT_POD" "$READ_COUNT_POD" "$WRITE_COUNT_POD" "$READ_NOT_FOUND_COUNT_POD" "$PRELOAD_ATTEMPT_POD" "$PRELOAD_SUCCESS_POD" "$PRELOAD_FAILED_POD"; do
    if ! is_num "${value:-}"; then
      POD_METRIC_FAILURES=$((POD_METRIC_FAILURES + 1))
      add_error_sample "invalid_metric:$POD_NAME" "$ERROR_SAMPLES_FILE"
      continue 2
    fi
  done

  SUM_OPERATIONS="$(sum_dec "$SUM_OPERATIONS" "$OPS_POD")"
  SUM_SUCCESS_COUNT="$(sum_dec "$SUM_SUCCESS_COUNT" "$SUCCESS_COUNT_POD")"
  SUM_ERROR_COUNT="$(sum_dec "$SUM_ERROR_COUNT" "$ERROR_COUNT_POD")"
  SUM_READ_COUNT="$(sum_dec "$SUM_READ_COUNT" "$READ_COUNT_POD")"
  SUM_WRITE_COUNT="$(sum_dec "$SUM_WRITE_COUNT" "$WRITE_COUNT_POD")"
  SUM_READ_NOT_FOUND_COUNT="$(sum_dec "$SUM_READ_NOT_FOUND_COUNT" "$READ_NOT_FOUND_COUNT_POD")"
  SUM_PRELOAD_ATTEMPTED="$(sum_dec "$SUM_PRELOAD_ATTEMPTED" "$PRELOAD_ATTEMPT_POD")"
  SUM_PRELOAD_SUCCESS="$(sum_dec "$SUM_PRELOAD_SUCCESS" "$PRELOAD_SUCCESS_POD")"
  SUM_PRELOAD_FAILED="$(sum_dec "$SUM_PRELOAD_FAILED" "$PRELOAD_FAILED_POD")"
  SUM_THROUGHPUT_RPS="$(sum_dec "$SUM_THROUGHPUT_RPS" "$THROUGHPUT")"
  SUM_SUCCESS_THROUGHPUT_RPS="$(sum_dec "$SUM_SUCCESS_THROUGHPUT_RPS" "$SUCCESS_THROUGHPUT")"
  MAX_P50_MS="$(max_dec "$MAX_P50_MS" "$P50")"
  MAX_P95_MS="$(max_dec "$MAX_P95_MS" "$P95")"
  MAX_P99_MS="$(max_dec "$MAX_P99_MS" "$P99")"

  ERROR_LINES="$(rg 'WARN|ERRO' "$LOG_FILE" || true)"
  if [[ -n "$ERROR_LINES" ]]; then
    while IFS= read -r ERROR_LINE; do
      add_error_sample "$ERROR_LINE" "$ERROR_SAMPLES_FILE"
    done <<<"$ERROR_LINES"
  fi
done <<<"$PODS_RAW"

SUM_OPERATIONS_INT="$(fmt_int "$SUM_OPERATIONS")"
SUM_SUCCESS_COUNT_INT="$(fmt_int "$SUM_SUCCESS_COUNT")"
SUM_ERROR_COUNT_INT="$(fmt_int "$SUM_ERROR_COUNT")"
SUM_READ_COUNT_INT="$(fmt_int "$SUM_READ_COUNT")"
SUM_WRITE_COUNT_INT="$(fmt_int "$SUM_WRITE_COUNT")"
SUM_READ_NOT_FOUND_COUNT_INT="$(fmt_int "$SUM_READ_NOT_FOUND_COUNT")"
SUM_PRELOAD_ATTEMPTED_INT="$(fmt_int "$SUM_PRELOAD_ATTEMPTED")"
SUM_PRELOAD_SUCCESS_INT="$(fmt_int "$SUM_PRELOAD_SUCCESS")"
SUM_PRELOAD_FAILED_INT="$(fmt_int "$SUM_PRELOAD_FAILED")"

ERROR_RATE_PERCENT="$(awk -v errors="$SUM_ERROR_COUNT" -v ops="$SUM_OPERATIONS" 'BEGIN { if (ops <= 0) printf "0.0000"; else printf "%.4f", (errors * 100.0) / ops }')"

STATUS="PASS"
if [[ "$JOB_COMPLETED" != "true" ]] || (( POD_COUNT == 0 )) || (( POD_METRIC_FAILURES > 0 )); then
  STATUS="FAIL"
elif awk -v rate="$ERROR_RATE_PERCENT" 'BEGIN { exit !(rate > 1.0) }'; then
  STATUS="WARN"
fi

THROUGHPUT_FMT="$(fmt_dec "$SUM_THROUGHPUT_RPS" 2)"
SUCCESS_THROUGHPUT_FMT="$(fmt_dec "$SUM_SUCCESS_THROUGHPUT_RPS" 2)"
P50_FMT="$(fmt_dec "$MAX_P50_MS" 3)"
P95_FMT="$(fmt_dec "$MAX_P95_MS" 3)"
P99_FMT="$(fmt_dec "$MAX_P99_MS" 3)"

RUN_DIR_REL="${RUN_DIR#$ROOT_DIR/}"
POD_PLACEMENT_REL="${POD_PLACEMENT_FILE#$ROOT_DIR/}"
PODS_TOP_REL="${PODS_TOP_FILE#$ROOT_DIR/}"
PODS_TOP_ERR_REL="${PODS_TOP_ERR_FILE#$ROOT_DIR/}"
NODES_TOP_REL="${NODES_TOP_FILE#$ROOT_DIR/}"
NODES_TOP_ERR_REL="${NODES_TOP_ERR_FILE#$ROOT_DIR/}"
BENCH_TOP_SUMMARY_REL="${BENCH_TOP_SUMMARY_FILE#$ROOT_DIR/}"
DATA_TOP_SUMMARY_REL="${DATA_TOP_SUMMARY_FILE#$ROOT_DIR/}"
NODES_TOP_SUMMARY_REL="${NODES_TOP_SUMMARY_FILE#$ROOT_DIR/}"

TELEM_BENCH_PODS="$(extract_metric "$BENCH_TOP_SUMMARY_FILE" "pod_count")"
TELEM_BENCH_CPU_SUM="$(extract_metric "$BENCH_TOP_SUMMARY_FILE" "cpu_mcores_sum")"
TELEM_BENCH_CPU_AVG="$(extract_metric "$BENCH_TOP_SUMMARY_FILE" "cpu_mcores_avg")"
TELEM_BENCH_MEM_SUM="$(extract_metric "$BENCH_TOP_SUMMARY_FILE" "memory_mib_sum")"
TELEM_BENCH_MEM_AVG="$(extract_metric "$BENCH_TOP_SUMMARY_FILE" "memory_mib_avg")"
TELEM_DATA_PODS="$(extract_metric "$DATA_TOP_SUMMARY_FILE" "pod_count")"
TELEM_DATA_CPU_SUM="$(extract_metric "$DATA_TOP_SUMMARY_FILE" "cpu_mcores_sum")"
TELEM_DATA_CPU_AVG="$(extract_metric "$DATA_TOP_SUMMARY_FILE" "cpu_mcores_avg")"
TELEM_DATA_MEM_SUM="$(extract_metric "$DATA_TOP_SUMMARY_FILE" "memory_mib_sum")"
TELEM_DATA_MEM_AVG="$(extract_metric "$DATA_TOP_SUMMARY_FILE" "memory_mib_avg")"
TELEM_NODE_COUNT="$(extract_metric "$NODES_TOP_SUMMARY_FILE" "node_count")"
TELEM_NODE_CPU_SUM="$(extract_metric "$NODES_TOP_SUMMARY_FILE" "cpu_mcores_sum")"
TELEM_NODE_CPU_PERCENT_MAX="$(extract_metric "$NODES_TOP_SUMMARY_FILE" "cpu_percent_max")"
TELEM_NODE_MEM_SUM="$(extract_metric "$NODES_TOP_SUMMARY_FILE" "memory_mib_sum")"
TELEM_NODE_MEM_PERCENT_MAX="$(extract_metric "$NODES_TOP_SUMMARY_FILE" "memory_percent_max")"

if ! is_uint "${TELEM_BENCH_PODS:-}"; then TELEM_BENCH_PODS=0; fi
if ! is_uint "${TELEM_DATA_PODS:-}"; then TELEM_DATA_PODS=0; fi
if ! is_uint "${TELEM_NODE_COUNT:-}"; then TELEM_NODE_COUNT=0; fi
if ! is_num "${TELEM_BENCH_CPU_SUM:-}"; then TELEM_BENCH_CPU_SUM="0.000"; fi
if ! is_num "${TELEM_BENCH_CPU_AVG:-}"; then TELEM_BENCH_CPU_AVG="0.000"; fi
if ! is_num "${TELEM_BENCH_MEM_SUM:-}"; then TELEM_BENCH_MEM_SUM="0.000"; fi
if ! is_num "${TELEM_BENCH_MEM_AVG:-}"; then TELEM_BENCH_MEM_AVG="0.000"; fi
if ! is_num "${TELEM_DATA_CPU_SUM:-}"; then TELEM_DATA_CPU_SUM="0.000"; fi
if ! is_num "${TELEM_DATA_CPU_AVG:-}"; then TELEM_DATA_CPU_AVG="0.000"; fi
if ! is_num "${TELEM_DATA_MEM_SUM:-}"; then TELEM_DATA_MEM_SUM="0.000"; fi
if ! is_num "${TELEM_DATA_MEM_AVG:-}"; then TELEM_DATA_MEM_AVG="0.000"; fi
if ! is_num "${TELEM_NODE_CPU_SUM:-}"; then TELEM_NODE_CPU_SUM="0.000"; fi
if ! is_num "${TELEM_NODE_CPU_PERCENT_MAX:-}"; then TELEM_NODE_CPU_PERCENT_MAX="0.000"; fi
if ! is_num "${TELEM_NODE_MEM_SUM:-}"; then TELEM_NODE_MEM_SUM="0.000"; fi
if ! is_num "${TELEM_NODE_MEM_PERCENT_MAX:-}"; then TELEM_NODE_MEM_PERCENT_MAX="0.000"; fi

TELEM_GENERATOR_TO_SERVICE_CPU_RATIO="$(awk -v g="$TELEM_BENCH_CPU_SUM" -v s="$TELEM_DATA_CPU_SUM" 'BEGIN { if ((s + 0) <= 0) printf "0.000"; else printf "%.3f", (g + 0) / (s + 0) }')"
TELEM_ATTRIBUTION_HINT="inconclusive"
TELEM_ATTRIBUTION_REASON="insufficient pod-level telemetry"
if [[ "$TELEMETRY_PODS_TOP_AVAILABLE" == "true" ]] && (( TELEM_BENCH_PODS > 0 )) && (( TELEM_DATA_PODS > 0 )); then
  if awk -v g="$TELEM_BENCH_CPU_SUM" -v s="$TELEM_DATA_CPU_SUM" 'BEGIN { exit !((g + 0) >= ((s + 0) * 1.5)) }'; then
    TELEM_ATTRIBUTION_HINT="generator-pressure-dominant"
    TELEM_ATTRIBUTION_REASON="benchmark pod CPU sum is >= 1.5x data pod CPU sum during sample window"
  elif awk -v g="$TELEM_BENCH_CPU_SUM" -v s="$TELEM_DATA_CPU_SUM" 'BEGIN { exit !((s + 0) >= ((g + 0) * 1.5)) }'; then
    TELEM_ATTRIBUTION_HINT="service-pressure-dominant"
    TELEM_ATTRIBUTION_REASON="data pod CPU sum is >= 1.5x benchmark pod CPU sum during sample window"
  else
    TELEM_ATTRIBUTION_HINT="mixed-or-balanced"
    TELEM_ATTRIBUTION_REASON="benchmark/data pod CPU sums are within 1.5x ratio during sample window"
  fi
fi

ERROR_SAMPLES_JSON=""
ERROR_SAMPLES_MD=""
SAMPLE_INDEX=0
while IFS= read -r SAMPLE; do
  if [[ -z "$SAMPLE" ]]; then
    continue
  fi
  SAMPLE_ESCAPED="${SAMPLE//\"/\\\"}"
  if (( SAMPLE_INDEX == 0 )); then
    ERROR_SAMPLES_JSON="\"$SAMPLE_ESCAPED\""
  else
    ERROR_SAMPLES_JSON="$ERROR_SAMPLES_JSON, \"$SAMPLE_ESCAPED\""
  fi
  ERROR_SAMPLES_MD="${ERROR_SAMPLES_MD}- \`$SAMPLE\`\n"
  SAMPLE_INDEX=$((SAMPLE_INDEX + 1))
done <"$ERROR_SAMPLES_FILE"

cat >"$OUTPUT_FILE" <<JSON
{
  "benchmark": "e2e_http_incluster_k6",
  "category": "in-cluster-job",
  "status": "$STATUS",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "cluster_name": "$CLUSTER_NAME",
  "region": "$REGION",
  "namespace": "$NAMESPACE",
  "base_url": "$BASE_URL",
  "job": {
    "name": "$RUN_JOB_NAME",
    "parallelism": "$PARALLELISM",
    "completions": "$COMPLETIONS",
    "bench_node_label": "$BENCH_NODE_LABEL",
    "bench_taint_effect": "$BENCH_TAINT_EFFECT",
    "job_completed": "$JOB_COMPLETED",
    "pod_count": "$POD_COUNT",
    "pod_metric_failures": "$POD_METRIC_FAILURES",
    "ttl_seconds_after_finished": "$TTL_SECONDS_AFTER_FINISHED"
  },
  "config": {
    "driver": "k6",
    "keyspace": "$KEYSPACE",
    "value_bytes": "$VALUE_BYTES",
    "read_ratio": "$READ_RATIO",
    "distribution": "$DISTRIBUTION",
    "preload": "$PRELOAD",
    "skip_main": "$SKIP_MAIN",
    "vus_per_pod": "$K6_VUS",
    "duration": "$K6_DURATION",
    "setup_timeout": "$K6_SETUP_TIMEOUT",
    "request_timeout_ms": "$REQUEST_TIMEOUT_MS",
    "preload_retries": "$PRELOAD_RETRIES",
    "preload_retry_sleep_ms": "$PRELOAD_RETRY_SLEEP_MS",
    "data_pod_selector": "$DATA_POD_SELECTOR",
    "telemetry_sample_attempts": "$TELEMETRY_SAMPLE_ATTEMPTS",
    "telemetry_sample_interval_sec": "$TELEMETRY_SAMPLE_INTERVAL_SEC",
    "image": "$IMAGE"
  },
  "results": {
    "operations_effective": "$SUM_OPERATIONS_INT",
    "throughput_rps_aggregate": "$THROUGHPUT_FMT",
    "success_throughput_rps_aggregate": "$SUCCESS_THROUGHPUT_FMT",
    "latency_ms_p50_max_pod": "$P50_FMT",
    "latency_ms_p95_max_pod": "$P95_FMT",
    "latency_ms_p99_max_pod": "$P99_FMT",
    "success_count": "$SUM_SUCCESS_COUNT_INT",
    "error_count": "$SUM_ERROR_COUNT_INT",
    "error_rate_percent": "$ERROR_RATE_PERCENT",
    "read_count": "$SUM_READ_COUNT_INT",
    "write_count": "$SUM_WRITE_COUNT_INT",
    "read_not_found_count": "$SUM_READ_NOT_FOUND_COUNT_INT",
    "preload_attempted": "$SUM_PRELOAD_ATTEMPTED_INT",
    "preload_success": "$SUM_PRELOAD_SUCCESS_INT",
    "preload_failed": "$SUM_PRELOAD_FAILED_INT"
  },
  "telemetry": {
    "collection": {
      "sample_attempts_configured": "$TELEMETRY_SAMPLE_ATTEMPTS",
      "sample_attempts_used": "$TELEMETRY_SAMPLE_COUNT",
      "sample_interval_sec": "$TELEMETRY_SAMPLE_INTERVAL_SEC",
      "pods_top_available": "$TELEMETRY_PODS_TOP_AVAILABLE",
      "nodes_top_available": "$TELEMETRY_NODES_TOP_AVAILABLE"
    },
    "signals": {
      "generator_pod_count": "$TELEM_BENCH_PODS",
      "generator_cpu_mcores_sum": "$TELEM_BENCH_CPU_SUM",
      "generator_cpu_mcores_avg": "$TELEM_BENCH_CPU_AVG",
      "generator_memory_mib_sum": "$TELEM_BENCH_MEM_SUM",
      "generator_memory_mib_avg": "$TELEM_BENCH_MEM_AVG",
      "service_pod_count": "$TELEM_DATA_PODS",
      "service_cpu_mcores_sum": "$TELEM_DATA_CPU_SUM",
      "service_cpu_mcores_avg": "$TELEM_DATA_CPU_AVG",
      "service_memory_mib_sum": "$TELEM_DATA_MEM_SUM",
      "service_memory_mib_avg": "$TELEM_DATA_MEM_AVG",
      "cluster_node_count": "$TELEM_NODE_COUNT",
      "cluster_cpu_mcores_sum": "$TELEM_NODE_CPU_SUM",
      "cluster_cpu_percent_max": "$TELEM_NODE_CPU_PERCENT_MAX",
      "cluster_memory_mib_sum": "$TELEM_NODE_MEM_SUM",
      "cluster_memory_percent_max": "$TELEM_NODE_MEM_PERCENT_MAX",
      "generator_to_service_cpu_ratio": "$TELEM_GENERATOR_TO_SERVICE_CPU_RATIO",
      "attribution_hint": "$TELEM_ATTRIBUTION_HINT",
      "attribution_reason": "$TELEM_ATTRIBUTION_REASON"
    },
    "artifacts": {
      "pod_placement": "$POD_PLACEMENT_REL",
      "pods_top_snapshot": "$PODS_TOP_REL",
      "pods_top_error": "$PODS_TOP_ERR_REL",
      "nodes_top_snapshot": "$NODES_TOP_REL",
      "nodes_top_error": "$NODES_TOP_ERR_REL",
      "generator_top_summary": "$BENCH_TOP_SUMMARY_REL",
      "service_top_summary": "$DATA_TOP_SUMMARY_REL",
      "nodes_top_summary": "$NODES_TOP_SUMMARY_REL"
    }
  },
  "error_samples": [${ERROR_SAMPLES_JSON}],
  "artifacts": {
    "run_dir": "$RUN_DIR_REL",
    "job_manifest": "${JOB_MANIFEST#$ROOT_DIR/}",
    "script_configmap": "$SCRIPT_CONFIGMAP_NAME",
    "pod_logs_glob": "$RUN_DIR_REL/*.log",
    "telemetry_dir": "${TELEMETRY_DIR#$ROOT_DIR/}"
  }
}
JSON

{
  echo "# NotDynamo E2E HTTP In-Cluster Benchmark Report (k6)"
  echo
  echo "- Status: **$STATUS**"
  echo "- Timestamp (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "- Category: \`in-cluster-job\`"
  echo "- Driver: \`k6\`"
  echo "- Cluster: \`$CLUSTER_NAME\`"
  echo "- Region: \`$REGION\`"
  echo "- Namespace: \`$NAMESPACE\`"
  echo "- Base URL: \`$BASE_URL\`"
  echo "- Job: \`$RUN_JOB_NAME\`"
  echo
  echo "## Configuration"
  echo
  echo "| Field | Value |"
  echo "|---|---|"
  echo "| Parallelism | $PARALLELISM |"
  echo "| Completions | $COMPLETIONS |"
  echo "| Benchmark node label | ${BENCH_NODE_LABEL:-none} |"
  echo "| Benchmark taint effect | $BENCH_TAINT_EFFECT |"
  echo "| k6 VUs per pod | $K6_VUS |"
  echo "| k6 Duration | $K6_DURATION |"
  echo "| k6 Setup timeout | $K6_SETUP_TIMEOUT |"
  echo "| Keyspace | $KEYSPACE |"
  echo "| Read ratio | $READ_RATIO |"
  echo "| Distribution | $DISTRIBUTION |"
  echo "| Value bytes | $VALUE_BYTES |"
  echo "| Preload | $PRELOAD |"
  echo "| Skip main | $SKIP_MAIN |"
  echo "| Request timeout ms | $REQUEST_TIMEOUT_MS |"
  echo
  echo "## Results"
  echo
  echo "| Metric | Value |"
  echo "|---|---|"
  echo "| Effective operations | $SUM_OPERATIONS_INT |"
  echo "| Aggregate throughput (rps) | $THROUGHPUT_FMT |"
  echo "| Aggregate success throughput (rps) | $SUCCESS_THROUGHPUT_FMT |"
  echo "| Max pod p50 latency (ms) | $P50_FMT |"
  echo "| Max pod p95 latency (ms) | $P95_FMT |"
  echo "| Max pod p99 latency (ms) | $P99_FMT |"
  echo "| Success count | $SUM_SUCCESS_COUNT_INT |"
  echo "| Error count | $SUM_ERROR_COUNT_INT |"
  echo "| Error rate (%) | $ERROR_RATE_PERCENT |"
  echo "| Read count | $SUM_READ_COUNT_INT |"
  echo "| Write count | $SUM_WRITE_COUNT_INT |"
  echo "| Read not found count | $SUM_READ_NOT_FOUND_COUNT_INT |"
  echo "| Preload attempted | $SUM_PRELOAD_ATTEMPTED_INT |"
  echo "| Preload success | $SUM_PRELOAD_SUCCESS_INT |"
  echo "| Preload failed | $SUM_PRELOAD_FAILED_INT |"
  echo "| Job completed | $JOB_COMPLETED |"
  echo "| Pod count | $POD_COUNT |"
  echo "| Pod metric failures | $POD_METRIC_FAILURES |"
  echo
  echo "## Telemetry Summary"
  echo
  echo "| Signal | Value |"
  echo "|---|---|"
  echo "| Sample attempts (used/configured) | $TELEMETRY_SAMPLE_COUNT / $TELEMETRY_SAMPLE_ATTEMPTS |"
  echo "| Pods top available | $TELEMETRY_PODS_TOP_AVAILABLE |"
  echo "| Nodes top available | $TELEMETRY_NODES_TOP_AVAILABLE |"
  echo "| Generator pod count (sampled) | $TELEM_BENCH_PODS |"
  echo "| Generator CPU mcores sum | $TELEM_BENCH_CPU_SUM |"
  echo "| Generator CPU mcores avg | $TELEM_BENCH_CPU_AVG |"
  echo "| Service pod count (sampled) | $TELEM_DATA_PODS |"
  echo "| Service CPU mcores sum | $TELEM_DATA_CPU_SUM |"
  echo "| Service CPU mcores avg | $TELEM_DATA_CPU_AVG |"
  echo "| Generator/Service CPU ratio | $TELEM_GENERATOR_TO_SERVICE_CPU_RATIO |"
  echo "| Attribution hint | $TELEM_ATTRIBUTION_HINT |"
  echo "| Attribution reason | $TELEM_ATTRIBUTION_REASON |"
  echo "| Cluster node count (sampled) | $TELEM_NODE_COUNT |"
  echo "| Cluster CPU percent max | $TELEM_NODE_CPU_PERCENT_MAX |"
  echo "| Cluster memory percent max | $TELEM_NODE_MEM_PERCENT_MAX |"
  if [[ -n "$ERROR_SAMPLES_MD" ]]; then
    echo
    echo "## Error Samples"
    echo
    printf "%b" "$ERROR_SAMPLES_MD"
  fi
  echo
  echo "## Artifacts"
  echo
  echo "- JSON report: \`${OUTPUT_FILE#$ROOT_DIR/}\`"
  echo "- Run directory: \`$RUN_DIR_REL\`"
  echo "- Job manifest: \`${JOB_MANIFEST#$ROOT_DIR/}\`"
  echo "- Script configmap: \`$SCRIPT_CONFIGMAP_NAME\`"
  echo "- Pod placement snapshot: \`$POD_PLACEMENT_REL\`"
  echo "- Pods top snapshot: \`$PODS_TOP_REL\`"
  echo "- Nodes top snapshot: \`$NODES_TOP_REL\`"
  echo "- Generator top summary: \`$BENCH_TOP_SUMMARY_REL\`"
  echo "- Service top summary: \`$DATA_TOP_SUMMARY_REL\`"
  echo "- Nodes top summary: \`$NODES_TOP_SUMMARY_REL\`"
} >"$HUMAN_REPORT_FILE"

cp "$OUTPUT_FILE" "$LATEST_JSON_FILE"
cp "$HUMAN_REPORT_FILE" "$LATEST_MD_FILE"

if (( KEEP_JOB == 0 )); then
  kctl -n "$NAMESPACE" delete job "$RUN_JOB_NAME" --ignore-not-found >/dev/null 2>&1 || true
  kctl -n "$NAMESPACE" delete configmap "$SCRIPT_CONFIGMAP_NAME" --ignore-not-found >/dev/null 2>&1 || true
fi

echo "EKS in-cluster E2E benchmark (k6) complete."
echo "JSON report: $OUTPUT_FILE"
echo "Human report: $HUMAN_REPORT_FILE"
echo "Latest JSON: $LATEST_JSON_FILE"
echo "Latest human report: $LATEST_MD_FILE"
echo "Run directory: $RUN_DIR"
