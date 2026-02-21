#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CLUSTER_NAME="${NOTDYNAMO_EKS_CLUSTER:-notdynamo-eks}"
REGION="${AWS_REGION:-us-west-2}"
NAMESPACE="notdynamo"
NODE_TYPE="t3.large"
NODES=2
NODES_MIN=2
NODES_MAX=4
MAX_DAILY_USD=20
ALLOW_OVER_BUDGET=0
API_ENDPOINT_MODE="restricted"
API_PUBLIC_CIDR=""

DATA_REPLICAS=3
CONTROL_PLANE_REPLICAS=1
PROVIDER="${IMAGE_PROVIDER:-auto}"
SKIP_BUILD=0
IMAGE=""

RUN_EXTERNAL=0
EXTERNAL_MODE="port-forward"
EXTERNAL_LB_WAIT_TIMEOUT_SEC=900
EXTERNAL_LB_SCHEME="internet-facing"
EXTERNAL_LB_TYPE="nlb"
EXTERNAL_LB_HOST=""
EXTERNAL_LB_MANAGE_SERVICE=1
EXTERNAL_LB_KEEP_SERVICE=0

OPERATIONS=10000
KEYSPACE=10000
THREADS=16
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
INCLUSTER_BENCH_NODE_LABEL=""
INCLUSTER_BENCH_TAINT_EFFECT="NoSchedule"

KEEP_CLUSTER=0
DELETE_ECR_REPO=0
SKIP_EBS_CLEANUP=0
IMAGE_REPO="notdynamo/notdynamo"

OUTPUT_PREFIX=""
RUNBOOK_JSON=""
RUNBOOK_MD=""

