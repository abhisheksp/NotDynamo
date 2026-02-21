#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CLUSTER_NAME="${NOTDYNAMO_EKS_CLUSTER:-notdynamo-eks}"
REGION="${AWS_REGION:-us-west-2}"
NAMESPACE="notdynamo"
SERVICE_NAME="notdynamo-data"
SERVICE_PORT=8080
NODEGROUP_NAME="notdynamo-ng"
DATA_STATEFULSET="notdynamo-data"
CONTROL_PLANE_DEPLOYMENT="notdynamo-control-plane"

NODE_COUNTS="2,3,4"
DATA_REPLICA_COUNTS="3,6"
SETTLE_SEC=20
NODE_READY_TIMEOUT_SEC=900
ROLLOUT_TIMEOUT_SEC=1200
RESTORE_ON_EXIT=1

RUN_EXTERNAL=0
RUN_INCLUSTER=1
EXTERNAL_MODE="port-forward"
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
PRELOAD=false
CONNECT_TIMEOUT_MS=3000
REQUEST_TIMEOUT_MS=5000
INCLUSTER_PARALLELISM=4
INCLUSTER_COMPLETIONS=4
INCLUSTER_KEEP_JOB=0
INCLUSTER_SKIP_BUILD=0
INCLUSTER_IMAGE=""
INCLUSTER_BENCH_NODE_LABEL=""
INCLUSTER_BENCH_TAINT_EFFECT="NoSchedule"

OUTPUT_PREFIX=""
LATEST_JSON_FILE=""
LATEST_MD_FILE=""
LATEST_CSV_FILE=""

ORIGINAL_NODEGROUP_DESIRED=""
ORIGINAL_NODEGROUP_MIN=""
ORIGINAL_NODEGROUP_MAX=""
ORIGINAL_DATA_REPLICAS=""
RESTORE_ARMED=0

