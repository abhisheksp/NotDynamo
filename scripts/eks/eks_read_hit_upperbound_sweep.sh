#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CLUSTER_NAME="${NOTDYNAMO_EKS_CLUSTER:-notdynamo-eks}"
REGION="${AWS_REGION:-us-west-2}"
NAMESPACE="notdynamo"
NODEGROUP_NAME="notdynamo-ng"
DATA_STATEFULSET="notdynamo-data"
CONTROL_PLANE_DEPLOYMENT="notdynamo-control-plane"
SERVICE_NAME="notdynamo-data"

NODE_COUNTS="11,17,23,29,35"
REPEATS=2
SETTLE_SEC=20
NODE_READY_TIMEOUT_SEC=1200
ROLLOUT_TIMEOUT_SEC=1800
WAIT_TIMEOUT_SEC=1800
RESTORE_ON_EXIT=1

KEYSPACE=20000
VALUE_BYTES=256
REQUEST_TIMEOUT_MS=5000
READ_DISTRIBUTION="uniform"
READ_VUS=32
READ_DURATION="90s"
PRELOAD_DURATION="30s"
PRELOAD_RETRIES=3
PRELOAD_RETRY_SLEEP_MS=5
IMAGE=""
BENCH_NODE_LABEL=""
BENCH_TAINT_EFFECT="NoSchedule"

MAX_DAILY_USD="${NOTDYNAMO_MAX_DAILY_COST_USD:-20}"
ALLOW_OVER_BUDGET=0
NODE_HOURLY_USD=""
EKS_CONTROL_PLANE_HOURLY_USD="0.10"
EBS_GP3_GB_MONTH_USD="0.08"
NODE_VOLUME_GIB=80
NODE_TYPE=""

OUTPUT_PREFIX=""

ORIGINAL_NODEGROUP_DESIRED=""
ORIGINAL_NODEGROUP_MIN=""
ORIGINAL_NODEGROUP_MAX=""
ORIGINAL_DATA_REPLICAS=""
ORIGINAL_SHARD_COUNT=""
EFFECTIVE_SHARD_COUNT=""
SHARD_COUNT_MIN_REQUIRED=""
MAX_DATA_REPLICAS_IN_SWEEP=""
RESTORE_ARMED=0

usage() {
  cat <<'USAGE'
Usage: eks_read_hit_upperbound_sweep.sh [options]

Runs lockstep EKS sweeps for read-hit-heavy upper-bound throughput using a staged flow:
  1) preload-only k6 job (not measured)
  2) measured read-only k6 jobs (repeated, median reported)

Defaults:
  node_counts=11,17,23,29,35
  repeats=2 (measured stage repeats)
  measured profile: read_ratio=1.0, vus=32, duration=90s, preload=false
  preload profile: read_ratio=1.0, vus=1, duration=30s, preload=true, skip-main=true

Options:
  --name <cluster-name>           EKS cluster name (default: notdynamo-eks)
  --region <aws-region>           AWS region (default: AWS_REGION or us-west-2)
  --namespace <ns>                Namespace (default: notdynamo)
  --nodegroup-name <name>         Managed nodegroup name (default: notdynamo-ng)
  --data-statefulset <name>       Data StatefulSet name (default: notdynamo-data)
  --control-plane-deployment <n>  Control-plane deployment (default: notdynamo-control-plane)
  --service <name>                Service name (default: notdynamo-data)

  --node-counts <csv>             Lockstep counts, e.g. 11,17,23,29,35
  --repeats <n>                   Measured read runs per point (default: 2)
  --settle-sec <n>                Wait after scaling (default: 20)
  --node-ready-timeout-sec <n>    Node readiness timeout (default: 1200)
  --rollout-timeout-sec <n>       StatefulSet rollout timeout (default: 1800)
  --wait-timeout-sec <n>          Per-job benchmark timeout (default: 1800)
  --no-restore                    Do not restore original scale on exit

  --keyspace <n>                  Keyspace (default: 20000)
  --value-bytes <n>               Value bytes (default: 256)
  --request-timeout-ms <n>        HTTP timeout for k6 (default: 5000)
  --read-distribution <name>      uniform|sequential (default: uniform)
  --read-vus <n>                  k6 VUs per benchmark pod (default: 32)
  --read-duration <value>         k6 duration per measured benchmark pod (default: 90s)
  --preload-duration <value>      k6 duration for preload setup job maxDuration (default: 30s)
  --preload-retries <n>           Preload retries per key (default: 3)
  --preload-retry-sleep-ms <n>    Preload backoff base ms (default: 5)
  --image <image-ref>             k6 image override
  --bench-node-label <k=v>        Pin benchmark jobs to benchmark nodes
  --bench-taint-effect <effect>   Toleration effect (default: NoSchedule)

  --max-daily-usd <amount>        Budget cap check using max node count (default: 20)
  --node-hourly-usd <amount>      Override node hourly estimate
  --allow-over-budget             Bypass budget guard

  --output-prefix <path>          Writes <path>.json/.md/.csv and run artifacts under <path>_runs
  --help                          Show help
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
    --service)
      SERVICE_NAME="$2"
      shift 2
      ;;
    --node-counts)
      NODE_COUNTS="$2"
      shift 2
      ;;
    --repeats)
      REPEATS="$2"
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
    --wait-timeout-sec)
      WAIT_TIMEOUT_SEC="$2"
      shift 2
      ;;
    --no-restore)
      RESTORE_ON_EXIT=0
      shift
      ;;
    --keyspace)
      KEYSPACE="$2"
      shift 2
      ;;
    --value-bytes)
      VALUE_BYTES="$2"
      shift 2
      ;;
    --request-timeout-ms)
      REQUEST_TIMEOUT_MS="$2"
      shift 2
      ;;
    --read-distribution)
      READ_DISTRIBUTION="$2"
      shift 2
      ;;
    --read-vus)
      READ_VUS="$2"
      shift 2
      ;;
    --read-duration)
      READ_DURATION="$2"
      shift 2
      ;;
    --preload-duration)
      PRELOAD_DURATION="$2"
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
    --image)
      IMAGE="$2"
      shift 2
      ;;
    --bench-node-label)
      BENCH_NODE_LABEL="$2"
      shift 2
      ;;
    --bench-taint-effect)
      BENCH_TAINT_EFFECT="$2"
      shift 2
      ;;
    --max-daily-usd)
      MAX_DAILY_USD="$2"
      shift 2
      ;;
    --node-hourly-usd)
      NODE_HOURLY_USD="$2"
      shift 2
      ;;
    --allow-over-budget)
      ALLOW_OVER_BUDGET=1
      shift
      ;;
    --output-prefix)
      OUTPUT_PREFIX="$2"
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