usage() {
  cat <<'USAGE'
Usage: eks_runbook.sh [options]

Runs one-command EKS lifecycle:
  setup -> deploy -> smoke -> benchmark -> teardown -> cleanup-audit

Cluster setup options:
  --name <cluster-name>           EKS cluster name (default: notdynamo-eks)
  --region <aws-region>           AWS region (default: AWS_REGION or us-west-2)
  --namespace <ns>                Namespace (default: notdynamo)
  --node-type <type>              Node instance type (default: t3.large)
  --nodes <n>                     Desired nodes (default: 2)
  --nodes-min <n>                 Nodegroup min (default: 2)
  --nodes-max <n>                 Nodegroup max (default: 4)
  --max-daily-usd <amount>        Cost cap passed to eks_up.sh (default: 20)
  --allow-over-budget             Pass --allow-over-budget to eks_up.sh
  --public-api                    Pass --public-api to eks_up.sh
  --private-api-only              Pass --private-api-only to eks_up.sh
  --public-cidr <cidr>            Pass --public-cidr to eks_up.sh

Deploy options:
  --data-replicas <n>             Stateful data replicas (default: 3)
  --control-plane-replicas <n>    Control-plane replicas (default: 1)
  --provider <auto|docker|nerdctl>
                                  Image provider for eks_deploy.sh (default: auto)
  --skip-build                    Deploy an existing image (requires --image)
  --image <image-ref>             Image to deploy with --skip-build
  --image-repo <repo>             ECR repo used by deploy/teardown (default: notdynamo/notdynamo)

Benchmark options:
  --include-external              Include external benchmark path in matrix
  --external-mode <mode>          port-forward|load-balancer (default: port-forward)
  --external-lb-wait-timeout-sec <n>
                                  LB wait timeout (default: 900)
  --external-lb-scheme <mode>     internet-facing|internal (default: internet-facing)
  --external-lb-type <type>       nlb|classic (default: nlb)
  --external-lb-host <host>       LB host/IP override
  --external-lb-no-manage-service Do not patch service in LB mode
  --external-lb-keep-service-lb   Keep service LB exposure after benchmark
  --operations <n>                Benchmark operations (default: 10000)
  --keyspace <n>                  Benchmark keyspace (default: 10000)
  --threads <n>                   Benchmark threads (default: 16)
  --read-ratio <0..1>             Read ratio (default: 0.90)
  --distribution <name>           uniform|sequential|zipf (default: uniform)
  --zipf-theta <0..1>             Zipf theta (default: 0.90)
  --value-bytes <n>               Value bytes (default: 256)
  --preload <true|false>          Preload keyspace (default: false)
  --connect-timeout-ms <n>        Connect timeout (default: 3000)
  --request-timeout-ms <n>        Request timeout (default: 5000)
  --incluster-parallelism <n>     In-cluster parallelism (default: 4)
  --incluster-completions <n>     In-cluster completions (default: 4)
  --incluster-keep-job            Keep in-cluster benchmark jobs
  --incluster-bench-node-label <key=value>
                                  Schedule in-cluster benchmark pods only on nodes with this label
                                  and add matching toleration
  --incluster-bench-taint-effect <effect>
                                  Toleration effect for benchmark node taint
                                  (default: NoSchedule)

Teardown options:
  --keep-cluster                  Skip teardown and cleanup audit
  --delete-ecr-repo              Delete ECR repo in teardown
  --skip-ebs-cleanup             Skip EBS cleanup in teardown

Output options:
  --output-prefix <path>          Writes <path>.json/.md and artifacts in <path>_artifacts
  --runbook-json <path>           Explicit JSON report path
  --runbook-md <path>             Explicit Markdown report path

  --help                          Show this help
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
    --node-type)
      NODE_TYPE="$2"
      shift 2
      ;;
    --nodes)
      NODES="$2"
      shift 2
      ;;
    --nodes-min)
      NODES_MIN="$2"
      shift 2
      ;;
    --nodes-max)
      NODES_MAX="$2"
      shift 2
      ;;
    --max-daily-usd)
      MAX_DAILY_USD="$2"
      shift 2
      ;;
    --allow-over-budget)
      ALLOW_OVER_BUDGET=1
      shift
      ;;
    --public-api)
      API_ENDPOINT_MODE="public"
      shift
      ;;
    --private-api-only)
      API_ENDPOINT_MODE="private"
      shift
      ;;
    --public-cidr)
      API_PUBLIC_CIDR="$2"
      shift 2
      ;;
    --data-replicas)
      DATA_REPLICAS="$2"
      shift 2
      ;;
    --control-plane-replicas)
      CONTROL_PLANE_REPLICAS="$2"
      shift 2
      ;;
    --provider)
      PROVIDER="$2"
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
    --image-repo)
      IMAGE_REPO="$2"
      shift 2
      ;;
    --include-external)
      RUN_EXTERNAL=1
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
    --incluster-bench-node-label)
      INCLUSTER_BENCH_NODE_LABEL="$2"
      shift 2
      ;;
    --incluster-bench-taint-effect)
      INCLUSTER_BENCH_TAINT_EFFECT="$2"
      shift 2
      ;;
    --keep-cluster)
      KEEP_CLUSTER=1
      shift
      ;;
    --delete-ecr-repo)
      DELETE_ECR_REPO=1
      shift
      ;;
    --skip-ebs-cleanup)
      SKIP_EBS_CLEANUP=1
      shift
      ;;
    --output-prefix)
      OUTPUT_PREFIX="$2"
      shift 2
      ;;
    --runbook-json)
      RUNBOOK_JSON="$2"
      shift 2
      ;;
    --runbook-md)
      RUNBOOK_MD="$2"
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
  "$NODES" "$NODES_MIN" "$NODES_MAX" "$DATA_REPLICAS" "$CONTROL_PLANE_REPLICAS" \
  "$EXTERNAL_LB_WAIT_TIMEOUT_SEC" "$OPERATIONS" "$KEYSPACE" "$THREADS" "$VALUE_BYTES" \
  "$CONNECT_TIMEOUT_MS" "$REQUEST_TIMEOUT_MS" "$INCLUSTER_PARALLELISM" "$INCLUSTER_COMPLETIONS"
do
  if [[ ! "$n" =~ ^[0-9]+$ ]] || (( n <= 0 )); then
    echo "numeric options must be positive integers" >&2
    exit 1
  fi
