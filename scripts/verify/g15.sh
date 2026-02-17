#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
REPORT_FILE="$REPORT_DIR/g15.json"
NODE_LOG="/tmp/notdynamo-g15-node.log"
IT_LOG="/tmp/notdynamo-g15-it.log"

mkdir -p "$REPORT_DIR"

pushd "$ROOT_DIR" >/dev/null
./gradlew :node:test \
  --tests "io.notdynamo.node.cluster.GrpcNodeRpcClientTest" \
  >"$NODE_LOG"

./gradlew :it:test \
  --tests "io.notdynamo.it.RaftRoutingIT" \
  >"$IT_LOG"
popd >/dev/null

cat >"$REPORT_FILE" <<JSON
{
  "gate": "G15",
  "status": "PASS",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "node_tests": "./gradlew :node:test --tests io.notdynamo.node.cluster.GrpcNodeRpcClientTest",
  "integration_tests": "./gradlew :it:test --tests io.notdynamo.it.RaftRoutingIT",
  "node_log": "$NODE_LOG",
  "integration_log": "$IT_LOG",
  "notes": "Raft vote/append RPC transport, leader failover election, and quorum-commit routing validated"
}
JSON

echo "G15 verification passed: $REPORT_FILE"
