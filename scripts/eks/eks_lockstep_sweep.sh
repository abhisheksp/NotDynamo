#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CLUSTER_NAME="${NOTDYNAMO_EKS_CLUSTER:-notdynamo-eks}"
REGION="${AWS_REGION:-us-west-2}"
NAMESPACE="notdynamo"
NODEGROUP_NAME="notdynamo-ng"
DATA_STATEFULSET="notdynamo-data"
CONTROL_PLANE_DEPLOYMENT="notdynamo-control-plane"

NODE_COUNTS="11,17,23,29,35"
REPLICATION_FACTOR=3
TOTAL_SHARDS="${NOTDYNAMO_SHARD_COUNT:-128}"
SETTLE_SEC=20
NODE_READY_TIMEOUT_SEC=900
ROLLOUT_TIMEOUT_SEC=1200
RESTORE_ON_EXIT=1

RUN_EXTERNAL=0
RUN_INCLUSTER=1
EXTERNAL_MODE="load-balancer"
EXTERNAL_LB_WAIT_TIMEOUT_SEC=900
EXTERNAL_LB_SCHEME="internet-facing"
EXTERNAL_LB_TYPE="nlb"
EXTERNAL_LB_HOST=""
EXTERNAL_LB_MANAGE_SERVICE=1
EXTERNAL_LB_KEEP_SERVICE=0

OPERATIONS=36000
KEYSPACE=10000
THREADS=24
READ_RATIO=0.90
DISTRIBUTION="uniform"
ZIPF_THETA=0.90
VALUE_BYTES=256
PRELOAD=true
CONNECT_TIMEOUT_MS=3000
REQUEST_TIMEOUT_MS=5000
INCLUSTER_PARALLELISM=6
INCLUSTER_COMPLETIONS=6
INCLUSTER_KEEP_JOB=0
INCLUSTER_SKIP_BUILD=0
INCLUSTER_IMAGE=""
INCLUSTER_BENCH_NODE_LABEL=""
INCLUSTER_BENCH_TAINT_EFFECT="NoSchedule"

OUTPUT_PREFIX=""
LATEST_JSON_FILE=""
LATEST_MD_FILE=""
LATEST_CSV_FILE=""

NODE_HOURLY_USD=""
EKS_CONTROL_PLANE_HOURLY_USD="0.10"
NODE_ROOT_EBS_GIB=80
NODE_ROOT_EBS_GB_MONTH_USD="0.08"
DATA_PVC_EBS_GIB=20
DATA_PVC_EBS_GB_MONTH_USD="0.10"
ENFORCE_QUOTA_CHECK=1

ORIGINAL_NODEGROUP_DESIRED=""
ORIGINAL_NODEGROUP_MIN=""
ORIGINAL_NODEGROUP_MAX=""
ORIGINAL_DATA_REPLICAS=""
RESTORE_ARMED=0