usage() {
  cat <<'USAGE'
Usage: eks_scaling_sweep.sh [options]

Runs horizontal scaling sweeps on EKS and emits per-run benchmark artifacts plus sweep summary reports.

Cluster options:
  --name <cluster-name>            EKS cluster name (default: notdynamo-eks)
  --region <aws-region>            AWS region (default: AWS_REGION or us-west-2)
  --namespace <ns>                 Kubernetes namespace (default: notdynamo)
  --service <name>                 Service name for benchmark target (default: notdynamo-data)
  --service-port <n>               Service port (default: 8080)
  --nodegroup-name <name>          Managed nodegroup name (default: notdynamo-ng)
  --data-statefulset <name>        Data statefulset name (default: notdynamo-data)
  --control-plane-deployment <n>   Control-plane deployment name (default: notdynamo-control-plane)

Sweep dimensions:
  --node-counts <csv>              Node counts, e.g. 2,3,4 (default: 2,3,4)
  --data-replicas <csv>            Data replica counts, e.g. 3,6 (default: 3,6)
  --settle-sec <n>                 Sleep after each scale event (default: 20)
  --node-ready-timeout-sec <n>     Node readiness timeout (default: 900)
  --rollout-timeout-sec <n>        Stateful workload rollout timeout (default: 1200)
  --no-restore                     Do not restore original nodegroup + data replicas on exit

Benchmark categories:
  --include-external               Include external benchmark in matrix (default: disabled)
  --skip-external                  Explicitly disable external benchmark category
  --skip-incluster                 Skip in-cluster benchmark in matrix
  --external-mode <mode>           port-forward|load-balancer (default: port-forward)
  --external-lb-wait-timeout-sec <n>
                                   LB endpoint readiness timeout (default: 900)
  --external-lb-scheme <mode>      internet-facing|internal (default: internet-facing)
  --external-lb-type <type>        nlb|classic (default: nlb)
  --external-lb-host <host>        LB host/IP override
  --external-lb-no-manage-service  Do not patch service in LB mode
  --external-lb-keep-service-lb    Keep service exposed as LB after each external run

Benchmark knobs:
  --operations <n>                 Total operations (default: 200000)
  --keyspace <n>                   Keyspace size (default: 20000)
  --threads <n>                    Threads (default: 32)
  --read-ratio <0..1>              Read ratio (default: 0.90)
  --distribution <name>            uniform|sequential|zipf (default: uniform)
  --zipf-theta <0..1>              Zipf theta (default: 0.90)
  --value-bytes <n>                Value bytes (default: 256)
  --preload <true|false>           Preload benchmark keyspace (default: false)
  --connect-timeout-ms <n>         Connect timeout (default: 3000)
  --request-timeout-ms <n>         Request timeout (default: 5000)
  --incluster-parallelism <n>      In-cluster job parallelism (default: 4)
  --incluster-completions <n>      In-cluster job completions (default: 4)
  --incluster-keep-job             Keep in-cluster job resources after each run
  --incluster-skip-build           Reuse existing benchmark image (requires --incluster-image)
  --incluster-image <image>        Benchmark image to use for in-cluster jobs
  --incluster-bench-node-label <key=value>
                                   Schedule in-cluster benchmark pods only on nodes with this label
                                   and add matching toleration
  --incluster-bench-taint-effect <effect>
                                   Toleration effect for benchmark node taint
                                   (default: NoSchedule)

Output:
  --output-prefix <path>           Writes <path>.json|md|csv and run dir <path>_runs
  --latest-json <path>             Override latest JSON target
  --latest-md <path>               Override latest Markdown target
  --latest-csv <path>              Override latest CSV target

  --help                           Show this help
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
    --nodegroup-name)
      NODEGROUP_NAME="$2"
      shift 2
      ;;
    --data-statefulset)
      DATA_STATEFULSET="$2"
      shift 2
      ;;
    --control-plane-deployment)
      CONTROL_PLANE_DEPLOYMENT="$2"
      shift 2
      ;;
    --node-counts)
      NODE_COUNTS="$2"
      shift 2
      ;;
    --data-replicas)
      DATA_REPLICA_COUNTS="$2"
      shift 2
      ;;
    --settle-sec)
      SETTLE_SEC="$2"
      shift 2
      ;;
    --node-ready-timeout-sec)
      NODE_READY_TIMEOUT_SEC="$2"
      shift 2
      ;;
    --rollout-timeout-sec)
      ROLLOUT_TIMEOUT_SEC="$2"
      shift 2
      ;;
    --no-restore)
      RESTORE_ON_EXIT=0
      shift
      ;;
    --include-external)
      RUN_EXTERNAL=1
      shift
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
      EXTERNAL_MODE="$2"
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
    --output-prefix)
      OUTPUT_PREFIX="$2"
      shift 2
      ;;
    --latest-json)
      LATEST_JSON_FILE="$2"
      shift 2
      ;;
    --latest-md)
      LATEST_MD_FILE="$2"
      shift 2
      ;;
    --latest-csv)
      LATEST_CSV_FILE="$2"
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
  "$SERVICE_PORT" "$SETTLE_SEC" "$NODE_READY_TIMEOUT_SEC" "$ROLLOUT_TIMEOUT_SEC" \
  "$EXTERNAL_LB_WAIT_TIMEOUT_SEC" "$OPERATIONS" "$KEYSPACE" "$THREADS" "$VALUE_BYTES" \
  "$CONNECT_TIMEOUT_MS" "$REQUEST_TIMEOUT_MS" "$INCLUSTER_PARALLELISM" "$INCLUSTER_COMPLETIONS"
do
  if [[ ! "$n" =~ ^[0-9]+$ ]] || (( n < 0 )); then
    echo "numeric options must be non-negative integers" >&2
    exit 1
  fi
done
if (( SERVICE_PORT == 0 || OPERATIONS == 0 || KEYSPACE == 0 || THREADS == 0 || VALUE_BYTES == 0 || CONNECT_TIMEOUT_MS == 0 || REQUEST_TIMEOUT_MS == 0 || INCLUSTER_PARALLELISM == 0 || INCLUSTER_COMPLETIONS == 0 )); then
  echo "service-port, operations, keyspace, threads, value-bytes, timeouts, and in-cluster sizes must be greater than zero" >&2
  exit 1
fi
if [[ "$EXTERNAL_MODE" != "port-forward" && "$EXTERNAL_MODE" != "load-balancer" ]]; then
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
if (( RUN_EXTERNAL == 0 && RUN_INCLUSTER == 0 )); then
  echo "at least one benchmark category must be enabled" >&2
  exit 1
