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
DATA_REPLICAS_MODE="lockstep"
DATA_REPLICAS_FIXED=""
REPEATS=2
SETTLE_SEC=20
NODE_READY_TIMEOUT_SEC=1200
ROLLOUT_TIMEOUT_SEC=1800
RESTORE_ON_EXIT=1

KEYSPACE=20000
VALUE_BYTES=256
DISTRIBUTION="uniform"
ZIPF_THETA=0.90
PRELOAD="false"
SKIP_BUILD=0
IMAGE=""
BENCH_NODE_LABEL=""
BENCH_TAINT_EFFECT="NoSchedule"
WAIT_TIMEOUT_SEC=1800

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
Usage: eks_write_gate_sweep.sh [options]

Runs standardized write-gate benchmark sweeps across node counts.
For each point, it runs N repeated in-cluster write-gate trials and reports median metrics.

Defaults:
  node_counts=11,17,23,29,35
  repeats=2
  data_replicas_mode=lockstep (data replicas == node count)

Options:
  --name <cluster-name>           EKS cluster name (default: notdynamo-eks)
  --region <aws-region>           AWS region (default: AWS_REGION or us-west-2)
  --namespace <ns>                Namespace (default: notdynamo)
  --nodegroup-name <name>         Managed nodegroup name (default: notdynamo-ng)
  --data-statefulset <name>       Data StatefulSet name (default: notdynamo-data)
  --control-plane-deployment <n>  Control-plane deployment (default: notdynamo-control-plane)
  --service <name>                Service name (default: notdynamo-data)

  --node-counts <csv>             Node counts, e.g. 11,17,23,29,35
  --repeats <n>                   Repeats per node count (default: 2)
  --data-replicas-mode <mode>     lockstep|fixed (default: lockstep)
  --data-replicas-fixed <n>       Used when mode=fixed

  --settle-sec <n>                Wait after scaling (default: 20)
  --node-ready-timeout-sec <n>    Node readiness timeout (default: 1200)
  --rollout-timeout-sec <n>       StatefulSet rollout timeout (default: 1800)
  --wait-timeout-sec <n>          Per-trial benchmark timeout (default: 1800)
  --no-restore                    Do not restore original scale on exit

  --keyspace <n>                  Keyspace (default: 20000)
  --value-bytes <n>               Value bytes (default: 256)
  --distribution <name>           uniform|sequential|zipf (default: uniform)
  --zipf-theta <0..1>             Zipf theta (default: 0.90)
  --preload <true|false>          Preload in trial (default: false)
  --skip-build                    Reuse existing benchmark image
  --image <image-ref>             Benchmark image (required with --skip-build)
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
    --data-replicas-mode)
      DATA_REPLICAS_MODE="$2"
      shift 2
      ;;
    --data-replicas-fixed)
      DATA_REPLICAS_FIXED="$2"
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
    --distribution)
      DISTRIBUTION="$2"
      shift 2
      ;;
    --zipf-theta)
      ZIPF_THETA="$2"
      shift 2
      ;;
    --preload)
      PRELOAD="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
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
  local raw
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
  echo \
    "Adjusting NOTDYNAMO_SHARD_COUNT from $current_shard_count to $EFFECTIVE_SHARD_COUNT for lockstep coverage (max_replicas=$max_data_replicas rf=$replication_factor)"
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
    local nodes_json
    nodes_json="$(kubectl get nodes -l "$selector" -o json)"
    local node_count ready_count
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

for n in "$REPEATS" "$SETTLE_SEC" "$NODE_READY_TIMEOUT_SEC" "$ROLLOUT_TIMEOUT_SEC" "$WAIT_TIMEOUT_SEC" "$KEYSPACE" "$VALUE_BYTES"; do
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
if [[ "$DATA_REPLICAS_MODE" != "lockstep" && "$DATA_REPLICAS_MODE" != "fixed" ]]; then
  echo "--data-replicas-mode must be one of: lockstep, fixed" >&2
  exit 1
fi
if [[ "$DATA_REPLICAS_MODE" == "fixed" ]]; then
  if [[ -z "$DATA_REPLICAS_FIXED" || ! "$DATA_REPLICAS_FIXED" =~ ^[0-9]+$ || "$DATA_REPLICAS_FIXED" == "0" ]]; then
    echo "--data-replicas-fixed must be a positive integer when mode=fixed" >&2
    exit 1
  fi