usage() {
  cat <<'USAGE'
Usage: eks_lockstep_sweep.sh [options]

Runs lockstep EKS sweeps where node_count == data_replicas for each point.
This wraps eks_scaling_sweep.sh and always emits one summary CSV/JSON/MD report set.

Cluster options:
  --name <cluster-name>            EKS cluster name (default: notdynamo-eks)
  --region <aws-region>            AWS region (default: AWS_REGION or us-west-2)
  --namespace <ns>                 Kubernetes namespace (default: notdynamo)
  --nodegroup-name <name>          Managed nodegroup name (default: notdynamo-ng)
  --data-statefulset <name>        Data statefulset name (default: notdynamo-data)
  --control-plane-deployment <n>   Control-plane deployment name (default: notdynamo-control-plane)

Sweep options:
  --counts <csv>                   Lockstep counts, e.g. 11,17,23,29,35
  --replication-factor <n>         RF for reporting (default: 3)
  --total-shards <n>               Logical shard count (default: 128)
  --settle-sec <n>                 Sleep after each scale event (default: 20)
  --node-ready-timeout-sec <n>     Node readiness timeout (default: 900)
  --rollout-timeout-sec <n>        Stateful workload rollout timeout (default: 1200)
  --no-restore                     Do not restore original nodegroup + data replicas on exit

Categories:
  --include-external               Include external benchmark category (default: disabled)
  --skip-incluster                 Skip in-cluster benchmark category
  --external-mode <mode>           port-forward|load-balancer (default: load-balancer)
  --external-lb-wait-timeout-sec <n>
                                   LB endpoint readiness timeout (default: 900)
  --external-lb-scheme <mode>      internet-facing|internal (default: internet-facing)
  --external-lb-type <type>        nlb|classic (default: nlb)
  --external-lb-host <host>        LB host/IP override
  --external-lb-no-manage-service  Do not patch service type/annotations in LB mode
  --external-lb-keep-service-lb    Keep service as LB after each external run

Benchmark knobs:
  --operations <n>                 Total operations (default: 36000)
  --keyspace <n>                   Keyspace size (default: 10000)
  --threads <n>                    Threads (default: 24)
  --read-ratio <0..1>              Read ratio (default: 0.90)
  --distribution <name>            uniform|sequential|zipf (default: uniform)
  --zipf-theta <0..1>              Zipf theta (default: 0.90)
  --value-bytes <n>                Value bytes (default: 256)
  --preload <true|false>           Preload benchmark keyspace (default: true)
  --connect-timeout-ms <n>         Connect timeout (default: 3000)
  --request-timeout-ms <n>         Request timeout (default: 5000)
  --incluster-parallelism <n>      In-cluster job parallelism (default: 6)
  --incluster-completions <n>      In-cluster job completions (default: 6)
  --incluster-keep-job             Keep in-cluster benchmark job resources after each run
  --incluster-skip-build           Reuse existing benchmark image (requires --incluster-image)
  --incluster-image <image>        Benchmark image to use for in-cluster jobs
  --incluster-bench-node-label <key=value>
                                   Schedule in-cluster benchmark pods only on nodes with this label
                                   and add matching toleration
  --incluster-bench-taint-effect <effect>
                                   Toleration effect for benchmark node taint
                                   (default: NoSchedule)

Cost options:
  --node-hourly-usd <amount>       Override node instance hourly price for estimates
  --skip-quota-check               Skip EC2 vCPU quota feasibility pre-check

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
    --counts)
      NODE_COUNTS="$2"
      shift 2
      ;;
    --replication-factor)
      REPLICATION_FACTOR="$2"
      shift 2
      ;;
    --total-shards)
      TOTAL_SHARDS="$2"
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
    --node-hourly-usd)
      NODE_HOURLY_USD="$2"
      shift 2
      ;;
    --skip-quota-check)
      ENFORCE_QUOTA_CHECK=0
      shift
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
  "$REPLICATION_FACTOR" "$TOTAL_SHARDS" "$SETTLE_SEC" "$NODE_READY_TIMEOUT_SEC" "$ROLLOUT_TIMEOUT_SEC" \
  "$EXTERNAL_LB_WAIT_TIMEOUT_SEC" "$OPERATIONS" "$KEYSPACE" "$THREADS" "$VALUE_BYTES" \
  "$CONNECT_TIMEOUT_MS" "$REQUEST_TIMEOUT_MS" "$INCLUSTER_PARALLELISM" "$INCLUSTER_COMPLETIONS"
do
  if [[ ! "$n" =~ ^[0-9]+$ ]] || (( n <= 0 )); then
    echo "numeric options must be positive integers" >&2
    exit 1
  fi
done
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
if [[ -n "$NODE_HOURLY_USD" ]] && ! [[ "$NODE_HOURLY_USD" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "--node-hourly-usd must be a positive number" >&2
  exit 1
fi
if (( RUN_EXTERNAL == 0 && RUN_INCLUSTER == 0 )); then
  echo "at least one benchmark category must be enabled" >&2
  exit 1
fi
if (( INCLUSTER_SKIP_BUILD == 1 )) && [[ -z "$INCLUSTER_IMAGE" ]]; then
  echo "--incluster-skip-build requires --incluster-image <image>" >&2
  exit 1
fi

require_bin() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

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

number_or_null() {
  local value="$1"
  if [[ -z "$value" || "$value" == "null" ]]; then
    echo "null"
  elif [[ "$value" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
    echo "$value"
  else
    echo "null"
  fi
}

resolve_node_hourly_usd() {
  if [[ -n "$NODE_HOURLY_USD" ]]; then
    echo "$NODE_HOURLY_USD"
    return 0
  fi

  local node_type
  node_type="$(aws eks describe-nodegroup \
    --cluster-name "$CLUSTER_NAME" \
    --region "$REGION" \
    --nodegroup-name "$NODEGROUP_NAME" \
    --query 'nodegroup.instanceTypes[0]' \
    --output text)"

  case "$node_type" in
    t3.medium) echo "0.0416" ;;
    t3.large) echo "0.0832" ;;
    c6i.large) echo "0.0850" ;;
    m6i.large) echo "0.0960" ;;
    m5.large) echo "0.0960" ;;
    c5.large) echo "0.0850" ;;
    *)
      echo ""
      ;;
  esac
}