require_bin() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

is_positive_number() {
  awk -v value="$1" 'BEGIN { exit !(value ~ /^[0-9]+([.][0-9]+)?$/ && value > 0) }'
}

to_repo_relative() {
  local path="$1"
  if [[ "$path" == "$ROOT_DIR/"* ]]; then
    printf '%s\n' "${path#"$ROOT_DIR/"}"
  else
    printf '%s\n' "$path"
  fi
}

parse_csv_positive_ints() {
  local csv="$1"
  local label="$2"
  local out_var="$3"
  local IFS=','
  local -a raw
  local -a parsed=()
  read -r -a raw <<<"$csv"
  if (( ${#raw[@]} == 0 )); then
    echo "$label must include at least one value" >&2
    exit 1
  fi
  local item trimmed
  for item in "${raw[@]}"; do
    trimmed="$(printf '%s' "$item" | tr -d '[:space:]')"
    if [[ -z "$trimmed" || ! "$trimmed" =~ ^[0-9]+$ || "$trimmed" == "0" ]]; then
      echo "$label must contain positive integers: '$item'" >&2
      exit 1
    fi
    parsed+=("$trimmed")
  done
  eval "$out_var=(\"\${parsed[@]}\")"
}

infer_node_hourly_usd() {
  case "$1" in
    t3.medium) printf '0.0416\n' ;;
    t3.large) printf '0.0832\n' ;;
    t3.xlarge) printf '0.1664\n' ;;
    m5.large) printf '0.096\n' ;;
    m5.xlarge) printf '0.192\n' ;;
    c6i.large) printf '0.085\n' ;;
    c6i.xlarge) printf '0.17\n' ;;
    *) printf '\n' ;;
  esac
}

resource_env_value() {
  local kind="$1"
  local name="$2"
  local env_name="$3"
  kubectl -n "$NAMESPACE" get "$kind" "$name" -o json | jq -r \
    --arg env_name "$env_name" \
    '[.spec.template.spec.containers[]?.env[]? | select(.name == $env_name) | .value][0] // empty'
}

ensure_shard_count_coverage() {
  local max_data_replicas="$1"

  local replication_factor
  replication_factor="$(resource_env_value statefulset "$DATA_STATEFULSET" "NOTDYNAMO_REPLICATION_FACTOR")"
  if [[ ! "$replication_factor" =~ ^[0-9]+$ ]] || (( replication_factor <= 0 )); then
    replication_factor=3
  fi

  local current_shard_count
  current_shard_count="$(resource_env_value statefulset "$DATA_STATEFULSET" "NOTDYNAMO_SHARD_COUNT")"
  if [[ ! "$current_shard_count" =~ ^[0-9]+$ ]] || (( current_shard_count <= 0 )); then
    current_shard_count=64
  fi

  SHARD_COUNT_MIN_REQUIRED=$(( max_data_replicas - replication_factor + 1 ))
  if (( SHARD_COUNT_MIN_REQUIRED < 1 )); then
    SHARD_COUNT_MIN_REQUIRED=1
  fi
  EFFECTIVE_SHARD_COUNT="$current_shard_count"

  if (( current_shard_count >= SHARD_COUNT_MIN_REQUIRED )); then
    return 0
  fi

  EFFECTIVE_SHARD_COUNT="$SHARD_COUNT_MIN_REQUIRED"
  echo "Adjusting NOTDYNAMO_SHARD_COUNT from $current_shard_count to $EFFECTIVE_SHARD_COUNT for lockstep coverage (max_replicas=$max_data_replicas rf=$replication_factor)"
  kubectl -n "$NAMESPACE" set env statefulset/"$DATA_STATEFULSET" NOTDYNAMO_SHARD_COUNT="$EFFECTIVE_SHARD_COUNT" >/dev/null
  if kubectl -n "$NAMESPACE" get deployment "$CONTROL_PLANE_DEPLOYMENT" >/dev/null 2>&1; then
    kubectl -n "$NAMESPACE" set env deployment/"$CONTROL_PLANE_DEPLOYMENT" NOTDYNAMO_SHARD_COUNT="$EFFECTIVE_SHARD_COUNT" >/dev/null
  fi
  kubectl -n "$NAMESPACE" rollout status "statefulset/$DATA_STATEFULSET" --timeout="${ROLLOUT_TIMEOUT_SEC}s" >/dev/null
  if kubectl -n "$NAMESPACE" get deployment "$CONTROL_PLANE_DEPLOYMENT" >/dev/null 2>&1; then
    kubectl -n "$NAMESPACE" rollout status "deployment/$CONTROL_PLANE_DEPLOYMENT" --timeout="${ROLLOUT_TIMEOUT_SEC}s" >/dev/null
  fi
}

cluster_exists() {
  aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" >/dev/null 2>&1
}

scale_nodegroup() {
  local desired="$1"
  echo "Scaling nodegroup '$NODEGROUP_NAME' to $desired"
  eksctl scale nodegroup \
    --cluster "$CLUSTER_NAME" \
    --region "$REGION" \
    --name "$NODEGROUP_NAME" \
    --nodes "$desired" \
    --nodes-min "$desired" \
    --nodes-max "$desired" \
    --wait >/dev/null

  aws eks wait nodegroup-active \
    --cluster-name "$CLUSTER_NAME" \
    --region "$REGION" \
    --nodegroup-name "$NODEGROUP_NAME"

  local selector="eks.amazonaws.com/nodegroup=${NODEGROUP_NAME}"
  local deadline=$((SECONDS + NODE_READY_TIMEOUT_SEC))
  while (( SECONDS < deadline )); do
    local nodes_json node_count ready_count
    nodes_json="$(kubectl get nodes -l "$selector" -o json)"
    node_count="$(jq -r '.items | length' <<<"$nodes_json")"
    ready_count="$(jq -r '[.items[] | select(any(.status.conditions[]?; .type=="Ready" and .status=="True"))] | length' <<<"$nodes_json")"
    if [[ "$node_count" =~ ^[0-9]+$ && "$ready_count" =~ ^[0-9]+$ ]]; then
      if (( node_count >= desired && ready_count >= desired )); then
        return 0
      fi
    fi
    sleep 5
  done

  local final_nodes final_ready
  final_nodes="$(kubectl get nodes -l "$selector" --no-headers 2>/dev/null | wc -l | tr -d ' ')"
  final_ready="$(kubectl get nodes -l "$selector" -o json | jq -r '[.items[] | select(any(.status.conditions[]?; .type=="Ready" and .status=="True"))] | length')"
  echo "timed out waiting for nodegroup '$NODEGROUP_NAME' to reach $desired ready nodes (nodes=$final_nodes ready=$final_ready)" >&2
  return 1
}

