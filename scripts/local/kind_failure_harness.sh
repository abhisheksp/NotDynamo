#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

NAMESPACE="notdynamo"
SCENARIOS="pod-restart,leader-restart,process-restart,node-drain"
FAILED_POD="notdynamo-data-0"
LEADER_POD=""
PROCESS_POD="notdynamo-data-0"
NODE_NAME=""
TIMEOUT_SECONDS=600
VALUE="failure-harness-value"
CONTINUE_ON_ERROR="false"
DRY_RUN="false"

REPORT_DIR="$ROOT_DIR/reports/failures"
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$REPORT_DIR/$RUN_ID"
RUN_LOG_DIR="$RUN_DIR/logs"
REPORT_JSON="$RUN_DIR/failure_harness.json"
REPORT_MD="$RUN_DIR/failure_harness.md"
LATEST_JSON="$REPORT_DIR/failure_harness_latest.json"
LATEST_MD="$REPORT_DIR/failure_harness_latest.md"

usage() {
  cat <<'USAGE'
Usage: kind_failure_harness.sh [options]

Runs a local failure-injection harness and writes pass/fail reports.

Scenarios:
  pod-restart      Delete a chosen pod and verify recovery
  leader-restart   Delete the shard-0 leader pod and verify recovery
  process-restart  Kill PID 1 inside a pod container and verify restart + recovery
  node-drain       Drain one Kubernetes node and verify recovery

Options:
  --namespace <ns>       Namespace (default: notdynamo)
  --scenarios <csv>      Scenario list (default: pod-restart,leader-restart,process-restart,node-drain)
  --failed-pod <name>    Pod name for pod-restart scenario (default: notdynamo-data-0)
  --leader-pod <name>    Explicit pod for leader-restart (default: auto-resolve from control-plane map)
  --process-pod <name>   Pod for process-restart scenario (default: notdynamo-data-0)
  --node <name>          Node for node-drain scenario (default: auto-select worker in drill script)
  --timeout-sec <n>      Wait timeout in seconds (default: 600)
  --value <value>        Value payload used in smoke checks (default: failure-harness-value)
  --continue-on-error    Continue running remaining scenarios after a failure
  --dry-run              Print commands without executing
  --help                 Show this help message
USAGE
}

while (( $# > 0 )); do
  case "$1" in
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --scenarios)
      SCENARIOS="$2"
      shift 2
      ;;
    --failed-pod)
      FAILED_POD="$2"
      shift 2
      ;;
    --leader-pod)
      LEADER_POD="$2"
      shift 2
      ;;
    --process-pod)
      PROCESS_POD="$2"
      shift 2
      ;;
    --node)
      NODE_NAME="$2"
      shift 2
      ;;
    --timeout-sec)
      TIMEOUT_SECONDS="$2"
      shift 2
      ;;
    --value)
      VALUE="$2"
      shift 2
      ;;
    --continue-on-error)
      CONTINUE_ON_ERROR="true"
      shift
      ;;
    --dry-run)
      DRY_RUN="true"
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

