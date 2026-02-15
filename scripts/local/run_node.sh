#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DATA_DIR="${NOTDYNAMO_DATA_DIR:-$ROOT_DIR/tmp/node-local}"

export NOTDYNAMO_NODE_ID="${NOTDYNAMO_NODE_ID:-node-local}"
export NOTDYNAMO_HOST="${NOTDYNAMO_HOST:-0.0.0.0}"
export NOTDYNAMO_GRPC_PORT="${NOTDYNAMO_GRPC_PORT:-9090}"
export NOTDYNAMO_HTTP_PORT="${NOTDYNAMO_HTTP_PORT:-8080}"
export NOTDYNAMO_SHARD_COUNT="${NOTDYNAMO_SHARD_COUNT:-64}"
export NOTDYNAMO_VIRTUAL_NODES_PER_SHARD="${NOTDYNAMO_VIRTUAL_NODES_PER_SHARD:-256}"
export NOTDYNAMO_DATA_DIR="$DATA_DIR"

mkdir -p "$NOTDYNAMO_DATA_DIR"

pushd "$ROOT_DIR" >/dev/null
./gradlew :node:run
popd >/dev/null
