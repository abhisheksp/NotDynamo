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

JOB_NAME_BASE="notdynamo-bench-http"
PARALLELISM=4
COMPLETIONS=4
TTL_SECONDS_AFTER_FINISHED=900
KEEP_JOB=0

IMAGE_REPO="notdynamo/notdynamo-bench"
IMAGE_TAG="bench-$(date -u +%Y%m%dT%H%M%SZ)"
IMAGE=""
IMAGE_PLATFORM="linux/amd64"
DOCKERFILE_PATH="Dockerfile.bench"
PROVIDER="${IMAGE_PROVIDER:-auto}"
SKIP_BUILD=0

OUTPUT_FILE=""
HUMAN_REPORT_FILE=""

usage() {
  cat <<'USAGE'
Usage: eks_bench_job_up.sh [options]

Runs E2E HTTP benchmark from inside EKS as a Kubernetes Job, then writes JSON + Markdown reports.

Cluster/service options:
  --name <cluster-name>          EKS cluster name (default: notdynamo-eks)
  --region <aws-region>          AWS region (default: AWS_REGION or us-west-2)
  --namespace <ns>               Namespace (default: notdynamo)
  --service <name>               Service name (default: notdynamo-data)
  --service-port <n>             Service port (default: 8080)
  --base-url <url>               Override in-cluster base URL
  --wait-timeout-sec <n>         Job completion timeout (default: 1800)

Benchmark options:
  --operations <n>               Total operations across all pods (default: 200000)
  --keyspace <n>                 Keyspace size per pod (default: 20000)
  --threads <n>                  Threads per pod (default: 32)
  --read-ratio <0..1>            Read ratio (default: 0.90)
  --distribution <name>          uniform|sequential|zipf (default: uniform)
  --zipf-theta <0..1>            Zipf theta when distribution=zipf (default: 0.90)
  --value-bytes <n>              PUT payload bytes (default: 256)
  --preload <true|false>         Preload keyspace in each pod (default: true)
  --connect-timeout-ms <n>       Connect timeout (default: 3000)
  --request-timeout-ms <n>       Request timeout (default: 5000)

Job options:
  --job-name <name>              Job name prefix (default: notdynamo-bench-http)
  --parallelism <n>              Job parallelism (default: 4)
  --completions <n>              Job completions (default: 4)
  --ttl-seconds-after-finished <n>
                                 Job TTL after completion (default: 900)
  --keep-job                     Do not delete job after report generation

Image options:
  --image <image-ref>            Existing benchmark image to use
  --skip-build                   Skip build/push and require --image
  --image-repo <repo>            ECR repo path (default: notdynamo/notdynamo-bench)
  --image-tag <tag>              Image tag (default: bench-<utc timestamp>)
  --platform <platform>          Build platform (default: linux/amd64)
  --dockerfile <path>            Dockerfile path (default: Dockerfile.bench)
  --provider <auto|docker|nerdctl>
                                 Container provider for build/push (default: auto)

Report options:
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
    --image)
      IMAGE="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --image-repo)
      IMAGE_REPO="$2"
      shift 2
      ;;
    --image-tag)
      IMAGE_TAG="$2"
      shift 2
      ;;
    --platform)
      IMAGE_PLATFORM="$2"
      shift 2
      ;;
    --dockerfile)
      DOCKERFILE_PATH="$2"
      shift 2
      ;;
    --provider)
      PROVIDER="$2"
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

for n in \
  "$SERVICE_PORT" "$WAIT_TIMEOUT_SEC" "$OPERATIONS" "$KEYSPACE" "$THREADS" "$VALUE_BYTES" \
  "$CONNECT_TIMEOUT_MS" "$REQUEST_TIMEOUT_MS" "$PARALLELISM" "$COMPLETIONS" "$TTL_SECONDS_AFTER_FINISHED"
do
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