done
if (( NODES_MIN > NODES_MAX )); then
  echo "--nodes-min cannot be greater than --nodes-max" >&2
  exit 1
fi
if (( NODES < NODES_MIN || NODES > NODES_MAX )); then
  echo "--nodes must be between --nodes-min and --nodes-max" >&2
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
if (( SKIP_BUILD == 1 )) && [[ -z "$IMAGE" ]]; then
  echo "--skip-build requires --image <image-ref>" >&2
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

record_step() {
  local step_name="$1"
  local status="$2"
  local exit_code="$3"
  local started_utc="$4"
  local finished_utc="$5"
  local command_text="$6"
  local note="$7"

  jq -n \
    --arg step "$step_name" \
    --arg status "$status" \
    --arg exit_code "$exit_code" \
    --arg started "$started_utc" \
    --arg finished "$finished_utc" \
    --arg command "$command_text" \
    --arg note "$note" \
    '{
      step: $step,
      status: $status,
      exit_code: (if $exit_code == "" then null else ($exit_code|tonumber) end),
      started_utc: $started,
      finished_utc: $finished,
      command: $command,
      note: $note
    }' >>"$STEPS_JSONL"
}

run_step() {
  local step_name="$1"
  shift
  local -a cmd=("$@")
  local started finished rc status command_text
  started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  command_text="$(printf '%q ' "${cmd[@]}")"
  set +e
  "${cmd[@]}"
  rc=$?
  set -e
  finished="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  status="PASS"
  if (( rc != 0 )); then
    status="FAIL"
  fi
  record_step "$step_name" "$status" "$rc" "$started" "$finished" "$command_text" ""
  return "$rc"
}

record_skipped_step() {
  local step_name="$1"
  local note="$2"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  record_step "$step_name" "SKIPPED" "" "$ts" "$ts" "" "$note"
}

RUN_TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_TS_HUMAN="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
REPORT_DIR="$ROOT_DIR/reports/benchmarks/aws"

if [[ -n "$OUTPUT_PREFIX" ]]; then
  RUNBOOK_JSON="${RUNBOOK_JSON:-${OUTPUT_PREFIX}.json}"
  RUNBOOK_MD="${RUNBOOK_MD:-${OUTPUT_PREFIX}.md}"
  RUN_ARTIFACT_DIR="${OUTPUT_PREFIX}_artifacts"
else
  RUNBOOK_JSON="${RUNBOOK_JSON:-$REPORT_DIR/runbook_${RUN_TS}.json}"
  RUNBOOK_MD="${RUNBOOK_MD:-$REPORT_DIR/runbook_${RUN_TS}.md}"
  RUN_ARTIFACT_DIR="$REPORT_DIR/runbook_${RUN_TS}_artifacts"
fi
mkdir -p "$(dirname "$RUNBOOK_JSON")"
mkdir -p "$(dirname "$RUNBOOK_MD")"
mkdir -p "$RUN_ARTIFACT_DIR"

MATRIX_JSON="$RUN_ARTIFACT_DIR/benchmark_matrix.json"
MATRIX_MD="$RUN_ARTIFACT_DIR/benchmark_matrix.md"
CLEANUP_JSON="$RUN_ARTIFACT_DIR/cleanup_audit.json"
CLEANUP_MD="$RUN_ARTIFACT_DIR/cleanup_audit.md"

STEPS_JSONL="$(mktemp /tmp/notdynamo-eks-runbook-steps.XXXXXX.jsonl)"
OVERALL_STATUS="PASS"

mark_fail() {
  OVERALL_STATUS="FAIL"
}

mark_warn_if_pass() {
  if [[ "$OVERALL_STATUS" == "PASS" ]]; then
    OVERALL_STATUS="WARN"
  fi
}

UP_OK=0
DEPLOY_OK=0
SMOKE_OK=0
BENCH_OK=0
TEARDOWN_OK=0
CLEANUP_OK=0
CLEANUP_STATUS="SKIPPED"