scale_data_plane() {
  local replicas="$1"
  echo "Scaling statefulset/$DATA_STATEFULSET to replicas=$replicas"
  kubectl -n "$NAMESPACE" set env statefulset/"$DATA_STATEFULSET" NOTDYNAMO_CLUSTER_SIZE="$replicas" >/dev/null
  if kubectl -n "$NAMESPACE" get deployment "$CONTROL_PLANE_DEPLOYMENT" >/dev/null 2>&1; then
    kubectl -n "$NAMESPACE" set env deployment/"$CONTROL_PLANE_DEPLOYMENT" NOTDYNAMO_CLUSTER_SIZE="$replicas" >/dev/null
  fi
  kubectl -n "$NAMESPACE" scale statefulset "$DATA_STATEFULSET" --replicas "$replicas" >/dev/null
  kubectl -n "$NAMESPACE" rollout status "statefulset/$DATA_STATEFULSET" --timeout="${ROLLOUT_TIMEOUT_SEC}s" >/dev/null
  if kubectl -n "$NAMESPACE" get deployment "$CONTROL_PLANE_DEPLOYMENT" >/dev/null 2>&1; then
    kubectl -n "$NAMESPACE" rollout status "deployment/$CONTROL_PLANE_DEPLOYMENT" --timeout="${ROLLOUT_TIMEOUT_SEC}s" >/dev/null
  fi
}

restore_scale() {
  if (( RESTORE_ON_EXIT == 0 || RESTORE_ARMED == 0 )); then
    return
  fi
  set +e
  echo "Restoring original node/data scale settings..."
  if [[ -n "$ORIGINAL_NODEGROUP_DESIRED" ]]; then
    eksctl scale nodegroup \
      --cluster "$CLUSTER_NAME" \
      --region "$REGION" \
      --name "$NODEGROUP_NAME" \
      --nodes "$ORIGINAL_NODEGROUP_DESIRED" \
      --nodes-min "$ORIGINAL_NODEGROUP_MIN" \
      --nodes-max "$ORIGINAL_NODEGROUP_MAX" \
      --wait >/dev/null
  fi
  if [[ -n "$ORIGINAL_DATA_REPLICAS" ]]; then
    kubectl -n "$NAMESPACE" set env statefulset/"$DATA_STATEFULSET" NOTDYNAMO_CLUSTER_SIZE="$ORIGINAL_DATA_REPLICAS" >/dev/null
    if kubectl -n "$NAMESPACE" get deployment "$CONTROL_PLANE_DEPLOYMENT" >/dev/null 2>&1; then
      kubectl -n "$NAMESPACE" set env deployment/"$CONTROL_PLANE_DEPLOYMENT" NOTDYNAMO_CLUSTER_SIZE="$ORIGINAL_DATA_REPLICAS" >/dev/null
    fi
    kubectl -n "$NAMESPACE" scale statefulset "$DATA_STATEFULSET" --replicas "$ORIGINAL_DATA_REPLICAS" >/dev/null
    kubectl -n "$NAMESPACE" rollout status "statefulset/$DATA_STATEFULSET" --timeout="${ROLLOUT_TIMEOUT_SEC}s" >/dev/null
  fi
  if [[ -n "$ORIGINAL_SHARD_COUNT" ]]; then
    kubectl -n "$NAMESPACE" set env statefulset/"$DATA_STATEFULSET" NOTDYNAMO_SHARD_COUNT="$ORIGINAL_SHARD_COUNT" >/dev/null
    if kubectl -n "$NAMESPACE" get deployment "$CONTROL_PLANE_DEPLOYMENT" >/dev/null 2>&1; then
      kubectl -n "$NAMESPACE" set env deployment/"$CONTROL_PLANE_DEPLOYMENT" NOTDYNAMO_SHARD_COUNT="$ORIGINAL_SHARD_COUNT" >/dev/null
    fi
    kubectl -n "$NAMESPACE" rollout status "statefulset/$DATA_STATEFULSET" --timeout="${ROLLOUT_TIMEOUT_SEC}s" >/dev/null
    if kubectl -n "$NAMESPACE" get deployment "$CONTROL_PLANE_DEPLOYMENT" >/dev/null 2>&1; then
      kubectl -n "$NAMESPACE" rollout status "deployment/$CONTROL_PLANE_DEPLOYMENT" --timeout="${ROLLOUT_TIMEOUT_SEC}s" >/dev/null
    fi
  fi
  set -e
}

run_k6_job() {
  local output_json="$1"
  local output_md="$2"
  shift 2

  local -a args=(
    "$ROOT_DIR/scripts/eks/eks_bench_job_k6_up.sh"
    --name "$CLUSTER_NAME"
    --region "$REGION"
    --namespace "$NAMESPACE"
    --service "$SERVICE_NAME"
    --wait-timeout-sec "$WAIT_TIMEOUT_SEC"
    --keyspace "$KEYSPACE"
    --value-bytes "$VALUE_BYTES"
    --request-timeout-ms "$REQUEST_TIMEOUT_MS"
    --preload-retries "$PRELOAD_RETRIES"
    --preload-retry-sleep-ms "$PRELOAD_RETRY_SLEEP_MS"
    --output-file "$output_json"
    --human-report-file "$output_md"
  )

  if [[ -n "$IMAGE" ]]; then
    args+=(--image "$IMAGE")
  fi
  if [[ -n "$BENCH_NODE_LABEL" ]]; then
    args+=(--bench-node-label "$BENCH_NODE_LABEL" --bench-taint-effect "$BENCH_TAINT_EFFECT")
  fi

  args+=("$@")

  "${args[@]}"
}