fi
if (( INCLUSTER_SKIP_BUILD == 1 )) && [[ -z "$INCLUSTER_IMAGE" ]]; then
  echo "--incluster-skip-build requires --incluster-image <image>" >&2
  exit 1
fi

parse_csv_positive_ints() {
  local csv="$1"
  local label="$2"
  local out_var_name="$3"
  local parsed_values=()

  IFS=',' read -r -a parsed_values <<<"$csv"
  if (( ${#parsed_values[@]} == 0 )); then
    echo "$label must contain at least one value" >&2
    exit 1
  fi
  for value in "${parsed_values[@]}"; do
    if [[ ! "$value" =~ ^[0-9]+$ ]] || (( value <= 0 )); then
      echo "invalid $label value: $value" >&2
      exit 1
    fi
  done

  eval "$out_var_name=(\"\${parsed_values[@]}\")"
}

require_bin() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

cluster_exists() {
  aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" >/dev/null 2>&1
}

to_repo_relative() {
  local path="$1"
  if [[ "$path" == "$ROOT_DIR/"* ]]; then
    echo "${path#"$ROOT_DIR/"}"
  elif [[ "$path" == "$ROOT_DIR" ]]; then
    echo "."
  else
    echo "$path"
  fi
}

scale_nodegroup() {
  local node_count="$1"
  echo "Scaling nodegroup '$NODEGROUP_NAME' to $node_count nodes..."
  eksctl scale nodegroup \
    --cluster "$CLUSTER_NAME" \
    --region "$REGION" \
    --name "$NODEGROUP_NAME" \
    --nodes "$node_count" \
    --nodes-min "$node_count" \
    --nodes-max "$node_count" \
    --wait >/dev/null
  kubectl wait --for=condition=Ready nodes --all --timeout="${NODE_READY_TIMEOUT_SEC}s" >/dev/null
}

scale_data_plane() {
  local replicas="$1"
  echo "Scaling '$DATA_STATEFULSET' to $replicas replicas..."
  kubectl -n "$NAMESPACE" scale statefulset "$DATA_STATEFULSET" --replicas="$replicas" >/dev/null
  kubectl -n "$NAMESPACE" set env "statefulset/$DATA_STATEFULSET" \
    NOTDYNAMO_CLUSTER_SIZE="$replicas" >/dev/null
  kubectl -n "$NAMESPACE" set env "deployment/$CONTROL_PLANE_DEPLOYMENT" \
    NOTDYNAMO_CLUSTER_SIZE="$replicas" >/dev/null
  kubectl -n "$NAMESPACE" rollout status "statefulset/$DATA_STATEFULSET" --timeout="${ROLLOUT_TIMEOUT_SEC}s" >/dev/null
  kubectl -n "$NAMESPACE" rollout status "deployment/$CONTROL_PLANE_DEPLOYMENT" --timeout="${ROLLOUT_TIMEOUT_SEC}s" >/dev/null
}

cleanup() {
  if (( RESTORE_ON_EXIT == 1 )) && (( RESTORE_ARMED == 1 )); then
    echo "Restoring original cluster scale settings..."
    eksctl scale nodegroup \
      --cluster "$CLUSTER_NAME" \
      --region "$REGION" \
      --name "$NODEGROUP_NAME" \
      --nodes "$ORIGINAL_NODEGROUP_DESIRED" \
      --nodes-min "$ORIGINAL_NODEGROUP_MIN" \
      --nodes-max "$ORIGINAL_NODEGROUP_MAX" \
      --wait >/dev/null 2>&1 || true
    kubectl -n "$NAMESPACE" scale statefulset "$DATA_STATEFULSET" --replicas="$ORIGINAL_DATA_REPLICAS" >/dev/null 2>&1 || true
    kubectl -n "$NAMESPACE" set env "statefulset/$DATA_STATEFULSET" \
      NOTDYNAMO_CLUSTER_SIZE="$ORIGINAL_DATA_REPLICAS" >/dev/null 2>&1 || true
    kubectl -n "$NAMESPACE" set env "deployment/$CONTROL_PLANE_DEPLOYMENT" \
      NOTDYNAMO_CLUSTER_SIZE="$ORIGINAL_DATA_REPLICAS" >/dev/null 2>&1 || true
    kubectl -n "$NAMESPACE" rollout status "statefulset/$DATA_STATEFULSET" --timeout="${ROLLOUT_TIMEOUT_SEC}s" >/dev/null 2>&1 || true
    kubectl -n "$NAMESPACE" rollout status "deployment/$CONTROL_PLANE_DEPLOYMENT" --timeout="${ROLLOUT_TIMEOUT_SEC}s" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

require_bin aws
require_bin kubectl
require_bin eksctl
require_bin jq

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
if ! kubectl -n "$NAMESPACE" get statefulset "$DATA_STATEFULSET" >/dev/null 2>&1; then
  echo "statefulset '$DATA_STATEFULSET' not found in namespace '$NAMESPACE'" >&2
  exit 1
fi
if ! kubectl -n "$NAMESPACE" get deployment "$CONTROL_PLANE_DEPLOYMENT" >/dev/null 2>&1; then
  echo "deployment '$CONTROL_PLANE_DEPLOYMENT' not found in namespace '$NAMESPACE'" >&2
  exit 1
fi

parse_csv_positive_ints "$NODE_COUNTS" "node-counts" NODE_COUNTS_ARRAY
parse_csv_positive_ints "$DATA_REPLICA_COUNTS" "data-replicas" DATA_REPLICA_COUNTS_ARRAY

ORIGINAL_NODEGROUP_DESIRED="$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --region "$REGION" --nodegroup-name "$NODEGROUP_NAME" --query 'nodegroup.scalingConfig.desiredSize' --output text)"
ORIGINAL_NODEGROUP_MIN="$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --region "$REGION" --nodegroup-name "$NODEGROUP_NAME" --query 'nodegroup.scalingConfig.minSize' --output text)"
ORIGINAL_NODEGROUP_MAX="$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --region "$REGION" --nodegroup-name "$NODEGROUP_NAME" --query 'nodegroup.scalingConfig.maxSize' --output text)"
ORIGINAL_DATA_REPLICAS="$(kubectl -n "$NAMESPACE" get statefulset "$DATA_STATEFULSET" -o jsonpath='{.spec.replicas}')"
RESTORE_ARMED=1

RUN_TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_TS_HUMAN="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
REPORT_DIR="$ROOT_DIR/reports/benchmarks/aws"
if [[ -n "$OUTPUT_PREFIX" ]]; then
  SWEEP_JSON="${OUTPUT_PREFIX}.json"
  SWEEP_MD="${OUTPUT_PREFIX}.md"
  SWEEP_CSV="${OUTPUT_PREFIX}.csv"
  RUN_ROOT="${OUTPUT_PREFIX}_runs"
else
  SWEEP_JSON="$REPORT_DIR/scaling_sweep_${RUN_TS}.json"
  SWEEP_MD="$REPORT_DIR/scaling_sweep_${RUN_TS}.md"
  SWEEP_CSV="$REPORT_DIR/scaling_sweep_${RUN_TS}.csv"
  RUN_ROOT="$REPORT_DIR/scaling_sweep_${RUN_TS}_runs"
fi
if [[ -z "$LATEST_JSON_FILE" ]]; then
  LATEST_JSON_FILE="$REPORT_DIR/scaling_sweep_latest.json"
fi
if [[ -z "$LATEST_MD_FILE" ]]; then
  LATEST_MD_FILE="$REPORT_DIR/scaling_sweep_latest.md"
fi
if [[ -z "$LATEST_CSV_FILE" ]]; then
  LATEST_CSV_FILE="$REPORT_DIR/scaling_sweep_latest.csv"
fi

mkdir -p "$(dirname "$SWEEP_JSON")"
mkdir -p "$(dirname "$SWEEP_MD")"
mkdir -p "$(dirname "$SWEEP_CSV")"
mkdir -p "$(dirname "$LATEST_JSON_FILE")"
mkdir -p "$(dirname "$LATEST_MD_FILE")"
mkdir -p "$(dirname "$LATEST_CSV_FILE")"
mkdir -p "$RUN_ROOT"

RUNS_JSONL="$(mktemp /tmp/notdynamo-scaling-sweep-runs.XXXXXX)"
echo "run_index,node_count,data_replicas,status,matrix_exit_code,external_mode,external_tps,external_p99_ms,incluster_tps,incluster_p99_ms,incluster_error_rate,incluster_telem_hint,incluster_telem_cpu_ratio,report_json,report_md" >"$SWEEP_CSV"

BEST_THROUGHPUT="0"
BEST_RUN_INDEX=""
BEST_NODE_COUNT=""
BEST_DATA_REPLICAS=""
OVERALL_STATUS="PASS"

RUN_INDEX=0
for node_count in "${NODE_COUNTS_ARRAY[@]}"; do
  scale_nodegroup "$node_count"
  for data_replicas in "${DATA_REPLICA_COUNTS_ARRAY[@]}"; do
    RUN_INDEX=$((RUN_INDEX + 1))

    scale_data_plane "$data_replicas"
    if (( SETTLE_SEC > 0 )); then
      sleep "$SETTLE_SEC"
    fi

    run_dir="$RUN_ROOT/run_${RUN_INDEX}_nodes${node_count}_replicas${data_replicas}"
    matrix_json="$run_dir/benchmark_matrix.json"
    matrix_md="$run_dir/benchmark_matrix.md"
    mkdir -p "$run_dir"

    matrix_args=(
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
      --incluster-parallelism "$INCLUSTER_PARALLELISM"
      --incluster-completions "$INCLUSTER_COMPLETIONS"
      --matrix-output-file "$matrix_json"
      --matrix-human-report-file "$matrix_md"
    )

    if (( RUN_EXTERNAL == 0 )); then
      matrix_args+=(--skip-external)
    else
      matrix_args+=(--external-mode "$EXTERNAL_MODE")
      if [[ "$EXTERNAL_MODE" == "load-balancer" ]]; then
        matrix_args+=(
          --external-lb-wait-timeout-sec "$EXTERNAL_LB_WAIT_TIMEOUT_SEC"
          --external-lb-scheme "$EXTERNAL_LB_SCHEME"
          --external-lb-type "$EXTERNAL_LB_TYPE"
        )
        if [[ -n "$EXTERNAL_LB_HOST" ]]; then
          matrix_args+=(--external-lb-host "$EXTERNAL_LB_HOST")
        fi
        if (( EXTERNAL_LB_MANAGE_SERVICE == 0 )); then
          matrix_args+=(--external-lb-no-manage-service)
        fi
        if (( EXTERNAL_LB_KEEP_SERVICE == 1 )); then
          matrix_args+=(--external-lb-keep-service-lb)
        fi
      fi
    fi
    if (( RUN_INCLUSTER == 0 )); then
      matrix_args+=(--skip-incluster)
    fi
    if (( INCLUSTER_KEEP_JOB == 1 )); then
      matrix_args+=(--incluster-keep-job)
    fi
    if (( INCLUSTER_SKIP_BUILD == 1 )); then
      matrix_args+=(--incluster-skip-build)
    fi
    if [[ -n "$INCLUSTER_IMAGE" ]]; then
      matrix_args+=(--incluster-image "$INCLUSTER_IMAGE")
    fi
    if [[ -n "$INCLUSTER_BENCH_NODE_LABEL" ]]; then
      matrix_args+=(
        --incluster-bench-node-label "$INCLUSTER_BENCH_NODE_LABEL"
        --incluster-bench-taint-effect "$INCLUSTER_BENCH_TAINT_EFFECT"
      )
    fi

    echo "Running benchmark matrix for node_count=$node_count data_replicas=$data_replicas ..."
    set +e
    "$ROOT_DIR/scripts/eks/eks_bench_matrix.sh" "${matrix_args[@]}"
    matrix_rc=$?
    set -e

    status="FAIL"
    external_mode_value="disabled"
    external_tps=""
    external_p99=""
    incluster_tps=""
    incluster_p99=""
    incluster_error_rate=""
    incluster_telem_hint=""
    incluster_telem_cpu_ratio=""
    report_json_rel="$(to_repo_relative "$matrix_json")"
    report_md_rel="$(to_repo_relative "$matrix_md")"

    if [[ -f "$matrix_json" ]]; then
      status="$(jq -r '.status // "UNKNOWN"' "$matrix_json")"
      external_key="$(jq -r '.categories | keys[] | select(startswith("external_client_"))' "$matrix_json" | head -n1 || true)"
      if [[ -n "$external_key" ]]; then
        external_mode_value="$(jq -r --arg k "$external_key" '.categories[$k].endpoint_mode // empty' "$matrix_json")"
        if [[ -z "$external_mode_value" ]]; then
          external_mode_value="$EXTERNAL_MODE"
        fi
        external_tps="$(jq -r --arg k "$external_key" '.categories[$k].throughput_rps // empty' "$matrix_json")"
        external_p99="$(jq -r --arg k "$external_key" '.categories[$k].latency_ms_p99 // empty' "$matrix_json")"
      fi
      incluster_tps="$(jq -r '.categories.in_cluster_job.throughput_rps_aggregate // empty' "$matrix_json")"
      incluster_p99="$(jq -r '.categories.in_cluster_job.latency_ms_p99_max_pod // empty' "$matrix_json")"
      incluster_error_rate="$(jq -r '.categories.in_cluster_job.error_rate_percent // empty' "$matrix_json")"
      incluster_telem_hint="$(jq -r '.categories.in_cluster_job.telemetry_attribution_hint // empty' "$matrix_json")"
      incluster_telem_cpu_ratio="$(jq -r '.categories.in_cluster_job.telemetry_generator_to_service_cpu_ratio // empty' "$matrix_json")"
    elif (( matrix_rc == 0 )); then
      status="UNKNOWN"
    fi

    case "$status" in
      FAIL|UNKNOWN)
        OVERALL_STATUS="FAIL"
        ;;
      WARN)
        if [[ "$OVERALL_STATUS" == "PASS" ]]; then
          OVERALL_STATUS="WARN"
        fi
        ;;
    esac
    if (( matrix_rc != 0 )) && [[ "$status" != "FAIL" ]]; then
      OVERALL_STATUS="FAIL"
    fi

    candidate_tps="$incluster_tps"
    if [[ -z "$candidate_tps" ]]; then
      candidate_tps="$external_tps"
    fi
    if [[ -z "$candidate_tps" ]]; then
      candidate_tps="0"
    fi
    if awk -v a="$candidate_tps" -v b="$BEST_THROUGHPUT" 'BEGIN { exit !(a > b) }'; then
      BEST_THROUGHPUT="$candidate_tps"
      BEST_RUN_INDEX="$RUN_INDEX"
      BEST_NODE_COUNT="$node_count"
      BEST_DATA_REPLICAS="$data_replicas"
    fi

    echo "$RUN_INDEX,$node_count,$data_replicas,$status,$matrix_rc,$external_mode_value,$external_tps,$external_p99,$incluster_tps,$incluster_p99,$incluster_error_rate,$incluster_telem_hint,$incluster_telem_cpu_ratio,$report_json_rel,$report_md_rel" >>"$SWEEP_CSV"

    run_json="$(
      jq -n \
        --arg run_index "$RUN_INDEX" \
        --arg node_count "$node_count" \
        --arg data_replicas "$data_replicas" \
        --arg status "$status" \
        --arg matrix_rc "$matrix_rc" \
        --arg external_mode "$external_mode_value" \
        --arg external_tps "$external_tps" \
        --arg external_p99 "$external_p99" \
        --arg incluster_tps "$incluster_tps" \
        --arg incluster_p99 "$incluster_p99" \
        --arg incluster_error_rate "$incluster_error_rate" \
        --arg incluster_telem_hint "$incluster_telem_hint" \
        --arg incluster_telem_cpu_ratio "$incluster_telem_cpu_ratio" \
        --arg report_json "$report_json_rel" \
        --arg report_md "$report_md_rel" \
        '{
          run_index: ($run_index|tonumber),
          node_count: ($node_count|tonumber),
          data_replicas: ($data_replicas|tonumber),
          status: $status,
          matrix_exit_code: ($matrix_rc|tonumber),
          external_mode: $external_mode,
          external_tps: (if $external_tps == "" then null else ($external_tps|tonumber) end),
          external_p99_ms: (if $external_p99 == "" then null else ($external_p99|tonumber) end),
          incluster_tps: (if $incluster_tps == "" then null else ($incluster_tps|tonumber) end),
          incluster_p99_ms: (if $incluster_p99 == "" then null else ($incluster_p99|tonumber) end),
          incluster_error_rate_percent: (if $incluster_error_rate == "" then null else ($incluster_error_rate|tonumber) end),
          incluster_telemetry_attribution_hint: (if $incluster_telem_hint == "" then null else $incluster_telem_hint end),
          incluster_telemetry_generator_to_service_cpu_ratio: (if $incluster_telem_cpu_ratio == "" then null else ($incluster_telem_cpu_ratio|tonumber) end),
          report_json: $report_json,
          report_md: $report_md
        }'
    )"
    echo "$run_json" >>"$RUNS_JSONL"
  done