resolve_nodegroup_instance_type() {
  aws eks describe-nodegroup \
    --cluster-name "$CLUSTER_NAME" \
    --region "$REGION" \
    --nodegroup-name "$NODEGROUP_NAME" \
    --query 'nodegroup.instanceTypes[0]' \
    --output text
}

resolve_nodegroup_capacity_type() {
  aws eks describe-nodegroup \
    --cluster-name "$CLUSTER_NAME" \
    --region "$REGION" \
    --nodegroup-name "$NODEGROUP_NAME" \
    --query 'nodegroup.capacityType' \
    --output text
}

resolve_instance_vcpus() {
  local instance_type="$1"
  aws ec2 describe-instance-types \
    --region "$REGION" \
    --instance-types "$instance_type" \
    --query 'InstanceTypes[0].VCpuInfo.DefaultVCpus' \
    --output text
}

resolve_vcpu_quota_limit() {
  local capacity_type="$1"
  local quota_code="L-1216C47A"
  if [[ "$capacity_type" == "SPOT" ]]; then
    quota_code="L-34B43A08"
  fi

  aws service-quotas get-service-quota \
    --service-code ec2 \
    --quota-code "$quota_code" \
    --region "$REGION" \
    --query 'Quota.Value' \
    --output text
}

cleanup() {
  if (( RESTORE_ON_EXIT == 1 )) && (( RESTORE_ARMED == 1 )); then
    echo "[restore] Restoring original cluster scale settings..."
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
    echo "[restore] done"
  fi
}
trap cleanup EXIT

require_bin aws
require_bin kubectl
require_bin eksctl
require_bin jq

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "AWS credentials are not configured or not valid." >&2
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
if ! kubectl -n "$NAMESPACE" get statefulset "$DATA_STATEFULSET" >/dev/null 2>&1; then
  echo "statefulset '$DATA_STATEFULSET' not found in namespace '$NAMESPACE'" >&2
  exit 1
fi
if ! kubectl -n "$NAMESPACE" get deployment "$CONTROL_PLANE_DEPLOYMENT" >/dev/null 2>&1; then
  echo "deployment '$CONTROL_PLANE_DEPLOYMENT' not found in namespace '$NAMESPACE'" >&2
  exit 1
fi

parse_csv_positive_ints "$NODE_COUNTS" "counts" NODE_COUNTS_ARRAY

NODE_HOURLY="$(resolve_node_hourly_usd)"
if [[ -z "$NODE_HOURLY" ]]; then
  echo "unable to infer node hourly cost for nodegroup '$NODEGROUP_NAME'." >&2
  echo "re-run with --node-hourly-usd <amount>" >&2
  exit 1
fi