if [[ ! "$TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || (( TIMEOUT_SECONDS <= 0 )); then
  echo "--timeout-sec must be a positive integer" >&2
  exit 1
fi

require_bin() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

require_bin kubectl

mkdir -p "$RUN_LOG_DIR"

declare -a scenario_names=()
declare -a scenario_status=()
declare -a scenario_logs=()
declare -a scenario_commands=()

resolve_leader_pod() {
  if [[ -n "$LEADER_POD" ]]; then
    echo "$LEADER_POD"
    return 0
  fi

  local port=19090
  local pf_log="/tmp/notdynamo-failure-harness-pf.log"
  kubectl -n "$NAMESPACE" port-forward svc/notdynamo-control-plane "${port}:9090" >"$pf_log" 2>&1 &
  local pf_pid=$!
  local cleanup_done="false"

  cleanup_pf() {
    if [[ "$cleanup_done" == "false" ]]; then
      cleanup_done="true"
      kill "$pf_pid" >/dev/null 2>&1 || true
      wait "$pf_pid" >/dev/null 2>&1 || true
    fi
  }
  trap cleanup_pf RETURN

  local ok="false"
  for _ in {1..40}; do
    if curl -sf "http://127.0.0.1:${port}/healthz" >/dev/null 2>&1; then
      ok="true"
      break
    fi
    sleep 0.2
  done
  if [[ "$ok" != "true" ]]; then
    echo "unable to reach control-plane endpoint via port-forward (see $pf_log)" >&2
    return 1
  fi

  local payload
  payload="$(curl -sf "http://127.0.0.1:${port}/v1/partition-map")"
  local leader
  leader="$(printf "%s" "$payload" | tr -d '\n' | grep -o '"0":"[^"]*"' | head -n1 | cut -d'"' -f4 || true)"
  if [[ -z "$leader" ]]; then
    echo "failed to parse shard-0 leader from control-plane payload" >&2
    return 1
  fi

  echo "$leader"
}

run_with_log() {
  local log_file="$1"
  shift
  if [[ "$DRY_RUN" == "true" ]]; then
    {
      echo "DRY_RUN: $*"
    } >"$log_file"
    return 0
  fi
  "$@" >"$log_file" 2>&1
}

run_process_restart_drill() {
  local log_file="$1"
  local baseline_key="failure-harness-process-baseline-key"
  local recovery_key="failure-harness-process-recovery-key"

  if [[ "$DRY_RUN" == "true" ]]; then
    {
      echo "DRY_RUN: $ROOT_DIR/scripts/local/kind_cross_node_smoke.sh --namespace $NAMESPACE --key $baseline_key --value $VALUE"
      echo "DRY_RUN: kubectl -n $NAMESPACE exec $PROCESS_POD -- sh -c 'kill 1'"
      echo "DRY_RUN: kubectl -n $NAMESPACE wait --for=condition=Ready pod/$PROCESS_POD --timeout=${TIMEOUT_SECONDS}s"
      echo "DRY_RUN: $ROOT_DIR/scripts/local/kind_cross_node_smoke.sh --namespace $NAMESPACE --key $recovery_key --value $VALUE"
    } >"$log_file"
    return 0
  fi

  {
    "$ROOT_DIR/scripts/local/kind_cross_node_smoke.sh" \
      --namespace "$NAMESPACE" \
      --key "$baseline_key" \
      --value "$VALUE"
    kubectl -n "$NAMESPACE" exec "$PROCESS_POD" -- sh -c 'kill 1' || true
    kubectl -n "$NAMESPACE" wait --for=condition=Ready "pod/$PROCESS_POD" --timeout="${TIMEOUT_SECONDS}s"
    "$ROOT_DIR/scripts/local/kind_cross_node_smoke.sh" \
      --namespace "$NAMESPACE" \
      --key "$recovery_key" \
      --value "$VALUE"
  } >"$log_file" 2>&1
}

run_scenario() {
  local name="$1"
  local command_desc="$2"
  shift 2
  local log_file="$RUN_LOG_DIR/${name}.log"

  echo "Running scenario: $name"
  scenario_names+=("$name")
  scenario_logs+=("$log_file")
  scenario_commands+=("$command_desc")

  if "$@"; then
    scenario_status+=("PASS")
    echo "Scenario PASS: $name"
    return 0
  else
    scenario_status+=("FAIL")
    echo "Scenario FAIL: $name (see $log_file)" >&2
    return 1
  fi
}

overall_status="PASS"
IFS=',' read -r -a selected_scenarios <<<"$SCENARIOS"
for raw in "${selected_scenarios[@]}"; do
  scenario="$(echo "$raw" | xargs)"
  if [[ -z "$scenario" ]]; then
    continue
  fi

  case "$scenario" in
    pod-restart)
      cmd="./scripts/local/kind_failure_pod_restart.sh --namespace $NAMESPACE --failed-pod $FAILED_POD --timeout-sec $TIMEOUT_SECONDS --value $VALUE"
      if ! run_scenario "pod-restart" "$cmd" run_with_log "$RUN_LOG_DIR/pod-restart.log" \
        "$ROOT_DIR/scripts/local/kind_failure_pod_restart.sh" \
        --namespace "$NAMESPACE" \
        --failed-pod "$FAILED_POD" \
        --timeout-sec "$TIMEOUT_SECONDS" \
        --value "$VALUE"; then
        overall_status="FAIL"
        [[ "$CONTINUE_ON_ERROR" == "true" ]] || break
      fi
      ;;
    leader-restart)
      if [[ -n "$LEADER_POD" ]]; then
        leader_target="$LEADER_POD"
      elif [[ "$DRY_RUN" == "true" ]]; then
        leader_target="leader-pod-placeholder"
      else
        leader_target="$(resolve_leader_pod)"
      fi
      cmd="./scripts/local/kind_failure_pod_restart.sh --namespace $NAMESPACE --failed-pod $leader_target --timeout-sec $TIMEOUT_SECONDS --value $VALUE"
      if ! run_scenario "leader-restart" "$cmd" run_with_log "$RUN_LOG_DIR/leader-restart.log" \
        "$ROOT_DIR/scripts/local/kind_failure_pod_restart.sh" \
        --namespace "$NAMESPACE" \
        --failed-pod "$leader_target" \
        --timeout-sec "$TIMEOUT_SECONDS" \
        --value "$VALUE"; then
        overall_status="FAIL"
        [[ "$CONTINUE_ON_ERROR" == "true" ]] || break
      fi
      ;;
    process-restart)
      cmd="kind_cross_node_smoke + kubectl exec $PROCESS_POD kill 1 + wait ready + kind_cross_node_smoke"
      if ! run_scenario "process-restart" "$cmd" run_process_restart_drill "$RUN_LOG_DIR/process-restart.log"; then
        overall_status="FAIL"
        [[ "$CONTINUE_ON_ERROR" == "true" ]] || break
      fi
      ;;
    node-drain)
      cmd="./scripts/local/kind_failure_node_drain.sh --namespace $NAMESPACE --timeout-sec $TIMEOUT_SECONDS --value $VALUE${NODE_NAME:+ --node $NODE_NAME}"
      if [[ -n "$NODE_NAME" ]]; then
        if ! run_scenario "node-drain" "$cmd" run_with_log "$RUN_LOG_DIR/node-drain.log" \
          "$ROOT_DIR/scripts/local/kind_failure_node_drain.sh" \
          --namespace "$NAMESPACE" \
          --node "$NODE_NAME" \
          --timeout-sec "$TIMEOUT_SECONDS" \
          --value "$VALUE"; then
          overall_status="FAIL"
          [[ "$CONTINUE_ON_ERROR" == "true" ]] || break
        fi
      else
        if ! run_scenario "node-drain" "$cmd" run_with_log "$RUN_LOG_DIR/node-drain.log" \
          "$ROOT_DIR/scripts/local/kind_failure_node_drain.sh" \
          --namespace "$NAMESPACE" \
          --timeout-sec "$TIMEOUT_SECONDS" \
          --value "$VALUE"; then
          overall_status="FAIL"
          [[ "$CONTINUE_ON_ERROR" == "true" ]] || break
        fi
      fi
      ;;
    *)
      echo "unknown scenario: $scenario" >&2
      exit 1
      ;;
  esac
