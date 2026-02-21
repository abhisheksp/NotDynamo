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
BENCH_NODE_LABEL=""
BENCH_TAINT_EFFECT="NoSchedule"
DATA_POD_SELECTOR="app=notdynamo-data"
TELEMETRY_SAMPLE_ATTEMPTS=15
TELEMETRY_SAMPLE_INTERVAL_SEC=2

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

BENCH_NODE_LABEL_KEY=""
BENCH_NODE_LABEL_VALUE=""
if [[ -n "$BENCH_NODE_LABEL" ]]; then
  if [[ "$BENCH_NODE_LABEL" != *=* ]]; then
    echo "--bench-node-label must be in key=value format" >&2
    exit 1
  fi
  BENCH_NODE_LABEL_KEY="${BENCH_NODE_LABEL%%=*}"
  BENCH_NODE_LABEL_VALUE="${BENCH_NODE_LABEL#*=}"
  if [[ -z "$BENCH_NODE_LABEL_KEY" || -z "$BENCH_NODE_LABEL_VALUE" ]]; then
    echo "--bench-node-label requires non-empty key and value" >&2
    exit 1
  fi
fi

if [[ "$BENCH_TAINT_EFFECT" != "NoSchedule" && "$BENCH_TAINT_EFFECT" != "PreferNoSchedule" && "$BENCH_TAINT_EFFECT" != "NoExecute" ]]; then
  echo "--bench-taint-effect must be one of: NoSchedule, PreferNoSchedule, NoExecute" >&2
  exit 1
fi
if [[ -z "$DATA_POD_SELECTOR" ]]; then
  echo "--data-pod-selector must not be empty" >&2
  exit 1
fi

for n in \
  "$SERVICE_PORT" "$WAIT_TIMEOUT_SEC" "$OPERATIONS" "$KEYSPACE" "$THREADS" "$VALUE_BYTES" \
  "$CONNECT_TIMEOUT_MS" "$REQUEST_TIMEOUT_MS" "$PARALLELISM" "$COMPLETIONS" "$TTL_SECONDS_AFTER_FINISHED" \
  "$TELEMETRY_SAMPLE_ATTEMPTS" "$TELEMETRY_SAMPLE_INTERVAL_SEC"
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