ensure_nerdctl_path() {
  if command -v nerdctl >/dev/null 2>&1; then
    return
  fi
  if ! command -v finch >/dev/null 2>&1; then
    echo "provider nerdctl requested, but neither nerdctl nor finch are installed" >&2
    exit 1
  fi

  local shim_dir="$ROOT_DIR/tmp/bin"
  mkdir -p "$shim_dir"
  cat >"$shim_dir/nerdctl" <<'EOF_SHIM'
#!/usr/bin/env bash
exec finch "$@"
EOF_SHIM
  chmod +x "$shim_dir/nerdctl"
  export PATH="$shim_dir:$PATH"
}

resolve_provider() {
  if [[ "$PROVIDER" != "auto" ]]; then
    echo "$PROVIDER"
    return
  fi
  if command -v docker >/dev/null 2>&1; then
    echo "docker"
  else
    echo "nerdctl"
  fi
}

cluster_exists() {
  aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" >/dev/null 2>&1
}

create_ecr_repo_if_missing() {
  if aws ecr describe-repositories --region "$REGION" --repository-names "$IMAGE_REPO" >/dev/null 2>&1; then
    return
  fi
  aws ecr create-repository --region "$REGION" --repository-name "$IMAGE_REPO" >/dev/null
}

ecr_login() {
  local provider="$1"
  local registry="$2"
  if [[ "$provider" == "docker" ]]; then
    aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$registry" >/dev/null
  else
    ensure_nerdctl_path
    require_bin finch
    aws ecr get-login-password --region "$REGION" | finch login --username AWS --password-stdin "$registry" >/dev/null
  fi
}

