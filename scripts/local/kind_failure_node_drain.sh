#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

NAMESPACE="notdynamo"
NODE_NAME=""
TIMEOUT_SECONDS=600
VALUE="node-drain-drill-value"
DRY_RUN="false"
BASELINE_KEY="node-drain-baseline-key"
RECOVERY_KEY="node-drain-recovery-key"
NODE_CORDONED="false"

usage() {
  cat <<'USAGE'
Usage: kind_failure_node_drain.sh [options]

Runs a local node-drain failure drill:
1) baseline cross-node smoke
2) cordon + drain one worker node
3) wait for data/control-plane rollouts
4) recovery cross-node smoke
5) uncordon drained node

Options:
  --namespace <ns>   Namespace (default: notdynamo)
  --node <name>      Node to drain (default: auto-select first non-control-plane node)
  --timeout-sec <n>  Rollout wait timeout in seconds (default: 600)
  --value <value>    Payload used in smoke checks (default: node-drain-drill-value)
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

if [[ -z "$NODE_NAME" ]]; then
  if [[ "$DRY_RUN" == "true" ]]; then
    NODE_NAME="node-placeholder"
  else
    NODE_NAME="$(kubectl get nodes -o name | sed 's#^node/##' | grep -v 'control-plane' | head -n1 || true)"
    if [[ -z "$NODE_NAME" ]]; then
      echo "unable to auto-select a worker node (no non-control-plane node found)" >&2
      exit 1
    fi
  fi
fi

cleanup() {
  if [[ "$DRY_RUN" == "true" ]]; then
    return
  fi
  if [[ "$NODE_CORDONED" == "true" ]]; then
    kubectl uncordon "$NODE_NAME" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

run_or_echo() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "DRY_RUN: $*"
  else
    "$@"
  fi
}

echo "Step 1/5: baseline cross-node smoke"
run_or_echo "$ROOT_DIR/scripts/local/kind_cross_node_smoke.sh" \
  --namespace "$NAMESPACE" \
  --key "$BASELINE_KEY" \
  --value "$VALUE"

echo "Step 2/5: cordon and drain node $NODE_NAME"
if [[ "$DRY_RUN" == "true" ]]; then
  echo "DRY_RUN: kubectl cordon $NODE_NAME"
  echo "DRY_RUN: kubectl drain $NODE_NAME --ignore-daemonsets --delete-emptydir-data --grace-period=30"
else
  kubectl cordon "$NODE_NAME" >/dev/null
  NODE_CORDONED="true"
  kubectl drain "$NODE_NAME" --ignore-daemonsets --delete-emptydir-data --grace-period=30
fi

echo "Step 3/5: wait for rollout recovery"
run_or_echo kubectl -n "$NAMESPACE" rollout status statefulset/notdynamo-data --timeout="${TIMEOUT_SECONDS}s"
run_or_echo kubectl -n "$NAMESPACE" rollout status deployment/notdynamo-control-plane --timeout="${TIMEOUT_SECONDS}s"

echo "Step 4/5: recovery cross-node smoke"
run_or_echo "$ROOT_DIR/scripts/local/kind_cross_node_smoke.sh" \
  --namespace "$NAMESPACE" \
  --key "$RECOVERY_KEY" \
  --value "$VALUE"

echo "Step 5/5: uncordon node"
if [[ "$DRY_RUN" == "true" ]]; then
  echo "DRY_RUN: kubectl uncordon $NODE_NAME"
else
  kubectl uncordon "$NODE_NAME" >/dev/null
  NODE_CORDONED="false"
fi

echo "Node-drain failure drill completed successfully."