fi
if (( SKIP_BUILD == 1 )) && [[ -z "$IMAGE" ]]; then
  echo "--skip-build requires --image <image-ref>" >&2
  exit 1
fi

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

parse_csv_positive_ints "$NODE_COUNTS" "node-counts" NODE_COUNTS_ARRAY

max_node_count=0
for n in "${NODE_COUNTS_ARRAY[@]}"; do
  if (( n > max_node_count )); then
    max_node_count="$n"
  fi
done
if [[ "$DATA_REPLICAS_MODE" == "lockstep" ]]; then
  MAX_DATA_REPLICAS_IN_SWEEP="$max_node_count"
else
  MAX_DATA_REPLICAS_IN_SWEEP="$DATA_REPLICAS_FIXED"
fi

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
  max_hourly="$(awk \
    -v cp="$EKS_CONTROL_PLANE_HOURLY_USD" \
    -v nh="$NODE_HOURLY_USD" \
    -v nv="$node_volume_hourly" \
    -v nodes="$max_node_count" \
    'BEGIN { printf "%.6f", cp + ((nh + nv) * nodes) }')"
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
  SWEEP_JSON="$REPORT_DIR/write_gate_sweep_${RUN_TS}.json"
  SWEEP_MD="$REPORT_DIR/write_gate_sweep_${RUN_TS}.md"
  SWEEP_CSV="$REPORT_DIR/write_gate_sweep_${RUN_TS}.csv"
  RUN_ROOT="$REPORT_DIR/write_gate_sweep_${RUN_TS}_runs"
fi
LATEST_JSON_FILE="$REPORT_DIR/write_gate_sweep_latest.json"
LATEST_MD_FILE="$REPORT_DIR/write_gate_sweep_latest.md"
LATEST_CSV_FILE="$REPORT_DIR/write_gate_sweep_latest.csv"

mkdir -p "$(dirname "$SWEEP_JSON")" "$(dirname "$SWEEP_MD")" "$(dirname "$SWEEP_CSV")" "$RUN_ROOT"

RUNS_JSONL="$(mktemp /tmp/notdynamo-write-gate-runs.XXXXXX)"
POINTS_JSONL="$(mktemp /tmp/notdynamo-write-gate-points.XXXXXX)"
echo "point_index,node_count,data_replicas,trial,status,success_tps,error_rate_percent,timeout_fraction,forward_error_fraction,consensus_error_fraction,forward_hop_ratio,generator_to_service_cpu_ratio,benchmark_json,scorecard_json" >"$SWEEP_CSV"

overall_status="PASS"
run_index=0
point_index=0
best_node_count=""
best_data_replicas=""
best_median_success_tps="0"

