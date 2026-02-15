#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="notdynamo"

usage() {
  cat <<'USAGE'
Usage: kind_down.sh [options]

Deletes a local kind cluster.

Options:
  --name <cluster-name>   Cluster name (default: notdynamo)
  --help                  Show this help message
USAGE
}

while (( $# > 0 )); do
  case "$1" in
    --name)
      CLUSTER_NAME="$2"
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

if ! command -v kind >/dev/null 2>&1; then
  echo "missing required command: kind" >&2
  exit 1
fi

if kind get clusters | rg -xq "$CLUSTER_NAME"; then
  kind delete cluster --name "$CLUSTER_NAME"
  echo "kind cluster '$CLUSTER_NAME' deleted"
else
  echo "kind cluster '$CLUSTER_NAME' does not exist"
fi