done

runs_json="$(jq -s '.' "$RUNS_JSONL")"

SWEEP_JSON_REL="$(to_repo_relative "$SWEEP_JSON")"
SWEEP_CSV_REL="$(to_repo_relative "$SWEEP_CSV")"
RUN_ROOT_REL="$(to_repo_relative "$RUN_ROOT")"

jq -n \
  --arg benchmark "eks_horizontal_scaling_sweep" \
  --arg timestamp_utc "$RUN_TS_HUMAN" \
  --arg cluster_name "$CLUSTER_NAME" \
  --arg region "$REGION" \
  --arg namespace "$NAMESPACE" \
  --arg nodegroup_name "$NODEGROUP_NAME" \
  --arg node_counts "$NODE_COUNTS" \
  --arg data_replicas "$DATA_REPLICA_COUNTS" \
  --arg restore_on_exit "$RESTORE_ON_EXIT" \
  --arg run_count "$RUN_INDEX" \
  --arg best_run_index "$BEST_RUN_INDEX" \
  --arg best_node_count "$BEST_NODE_COUNT" \
  --arg best_data_replicas "$BEST_DATA_REPLICAS" \
  --arg best_throughput "$BEST_THROUGHPUT" \
  --arg summary_csv "$SWEEP_CSV_REL" \
  --arg run_reports_root "$RUN_ROOT_REL" \
  --arg status "$OVERALL_STATUS" \
  --arg run_external "$RUN_EXTERNAL" \
  --arg run_incluster "$RUN_INCLUSTER" \
  --arg external_mode_config "$EXTERNAL_MODE" \
  --arg incluster_skip_build "$INCLUSTER_SKIP_BUILD" \
  --arg incluster_image "$INCLUSTER_IMAGE" \
  --arg incluster_bench_node_label "$INCLUSTER_BENCH_NODE_LABEL" \
  --arg incluster_bench_taint_effect "$INCLUSTER_BENCH_TAINT_EFFECT" \
  --arg original_nodegroup_desired "$ORIGINAL_NODEGROUP_DESIRED" \
  --arg original_nodegroup_min "$ORIGINAL_NODEGROUP_MIN" \
  --arg original_nodegroup_max "$ORIGINAL_NODEGROUP_MAX" \
  --arg original_data_replicas "$ORIGINAL_DATA_REPLICAS" \
  --argjson runs "$runs_json" \
  '{
    benchmark: $benchmark,
    status: $status,
    timestamp_utc: $timestamp_utc,
    cluster_name: $cluster_name,
    region: $region,
    namespace: $namespace,
    nodegroup_name: $nodegroup_name,
    sweep: {
      node_counts: $node_counts,
      data_replicas: $data_replicas
    },
    restore_on_exit: ($restore_on_exit == "1"),
    benchmark_categories: {
      external_enabled: ($run_external == "1"),
      external_mode: (if $run_external == "1" then $external_mode_config else "disabled" end),
      incluster_enabled: ($run_incluster == "1"),
      incluster_skip_build: ($incluster_skip_build == "1"),
      incluster_image: (if $incluster_image == "" then null else $incluster_image end),
      incluster_bench_node_label: (if $incluster_bench_node_label == "" then null else $incluster_bench_node_label end),
      incluster_bench_taint_effect: $incluster_bench_taint_effect
    },
    original_scale: {
      nodegroup_desired: ($original_nodegroup_desired|tonumber),
      nodegroup_min: ($original_nodegroup_min|tonumber),
      nodegroup_max: ($original_nodegroup_max|tonumber),
      data_replicas: ($original_data_replicas|tonumber)
    },
    run_count: ($run_count|tonumber),
    best_run: (
      if $best_run_index == "" then null
      else {
        run_index: ($best_run_index|tonumber),
        node_count: ($best_node_count|tonumber),
        data_replicas: ($best_data_replicas|tonumber),
        throughput_rps: ($best_throughput|tonumber)
      }
      end
    ),
    summary_csv: $summary_csv,
    run_reports_root: $run_reports_root,
    runs: $runs
  }' >"$SWEEP_JSON"