UP_CMD=(
  "$ROOT_DIR/scripts/eks/eks_up.sh"
  --name "$CLUSTER_NAME"
  --region "$REGION"
  --node-type "$NODE_TYPE"
  --nodes "$NODES"
  --nodes-min "$NODES_MIN"
  --nodes-max "$NODES_MAX"
  --max-daily-usd "$MAX_DAILY_USD"
)
if (( ALLOW_OVER_BUDGET == 1 )); then
  UP_CMD+=(--allow-over-budget)
fi
case "$API_ENDPOINT_MODE" in
  public)
    UP_CMD+=(--public-api)
    ;;
  private)
    UP_CMD+=(--private-api-only)
    ;;
esac
if [[ -n "$API_PUBLIC_CIDR" ]]; then
  UP_CMD+=(--public-cidr "$API_PUBLIC_CIDR")
fi

if run_step "eks_up" "${UP_CMD[@]}"; then
  UP_OK=1
else
  mark_fail
fi

if (( UP_OK == 1 )); then
  DEPLOY_CMD=(
    "$ROOT_DIR/scripts/eks/eks_deploy.sh"
    --name "$CLUSTER_NAME"
    --region "$REGION"
    --namespace "$NAMESPACE"
    --provider "$PROVIDER"
    --data-replicas "$DATA_REPLICAS"
    --control-plane-replicas "$CONTROL_PLANE_REPLICAS"
    --image-repo "$IMAGE_REPO"
  )
  if (( SKIP_BUILD == 1 )); then
    DEPLOY_CMD+=(--skip-build --image "$IMAGE")
  elif [[ -n "$IMAGE" ]]; then
    DEPLOY_CMD+=(--image "$IMAGE")
  fi

  if run_step "eks_deploy" "${DEPLOY_CMD[@]}"; then
    DEPLOY_OK=1
  else
    mark_fail
  fi
else
  record_skipped_step "eks_deploy" "Skipped because eks_up failed"
fi

if (( DEPLOY_OK == 1 )); then
  if run_step "eks_smoke" \
    "$ROOT_DIR/scripts/eks/eks_smoke.sh" \
    --name "$CLUSTER_NAME" \
    --region "$REGION" \
    --namespace "$NAMESPACE"; then
    SMOKE_OK=1
  else
    mark_fail
  fi
else
  record_skipped_step "eks_smoke" "Skipped because eks_deploy failed"
fi

if (( SMOKE_OK == 1 )); then
  BENCH_CMD=(
    "$ROOT_DIR/scripts/eks/eks_bench_matrix.sh"
    --name "$CLUSTER_NAME"
    --region "$REGION"
    --namespace "$NAMESPACE"
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
    --matrix-output-file "$MATRIX_JSON"
    --matrix-human-report-file "$MATRIX_MD"
  )
  if (( RUN_EXTERNAL == 0 )); then
    BENCH_CMD+=(--skip-external)
  else
    BENCH_CMD+=(--external-mode "$EXTERNAL_MODE")
    if [[ "$EXTERNAL_MODE" == "load-balancer" ]]; then
      BENCH_CMD+=(
        --external-lb-wait-timeout-sec "$EXTERNAL_LB_WAIT_TIMEOUT_SEC"
        --external-lb-scheme "$EXTERNAL_LB_SCHEME"
        --external-lb-type "$EXTERNAL_LB_TYPE"
      )
      if [[ -n "$EXTERNAL_LB_HOST" ]]; then
        BENCH_CMD+=(--external-lb-host "$EXTERNAL_LB_HOST")
      fi
      if (( EXTERNAL_LB_MANAGE_SERVICE == 0 )); then
        BENCH_CMD+=(--external-lb-no-manage-service)
      fi
      if (( EXTERNAL_LB_KEEP_SERVICE == 1 )); then
        BENCH_CMD+=(--external-lb-keep-service-lb)
      fi
    fi
  fi
  if (( INCLUSTER_KEEP_JOB == 1 )); then
    BENCH_CMD+=(--incluster-keep-job)
  fi
  if [[ -n "$INCLUSTER_BENCH_NODE_LABEL" ]]; then
    BENCH_CMD+=(
      --incluster-bench-node-label "$INCLUSTER_BENCH_NODE_LABEL"
      --incluster-bench-taint-effect "$INCLUSTER_BENCH_TAINT_EFFECT"
    )
  fi

  if run_step "eks_bench_matrix" "${BENCH_CMD[@]}"; then
    BENCH_OK=1
  else
    mark_fail
  fi

  if [[ -f "$MATRIX_JSON" ]]; then
    BENCH_STATUS="$(jq -r '.status // "UNKNOWN"' "$MATRIX_JSON")"
    if [[ "$BENCH_STATUS" == "WARN" ]]; then
      mark_warn_if_pass
    elif [[ "$BENCH_STATUS" == "FAIL" || "$BENCH_STATUS" == "UNKNOWN" ]]; then
      mark_fail
    fi
  fi
