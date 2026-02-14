#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="notdynamo"
NODE_NAME=""
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --node)
      NODE_NAME="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$NODE_NAME" ]]; then
  NODE_NAME="node-placeholder"
fi

CMD="kubectl drain $NODE_NAME --ignore-daemonsets --delete-emptydir-data --grace-period=30 --namespace $NAMESPACE"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "DRY_RUN: $CMD"
  exit 0
fi

echo "$CMD"
eval "$CMD"