build_and_push() {
  local provider="$1"
  local image_ref="$2"
  local platform="$3"
  local dockerfile="$4"

  if [[ "$provider" == "docker" ]]; then
    require_bin docker
    docker build --platform "$platform" -f "$dockerfile" -t "$image_ref" "$ROOT_DIR"
    docker push "$image_ref"
  else
    ensure_nerdctl_path
    require_bin finch
    finch build --platform "$platform" -f "$dockerfile" -t "$image_ref" "$ROOT_DIR"
    finch push "$image_ref"
  fi
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

extract_metric() {
  local file="$1"
  local key="$2"
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

require_bin aws
require_bin kubectl
require_bin rg

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

if [[ -z "$BASE_URL" ]]; then
  BASE_URL="http://${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local:${SERVICE_PORT}"
fi

if (( SKIP_BUILD == 1 )) && [[ -z "$IMAGE" ]]; then
  echo "--skip-build requires --image <image-ref>" >&2
  exit 1
fi

if (( SKIP_BUILD == 0 )) && [[ -z "$IMAGE" ]]; then
  if [[ ! -f "$ROOT_DIR/$DOCKERFILE_PATH" ]]; then
    echo "dockerfile not found: $ROOT_DIR/$DOCKERFILE_PATH" >&2
    exit 1
  fi

  ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
  REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
  IMAGE="${REGISTRY}/${IMAGE_REPO}:${IMAGE_TAG}"

  create_ecr_repo_if_missing
  EFFECTIVE_PROVIDER="$(resolve_provider)"
  if [[ "$EFFECTIVE_PROVIDER" != "docker" && "$EFFECTIVE_PROVIDER" != "nerdctl" ]]; then
    echo "unsupported provider: $EFFECTIVE_PROVIDER" >&2
    exit 1
  fi

  ecr_login "$EFFECTIVE_PROVIDER" "$REGISTRY"
  build_and_push "$EFFECTIVE_PROVIDER" "$IMAGE" "$IMAGE_PLATFORM" "$ROOT_DIR/$DOCKERFILE_PATH"
fi

RUN_TS="$(date -u +%Y%m%dT%H%M%SZ)"
if [[ -z "$OUTPUT_FILE" ]]; then
  OUTPUT_FILE="$ROOT_DIR/reports/benchmarks/aws/e2e_http_incluster_${RUN_TS}.json"
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

LATEST_JSON_FILE="$(dirname "$OUTPUT_FILE")/e2e_http_incluster_latest.json"
LATEST_MD_FILE="$(dirname "$HUMAN_REPORT_FILE")/e2e_http_incluster_latest.md"

SANITIZED_JOB_BASE="$(sanitize_k8s_name "$JOB_NAME_BASE")"
if [[ -z "$SANITIZED_JOB_BASE" ]]; then
  SANITIZED_JOB_BASE="notdynamo-bench-http"
fi
JOB_SUFFIX="$(date -u +%Y%m%d%H%M%S)"
RUN_JOB_NAME="$(build_job_name "$SANITIZED_JOB_BASE" "$JOB_SUFFIX")"
OPERATIONS_PER_POD=$(( (OPERATIONS + COMPLETIONS - 1) / COMPLETIONS ))

RUN_DIR="$ROOT_DIR/reports/benchmarks/aws/incluster_runs/${RUN_JOB_NAME}"
mkdir -p "$RUN_DIR"
ERROR_SAMPLES_FILE="$RUN_DIR/error_samples.txt"
: >"$ERROR_SAMPLES_FILE"

JOB_MANIFEST="$RUN_DIR/job.yaml"
cat >"$JOB_MANIFEST" <<YAML
apiVersion: batch/v1
kind: Job
metadata:
  name: $RUN_JOB_NAME
  namespace: $NAMESPACE
  labels:
    app: notdynamo-bench
    benchmark-category: in-cluster
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
    spec:
      restartPolicy: Never
      containers:
        - name: bench
          image: $IMAGE
          imagePullPolicy: IfNotPresent
          args:
            - --scenario
            - e2e-http
            - --baseUrl
            - $BASE_URL
            - --operations
            - "$OPERATIONS_PER_POD"
            - --keyspace
            - "$KEYSPACE"
            - --threads
            - "$THREADS"
            - --readRatio
            - "$READ_RATIO"
            - --distribution
            - "$DISTRIBUTION"
            - --zipfTheta
            - "$ZIPF_THETA"
            - --valueBytes
            - "$VALUE_BYTES"
            - --preload
            - "$PRELOAD"
            - --connectTimeoutMs
            - "$CONNECT_TIMEOUT_MS"
            - --requestTimeoutMs
            - "$REQUEST_TIMEOUT_MS"
YAML

kubectl apply -f "$JOB_MANIFEST" >/dev/null

JOB_COMPLETED="true"
if ! kubectl -n "$NAMESPACE" wait --for=condition=complete "job/$RUN_JOB_NAME" --timeout="${WAIT_TIMEOUT_SEC}s" >/dev/null; then
  JOB_COMPLETED="false"
fi

PODS_RAW="$(kubectl -n "$NAMESPACE" get pods -l "job-name=$RUN_JOB_NAME" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' || true)"

POD_COUNT=0
POD_METRIC_FAILURES=0
SUM_OPERATIONS=0
SUM_SUCCESS_COUNT=0
SUM_ERROR_COUNT=0
SUM_READ_COUNT=0
SUM_WRITE_COUNT=0
SUM_READ_NOT_FOUND_COUNT=0
SUM_THROUGHPUT_RPS="0.0"
SUM_SUCCESS_THROUGHPUT_RPS="0.0"
MAX_P50_MS="0.0"
MAX_P95_MS="0.0"
MAX_P99_MS="0.0"

while IFS= read -r POD_NAME; do
  if [[ -z "$POD_NAME" ]]; then
    continue
  fi
  POD_COUNT=$((POD_COUNT + 1))
  LOG_FILE="$RUN_DIR/${POD_NAME}.log"
  if ! kubectl -n "$NAMESPACE" logs "$POD_NAME" >"$LOG_FILE" 2>"$RUN_DIR/${POD_NAME}.err"; then
    POD_METRIC_FAILURES=$((POD_METRIC_FAILURES + 1))
    continue
  fi

  THROUGHPUT="$(extract_metric "$LOG_FILE" "throughput_rps")"
  SUCCESS_THROUGHPUT="$(extract_metric "$LOG_FILE" "success_throughput_rps")"
  P50="$(extract_metric "$LOG_FILE" "latency_ms_p50")"
  P95="$(extract_metric "$LOG_FILE" "latency_ms_p95")"
  P99="$(extract_metric "$LOG_FILE" "latency_ms_p99")"

  if [[ -z "$THROUGHPUT" || -z "$SUCCESS_THROUGHPUT" || -z "$P99" ]]; then
    POD_METRIC_FAILURES=$((POD_METRIC_FAILURES + 1))
    continue
  fi

  OPS_POD="$(extract_metric "$LOG_FILE" "operations")"
  SUCCESS_COUNT_POD="$(extract_metric "$LOG_FILE" "success_count")"
  ERROR_COUNT_POD="$(extract_metric "$LOG_FILE" "error_count")"
  READ_COUNT_POD="$(extract_metric "$LOG_FILE" "read_count")"
  WRITE_COUNT_POD="$(extract_metric "$LOG_FILE" "write_count")"
  READ_NOT_FOUND_COUNT_POD="$(extract_metric "$LOG_FILE" "read_not_found_count")"

  if ! is_uint "${OPS_POD:-}"; then
    OPS_POD="$OPERATIONS_PER_POD"
  fi
  if ! is_uint "${SUCCESS_COUNT_POD:-}"; then
    SUCCESS_COUNT_POD=0
  fi
  if ! is_uint "${ERROR_COUNT_POD:-}"; then
    ERROR_COUNT_POD=0
  fi
  if ! is_uint "${READ_COUNT_POD:-}"; then
    READ_COUNT_POD=0
  fi
  if ! is_uint "${WRITE_COUNT_POD:-}"; then
    WRITE_COUNT_POD=0
  fi
  if ! is_uint "${READ_NOT_FOUND_COUNT_POD:-}"; then
    READ_NOT_FOUND_COUNT_POD=0
  fi

  SUM_OPERATIONS=$((SUM_OPERATIONS + OPS_POD))
  SUM_SUCCESS_COUNT=$((SUM_SUCCESS_COUNT + SUCCESS_COUNT_POD))
  SUM_ERROR_COUNT=$((SUM_ERROR_COUNT + ERROR_COUNT_POD))
  SUM_READ_COUNT=$((SUM_READ_COUNT + READ_COUNT_POD))
  SUM_WRITE_COUNT=$((SUM_WRITE_COUNT + WRITE_COUNT_POD))
  SUM_READ_NOT_FOUND_COUNT=$((SUM_READ_NOT_FOUND_COUNT + READ_NOT_FOUND_COUNT_POD))
  SUM_THROUGHPUT_RPS="$(sum_dec "$SUM_THROUGHPUT_RPS" "$THROUGHPUT")"
  SUM_SUCCESS_THROUGHPUT_RPS="$(sum_dec "$SUM_SUCCESS_THROUGHPUT_RPS" "$SUCCESS_THROUGHPUT")"
  MAX_P50_MS="$(max_dec "$MAX_P50_MS" "$P50")"
  MAX_P95_MS="$(max_dec "$MAX_P95_MS" "$P95")"
  MAX_P99_MS="$(max_dec "$MAX_P99_MS" "$P99")"

  ERROR_LINES="$(rg '^error_sample_[0-9]+=' "$LOG_FILE" || true)"
  if [[ -n "$ERROR_LINES" ]]; then
    while IFS= read -r ERROR_LINE; do
      add_error_sample "${ERROR_LINE#*=}" "$ERROR_SAMPLES_FILE"
    done <<<"$ERROR_LINES"
  fi
done <<<"$PODS_RAW"

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
  "benchmark": "e2e_http_incluster",
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
    "job_completed": "$JOB_COMPLETED",
    "pod_count": "$POD_COUNT",
    "pod_metric_failures": "$POD_METRIC_FAILURES",
    "ttl_seconds_after_finished": "$TTL_SECONDS_AFTER_FINISHED"
  },
  "config": {
    "operations_total_requested": "$OPERATIONS",
    "operations_per_pod": "$OPERATIONS_PER_POD",
    "keyspace": "$KEYSPACE",
    "threads_per_pod": "$THREADS",
    "read_ratio": "$READ_RATIO",
    "distribution": "$DISTRIBUTION",
    "zipf_theta": "$ZIPF_THETA",
    "value_bytes": "$VALUE_BYTES",
    "preload": "$PRELOAD",
    "connect_timeout_ms": "$CONNECT_TIMEOUT_MS",
    "request_timeout_ms": "$REQUEST_TIMEOUT_MS"
  },
  "results": {
    "operations_effective": "$SUM_OPERATIONS",
    "throughput_rps_aggregate": "$THROUGHPUT_FMT",
    "success_throughput_rps_aggregate": "$SUCCESS_THROUGHPUT_FMT",
    "latency_ms_p50_max_pod": "$P50_FMT",
    "latency_ms_p95_max_pod": "$P95_FMT",
    "latency_ms_p99_max_pod": "$P99_FMT",
    "success_count": "$SUM_SUCCESS_COUNT",
    "error_count": "$SUM_ERROR_COUNT",
    "error_rate_percent": "$ERROR_RATE_PERCENT",
    "read_count": "$SUM_READ_COUNT",
    "write_count": "$SUM_WRITE_COUNT",
    "read_not_found_count": "$SUM_READ_NOT_FOUND_COUNT"
  },
  "error_samples": [${ERROR_SAMPLES_JSON}],
  "artifacts": {
    "run_dir": "$RUN_DIR_REL",
    "job_manifest": "${JOB_MANIFEST#$ROOT_DIR/}",
    "pod_logs_glob": "$RUN_DIR_REL/*.log"
  }
}
JSON