else
  record_skipped_step "eks_bench_matrix" "Skipped because smoke step failed"
fi

if (( KEEP_CLUSTER == 0 )); then
  DOWN_CMD=(
    "$ROOT_DIR/scripts/eks/eks_down.sh"
    --name "$CLUSTER_NAME"
    --region "$REGION"
    --namespace "$NAMESPACE"
    --image-repo "$IMAGE_REPO"
  )
  if (( DELETE_ECR_REPO == 1 )); then
    DOWN_CMD+=(--delete-ecr-repo)
  fi
  if (( SKIP_EBS_CLEANUP == 1 )); then
    DOWN_CMD+=(--skip-ebs-cleanup)
  fi

  if run_step "eks_down" "${DOWN_CMD[@]}"; then
    TEARDOWN_OK=1
  else
    mark_fail
  fi

  AUDIT_CMD=(
    "$ROOT_DIR/scripts/eks/eks_cleanup_audit.sh"
    --name "$CLUSTER_NAME"
    --region "$REGION"
    --image-repo "$IMAGE_REPO"
    --expect-ecr-absent "$( (( DELETE_ECR_REPO == 1 )) && echo true || echo false )"
    --output-file "$CLEANUP_JSON"
    --human-report-file "$CLEANUP_MD"
  )

  if run_step "eks_cleanup_audit" "${AUDIT_CMD[@]}"; then
    CLEANUP_OK=1
  else
    mark_fail
  fi

  if [[ -f "$CLEANUP_JSON" ]]; then
    CLEANUP_STATUS="$(jq -r '.status // "UNKNOWN"' "$CLEANUP_JSON")"
    if [[ "$CLEANUP_STATUS" == "WARN" ]]; then
      mark_warn_if_pass
    elif [[ "$CLEANUP_STATUS" == "FAIL" || "$CLEANUP_STATUS" == "UNKNOWN" ]]; then
      mark_fail
    fi
  fi
else
  record_skipped_step "eks_down" "Skipped because --keep-cluster was set"
  record_skipped_step "eks_cleanup_audit" "Skipped because --keep-cluster was set"
  mark_warn_if_pass
fi

steps_json="$(jq -s '.' "$STEPS_JSONL")"
rm -f "$STEPS_JSONL"

RUNBOOK_JSON_REL="$(to_repo_relative "$RUNBOOK_JSON")"
RUNBOOK_MD_REL="$(to_repo_relative "$RUNBOOK_MD")"
RUN_ARTIFACT_DIR_REL="$(to_repo_relative "$RUN_ARTIFACT_DIR")"
MATRIX_JSON_REL="$(to_repo_relative "$MATRIX_JSON")"
MATRIX_MD_REL="$(to_repo_relative "$MATRIX_MD")"
CLEANUP_JSON_REL="$(to_repo_relative "$CLEANUP_JSON")"
CLEANUP_MD_REL="$(to_repo_relative "$CLEANUP_MD")"