is_num() {
  [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
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

capture_pod_placement() {
  local out_file="$1"
  {
    echo "# benchmark_pods"
    kubectl -n "$NAMESPACE" get pods -l "job-name=$RUN_JOB_NAME" -o wide 2>/dev/null || true
    echo
    echo "# data_pods"
    kubectl -n "$NAMESPACE" get pods -l "$DATA_POD_SELECTOR" -o wide 2>/dev/null || true
  } >"$out_file"
}

capture_pod_list() {
  local selector="$1"
  local out_file="$2"
  kubectl -n "$NAMESPACE" get pods -l "$selector" \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null \
    | sed '/^$/d' >"$out_file" || true
}

write_top_group_summary() {
  local top_file="$1"
  local pod_list_file="$2"
  local out_file="$3"
  if [[ ! -s "$top_file" || ! -s "$pod_list_file" ]]; then
    cat >"$out_file" <<EOF
pod_count=0
cpu_mcores_sum=0.000
cpu_mcores_avg=0.000
memory_mib_sum=0.000
memory_mib_avg=0.000
EOF
    return
  fi

  awk '
  function cpu_to_m(v, n) {
    n = v
    if (n ~ /m$/) {
      sub(/m$/, "", n)
      return n + 0
    }
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
    if ($1 != "") {
      wanted[$1] = 1
    }
    next
  }
  {
    name = $1
    if (!(name in wanted)) {
      next
    }
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
    cat >"$out_file" <<EOF
node_count=0
cpu_mcores_sum=0.000
cpu_percent_max=0.000
memory_mib_sum=0.000
memory_percent_max=0.000
EOF
    return
  fi

  awk '
  function cpu_to_m(v, n) {
    n = v
    if (n ~ /m$/) {
      sub(/m$/, "", n)
      return n + 0
    }
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
    if ((cpu_pct + 0) > cpu_pct_max) {
      cpu_pct_max = cpu_pct + 0
    }
    mem_sum += mem_to_mib($4)
    mem_pct = $5
    gsub(/%/, "", mem_pct)
    if ((mem_pct + 0) > mem_pct_max) {
      mem_pct_max = mem_pct + 0
    }
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
$SCHEDULING_BLOCK
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

ATTEMPT=1
while (( ATTEMPT <= TELEMETRY_SAMPLE_ATTEMPTS )); do
  TELEMETRY_SAMPLE_COUNT="$ATTEMPT"
  capture_pod_placement "$POD_PLACEMENT_FILE"
  capture_pod_list "job-name=$RUN_JOB_NAME" "$BENCH_PODS_FILE"
  capture_pod_list "$DATA_POD_SELECTOR" "$DATA_PODS_FILE"

  if kubectl -n "$NAMESPACE" top pods --no-headers >"$PODS_TOP_FILE" 2>"$PODS_TOP_ERR_FILE"; then
    TELEMETRY_PODS_TOP_AVAILABLE="true"
    write_top_group_summary "$PODS_TOP_FILE" "$BENCH_PODS_FILE" "$BENCH_TOP_SUMMARY_FILE"
    write_top_group_summary "$PODS_TOP_FILE" "$DATA_PODS_FILE" "$DATA_TOP_SUMMARY_FILE"
    BENCH_POD_METRIC_COUNT="$(extract_metric "$BENCH_TOP_SUMMARY_FILE" "pod_count")"
    DATA_POD_METRIC_COUNT="$(extract_metric "$DATA_TOP_SUMMARY_FILE" "pod_count")"
    if is_uint "${BENCH_POD_METRIC_COUNT:-}" && is_uint "${DATA_POD_METRIC_COUNT:-}" && (( BENCH_POD_METRIC_COUNT > 0 )) && (( DATA_POD_METRIC_COUNT > 0 )); then
      break
    fi
  fi

  if (( ATTEMPT == TELEMETRY_SAMPLE_ATTEMPTS )); then
    break
  fi
  sleep "$TELEMETRY_SAMPLE_INTERVAL_SEC"
  ATTEMPT=$((ATTEMPT + 1))
done

if [[ "$TELEMETRY_PODS_TOP_AVAILABLE" != "true" ]]; then
  write_top_group_summary "$PODS_TOP_FILE" "$BENCH_PODS_FILE" "$BENCH_TOP_SUMMARY_FILE"
  write_top_group_summary "$PODS_TOP_FILE" "$DATA_PODS_FILE" "$DATA_TOP_SUMMARY_FILE"
fi

if kubectl top nodes --no-headers >"$NODES_TOP_FILE" 2>"$NODES_TOP_ERR_FILE"; then
  TELEMETRY_NODES_TOP_AVAILABLE="true"
fi
write_nodes_top_summary "$NODES_TOP_FILE" "$NODES_TOP_SUMMARY_FILE"

JOB_COMPLETED="true"
if ! kubectl -n "$NAMESPACE" wait --for=condition=complete "job/$RUN_JOB_NAME" --timeout="${WAIT_TIMEOUT_SEC}s" >/dev/null; then
  JOB_COMPLETED="false"
fi
capture_pod_placement "$POD_PLACEMENT_FILE"

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
    "bench_node_label": "$BENCH_NODE_LABEL",
    "bench_taint_effect": "$BENCH_TAINT_EFFECT",
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
    "request_timeout_ms": "$REQUEST_TIMEOUT_MS",
    "data_pod_selector": "$DATA_POD_SELECTOR",
    "telemetry_sample_attempts": "$TELEMETRY_SAMPLE_ATTEMPTS",
    "telemetry_sample_interval_sec": "$TELEMETRY_SAMPLE_INTERVAL_SEC"
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
    "pod_logs_glob": "$RUN_DIR_REL/*.log",
    "telemetry_dir": "${TELEMETRY_DIR#$ROOT_DIR/}"
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
  echo "| Benchmark node label | ${BENCH_NODE_LABEL:-none} |"
  echo "| Benchmark taint effect | $BENCH_TAINT_EFFECT |"
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