{
  echo "# NotDynamo EKS Horizontal Scaling Sweep"
  echo
  echo "- Timestamp (UTC): $RUN_TS_HUMAN"
  echo "- Cluster: \`$CLUSTER_NAME\`"
  echo "- Region: \`$REGION\`"
  echo "- Namespace: \`$NAMESPACE\`"
  echo "- Nodegroup: \`$NODEGROUP_NAME\`"
  echo "- Node counts: \`$NODE_COUNTS\`"
  echo "- Data replicas: \`$DATA_REPLICA_COUNTS\`"
  echo "- Runs executed: \`$RUN_INDEX\`"
  echo "- Status: \`$OVERALL_STATUS\`"
  echo "- Restore on exit: \`$RESTORE_ON_EXIT\`"
  if (( INCLUSTER_SKIP_BUILD == 1 )); then
    echo "- In-cluster image reuse: \`$INCLUSTER_IMAGE\`"
  fi
  if [[ -n "$INCLUSTER_BENCH_NODE_LABEL" ]]; then
    echo "- In-cluster benchmark node label: \`$INCLUSTER_BENCH_NODE_LABEL\` (\`$INCLUSTER_BENCH_TAINT_EFFECT\`)"
  fi
  if [[ -n "$BEST_RUN_INDEX" ]]; then
    echo "- Best throughput run: \`run=$BEST_RUN_INDEX node_count=$BEST_NODE_COUNT data_replicas=$BEST_DATA_REPLICAS throughput_rps=$BEST_THROUGHPUT\`"
  fi
  echo
  echo "## Results Matrix"
  echo
  echo "| Run | Node count | Data replicas | Status | Matrix exit | External mode | External TPS | External p99 (ms) | In-cluster TPS | In-cluster p99 (ms) | In-cluster error (%) | Telem hint | Gen/Svc CPU ratio | Report |"
  echo "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"
  awk -F',' 'NR>1 {
    report=$14
    printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | `%s` |\n", $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,report
  }' "$SWEEP_CSV"
  echo
  echo "## Artifacts"
  echo
  echo "- JSON summary: \`$SWEEP_JSON_REL\`"
  echo "- CSV summary: \`$SWEEP_CSV_REL\`"
  echo "- Run reports root: \`$RUN_ROOT_REL\`"
} >"$SWEEP_MD"

cp "$SWEEP_JSON" "$LATEST_JSON_FILE"
cp "$SWEEP_MD" "$LATEST_MD_FILE"
cp "$SWEEP_CSV" "$LATEST_CSV_FILE"
rm -f "$RUNS_JSONL"

echo "EKS horizontal scaling sweep complete."
echo "Status: $OVERALL_STATUS"
echo "JSON summary: $(to_repo_relative "$SWEEP_JSON")"
echo "Markdown summary: $(to_repo_relative "$SWEEP_MD")"
echo "CSV summary: $(to_repo_relative "$SWEEP_CSV")"
echo "Latest JSON: $(to_repo_relative "$LATEST_JSON_FILE")"
echo "Latest Markdown: $(to_repo_relative "$LATEST_MD_FILE")"
echo "Latest CSV: $(to_repo_relative "$LATEST_CSV_FILE")"

if [[ "$OVERALL_STATUS" == "FAIL" ]]; then
  exit 1
fi
