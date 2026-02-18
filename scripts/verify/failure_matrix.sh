#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

NAMESPACE="notdynamo"
SCENARIOS="pod-restart,leader-restart,process-restart,node-drain"
TIMEOUT_SECONDS=600
CONTINUE_ON_ERROR="false"
DRY_RUN="false"

REPORT_DIR="$ROOT_DIR/reports/verification"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_JSON="$REPORT_DIR/failure_matrix_${TS}.json"
REPORT_MD="$REPORT_DIR/failure_matrix_${TS}.md"
LATEST_JSON="$REPORT_DIR/failure_matrix_latest.json"
LATEST_MD="$REPORT_DIR/failure_matrix_latest.md"
HARNESS_LOG="/tmp/notdynamo-failure-matrix-${TS}.log"

usage() {
  cat <<'USAGE'
Usage: failure_matrix.sh [options]

Runs failure-mode verification matrix and writes human/machine reports.

Options:
  --namespace <ns>       Namespace (default: notdynamo)
  --scenarios <csv>      Scenario list (default: pod-restart,leader-restart,process-restart,node-drain)
  --timeout-sec <n>      Timeout seconds for failure drills (default: 600)
  --continue-on-error    Continue remaining scenarios after first failure
  --dry-run              Run matrix in dry-run mode
  --help                 Show this help
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
    --timeout-sec)
      TIMEOUT_SECONDS="$2"
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

mkdir -p "$REPORT_DIR"

harness_cmd=(
  "$ROOT_DIR/scripts/local/kind_failure_harness.sh"
  --namespace "$NAMESPACE"
  --scenarios "$SCENARIOS"
  --timeout-sec "$TIMEOUT_SECONDS"
)
if [[ "$CONTINUE_ON_ERROR" == "true" ]]; then
  harness_cmd+=(--continue-on-error)
fi
if [[ "$DRY_RUN" == "true" ]]; then
  harness_cmd+=(--dry-run)
fi

harness_status="PASS"
if ! "${harness_cmd[@]}" >"$HARNESS_LOG" 2>&1; then
  harness_status="FAIL"
fi

HARNESS_JSON="$ROOT_DIR/reports/failures/failure_harness_latest.json"
HARNESS_MD="$ROOT_DIR/reports/failures/failure_harness_latest.md"
if [[ ! -f "$HARNESS_JSON" ]]; then
  echo "missing harness json output: $HARNESS_JSON (see $HARNESS_LOG)" >&2
  exit 1
fi

overall_status="$(grep -o '"overall_status":[[:space:]]*"[^"]*"' "$HARNESS_JSON" | head -n1 | cut -d'"' -f4 || true)"
if [[ -z "$overall_status" ]]; then
  overall_status="$harness_status"
fi

scenario_names=()
while IFS= read -r name; do
  scenario_names+=("$name")
done < <(grep -o '"name":[[:space:]]*"[^"]*"' "$HARNESS_JSON" | cut -d'"' -f4)

scenario_statuses=()
while IFS= read -r status; do
  scenario_statuses+=("$status")
done < <(grep -o '"status":[[:space:]]*"[^"]*"' "$HARNESS_JSON" | cut -d'"' -f4)

{
  echo "# NotDynamo Failure Verification Matrix"
  echo
  echo "- Timestamp (UTC): \`$(date -u +%Y-%m-%dT%H:%M:%SZ)\`"
  echo "- Namespace: \`$NAMESPACE\`"
  echo "- Mode: \`$([[ \"$DRY_RUN\" == \"true\" ]] && echo dry-run || echo live)\`"
  echo "- Overall: \`$overall_status\`"
  echo "- Harness Log: \`$HARNESS_LOG\`"
  echo "- Harness JSON: \`$HARNESS_JSON\`"
  echo "- Harness Markdown: \`$HARNESS_MD\`"
  echo
  echo "## Assertions"
  echo
  echo "- Availability after injected fault (cross-node PUT/GET recovery smoke)"
  echo "- Recovery of Kubernetes workload readiness after failure"
  echo "- Reproducible command path with per-scenario logs"
  echo
  echo "## Scenario Status"
  echo
  for i in "${!scenario_names[@]}"; do
    status="${scenario_statuses[$i]:-UNKNOWN}"
    echo "- ${scenario_names[$i]}: $status"
  done
} >"$REPORT_MD"

{
  echo "{"
  echo "  \"gate\": \"failure-matrix\","
  echo "  \"timestamp_utc\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"namespace\": \"$NAMESPACE\","
  echo "  \"mode\": \"$([[ \"$DRY_RUN\" == \"true\" ]] && echo dry-run || echo live)\","
  echo "  \"overall_status\": \"$overall_status\","
  echo "  \"harness_command\": \"${harness_cmd[*]}\","
  echo "  \"harness_status\": \"$harness_status\","
  echo "  \"harness_log\": \"$HARNESS_LOG\","
  echo "  \"harness_json\": \"$HARNESS_JSON\","
  echo "  \"harness_md\": \"$HARNESS_MD\","
  echo "  \"scenarios\": ["
  for i in "${!scenario_names[@]}"; do
    comma=","
    if (( i == ${#scenario_names[@]} - 1 )); then
      comma=""
    fi
    status="${scenario_statuses[$i]:-UNKNOWN}"
    echo "    {\"name\":\"${scenario_names[$i]}\",\"status\":\"$status\"}$comma"
  done
  echo "  ]"
  echo "}"
} >"$REPORT_JSON"

cp "$REPORT_MD" "$LATEST_MD"
cp "$REPORT_JSON" "$LATEST_JSON"

echo "Failure matrix report: $REPORT_MD"
echo "Failure matrix json:   $REPORT_JSON"

if [[ "$overall_status" != "PASS" ]]; then
  exit 1
fi