{
  echo "# NotDynamo E2E HTTP In-Cluster Benchmark Report"
  echo
  echo "- Status: **$STATUS**"
  echo "- Timestamp (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "- Category: \`in-cluster-job\`"
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
  echo "| Operations total (requested) | $OPERATIONS |"
  echo "| Operations per pod | $OPERATIONS_PER_POD |"
  echo "| Parallelism | $PARALLELISM |"
  echo "| Completions | $COMPLETIONS |"
  echo "| Keyspace | $KEYSPACE |"
  echo "| Threads per pod | $THREADS |"
  echo "| Read ratio | $READ_RATIO |"
  echo "| Distribution | $DISTRIBUTION |"
  echo "| Zipf theta | $ZIPF_THETA |"
  echo "| Value bytes | $VALUE_BYTES |"
  echo "| Preload | $PRELOAD |"
  echo
  echo "## Results"
  echo
  echo "| Metric | Value |"
  echo "|---|---|"
  echo "| Effective operations | $SUM_OPERATIONS |"
  echo "| Aggregate throughput (rps) | $THROUGHPUT_FMT |"
  echo "| Aggregate success throughput (rps) | $SUCCESS_THROUGHPUT_FMT |"
  echo "| Max pod p50 latency (ms) | $P50_FMT |"
  echo "| Max pod p95 latency (ms) | $P95_FMT |"
  echo "| Max pod p99 latency (ms) | $P99_FMT |"
  echo "| Success count | $SUM_SUCCESS_COUNT |"
  echo "| Error count | $SUM_ERROR_COUNT |"
  echo "| Error rate (%) | $ERROR_RATE_PERCENT |"
  echo "| Read count | $SUM_READ_COUNT |"
  echo "| Write count | $SUM_WRITE_COUNT |"
  echo "| Read not found count | $SUM_READ_NOT_FOUND_COUNT |"
  echo "| Job completed | $JOB_COMPLETED |"
  echo "| Pod count | $POD_COUNT |"
  echo "| Pod metric failures | $POD_METRIC_FAILURES |"
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
} >"$HUMAN_REPORT_FILE"

cp "$OUTPUT_FILE" "$LATEST_JSON_FILE"
cp "$HUMAN_REPORT_FILE" "$LATEST_MD_FILE"

if (( KEEP_JOB == 0 )); then
  kubectl -n "$NAMESPACE" delete job "$RUN_JOB_NAME" --ignore-not-found >/dev/null 2>&1 || true
fi

echo "EKS in-cluster E2E benchmark complete."
echo "JSON report: $OUTPUT_FILE"
echo "Human report: $HUMAN_REPORT_FILE"
echo "Latest JSON: $LATEST_JSON_FILE"
echo "Latest human report: $LATEST_MD_FILE"
echo "Run directory: $RUN_DIR"

if [[ "$STATUS" == "FAIL" ]]; then
  exit 1
fi
