#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
REPORT_FILE="$REPORT_DIR/g10.json"
NODE_LOG="/tmp/notdynamo-g10-node.log"
IT_LOG="/tmp/notdynamo-g10-it.log"

mkdir -p "$REPORT_DIR"

pushd "$ROOT_DIR" >/dev/null
./gradlew :node:test \
  --tests "io.notdynamo.node.cluster.GrpcNodeRpcClientTest" \
  --tests "io.notdynamo.node.http.HttpBridgeServerTest" \
  >"$NODE_LOG"

./gradlew :it:test \
  --tests "io.notdynamo.it.MultiNodeRoutingIT" \
  --tests "io.notdynamo.it.LiveGrpcRoutingIT" \
  >"$IT_LOG"
popd >/dev/null

cat >"$REPORT_FILE" <<JSON
{
  "gate": "G10",
  "status": "PASS",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "node_tests": "./gradlew :node:test --tests io.notdynamo.node.cluster.GrpcNodeRpcClientTest --tests io.notdynamo.node.http.HttpBridgeServerTest",
  "integration_tests": "./gradlew :it:test --tests io.notdynamo.it.MultiNodeRoutingIT --tests io.notdynamo.it.LiveGrpcRoutingIT",
  "node_log": "$NODE_LOG",
  "integration_log": "$IT_LOG",
  "notes": "Runtime gRPC node transport and partitioned routing bootstrap validated in tests"
}
JSON

echo "G10 verification passed: $REPORT_FILE"