extract_result_field() {
  local json_file="$1"
  local primary="$2"
  local fallback="$3"
  jq -r --arg p "$primary" --arg f "$fallback" '
    def val($x): (getpath($x) // null);
    (val(($p|split("."))) // val(($f|split(".")))) // empty
  ' "$json_file"
}

for n in "$REPEATS" "$SETTLE_SEC" "$NODE_READY_TIMEOUT_SEC" "$ROLLOUT_TIMEOUT_SEC" "$WAIT_TIMEOUT_SEC" \
         "$KEYSPACE" "$VALUE_BYTES" "$REQUEST_TIMEOUT_MS" "$READ_VUS" "$PRELOAD_RETRIES" "$PRELOAD_RETRY_SLEEP_MS"; do
  if [[ ! "$n" =~ ^[0-9]+$ ]] || (( n <= 0 )); then
    echo "numeric options must be positive integers" >&2
    exit 1
  fi
done
if ! is_positive_number "$MAX_DAILY_USD"; then
  echo "--max-daily-usd must be a positive number" >&2
  exit 1
fi
if [[ -n "$NODE_HOURLY_USD" ]] && ! is_positive_number "$NODE_HOURLY_USD"; then
  echo "--node-hourly-usd must be a positive number" >&2
  exit 1
fi
if [[ "$READ_DISTRIBUTION" != "uniform" && "$READ_DISTRIBUTION" != "sequential" ]]; then
  echo "--read-distribution must be one of: uniform, sequential" >&2
  exit 1
fi
if [[ "$BENCH_TAINT_EFFECT" != "NoSchedule" && "$BENCH_TAINT_EFFECT" != "PreferNoSchedule" && "$BENCH_TAINT_EFFECT" != "NoExecute" ]]; then
  echo "--bench-taint-effect must be one of: NoSchedule, PreferNoSchedule, NoExecute" >&2
  exit 1
fi

require_bin aws
require_bin kubectl
require_bin eksctl
require_bin jq

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "AWS credentials are not configured or not valid." >&2
  echo "Run: aws login / aws configure" >&2
  exit 1
fi
if ! cluster_exists; then
  echo "EKS cluster '$CLUSTER_NAME' not found in '$REGION'." >&2
  exit 1
fi

aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" >/dev/null

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "namespace '$NAMESPACE' not found. Deploy NotDynamo first." >&2
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

max_node_count=0
for n in "${NODE_COUNTS_ARRAY[@]}"; do
  if (( n > max_node_count )); then
    max_node_count="$n"
  fi
done
MAX_DATA_REPLICAS_IN_SWEEP="$max_node_count"

ORIGINAL_NODEGROUP_DESIRED="$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --region "$REGION" --nodegroup-name "$NODEGROUP_NAME" --query 'nodegroup.scalingConfig.desiredSize' --output text)"
ORIGINAL_NODEGROUP_MIN="$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --region "$REGION" --nodegroup-name "$NODEGROUP_NAME" --query 'nodegroup.scalingConfig.minSize' --output text)"
ORIGINAL_NODEGROUP_MAX="$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --region "$REGION" --nodegroup-name "$NODEGROUP_NAME" --query 'nodegroup.scalingConfig.maxSize' --output text)"
NODE_TYPE="$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --region "$REGION" --nodegroup-name "$NODEGROUP_NAME" --query 'nodegroup.instanceTypes[0]' --output text)"
ORIGINAL_DATA_REPLICAS="$(kubectl -n "$NAMESPACE" get statefulset "$DATA_STATEFULSET" -o jsonpath='{.spec.replicas}')"
ORIGINAL_SHARD_COUNT="$(resource_env_value statefulset "$DATA_STATEFULSET" "NOTDYNAMO_SHARD_COUNT")"
if [[ ! "$ORIGINAL_SHARD_COUNT" =~ ^[0-9]+$ ]] || (( ORIGINAL_SHARD_COUNT <= 0 )); then
  ORIGINAL_SHARD_COUNT=""
fi
RESTORE_ARMED=1
trap 'rc=$?; restore_scale; exit $rc' EXIT

if [[ -z "$NODE_HOURLY_USD" ]]; then
  NODE_HOURLY_USD="$(infer_node_hourly_usd "$NODE_TYPE")"
fi
if [[ -z "$NODE_HOURLY_USD" ]]; then
  echo "warning: no hourly estimate known for node type '$NODE_TYPE'; skipping budget guard" >&2
else
  node_volume_hourly="$(awk -v gib="$NODE_VOLUME_GIB" -v per_gb_month="$EBS_GP3_GB_MONTH_USD" 'BEGIN { printf "%.6f", (gib * per_gb_month) / 730.0 }')"
  max_hourly="$(awk -v cp="$EKS_CONTROL_PLANE_HOURLY_USD" -v nh="$NODE_HOURLY_USD" -v nv="$node_volume_hourly" -v nodes="$max_node_count" 'BEGIN { printf "%.6f", cp + ((nh + nv) * nodes) }')"
  max_daily="$(awk -v hourly="$max_hourly" 'BEGIN { printf "%.4f", hourly * 24.0 }')"
  if awk -v est="$max_daily" -v cap="$MAX_DAILY_USD" 'BEGIN { exit !(est > cap) }'; then
    if (( ALLOW_OVER_BUDGET == 0 )); then
      echo "estimated daily max cost ($max_daily USD) exceeds cap ($MAX_DAILY_USD USD)." >&2
      echo "pass --allow-over-budget to proceed intentionally." >&2
      exit 1
    fi
    echo "warning: proceeding over budget cap: estimated daily max=$max_daily USD cap=$MAX_DAILY_USD USD" >&2
  fi
fi

ensure_shard_count_coverage "$MAX_DATA_REPLICAS_IN_SWEEP"

RUN_TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_TS_HUMAN="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
REPORT_DIR="$ROOT_DIR/reports/benchmarks/aws"
if [[ -n "$OUTPUT_PREFIX" ]]; then
  SWEEP_JSON="${OUTPUT_PREFIX}.json"
  SWEEP_MD="${OUTPUT_PREFIX}.md"
  SWEEP_CSV="${OUTPUT_PREFIX}.csv"
  RUN_ROOT="${OUTPUT_PREFIX}_runs"
else
  SWEEP_JSON="$REPORT_DIR/read_hit_upperbound_sweep_${RUN_TS}.json"
  SWEEP_MD="$REPORT_DIR/read_hit_upperbound_sweep_${RUN_TS}.md"
  SWEEP_CSV="$REPORT_DIR/read_hit_upperbound_sweep_${RUN_TS}.csv"
  RUN_ROOT="$REPORT_DIR/read_hit_upperbound_sweep_${RUN_TS}_runs"
fi
LATEST_JSON_FILE="$REPORT_DIR/read_hit_upperbound_sweep_latest.json"
LATEST_MD_FILE="$REPORT_DIR/read_hit_upperbound_sweep_latest.md"
LATEST_CSV_FILE="$REPORT_DIR/read_hit_upperbound_sweep_latest.csv"

mkdir -p "$(dirname "$SWEEP_JSON")" "$(dirname "$SWEEP_MD")" "$(dirname "$SWEEP_CSV")" "$RUN_ROOT"

RUNS_JSONL="$(mktemp /tmp/notdynamo-read-upper-runs.XXXXXX)"
POINTS_JSONL="$(mktemp /tmp/notdynamo-read-upper-points.XXXXXX)"
echo "point_index,node_count,data_replicas,trial,status,attempted_read_tps,success_read_tps,error_rate_percent,p50_ms,p95_ms,p99_ms,read_count,write_count,read_not_found_count,generator_to_service_cpu_ratio,service_cpu_mcores_sum,generator_cpu_mcores_sum,cluster_node_count,preload_status,preload_failed,preload_json,measured_json" >"$SWEEP_CSV"

overall_status="PASS"
run_index=0
point_index=0
best_node_count=""
best_data_replicas=""
best_median_success_tps="0"

for node_count in "${NODE_COUNTS_ARRAY[@]}"; do
  point_index=$((point_index + 1))
  data_replicas="$node_count"

  scale_nodegroup "$node_count"
  scale_data_plane "$data_replicas"
  if (( SETTLE_SEC > 0 )); then
    sleep "$SETTLE_SEC"
  fi

  point_dir="$RUN_ROOT/point_${point_index}_n${node_count}_r${data_replicas}"
  mkdir -p "$point_dir"

  preload_json="$point_dir/preload_stage.json"
  preload_md="$point_dir/preload_stage.md"
  echo "Running preload stage: point=$point_index node_count=$node_count data_replicas=$data_replicas"
  set +e
  run_k6_job "$preload_json" "$preload_md" \
    --parallelism 1 \
    --completions 1 \
    --vus 1 \
    --duration "$PRELOAD_DURATION" \
    --preload true \
    --skip-main true \
    --read-ratio 1.0 \
    --distribution sequential
  preload_rc=$?
  set -e

  preload_status="FAIL"
  preload_attempted=""
  preload_success=""
  preload_failed=""
  if (( preload_rc == 0 )) && [[ -f "$preload_json" ]]; then
    preload_status="$(jq -r '.status // "PASS"' "$preload_json")"
    preload_attempted="$(jq -r '.results.preload_attempted // .results.preload_attempted_aggregate // empty' "$preload_json")"
    preload_success="$(jq -r '.results.preload_success // .results.preload_success_aggregate // empty' "$preload_json")"
    preload_failed="$(jq -r '.results.preload_failed // .results.preload_failed_aggregate // empty' "$preload_json")"
  fi

  POINT_RUNS_JSONL="$(mktemp /tmp/notdynamo-read-upper-point-runs.XXXXXX)"
  point_status="PASS"

  for trial in $(seq 1 "$REPEATS"); do
    run_index=$((run_index + 1))
    trial_dir="$point_dir/trial_${trial}"
    mkdir -p "$trial_dir"
    measured_json="$trial_dir/read_hit_stage.json"
    measured_md="$trial_dir/read_hit_stage.md"

    status="FAIL"
    run_rc=1
    attempted_tps=""
    success_tps=""
    error_rate=""
    p50_ms=""
    p95_ms=""
    p99_ms=""
    read_count=""
    write_count=""
    read_not_found_count=""
    generator_ratio=""
    service_cpu_sum=""
    generator_cpu_sum=""
    cluster_node_count=""

    if (( preload_rc != 0 )) || [[ ! -f "$preload_json" ]]; then
      echo "Skipping measured run because preload stage failed: point=$point_index trial=$trial" >&2
      point_status="FAIL"
      overall_status="FAIL"
    else
      echo "Running measured read-hit stage: point=$point_index node_count=$node_count data_replicas=$data_replicas trial=$trial"
      set +e
      run_k6_job "$measured_json" "$measured_md" \
        --parallelism "$node_count" \
        --completions "$node_count" \
        --vus "$READ_VUS" \
        --duration "$READ_DURATION" \
        --preload false \
        --skip-main false \
        --read-ratio 1.0 \
        --distribution "$READ_DISTRIBUTION"
      run_rc=$?
      set -e

      if (( run_rc != 0 )) || [[ ! -f "$measured_json" ]]; then
        status="FAIL"
        point_status="FAIL"
        overall_status="FAIL"
      else
        status="$(jq -r '.status // "PASS"' "$measured_json")"
        attempted_tps="$(jq -r '.results.throughput_rps_aggregate // .results.throughput_rps // empty' "$measured_json")"
        success_tps="$(jq -r '.results.success_throughput_rps_aggregate // .results.success_throughput_rps // empty' "$measured_json")"
        error_rate="$(jq -r '.results.error_rate_percent // .results.error_rate_percent_aggregate // empty' "$measured_json")"
        p50_ms="$(jq -r '.results.latency_ms_p50_max_pod // .results.latency_ms_p50 // empty' "$measured_json")"
        p95_ms="$(jq -r '.results.latency_ms_p95_max_pod // .results.latency_ms_p95 // empty' "$measured_json")"
        p99_ms="$(jq -r '.results.latency_ms_p99_max_pod // .results.latency_ms_p99 // empty' "$measured_json")"
        read_count="$(jq -r '.results.read_count // .results.read_count_aggregate // empty' "$measured_json")"
        write_count="$(jq -r '.results.write_count // .results.write_count_aggregate // empty' "$measured_json")"
        read_not_found_count="$(jq -r '.results.read_not_found_count // .results.read_not_found_count_aggregate // empty' "$measured_json")"
        generator_ratio="$(jq -r '.telemetry.signals.generator_to_service_cpu_ratio // empty' "$measured_json")"
        service_cpu_sum="$(jq -r '.telemetry.signals.service_cpu_mcores_sum // empty' "$measured_json")"
        generator_cpu_sum="$(jq -r '.telemetry.signals.generator_cpu_mcores_sum // empty' "$measured_json")"
        cluster_node_count="$(jq -r '.telemetry.signals.cluster_node_count // empty' "$measured_json")"

        if [[ "$status" == "FAIL" ]]; then
          point_status="FAIL"
          overall_status="FAIL"
        fi
      fi
    fi

    preload_json_rel="$(to_repo_relative "$preload_json")"
    measured_json_rel="$(to_repo_relative "$measured_json")"
    echo "$point_index,$node_count,$data_replicas,$trial,$status,$attempted_tps,$success_tps,$error_rate,$p50_ms,$p95_ms,$p99_ms,$read_count,$write_count,$read_not_found_count,$generator_ratio,$service_cpu_sum,$generator_cpu_sum,$cluster_node_count,$preload_status,$preload_failed,$preload_json_rel,$measured_json_rel" >>"$SWEEP_CSV"

    run_json="$(jq -n \
      --arg run_index "$run_index" \
      --arg point_index "$point_index" \
      --arg node_count "$node_count" \
      --arg data_replicas "$data_replicas" \
      --arg trial "$trial" \
      --arg status "$status" \
      --arg run_rc "$run_rc" \
      --arg attempted_tps "$attempted_tps" \
      --arg success_tps "$success_tps" \
      --arg error_rate "$error_rate" \
      --arg p50_ms "$p50_ms" \
      --arg p95_ms "$p95_ms" \
      --arg p99_ms "$p99_ms" \
      --arg read_count "$read_count" \
      --arg write_count "$write_count" \
      --arg read_not_found_count "$read_not_found_count" \
      --arg generator_ratio "$generator_ratio" \
      --arg service_cpu_sum "$service_cpu_sum" \
      --arg generator_cpu_sum "$generator_cpu_sum" \
      --arg cluster_node_count "$cluster_node_count" \
      --arg preload_status "$preload_status" \
      --arg preload_attempted "$preload_attempted" \
      --arg preload_success "$preload_success" \
      --arg preload_failed "$preload_failed" \
      --arg preload_json "$preload_json_rel" \
      --arg measured_json "$measured_json_rel" \
      '{
        run_index: ($run_index|tonumber),
        point_index: ($point_index|tonumber),
        node_count: ($node_count|tonumber),
        data_replicas: ($data_replicas|tonumber),
        trial: ($trial|tonumber),
        status: $status,
        exit_code: ($run_rc|tonumber),
        attempted_read_tps: (if $attempted_tps == "" then null else ($attempted_tps|tonumber) end),
        success_read_tps: (if $success_tps == "" then null else ($success_tps|tonumber) end),
        error_rate_percent: (if $error_rate == "" then null else ($error_rate|tonumber) end),
        p50_ms: (if $p50_ms == "" then null else ($p50_ms|tonumber) end),
        p95_ms: (if $p95_ms == "" then null else ($p95_ms|tonumber) end),
        p99_ms: (if $p99_ms == "" then null else ($p99_ms|tonumber) end),
        read_count: (if $read_count == "" then null else ($read_count|tonumber) end),
        write_count: (if $write_count == "" then null else ($write_count|tonumber) end),
        read_not_found_count: (if $read_not_found_count == "" then null else ($read_not_found_count|tonumber) end),
        generator_to_service_cpu_ratio: (if $generator_ratio == "" then null else ($generator_ratio|tonumber) end),
        service_cpu_mcores_sum: (if $service_cpu_sum == "" then null else ($service_cpu_sum|tonumber) end),
        generator_cpu_mcores_sum: (if $generator_cpu_sum == "" then null else ($generator_cpu_sum|tonumber) end),
        cluster_node_count: (if $cluster_node_count == "" then null else ($cluster_node_count|tonumber) end),
        preload: {
          status: $preload_status,
          attempted: (if $preload_attempted == "" then null else ($preload_attempted|tonumber) end),
          success: (if $preload_success == "" then null else ($preload_success|tonumber) end),
          failed: (if $preload_failed == "" then null else ($preload_failed|tonumber) end),
          json: $preload_json
        },
        measured_json: $measured_json,
        acceptance: {
          write_count_zero: (($write_count == "") or (($write_count|tonumber) == 0)),
          read_not_found_zero: (($read_not_found_count == "") or (($read_not_found_count|tonumber) == 0))
        }
      }')"

    echo "$run_json" >>"$RUNS_JSONL"
    echo "$run_json" >>"$POINT_RUNS_JSONL"
  done

  point_runs_json="$(jq -s '.' "$POINT_RUNS_JSONL")"
  point_summary_json="$(jq -n --arg point_status "$point_status" --argjson runs "$point_runs_json" '
    def median(vals):
      if (vals | length) == 0 then null
      elif (vals | length) % 2 == 1 then (vals | sort | .[((length / 2) | floor)])
      else
        (vals | sort) as $v
        | (($v[(($v | length) / 2) - 1] + $v[(($v | length) / 2)]) / 2)
      end;
    {
      status: $point_status,
      runs: $runs,
      medians: {
        attempted_read_tps: median([$runs[] | select(.attempted_read_tps != null) | .attempted_read_tps]),
        success_read_tps: median([$runs[] | select(.success_read_tps != null) | .success_read_tps]),
        error_rate_percent: median([$runs[] | select(.error_rate_percent != null) | .error_rate_percent]),
        p50_ms: median([$runs[] | select(.p50_ms != null) | .p50_ms]),
        p95_ms: median([$runs[] | select(.p95_ms != null) | .p95_ms]),
        p99_ms: median([$runs[] | select(.p99_ms != null) | .p99_ms]),
        read_count: median([$runs[] | select(.read_count != null) | .read_count]),
        write_count: median([$runs[] | select(.write_count != null) | .write_count]),
        read_not_found_count: median([$runs[] | select(.read_not_found_count != null) | .read_not_found_count]),
        generator_to_service_cpu_ratio: median([$runs[] | select(.generator_to_service_cpu_ratio != null) | .generator_to_service_cpu_ratio]),
        service_cpu_mcores_sum: median([$runs[] | select(.service_cpu_mcores_sum != null) | .service_cpu_mcores_sum]),
        generator_cpu_mcores_sum: median([$runs[] | select(.generator_cpu_mcores_sum != null) | .generator_cpu_mcores_sum]),
        cluster_node_count: median([$runs[] | select(.cluster_node_count != null) | .cluster_node_count])
      },
      acceptance: {
        all_trials_write_count_zero: ([$runs[] | .acceptance.write_count_zero] | all),
        all_trials_read_not_found_zero: ([$runs[] | .acceptance.read_not_found_zero] | all)
      },
      preload: {
        status: ($runs[0].preload.status // null),
        attempted: ($runs[0].preload.attempted // null),
        success: ($runs[0].preload.success // null),
        failed: ($runs[0].preload.failed // null),
        json: ($runs[0].preload.json // null)
      }
    }
  ')"

  median_attempted_tps="$(jq -r '.medians.attempted_read_tps // empty' <<<"$point_summary_json")"
  median_success_tps="$(jq -r '.medians.success_read_tps // empty' <<<"$point_summary_json")"
  median_error_rate="$(jq -r '.medians.error_rate_percent // empty' <<<"$point_summary_json")"
  median_p50="$(jq -r '.medians.p50_ms // empty' <<<"$point_summary_json")"
  median_p95="$(jq -r '.medians.p95_ms // empty' <<<"$point_summary_json")"
  median_p99="$(jq -r '.medians.p99_ms // empty' <<<"$point_summary_json")"
  median_read_count="$(jq -r '.medians.read_count // empty' <<<"$point_summary_json")"
  median_write_count="$(jq -r '.medians.write_count // empty' <<<"$point_summary_json")"
  median_read_not_found_count="$(jq -r '.medians.read_not_found_count // empty' <<<"$point_summary_json")"
  median_generator_ratio="$(jq -r '.medians.generator_to_service_cpu_ratio // empty' <<<"$point_summary_json")"
  median_service_cpu="$(jq -r '.medians.service_cpu_mcores_sum // empty' <<<"$point_summary_json")"
  median_generator_cpu="$(jq -r '.medians.generator_cpu_mcores_sum // empty' <<<"$point_summary_json")"
  median_cluster_nodes="$(jq -r '.medians.cluster_node_count // empty' <<<"$point_summary_json")"
  preload_failed_value="$(jq -r '.preload.failed // empty' <<<"$point_summary_json")"
  preload_status_value="$(jq -r '.preload.status // empty' <<<"$point_summary_json")"
  preload_json_rel_value="$(jq -r '.preload.json // empty' <<<"$point_summary_json")"

  echo "$point_index,$node_count,$data_replicas,median,$point_status,$median_attempted_tps,$median_success_tps,$median_error_rate,$median_p50,$median_p95,$median_p99,$median_read_count,$median_write_count,$median_read_not_found_count,$median_generator_ratio,$median_service_cpu,$median_generator_cpu,$median_cluster_nodes,$preload_status_value,$preload_failed_value,$preload_json_rel_value," >>"$SWEEP_CSV"

  if [[ -n "$median_success_tps" ]] && awk -v a="$median_success_tps" -v b="$best_median_success_tps" 'BEGIN { exit !(a > b) }'; then
    best_median_success_tps="$median_success_tps"
    best_node_count="$node_count"
    best_data_replicas="$data_replicas"
  fi

  point_json="$(jq -n \
    --arg point_index "$point_index" \
    --arg node_count "$node_count" \
    --arg data_replicas "$data_replicas" \
    --arg point_status "$point_status" \
    --argjson point_summary "$point_summary_json" \
    --arg est_hourly "$(
      if [[ -n "$NODE_HOURLY_USD" ]]; then
        awk -v cp="$EKS_CONTROL_PLANE_HOURLY_USD" -v nh="$NODE_HOURLY_USD" -v nodes="$node_count" 'BEGIN { printf "%.4f", cp + (nh * nodes) }'
      else
        printf ''
      fi
    )" \
    '{
      point_index: ($point_index|tonumber),
      node_count: ($node_count|tonumber),
      data_replicas: ($data_replicas|tonumber),
      status: $point_status,
      estimated_hourly_usd_compute_only: (if $est_hourly == "" then null else ($est_hourly|tonumber) end),
      preload: $point_summary.preload,
      medians: $point_summary.medians,
      acceptance_gate_median: {
        write_count_zero: (($point_summary.medians.write_count // 0) == 0),
        read_not_found_zero: (($point_summary.medians.read_not_found_count // 0) == 0),
        all_trials_write_count_zero: ($point_summary.acceptance.all_trials_write_count_zero // false),
        all_trials_read_not_found_zero: ($point_summary.acceptance.all_trials_read_not_found_zero // false)
      },
      runs: $point_summary.runs
    }')"
  echo "$point_json" >>"$POINTS_JSONL"

  rm -f "$POINT_RUNS_JSONL"
done

runs_json="$(jq -s '.' "$RUNS_JSONL")"
points_json="$(jq -s '.' "$POINTS_JSONL")"

max_daily_estimate=""
if [[ -n "$NODE_HOURLY_USD" ]]; then
  max_daily_estimate="$(awk -v cp="$EKS_CONTROL_PLANE_HOURLY_USD" -v nh="$NODE_HOURLY_USD" -v nodes="$max_node_count" 'BEGIN { printf "%.4f", (cp + (nh * nodes)) * 24.0 }')"
fi

SWEEP_JSON_REL="$(to_repo_relative "$SWEEP_JSON")"
SWEEP_CSV_REL="$(to_repo_relative "$SWEEP_CSV")"
RUN_ROOT_REL="$(to_repo_relative "$RUN_ROOT")"

jq -n \
  --arg benchmark "eks_read_hit_upperbound_sweep" \
  --arg status "$overall_status" \
  --arg timestamp_utc "$RUN_TS_HUMAN" \
  --arg cluster_name "$CLUSTER_NAME" \
  --arg region "$REGION" \
  --arg namespace "$NAMESPACE" \
  --arg nodegroup_name "$NODEGROUP_NAME" \
  --arg node_type "$NODE_TYPE" \
  --arg node_counts "$NODE_COUNTS" \
  --arg repeats "$REPEATS" \
  --arg keyspace "$KEYSPACE" \
  --arg value_bytes "$VALUE_BYTES" \
  --arg read_distribution "$READ_DISTRIBUTION" \
  --arg read_vus "$READ_VUS" \
  --arg read_duration "$READ_DURATION" \
  --arg preload_duration "$PRELOAD_DURATION" \
  --arg request_timeout_ms "$REQUEST_TIMEOUT_MS" \
  --arg preload_retries "$PRELOAD_RETRIES" \
  --arg preload_retry_sleep_ms "$PRELOAD_RETRY_SLEEP_MS" \
  --arg image "$IMAGE" \
  --arg bench_node_label "$BENCH_NODE_LABEL" \
  --arg bench_taint_effect "$BENCH_TAINT_EFFECT" \
  --arg max_daily_usd "$MAX_DAILY_USD" \
  --arg node_hourly_usd "$NODE_HOURLY_USD" \
  --arg max_daily_estimate "$max_daily_estimate" \
  --arg restore_on_exit "$RESTORE_ON_EXIT" \
  --arg original_nodegroup_desired "$ORIGINAL_NODEGROUP_DESIRED" \
  --arg original_nodegroup_min "$ORIGINAL_NODEGROUP_MIN" \
  --arg original_nodegroup_max "$ORIGINAL_NODEGROUP_MAX" \
  --arg original_data_replicas "$ORIGINAL_DATA_REPLICAS" \
  --arg max_data_replicas "$MAX_DATA_REPLICAS_IN_SWEEP" \
  --arg required_min_shards "$SHARD_COUNT_MIN_REQUIRED" \
  --arg effective_shards "$EFFECTIVE_SHARD_COUNT" \
  --arg best_node_count "$best_node_count" \
  --arg best_data_replicas "$best_data_replicas" \
  --arg best_median_success_tps "$best_median_success_tps" \
  --arg summary_csv "$SWEEP_CSV_REL" \
  --arg run_reports_root "$RUN_ROOT_REL" \
  --argjson runs "$runs_json" \
  --argjson points "$points_json" \
  '{
    benchmark: $benchmark,
    status: $status,
    timestamp_utc: $timestamp_utc,
    cluster_name: $cluster_name,
    region: $region,
    namespace: $namespace,
    nodegroup_name: $nodegroup_name,
    node_type: $node_type,
    sweep: {
      node_counts: $node_counts,
      repeats: ($repeats|tonumber),
      mode: "lockstep"
    },
    benchmark_profile: {
      preload_stage: {
        parallelism: 1,
        completions: 1,
        vus: 1,
        duration: $preload_duration,
        preload: true,
        skip_main: true,
        read_ratio: 1.0,
        distribution: "sequential"
      },
      measured_stage: {
        parallelism_mode: "lockstep_node_count",
        completions_mode: "lockstep_node_count",
        vus_per_pod: ($read_vus|tonumber),
        duration: $read_duration,
        preload: false,
        skip_main: false,
        read_ratio: 1.0,
        distribution: $read_distribution,
        request_timeout_ms: ($request_timeout_ms|tonumber),
        keyspace: ($keyspace|tonumber),
        value_bytes: ($value_bytes|tonumber)
      }
    },
    run_options: {
      image: (if $image == "" then null else $image end),
      bench_node_label: (if $bench_node_label == "" then null else $bench_node_label end),
      bench_taint_effect: $bench_taint_effect,
      preload_retries: ($preload_retries|tonumber),
      preload_retry_sleep_ms: ($preload_retry_sleep_ms|tonumber)
    },
    cost_guardrail: {
      max_daily_usd: ($max_daily_usd|tonumber),
      node_hourly_usd: (if $node_hourly_usd == "" then null else ($node_hourly_usd|tonumber) end),
      max_daily_estimate_compute_only: (if $max_daily_estimate == "" then null else ($max_daily_estimate|tonumber) end)
    },
    restore_on_exit: ($restore_on_exit == "1"),
    shard_count: {
      max_data_replicas_in_sweep: ($max_data_replicas|tonumber),
      required_min: ($required_min_shards|tonumber),
      effective: ($effective_shards|tonumber)
    },
    original_scale: {
      nodegroup_desired: ($original_nodegroup_desired|tonumber),
      nodegroup_min: ($original_nodegroup_min|tonumber),
      nodegroup_max: ($original_nodegroup_max|tonumber),
      data_replicas: ($original_data_replicas|tonumber)
    },
    best_point: (
      if $best_node_count == "" then null
      else {
        node_count: ($best_node_count|tonumber),
        data_replicas: ($best_data_replicas|tonumber),
        median_success_read_tps: ($best_median_success_tps|tonumber)
      }
      end
    ),
    summary_csv: $summary_csv,
    run_reports_root: $run_reports_root,
    points: $points,
    runs: $runs
  }' >"$SWEEP_JSON"

{
  echo "# NotDynamo EKS Read-Hit Upper-Bound Sweep"
  echo
  echo "- Timestamp (UTC): \`$RUN_TS_HUMAN\`"
  echo "- Cluster: \`$CLUSTER_NAME\`"
  echo "- Region: \`$REGION\`"
  echo "- Namespace: \`$NAMESPACE\`"
  echo "- Nodegroup: \`$NODEGROUP_NAME\`"
  echo "- Node type: \`$NODE_TYPE\`"
  echo "- Node counts: \`$NODE_COUNTS\`"
  echo "- Repeats per point (measured stage): \`$REPEATS\`"
  echo "- Measured profile: \`read_ratio=1.0\`, \`distribution=$READ_DISTRIBUTION\`, \`vus_per_pod=$READ_VUS\`, \`duration=$READ_DURATION\`"
  echo "- Preload profile: \`parallelism=1\`, \`completions=1\`, \`vus=1\`, \`duration=$PRELOAD_DURATION\`, \`preload=true\`, \`skip_main=true\`"
  echo "- Shard count effective: \`$EFFECTIVE_SHARD_COUNT\` (required min for sweep: \`$SHARD_COUNT_MIN_REQUIRED\`)"
  echo "- Status: \`$overall_status\`"
  if [[ -n "$best_node_count" ]]; then
    echo "- Best median success read TPS: \`node_count=$best_node_count data_replicas=$best_data_replicas success_read_tps=$best_median_success_tps\`"
  fi
  if [[ -n "$NODE_HOURLY_USD" && -n "$max_daily_estimate" ]]; then
    echo "- Cost guard: \`max_daily_usd=$MAX_DAILY_USD\`, estimated max daily (compute+control only): \`$max_daily_estimate\`"
  fi
  if [[ -n "$BENCH_NODE_LABEL" ]]; then
    echo "- Benchmark node label: \`$BENCH_NODE_LABEL\` (\`$BENCH_TAINT_EFFECT\`)"
  fi
  echo
  echo "## Median By Point"
  echo
  echo "| Point | Node count | Data replicas | Median attempted read TPS | Median success read TPS | Median error % | Median p95 (ms) | Median p99 (ms) | Median read misses | Median write count | Median gen/service CPU ratio | All trials write=0 | All trials miss=0 |"
  echo "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|"
  jq -r '.points[] | "| \(.point_index) | \(.node_count) | \(.data_replicas) | \(.medians.attempted_read_tps // \"n/a\") | \(.medians.success_read_tps // \"n/a\") | \(.medians.error_rate_percent // \"n/a\") | \(.medians.p95_ms // \"n/a\") | \(.medians.p99_ms // \"n/a\") | \(.medians.read_not_found_count // \"n/a\") | \(.medians.write_count // \"n/a\") | \(.medians.generator_to_service_cpu_ratio // \"n/a\") | \(.acceptance_gate_median.all_trials_write_count_zero) | \(.acceptance_gate_median.all_trials_read_not_found_zero) |"' "$SWEEP_JSON"
  echo
  echo "## Trial Runs"
  echo
  echo "| Point | Trial | Node count | Data replicas | Status | Attempted read TPS | Success read TPS | Error % | p95 (ms) | p99 (ms) | Read count | Write count | Read misses | Gen/Svc CPU ratio | Preload status | Preload failed | Measured JSON |"
  echo "|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|"
  awk -F',' 'NR>1 && $4!="median" {
    printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | `%s` |\n", $1,$4,$2,$3,$5,$6,$7,$8,$10,$11,$12,$13,$14,$15,$19,$20,$22
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

rm -f "$RUNS_JSONL" "$POINTS_JSONL"

echo "EKS read-hit upper-bound sweep complete."
echo "Status: $overall_status"
echo "JSON summary: $(to_repo_relative "$SWEEP_JSON")"
echo "Markdown summary: $(to_repo_relative "$SWEEP_MD")"
echo "CSV summary: $(to_repo_relative "$SWEEP_CSV")"
echo "Latest JSON: $(to_repo_relative "$LATEST_JSON_FILE")"
echo "Latest Markdown: $(to_repo_relative "$LATEST_MD_FILE")"
echo "Latest CSV: $(to_repo_relative "$LATEST_CSV_FILE")"

if [[ "$overall_status" == "FAIL" ]]; then
  exit 1
fi