done

mkdir -p "$RUN_DIR"

{
  echo "# NotDynamo Failure Harness Report"
  echo
  echo "- Run ID: \`$RUN_ID\`"
  echo "- Timestamp (UTC): \`$(date -u +%Y-%m-%dT%H:%M:%SZ)\`"
  echo "- Namespace: \`$NAMESPACE\`"
  echo "- Overall: \`$overall_status\`"
  echo
  echo "## Scenario Results"
  echo
  for i in "${!scenario_names[@]}"; do
    echo "- ${scenario_names[$i]}: ${scenario_status[$i]}"
    echo "  command: \`${scenario_commands[$i]}\`"
    echo "  log: \`${scenario_logs[$i]}\`"
  done
} >"$REPORT_MD"

{
  echo "{"
  echo "  \"run_id\": \"$RUN_ID\","
  echo "  \"timestamp_utc\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"namespace\": \"$NAMESPACE\","
  echo "  \"overall_status\": \"$overall_status\","
  echo "  \"scenarios\": ["
  for i in "${!scenario_names[@]}"; do
    comma=","
    if (( i == ${#scenario_names[@]} - 1 )); then
      comma=""
    fi
    echo "    {"
    echo "      \"name\": \"${scenario_names[$i]}\","
    echo "      \"status\": \"${scenario_status[$i]}\","
    echo "      \"command\": \"${scenario_commands[$i]}\","
    echo "      \"log\": \"${scenario_logs[$i]}\""
    echo "    }$comma"
  done
  echo "  ]"
  echo "}"
} >"$REPORT_JSON"

cp "$REPORT_MD" "$LATEST_MD"
cp "$REPORT_JSON" "$LATEST_JSON"

echo "Failure harness report: $REPORT_MD"
echo "Failure harness json:   $REPORT_JSON"

if [[ "$overall_status" != "PASS" ]]; then
  exit 1
fi