jq -n \
  --arg benchmark "eks_runbook" \
  --arg status "$OVERALL_STATUS" \
  --arg timestamp_utc "$RUN_TS_HUMAN" \
  --arg cluster_name "$CLUSTER_NAME" \
  --arg region "$REGION" \
  --arg namespace "$NAMESPACE" \
  --arg max_daily_usd "$MAX_DAILY_USD" \
  --arg keep_cluster "$KEEP_CLUSTER" \
  --arg run_external "$RUN_EXTERNAL" \
  --arg cleanup_status "$CLEANUP_STATUS" \
  --arg report_md "$RUNBOOK_MD_REL" \
  --arg artifacts_dir "$RUN_ARTIFACT_DIR_REL" \
  --arg matrix_json "$MATRIX_JSON_REL" \
  --arg matrix_md "$MATRIX_MD_REL" \
  --arg cleanup_json "$CLEANUP_JSON_REL" \
  --arg cleanup_md "$CLEANUP_MD_REL" \
  --argjson steps "$steps_json" \
  '{
    benchmark: $benchmark,
    status: $status,
    timestamp_utc: $timestamp_utc,
    cluster_name: $cluster_name,
    region: $region,
    namespace: $namespace,
    cost_guardrail: {
      max_daily_usd: ($max_daily_usd|tonumber)
    },
    lifecycle: {
      keep_cluster: ($keep_cluster == "1"),
      external_benchmark_enabled: ($run_external == "1"),
      cleanup_audit_status: $cleanup_status
    },
    artifacts: {
      runbook_md: $report_md,
      runbook_artifacts_dir: $artifacts_dir,
      benchmark_matrix_json: $matrix_json,
      benchmark_matrix_md: $matrix_md,
      cleanup_audit_json: $cleanup_json,
      cleanup_audit_md: $cleanup_md
    },
    steps: $steps
  }' >"$RUNBOOK_JSON"

{
  echo "# NotDynamo EKS Runbook"
  echo
  echo "- Status: **$OVERALL_STATUS**"
  echo "- Timestamp (UTC): $RUN_TS_HUMAN"
  echo "- Cluster: \`$CLUSTER_NAME\`"
  echo "- Region: \`$REGION\`"
  echo "- Namespace: \`$NAMESPACE\`"
  echo "- Cost cap (daily USD): \`$MAX_DAILY_USD\`"
  echo "- Keep cluster: \`$KEEP_CLUSTER\`"
  echo "- Cleanup audit status: \`$CLEANUP_STATUS\`"
  echo
  echo "## Steps"
  echo
  echo "| Step | Status | Exit code | Started (UTC) | Finished (UTC) |"
  echo "|---|---|---|---|---|"
  jq -r '.[] | "| \(.step) | \(.status) | \(.exit_code // "") | \(.started_utc) | \(.finished_utc) |"' <<<"$steps_json"
  echo
  echo "## Artifacts"
  echo
  echo "- Runbook JSON: \`$RUNBOOK_JSON_REL\`"
  echo "- Benchmark matrix JSON: \`$MATRIX_JSON_REL\`"
  echo "- Benchmark matrix Markdown: \`$MATRIX_MD_REL\`"
  echo "- Cleanup audit JSON: \`$CLEANUP_JSON_REL\`"
  echo "- Cleanup audit Markdown: \`$CLEANUP_MD_REL\`"
  echo "- Artifact directory: \`$RUN_ARTIFACT_DIR_REL\`"
} >"$RUNBOOK_MD"

RUNBOOK_LATEST_JSON="$(dirname "$RUNBOOK_JSON")/runbook_latest.json"
RUNBOOK_LATEST_MD="$(dirname "$RUNBOOK_MD")/runbook_latest.md"
cp "$RUNBOOK_JSON" "$RUNBOOK_LATEST_JSON"
cp "$RUNBOOK_MD" "$RUNBOOK_LATEST_MD"

echo "EKS runbook complete."
echo "Status: $OVERALL_STATUS"
echo "JSON report: $RUNBOOK_JSON_REL"
echo "Markdown report: $RUNBOOK_MD_REL"
echo "Latest JSON: $(to_repo_relative "$RUNBOOK_LATEST_JSON")"
echo "Latest Markdown: $(to_repo_relative "$RUNBOOK_LATEST_MD")"

if [[ "$OVERALL_STATUS" == "FAIL" ]]; then
  exit 1
fi
