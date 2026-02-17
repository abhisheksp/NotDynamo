#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="notdynamo"
POD_NAME=""
WAIT_READY="true"
TIMEOUT_SECONDS=300
DRY_RUN="false"

usage() {
  cat <<'USAGE'
Usage: drill-pod-delete.sh [options]

Deletes one pod to simulate a process/node failure and optionally waits for readiness.

Options:
  --namespace <ns>   Namespace (default: notdynamo)
  --pod <name>       Pod name to delete (required unless --dry-run)
  --wait-ready       Wait for pod readiness after deletion (default)
  --no-wait-ready    Do not wait for readiness
  --timeout-sec <n>  Readiness wait timeout in seconds (default: 300)
  --dry-run          Print commands only
  --help             Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --pod)
      POD_NAME="$2"
      shift 2
      ;;
    --wait-ready)
      WAIT_READY="true"
      shift
      ;;
    --no-wait-ready)
      WAIT_READY="false"
      shift
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

if [[ "$DRY_RUN" != "true" && -z "$POD_NAME" ]]; then
  echo "--pod is required unless --dry-run is provided" >&2
  exit 1
fi

if [[ ! "$TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || (( TIMEOUT_SECONDS <= 0 )); then
  echo "--timeout-sec must be a positive integer" >&2
  exit 1
fi

if [[ "$DRY_RUN" == "true" ]]; then
  if [[ -z "$POD_NAME" ]]; then
    POD_NAME="pod-placeholder"
  fi
  echo "DRY_RUN: kubectl -n $NAMESPACE delete pod $POD_NAME --wait=false"
  if [[ "$WAIT_READY" == "true" ]]; then
    echo "DRY_RUN: kubectl -n $NAMESPACE wait --for=condition=Ready pod/$POD_NAME --timeout=${TIMEOUT_SECONDS}s"
  fi
  exit 0
fi

kubectl -n "$NAMESPACE" delete pod "$POD_NAME" --wait=false

if [[ "$WAIT_READY" == "true" ]]; then
  kubectl -n "$NAMESPACE" wait --for=condition=Ready "pod/$POD_NAME" --timeout="${TIMEOUT_SECONDS}s"
fi

echo "Pod failure drill completed for $NAMESPACE/$POD_NAME"
