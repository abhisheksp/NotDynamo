#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
REPORT_FILE="$REPORT_DIR/g5.json"
CONTROL_PLANE_LOG="/tmp/notdynamo-g5-control-plane.log"
NODE_LOG="/tmp/notdynamo-g5-node.log"
IT_LOG="/tmp/notdynamo-g5-it.log"

mkdir -p "$REPORT_DIR"

pushd "$ROOT_DIR" >/dev/null
./gradlew :control-plane:test --tests "io.notdynamo.controlplane.ReplicaPartitionMapTest" >"$CONTROL_PLANE_LOG"
./gradlew :node:test --tests "io.notdynamo.node.cluster.FreshReplicaPickerTest" >"$NODE_LOG"
./gradlew :it:test --tests "io.notdynamo.it.EventualReadFreshnessIT" >"$IT_LOG"
popd >/dev/null

cat >"$REPORT_FILE" <<JSON
{
  "gate": "G5",
  "status": "PASS",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "control_plane_tests": "./gradlew :control-plane:test --tests io.notdynamo.controlplane.ReplicaPartitionMapTest",
  "node_tests": "./gradlew :node:test --tests io.notdynamo.node.cluster.FreshReplicaPickerTest",
  "integration_tests": "./gradlew :it:test --tests io.notdynamo.it.EventualReadFreshnessIT",
  "control_plane_log": "$CONTROL_PLANE_LOG",
  "node_log": "$NODE_LOG",
  "integration_log": "$IT_LOG",
  "notes": "Replica placement, fresh follower selection, and leader fallback behavior validated"
}
JSON

echo "G5 verification passed: $REPORT_FILE"
