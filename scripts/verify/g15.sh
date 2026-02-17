#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
REPORT_FILE="$REPORT_DIR/g15.json"
RAFT_LOG="/tmp/notdynamo-g15-ratis.log"
NODE_LOG="/tmp/notdynamo-g15-node.log"
IT_LOG="/tmp/notdynamo-g15-it.log"

mkdir -p "$REPORT_DIR"

pushd "$ROOT_DIR" >/dev/null
./gradlew :raft-ratis:test \
  --tests "io.notdynamo.ratis.RatisConsensusEngineIT" \
  >"$RAFT_LOG"

./gradlew :node:test \
  --tests "io.notdynamo.node.cluster.GrpcNodeRpcClientTest" \
  --tests "io.notdynamo.node.cluster.RatisKvRouterTest" \
  >"$NODE_LOG"

./gradlew :it:test \
  --tests "io.notdynamo.it.RatisRoutingIT" \
  >"$IT_LOG"
popd >/dev/null

cat >"$REPORT_FILE" <<JSON
{
  "gate": "G15",
  "status": "PASS",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "ratis_tests": "./gradlew :raft-ratis:test --tests io.notdynamo.ratis.RatisConsensusEngineIT",
  "node_tests": "./gradlew :node:test --tests io.notdynamo.node.cluster.GrpcNodeRpcClientTest --tests io.notdynamo.node.cluster.RatisKvRouterTest",
  "it_tests": "./gradlew :it:test --tests io.notdynamo.it.RatisRoutingIT",
  "ratis_log": "$RAFT_LOG",
  "node_log": "$NODE_LOG",
  "it_log": "$IT_LOG",
  "notes": "Apache Ratis-backed consensus, bounded write-retry routing behavior, and node transport behavior validated"
}
JSON

echo "G15 verification passed: $REPORT_FILE"
