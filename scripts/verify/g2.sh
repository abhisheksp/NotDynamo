#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
REPORT_FILE="$REPORT_DIR/g2.json"
TEST_LOG="/tmp/notdynamo-g2-test.log"

mkdir -p "$REPORT_DIR"

pushd "$ROOT_DIR" >/dev/null
./gradlew :node:test \
  --tests "io.notdynamo.node.shard.HashRingTest" \
  --tests "io.notdynamo.node.shard.LocalShardRouterTest" \
  -Dnotdynamo.ring.sampleSize=10000000 \
  >"$TEST_LOG"
popd >/dev/null

cat >"$REPORT_FILE" <<JSON
{
  "gate": "G2",
  "status": "PASS",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "tests_command": "./gradlew :node:test --tests io.notdynamo.node.shard.HashRingTest --tests io.notdynamo.node.shard.LocalShardRouterTest -Dnotdynamo.ring.sampleSize=10000000",
  "test_log": "$TEST_LOG",
  "notes": "Consistent hashing determinism, remap behavior, and local shard routing validated"
}
JSON

echo "G2 verification passed: $REPORT_FILE"