for node_count in "${NODE_COUNTS_ARRAY[@]}"; do
  point_index=$((point_index + 1))
  if [[ "$DATA_REPLICAS_MODE" == "lockstep" ]]; then
    data_replicas="$node_count"
  else
    data_replicas="$DATA_REPLICAS_FIXED"
  fi

  scale_nodegroup "$node_count"
  scale_data_plane "$data_replicas"
  if (( SETTLE_SEC > 0 )); then
    sleep "$SETTLE_SEC"
  fi

  point_dir="$RUN_ROOT/point_${point_index}_n${node_count}_r${data_replicas}"
  mkdir -p "$point_dir"
  POINT_RUNS_JSONL="$(mktemp /tmp/notdynamo-write-gate-point-runs.XXXXXX)"
  point_status="PASS"

  for trial in $(seq 1 "$REPEATS"); do
    run_index=$((run_index + 1))
    trial_dir="$point_dir/trial_${trial}"
    mkdir -p "$trial_dir"
    score_prefix="$trial_dir/write_gate_scorecard"
    score_json="${score_prefix}.json"

    gate_args=(
      "$ROOT_DIR/scripts/eks/eks_write_gate_run.sh"
      --name "$CLUSTER_NAME"
      --region "$REGION"
      --namespace "$NAMESPACE"
      --data-statefulset "$DATA_STATEFULSET"
      --service "$SERVICE_NAME"
      --keyspace "$KEYSPACE"
      --value-bytes "$VALUE_BYTES"
      --distribution "$DISTRIBUTION"
      --zipf-theta "$ZIPF_THETA"
      --preload "$PRELOAD"
      --wait-timeout-sec "$WAIT_TIMEOUT_SEC"
      --output-prefix "$score_prefix"
    )
    if (( SKIP_BUILD == 1 )); then
      gate_args+=(--skip-build)
    fi
    if [[ -n "$IMAGE" ]]; then
      gate_args+=(--image "$IMAGE")
    fi
    if [[ -n "$BENCH_NODE_LABEL" ]]; then
      gate_args+=(--bench-node-label "$BENCH_NODE_LABEL" --bench-taint-effect "$BENCH_TAINT_EFFECT")
    fi

    echo "Running write gate trial: point=$point_index node_count=$node_count data_replicas=$data_replicas trial=$trial"
    set +e
    "${gate_args[@]}"
    run_rc=$?
    set -e

    status="PASS"
    success_tps=""
    error_rate=""
    timeout_fraction=""
    forward_fraction=""
    consensus_fraction=""
    forward_hop_ratio=""
    generator_ratio=""
    benchmark_json=""
    score_json_rel="$(to_repo_relative "$score_json")"
    if (( run_rc != 0 )) || [[ ! -f "$score_json" ]]; then
      status="FAIL"
      point_status="FAIL"
      overall_status="FAIL"
    else
      success_tps="$(jq -r '.scorecard.success_tps // empty' "$score_json")"
      error_rate="$(jq -r '.scorecard.error_rate_percent // empty' "$score_json")"
      timeout_fraction="$(jq -r '.scorecard.put_timeout_fraction_of_put_errors // empty' "$score_json")"
      forward_fraction="$(jq -r '.scorecard.forward_error_fraction // empty' "$score_json")"
      consensus_fraction="$(jq -r '.scorecard.consensus_reply_error_fraction // empty' "$score_json")"
      forward_hop_ratio="$(jq -r '.scorecard.forward_hop_ratio_avg // empty' "$score_json")"
      generator_ratio="$(jq -r '.scorecard.generator_to_service_cpu_ratio // empty' "$score_json")"
      benchmark_json="$(jq -r '.input_benchmark_json // empty' "$score_json")"
      if [[ -n "$benchmark_json" && "$benchmark_json" == "$ROOT_DIR/"* ]]; then
        benchmark_json="${benchmark_json#"$ROOT_DIR/"}"
      fi
    fi

    echo "$point_index,$node_count,$data_replicas,$trial,$status,$success_tps,$error_rate,$timeout_fraction,$forward_fraction,$consensus_fraction,$forward_hop_ratio,$generator_ratio,$benchmark_json,$score_json_rel" >>"$SWEEP_CSV"

    run_json="$(jq -n \
      --arg run_index "$run_index" \
      --arg point_index "$point_index" \
      --arg node_count "$node_count" \
      --arg data_replicas "$data_replicas" \
      --arg trial "$trial" \
      --arg status "$status" \
      --arg run_rc "$run_rc" \
      --arg success_tps "$success_tps" \
      --arg error_rate "$error_rate" \
      --arg timeout_fraction "$timeout_fraction" \
      --arg forward_fraction "$forward_fraction" \
      --arg consensus_fraction "$consensus_fraction" \
      --arg forward_hop_ratio "$forward_hop_ratio" \
      --arg generator_ratio "$generator_ratio" \
      --arg benchmark_json "$benchmark_json" \
      --arg scorecard_json "$score_json_rel" \
      '{
        run_index: ($run_index|tonumber),
        point_index: ($point_index|tonumber),
        node_count: ($node_count|tonumber),
        data_replicas: ($data_replicas|tonumber),
        trial: ($trial|tonumber),
        status: $status,
        exit_code: ($run_rc|tonumber),
        success_tps: (if $success_tps == "" then null else ($success_tps|tonumber) end),
        error_rate_percent: (if $error_rate == "" then null else ($error_rate|tonumber) end),
        timeout_fraction: (if $timeout_fraction == "" then null else ($timeout_fraction|tonumber) end),
        forward_error_fraction: (if $forward_fraction == "" then null else ($forward_fraction|tonumber) end),
        consensus_reply_error_fraction: (if $consensus_fraction == "" then null else ($consensus_fraction|tonumber) end),
        forward_hop_ratio_avg: (if $forward_hop_ratio == "" then null else ($forward_hop_ratio|tonumber) end),
        generator_to_service_cpu_ratio: (if $generator_ratio == "" then null else ($generator_ratio|tonumber) end),
        benchmark_json: (if $benchmark_json == "" then null else $benchmark_json end),
        scorecard_json: $scorecard_json
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
        success_tps: median([$runs[] | select(.success_tps != null) | .success_tps]),
        error_rate_percent: median([$runs[] | select(.error_rate_percent != null) | .error_rate_percent]),
        timeout_fraction: median([$runs[] | select(.timeout_fraction != null) | .timeout_fraction]),
        forward_error_fraction: median([$runs[] | select(.forward_error_fraction != null) | .forward_error_fraction]),
        consensus_reply_error_fraction: median([$runs[] | select(.consensus_reply_error_fraction != null) | .consensus_reply_error_fraction]),
        forward_hop_ratio_avg: median([$runs[] | select(.forward_hop_ratio_avg != null) | .forward_hop_ratio_avg]),
        generator_to_service_cpu_ratio: median([$runs[] | select(.generator_to_service_cpu_ratio != null) | .generator_to_service_cpu_ratio])
      }
    }
  ')"

  median_success_tps="$(jq -r '.medians.success_tps // empty' <<<"$point_summary_json")"
  median_error_rate="$(jq -r '.medians.error_rate_percent // empty' <<<"$point_summary_json")"
  median_timeout_fraction="$(jq -r '.medians.timeout_fraction // empty' <<<"$point_summary_json")"
  median_forward_fraction="$(jq -r '.medians.forward_error_fraction // empty' <<<"$point_summary_json")"
  median_consensus_fraction="$(jq -r '.medians.consensus_reply_error_fraction // empty' <<<"$point_summary_json")"
  median_forward_hop="$(jq -r '.medians.forward_hop_ratio_avg // empty' <<<"$point_summary_json")"
  median_generator_ratio="$(jq -r '.medians.generator_to_service_cpu_ratio // empty' <<<"$point_summary_json")"

  echo "$point_index,$node_count,$data_replicas,median,$point_status,$median_success_tps,$median_error_rate,$median_timeout_fraction,$median_forward_fraction,$median_consensus_fraction,$median_forward_hop,$median_generator_ratio,," >>"$SWEEP_CSV"

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
      medians: $point_summary.medians,
      acceptance_gate_median: {
        success_tps_gte_1000: (($point_summary.medians.success_tps // 0) >= 1000),
        error_rate_percent_lte_15: (($point_summary.medians.error_rate_percent // 1000000) <= 15),
        put_timeout_fraction_lte_0_60: (($point_summary.medians.timeout_fraction // 1000000) <= 0.60),
        generator_ratio_lt_0_25: (($point_summary.medians.generator_to_service_cpu_ratio // 1000000) < 0.25)
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
  max_node_count=0
  for n in "${NODE_COUNTS_ARRAY[@]}"; do
    if (( n > max_node_count )); then
      max_node_count="$n"
    fi
  done
  max_daily_estimate="$(awk -v cp="$EKS_CONTROL_PLANE_HOURLY_USD" -v nh="$NODE_HOURLY_USD" -v nodes="$max_node_count" 'BEGIN { printf "%.4f", (cp + (nh * nodes)) * 24.0 }')"
fi

SWEEP_JSON_REL="$(to_repo_relative "$SWEEP_JSON")"
SWEEP_CSV_REL="$(to_repo_relative "$SWEEP_CSV")"
RUN_ROOT_REL="$(to_repo_relative "$RUN_ROOT")"

jq -n \
  --arg benchmark "eks_write_gate_scaling_sweep" \
  --arg timestamp_utc "$RUN_TS_HUMAN" \
  --arg cluster_name "$CLUSTER_NAME" \
  --arg region "$REGION" \
  --arg namespace "$NAMESPACE" \
  --arg nodegroup_name "$NODEGROUP_NAME" \
  --arg node_type "$NODE_TYPE" \
  --arg node_counts "$NODE_COUNTS" \
  --arg repeats "$REPEATS" \
  --arg data_replicas_mode "$DATA_REPLICAS_MODE" \
  --arg data_replicas_fixed "$DATA_REPLICAS_FIXED" \
  --arg status "$overall_status" \
  --arg restore_on_exit "$RESTORE_ON_EXIT" \
  --arg keyspace "$KEYSPACE" \
  --arg value_bytes "$VALUE_BYTES" \
  --arg distribution "$DISTRIBUTION" \
  --arg zipf_theta "$ZIPF_THETA" \
  --arg preload "$PRELOAD" \
  --arg skip_build "$SKIP_BUILD" \
  --arg image "$IMAGE" \
  --arg bench_node_label "$BENCH_NODE_LABEL" \
  --arg bench_taint_effect "$BENCH_TAINT_EFFECT" \
  --arg max_daily_usd "$MAX_DAILY_USD" \
  --arg node_hourly_usd "$NODE_HOURLY_USD" \
  --arg max_daily_estimate "$max_daily_estimate" \
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
      data_replicas_mode: $data_replicas_mode,
      data_replicas_fixed: (if $data_replicas_fixed == "" then null else ($data_replicas_fixed|tonumber) end)
    },
    benchmark_profile: {
      read_ratio: 0.10,
      vus: 32,
      duration: "90s",
      request_timeout_ms: 5000,
      keyspace: ($keyspace|tonumber),
      value_bytes: ($value_bytes|tonumber),
      distribution: $distribution,
      zipf_theta: ($zipf_theta|tonumber),
      preload: ($preload == "true")
    },
    run_options: {
      skip_build: ($skip_build == "1"),
      image: (if $image == "" then null else $image end),
      bench_node_label: (if $bench_node_label == "" then null else $bench_node_label end),
      bench_taint_effect: $bench_taint_effect
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
        median_success_tps: ($best_median_success_tps|tonumber)
      }
      end
    ),
    summary_csv: $summary_csv,
    run_reports_root: $run_reports_root,
    points: $points,
    runs: $runs
  }' >"$SWEEP_JSON"

{
  echo "# NotDynamo EKS Write Gate Sweep"
  echo
  echo "- Timestamp (UTC): \`$RUN_TS_HUMAN\`"
  echo "- Cluster: \`$CLUSTER_NAME\`"
  echo "- Region: \`$REGION\`"
  echo "- Namespace: \`$NAMESPACE\`"
  echo "- Nodegroup: \`$NODEGROUP_NAME\`"
  echo "- Node type: \`$NODE_TYPE\`"
  echo "- Node counts: \`$NODE_COUNTS\`"
  echo "- Repeats per point: \`$REPEATS\`"
  echo "- Data replicas mode: \`$DATA_REPLICAS_MODE\`"
  echo "- Shard count effective: \`$EFFECTIVE_SHARD_COUNT\` (required min for sweep: \`$SHARD_COUNT_MIN_REQUIRED\`)"
  if [[ -n "$DATA_REPLICAS_FIXED" ]]; then
    echo "- Fixed data replicas: \`$DATA_REPLICAS_FIXED\`"
  fi
  echo "- Status: \`$overall_status\`"
  if [[ -n "$best_node_count" ]]; then
    echo "- Best median success TPS: \`node_count=$best_node_count data_replicas=$best_data_replicas success_tps=$best_median_success_tps\`"
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
  echo "| Point | Node count | Data replicas | Median success TPS | Median error % | Median timeout fraction | Median forward split | Median consensus split | Median forward-hop ratio | Median gen/service CPU ratio | Gate success>=1000 | Gate err<=15% | Gate timeout<=0.60 | Gate gen ratio<0.25 |"
  echo "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|---|---|"
  jq -r '.points[] | "| \(.point_index) | \(.node_count) | \(.data_replicas) | \(.medians.success_tps // "n/a") | \(.medians.error_rate_percent // "n/a") | \(.medians.timeout_fraction // "n/a") | \(.medians.forward_error_fraction // "n/a") | \(.medians.consensus_reply_error_fraction // "n/a") | \(.medians.forward_hop_ratio_avg // "n/a") | \(.medians.generator_to_service_cpu_ratio // "n/a") | \(.acceptance_gate_median.success_tps_gte_1000) | \(.acceptance_gate_median.error_rate_percent_lte_15) | \(.acceptance_gate_median.put_timeout_fraction_lte_0_60) | \(.acceptance_gate_median.generator_ratio_lt_0_25) |"' "$SWEEP_JSON"
  echo
  echo "## Trial Runs"
  echo
  echo "| Point | Trial | Node count | Data replicas | Status | Success TPS | Error % | Timeout fraction | Forward split | Consensus split | Forward-hop ratio | Gen/Svc CPU ratio | Scorecard |"
  echo "|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---|"
  awk -F',' 'NR>1 && $4!="median" {
    printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | `%s` |\n", $1,$4,$2,$3,$5,$6,$7,$8,$9,$10,$11,$12,$14
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

echo "EKS write gate sweep complete."
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
