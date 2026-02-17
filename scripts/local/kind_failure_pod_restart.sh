#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

NAMESPACE="notdynamo"
FAILED_POD="notdynamo-data-0"
PUT_POD="notdynamo-data-0"
GET_POD="notdynamo-data-1"
BASELINE_KEY="failure-baseline-key"
RECOVERY_KEY="failure-recovery-key"
VALUE="failure-drill-value"
TIMEOUT_SECONDS=300
DRY_RUN="false"

usage() {
  cat <<'USAGE'
Usage: kind_failure_pod_restart.sh [options]

Runs a local failure drill:
1) baseline cross-node smoke
2) delete one pod
3) wait for replacement readiness
4) cross-node smoke again

Options:
  --namespace <ns>   Namespace (default: notdynamo)
  --failed-pod <name>
                     Pod to delete during drill (default: notdynamo-data-0)
  --put-pod <name>   Pod for PUT in cross-node smoke (default: notdynamo-data-0)
  --get-pod <name>   Pod for GET in cross-node smoke (default: notdynamo-data-1)
  --value <value>    Payload for smoke cycles (default: failure-drill-value)
  --timeout-sec <n>  Pod readiness timeout in seconds (default: 300)
  --dry-run          Print commands only
  --help             Show this help message
USAGE
}

while (( $# > 0 )); do
  case "$1" in
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --failed-pod)
      FAILED_POD="$2"
      shift 2
      ;;
    --put-pod)
      PUT_POD="$2"
      shift 2
      ;;
    --get-pod)
      GET_POD="$2"
      shift 2
      ;;
    --value)
      VALUE="$2"
      shift 2
      ;;
    --timeout-sec)
      TIMEOUT_SECONDS="$2"
      shift 2
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

run_or_echo() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "DRY_RUN: $*"
  else
    "$@"
  fi
}

echo "Step 1/4: baseline cross-node smoke"
run_or_echo "$ROOT_DIR/scripts/local/kind_cross_node_smoke.sh" \
  --namespace "$NAMESPACE" \
  --put-pod "$PUT_POD" \
  --get-pod "$GET_POD" \
  --key "$BASELINE_KEY" \
  --value "$VALUE"

echo "Step 2/4: delete pod $FAILED_POD"
run_or_echo kubectl -n "$NAMESPACE" delete pod "$FAILED_POD" --wait=false

echo "Step 3/4: wait for pod readiness"
run_or_echo kubectl -n "$NAMESPACE" wait --for=condition=Ready "pod/$FAILED_POD" --timeout="${TIMEOUT_SECONDS}s"

echo "Step 4/4: recovery cross-node smoke"
run_or_echo "$ROOT_DIR/scripts/local/kind_cross_node_smoke.sh" \
  --namespace "$NAMESPACE" \
  --put-pod "$PUT_POD" \
  --get-pod "$GET_POD" \
  --key "$RECOVERY_KEY" \
  --value "$VALUE"

echo "Failure drill completed successfully."