if (( ENFORCE_QUOTA_CHECK == 1 )); then
  node_instance_type="$(resolve_nodegroup_instance_type)"
  node_capacity_type="$(resolve_nodegroup_capacity_type)"
  node_vcpus="$(resolve_instance_vcpus "$node_instance_type" 2>/dev/null || true)"
  quota_limit="$(resolve_vcpu_quota_limit "$node_capacity_type" 2>/dev/null || true)"

  if [[ "$node_vcpus" =~ ^[0-9]+$ ]] && [[ "$quota_limit" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    max_nodes_for_quota="$(awk -v quota="$quota_limit" -v vcpu="$node_vcpus" 'BEGIN { printf "%d", quota / vcpu }')"
    if (( max_nodes_for_quota <= 0 )); then
      echo "computed max nodes from quota is zero; check account EC2 quotas." >&2
      exit 1
    fi
    for n in "${NODE_COUNTS_ARRAY[@]}"; do
      if (( n > max_nodes_for_quota )); then
        echo "count '$n' exceeds account quota feasibility for nodegroup '$NODEGROUP_NAME'." >&2
        echo "node type=$node_instance_type vcpu_per_node=$node_vcpus capacity_type=$node_capacity_type quota_vcpu=$quota_limit max_nodes=$max_nodes_for_quota" >&2
        echo "either reduce --counts, switch to smaller-vCPU nodes, or increase AWS EC2 vCPU quota." >&2
        exit 1
      fi
    done
  else
    echo "warning: unable to resolve vCPU quota feasibility; continuing without quota pre-check" >&2
  fi
fi

ORIGINAL_NODEGROUP_DESIRED="$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --region "$REGION" --nodegroup-name "$NODEGROUP_NAME" --query 'nodegroup.scalingConfig.desiredSize' --output text)"
ORIGINAL_NODEGROUP_MIN="$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --region "$REGION" --nodegroup-name "$NODEGROUP_NAME" --query 'nodegroup.scalingConfig.minSize' --output text)"
ORIGINAL_NODEGROUP_MAX="$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --region "$REGION" --nodegroup-name "$NODEGROUP_NAME" --query 'nodegroup.scalingConfig.maxSize' --output text)"
ORIGINAL_DATA_REPLICAS="$(kubectl -n "$NAMESPACE" get statefulset "$DATA_STATEFULSET" -o jsonpath='{.spec.replicas}')"
RESTORE_ARMED=1

RUN_TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_TS_HUMAN="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
REPORT_DIR="$ROOT_DIR/reports/benchmarks/aws"
if [[ -n "$OUTPUT_PREFIX" ]]; then
  SUMMARY_JSON="${OUTPUT_PREFIX}.json"
  SUMMARY_MD="${OUTPUT_PREFIX}.md"
  SUMMARY_CSV="${OUTPUT_PREFIX}.csv"
  RUN_ROOT="${OUTPUT_PREFIX}_runs"
else
  SUMMARY_JSON="$REPORT_DIR/lockstep_sweep_${RUN_TS}.json"
  SUMMARY_MD="$REPORT_DIR/lockstep_sweep_${RUN_TS}.md"
  SUMMARY_CSV="$REPORT_DIR/lockstep_sweep_${RUN_TS}.csv"
  RUN_ROOT="$REPORT_DIR/lockstep_sweep_${RUN_TS}_runs"
fi
if [[ -z "$LATEST_JSON_FILE" ]]; then
  LATEST_JSON_FILE="$REPORT_DIR/lockstep_sweep_latest.json"
fi
if [[ -z "$LATEST_MD_FILE" ]]; then
  LATEST_MD_FILE="$REPORT_DIR/lockstep_sweep_latest.md"
fi
if [[ -z "$LATEST_CSV_FILE" ]]; then
  LATEST_CSV_FILE="$REPORT_DIR/lockstep_sweep_latest.csv"
fi

mkdir -p "$(dirname "$SUMMARY_JSON")"
mkdir -p "$(dirname "$SUMMARY_MD")"
mkdir -p "$(dirname "$SUMMARY_CSV")"
mkdir -p "$(dirname "$LATEST_JSON_FILE")"
mkdir -p "$(dirname "$LATEST_MD_FILE")"
mkdir -p "$(dirname "$LATEST_CSV_FILE")"
mkdir -p "$RUN_ROOT"

RUNS_JSONL="$(mktemp /tmp/notdynamo-lockstep-runs.XXXXXX)"
echo "node_count,data_replicas,replication_factor,total_shards,shard_replicas_per_node,estimated_cost_usd_per_hour,status,matrix_exit_code,external_mode,external_tps,external_p99_ms,external_error_rate_percent,incluster_tps,incluster_p95_ms,incluster_p99_ms,incluster_error_rate_percent,incluster_telem_hint,incluster_telem_cpu_ratio,report_json,report_md" >"$SUMMARY_CSV"

OVERALL_STATUS="PASS"
BEST_THROUGHPUT="0"
BEST_NODE_COUNT=""

run_index=0
for n in "${NODE_COUNTS_ARRAY[@]}"; do
  run_index=$((run_index + 1))
  prefix="$RUN_ROOT/lockstep_n${n}"
  json="${prefix}.json"
  md="${prefix}.md"

  cmd=(
    "$ROOT_DIR/scripts/eks/eks_scaling_sweep.sh"
    --name "$CLUSTER_NAME"
    --region "$REGION"
    --namespace "$NAMESPACE"
    --nodegroup-name "$NODEGROUP_NAME"
    --data-statefulset "$DATA_STATEFULSET"
    --control-plane-deployment "$CONTROL_PLANE_DEPLOYMENT"
    --node-counts "$n"
    --data-replicas "$n"
    --settle-sec "$SETTLE_SEC"
    --node-ready-timeout-sec "$NODE_READY_TIMEOUT_SEC"
    --rollout-timeout-sec "$ROLLOUT_TIMEOUT_SEC"
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
    --output-prefix "$prefix"
    --no-restore
  )

  if (( RUN_EXTERNAL == 1 )); then
    cmd+=(--include-external --external-mode "$EXTERNAL_MODE")
    if [[ "$EXTERNAL_MODE" == "load-balancer" ]]; then
      cmd+=(
        --external-lb-wait-timeout-sec "$EXTERNAL_LB_WAIT_TIMEOUT_SEC"
        --external-lb-scheme "$EXTERNAL_LB_SCHEME"
        --external-lb-type "$EXTERNAL_LB_TYPE"
      )
      if [[ -n "$EXTERNAL_LB_HOST" ]]; then
        cmd+=(--external-lb-host "$EXTERNAL_LB_HOST")
      fi
      if (( EXTERNAL_LB_MANAGE_SERVICE == 0 )); then
        cmd+=(--external-lb-no-manage-service)
      fi
      if (( EXTERNAL_LB_KEEP_SERVICE == 1 )); then
        cmd+=(--external-lb-keep-service-lb)
      fi
    fi
  else
    cmd+=(--skip-external)
  fi
  if (( RUN_INCLUSTER == 0 )); then
    cmd+=(--skip-incluster)
  fi
  if (( INCLUSTER_KEEP_JOB == 1 )); then
    cmd+=(--incluster-keep-job)
  fi
  if (( INCLUSTER_SKIP_BUILD == 1 )); then
    cmd+=(--incluster-skip-build)
  fi
  if [[ -n "$INCLUSTER_IMAGE" ]]; then
    cmd+=(--incluster-image "$INCLUSTER_IMAGE")
  fi
  if [[ -n "$INCLUSTER_BENCH_NODE_LABEL" ]]; then
    cmd+=(
      --incluster-bench-node-label "$INCLUSTER_BENCH_NODE_LABEL"
      --incluster-bench-taint-effect "$INCLUSTER_BENCH_TAINT_EFFECT"
    )
  fi

  echo "[run $run_index/${#NODE_COUNTS_ARRAY[@]}] lockstep count=$n"
  set +e
  "${cmd[@]}"
  rc=$?
  set -e

  status="FAIL"
  matrix_exit_code="$rc"
  external_mode="disabled"
  external_tps=""
  external_p99=""
  external_error_rate=""
  incluster_tps=""
  incluster_p95=""
  incluster_p99=""
  incluster_error_rate=""
  incluster_telem_hint=""
  incluster_telem_cpu_ratio=""

  if [[ -f "$json" ]]; then
    status="$(jq -r '.runs[0].status // .status // "UNKNOWN"' "$json")"
    matrix_exit_code="$(jq -r '.runs[0].matrix_exit_code // "'"$rc"'"' "$json")"
    external_mode="$(jq -r '.runs[0].external_mode // empty' "$json")"
    external_tps="$(jq -r '.runs[0].external_tps // empty' "$json")"
    external_p99="$(jq -r '.runs[0].external_p99_ms // empty' "$json")"
    external_error_rate="$(jq -r '.runs[0].external_error_rate_percent // empty' "$json")"
    incluster_tps="$(jq -r '.runs[0].incluster_tps // empty' "$json")"
    incluster_p99="$(jq -r '.runs[0].incluster_p99_ms // empty' "$json")"
    incluster_error_rate="$(jq -r '.runs[0].incluster_error_rate_percent // empty' "$json")"
    incluster_telem_hint="$(jq -r '.runs[0].incluster_telemetry_attribution_hint // empty' "$json")"
    incluster_telem_cpu_ratio="$(jq -r '.runs[0].incluster_telemetry_generator_to_service_cpu_ratio // empty' "$json")"

    matrix_report_rel="$(jq -r '.runs[0].report_json // empty' "$json")"
    if [[ -n "$matrix_report_rel" ]]; then
      if [[ "$matrix_report_rel" == /* ]]; then
        matrix_report_abs="$matrix_report_rel"
      else
        matrix_report_abs="$ROOT_DIR/$matrix_report_rel"
      fi
      if [[ -f "$matrix_report_abs" ]]; then
        incluster_p95="$(jq -r '.categories.in_cluster_job.latency_ms_p95_max_pod // empty' "$matrix_report_abs")"
      fi
    fi
  fi

  if [[ -z "$external_mode" ]]; then
    external_mode="disabled"
  fi

  if [[ "$status" == "FAIL" || "$status" == "UNKNOWN" || "$matrix_exit_code" != "0" ]]; then
    status="FAIL"
    OVERALL_STATUS="FAIL"
  fi

  shard_replicas_per_node="$(awk -v rf="$REPLICATION_FACTOR" -v shards="$TOTAL_SHARDS" -v n="$n" 'BEGIN { printf "%.2f", (rf*shards)/n }')"
  estimated_cost_usd_per_hour="$(awk \
    -v n="$n" \
    -v cp="$EKS_CONTROL_PLANE_HOURLY_USD" \
    -v node="$NODE_HOURLY" \
    -v root_gib="$NODE_ROOT_EBS_GIB" \
    -v root_rate="$NODE_ROOT_EBS_GB_MONTH_USD" \
    -v pvc_gib="$DATA_PVC_EBS_GIB" \
    -v pvc_rate="$DATA_PVC_EBS_GB_MONTH_USD" \
    'BEGIN { printf "%.6f", cp + (n*node) + ((n*root_gib*root_rate)/730.0) + ((n*pvc_gib*pvc_rate)/730.0) }')"

  report_json_rel="$(to_repo_relative "$json")"
  report_md_rel="$(to_repo_relative "$md")"

  if awk -v a="${incluster_tps:-0}" -v b="$BEST_THROUGHPUT" 'BEGIN { exit !(a > b) }'; then
    BEST_THROUGHPUT="${incluster_tps:-0}"
    BEST_NODE_COUNT="$n"
  fi

  echo "$n,$n,$REPLICATION_FACTOR,$TOTAL_SHARDS,$shard_replicas_per_node,$estimated_cost_usd_per_hour,$status,$matrix_exit_code,$external_mode,$external_tps,$external_p99,$external_error_rate,$incluster_tps,$incluster_p95,$incluster_p99,$incluster_error_rate,$incluster_telem_hint,$incluster_telem_cpu_ratio,$report_json_rel,$report_md_rel" >>"$SUMMARY_CSV"

  run_json="$(
    jq -n \
      --arg node_count "$n" \
      --arg data_replicas "$n" \
      --arg status "$status" \
      --arg matrix_exit_code "$matrix_exit_code" \
      --arg external_mode "$external_mode" \
      --arg report_json "$report_json_rel" \
      --arg report_md "$report_md_rel" \
      --argjson rf "$(number_or_null "$REPLICATION_FACTOR")" \
      --argjson total_shards "$(number_or_null "$TOTAL_SHARDS")" \
      --argjson shard_replicas_per_node "$(number_or_null "$shard_replicas_per_node")" \
      --argjson estimated_cost_usd_per_hour "$(number_or_null "$estimated_cost_usd_per_hour")" \
      --argjson external_tps "$(number_or_null "$external_tps")" \
      --argjson external_p99_ms "$(number_or_null "$external_p99")" \
      --argjson external_error_rate_percent "$(number_or_null "$external_error_rate")" \
      --argjson incluster_tps "$(number_or_null "$incluster_tps")" \
      --argjson incluster_p95_ms "$(number_or_null "$incluster_p95")" \
      --argjson incluster_p99_ms "$(number_or_null "$incluster_p99")" \
      --argjson incluster_error_rate_percent "$(number_or_null "$incluster_error_rate")" \
      --arg incluster_telem_hint "$incluster_telem_hint" \
      --argjson incluster_telem_cpu_ratio_num "$(number_or_null "$incluster_telem_cpu_ratio")" \
      '{
        node_count: ($node_count|tonumber),
        data_replicas: ($data_replicas|tonumber),
        replication_factor: $rf,
        total_shards: $total_shards,
        shard_replicas_per_node: $shard_replicas_per_node,
        estimated_cost_usd_per_hour: $estimated_cost_usd_per_hour,
        status: $status,
        matrix_exit_code: ($matrix_exit_code|tonumber),
        external_mode: $external_mode,
        external_tps: $external_tps,
        external_p99_ms: $external_p99_ms,
        external_error_rate_percent: $external_error_rate_percent,
        incluster_tps: $incluster_tps,
        incluster_p95_ms: $incluster_p95_ms,
        incluster_p99_ms: $incluster_p99_ms,
        incluster_error_rate_percent: $incluster_error_rate_percent,
        incluster_telemetry_attribution_hint: (if $incluster_telem_hint == "" then null else $incluster_telem_hint end),
        incluster_telemetry_generator_to_service_cpu_ratio: $incluster_telem_cpu_ratio_num,
        report_json: $report_json,
        report_md: $report_md
      }'
  )"
  echo "$run_json" >>"$RUNS_JSONL"
done

runs_json="$(jq -s '.' "$RUNS_JSONL")"

SUMMARY_JSON_REL="$(to_repo_relative "$SUMMARY_JSON")"
SUMMARY_MD_REL="$(to_repo_relative "$SUMMARY_MD")"
SUMMARY_CSV_REL="$(to_repo_relative "$SUMMARY_CSV")"
RUN_ROOT_REL="$(to_repo_relative "$RUN_ROOT")"

jq -n \
  --arg benchmark "eks_lockstep_scaling_sweep" \
  --arg status "$OVERALL_STATUS" \
  --arg timestamp_utc "$RUN_TS_HUMAN" \
  --arg cluster_name "$CLUSTER_NAME" \
  --arg region "$REGION" \
  --arg namespace "$NAMESPACE" \
  --arg nodegroup_name "$NODEGROUP_NAME" \
  --arg counts "$NODE_COUNTS" \
  --argjson replication_factor "$(number_or_null "$REPLICATION_FACTOR")" \
  --argjson total_shards "$(number_or_null "$TOTAL_SHARDS")" \
  --argjson node_hourly_usd "$(number_or_null "$NODE_HOURLY")" \
  --argjson control_plane_hourly_usd "$(number_or_null "$EKS_CONTROL_PLANE_HOURLY_USD")" \
  --argjson node_root_ebs_gib "$(number_or_null "$NODE_ROOT_EBS_GIB")" \
  --argjson node_root_ebs_gb_month_usd "$(number_or_null "$NODE_ROOT_EBS_GB_MONTH_USD")" \
  --argjson data_pvc_ebs_gib "$(number_or_null "$DATA_PVC_EBS_GIB")" \
  --argjson data_pvc_ebs_gb_month_usd "$(number_or_null "$DATA_PVC_EBS_GB_MONTH_USD")" \
  --arg run_external "$RUN_EXTERNAL" \
  --arg run_incluster "$RUN_INCLUSTER" \
  --arg incluster_skip_build "$INCLUSTER_SKIP_BUILD" \
  --arg incluster_image "$INCLUSTER_IMAGE" \
  --arg incluster_bench_node_label "$INCLUSTER_BENCH_NODE_LABEL" \
  --arg incluster_bench_taint_effect "$INCLUSTER_BENCH_TAINT_EFFECT" \
  --arg restore_on_exit "$RESTORE_ON_EXIT" \
  --arg best_node_count "$BEST_NODE_COUNT" \
  --argjson best_incluster_tps "$(number_or_null "$BEST_THROUGHPUT")" \
  --arg summary_csv "$SUMMARY_CSV_REL" \
  --arg run_reports_root "$RUN_ROOT_REL" \
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
      lockstep_counts: $counts,
      replication_factor: $replication_factor,
      total_shards: $total_shards
    },
    benchmark_categories: {
      external_enabled: ($run_external == "1"),
      incluster_enabled: ($run_incluster == "1"),
      incluster_skip_build: ($incluster_skip_build == "1"),
      incluster_image: (if $incluster_image == "" then null else $incluster_image end),
      incluster_bench_node_label: (if $incluster_bench_node_label == "" then null else $incluster_bench_node_label end),
      incluster_bench_taint_effect: $incluster_bench_taint_effect
    },
    cost_assumptions: {
      node_hourly_usd: $node_hourly_usd,
      control_plane_hourly_usd: $control_plane_hourly_usd,
      node_root_ebs_gib: $node_root_ebs_gib,
      node_root_ebs_gb_month_usd: $node_root_ebs_gb_month_usd,
      data_pvc_ebs_gib: $data_pvc_ebs_gib,
      data_pvc_ebs_gb_month_usd: $data_pvc_ebs_gb_month_usd
    },
    restore_on_exit: ($restore_on_exit == "1"),
    best_run: (if $best_node_count == "" then null else {
      node_count: ($best_node_count|tonumber),
      data_replicas: ($best_node_count|tonumber),
      incluster_tps: $best_incluster_tps
    } end),
    summary_csv: $summary_csv,
    run_reports_root: $run_reports_root,
    runs: $runs
  }' >"$SUMMARY_JSON"

{
  echo "# NotDynamo EKS Lockstep Sweep"
  echo
  echo "- Timestamp (UTC): $RUN_TS_HUMAN"
  echo "- Cluster: \`$CLUSTER_NAME\`"
  echo "- Region: \`$REGION\`"
  echo "- Namespace: \`$NAMESPACE\`"
  echo "- Nodegroup: \`$NODEGROUP_NAME\`"
  echo "- Lockstep counts: \`$NODE_COUNTS\`"
  echo "- RF: \`$REPLICATION_FACTOR\`"
  echo "- Total shards: \`$TOTAL_SHARDS\`"
  echo "- Status: \`$OVERALL_STATUS\`"
  echo "- Node hourly cost estimate: \`$NODE_HOURLY\` USD/hour"
  if (( INCLUSTER_SKIP_BUILD == 1 )); then
    echo "- In-cluster image reuse: \`$INCLUSTER_IMAGE\`"
  fi
  if [[ -n "$INCLUSTER_BENCH_NODE_LABEL" ]]; then
    echo "- In-cluster benchmark node label: \`$INCLUSTER_BENCH_NODE_LABEL\` (\`$INCLUSTER_BENCH_TAINT_EFFECT\`)"
  fi
  if [[ -n "$BEST_NODE_COUNT" ]]; then
    echo "- Best in-cluster TPS point: \`nodes=$BEST_NODE_COUNT data_replicas=$BEST_NODE_COUNT tps=$BEST_THROUGHPUT\`"
  fi
  echo
  echo "## Results"
  echo
  echo "| Nodes | Data replicas | RF | Shard replicas/node | Est $/hour | Status | In-cluster TPS | In-cluster p95 (ms) | In-cluster p99 (ms) | Error % | Telem hint | Gen/Svc CPU ratio | Report |"
  echo "|---|---|---|---|---|---|---|---|---|---|---|---|---|"
  awk -F',' 'NR>1 {printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | `%s` |\n", $1,$2,$3,$5,$6,$7,$13,$14,$15,$16,$17,$18,$19}' "$SUMMARY_CSV"
  echo
  echo "## Artifacts"
  echo
  echo "- JSON summary: \`$SUMMARY_JSON_REL\`"
  echo "- CSV summary: \`$SUMMARY_CSV_REL\`"
  echo "- Run reports root: \`$RUN_ROOT_REL\`"
} >"$SUMMARY_MD"

cp "$SUMMARY_JSON" "$LATEST_JSON_FILE"
cp "$SUMMARY_MD" "$LATEST_MD_FILE"
cp "$SUMMARY_CSV" "$LATEST_CSV_FILE"
rm -f "$RUNS_JSONL"

echo "EKS lockstep sweep complete."
echo "Status: $OVERALL_STATUS"
echo "JSON summary: $(to_repo_relative "$SUMMARY_JSON")"
echo "Markdown summary: $(to_repo_relative "$SUMMARY_MD")"
echo "CSV summary: $(to_repo_relative "$SUMMARY_CSV")"
echo "Latest JSON: $(to_repo_relative "$LATEST_JSON_FILE")"
echo "Latest Markdown: $(to_repo_relative "$LATEST_MD_FILE")"
echo "Latest CSV: $(to_repo_relative "$LATEST_CSV_FILE")"

if [[ "$OVERALL_STATUS" == "FAIL" ]]; then
  exit 1
fi
