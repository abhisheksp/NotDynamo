#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
REPORT_FILE="$REPORT_DIR/g4.json"
RAFT_TEST_LOG="/tmp/notdynamo-g4-raft.log"

mkdir -p "$REPORT_DIR"

pushd "$ROOT_DIR" >/dev/null
./gradlew :raft-ratis:test \
  --tests "io.notdynamo.raft.QuorumWriteIT" \
  --tests "io.notdynamo.raft.LeaderFailoverIT" \
  --tests "io.notdynamo.raft.PartitionSafetyIT" \
  --tests "io.notdynamo.raft.SnapshotCompactionIT" \
  >"$RAFT_TEST_LOG"
popd >/dev/null

cat >"$REPORT_FILE" <<JSON
{
  "gate": "G4",
  "status": "PASS",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "raft_tests": "./gradlew :raft-ratis:test --tests io.notdynamo.raft.QuorumWriteIT --tests io.notdynamo.raft.LeaderFailoverIT --tests io.notdynamo.raft.PartitionSafetyIT --tests io.notdynamo.raft.SnapshotCompactionIT",
  "raft_test_log": "$RAFT_TEST_LOG",
  "notes": "Quorum commit, leader failover, minority safety, and compaction behavior validated"
}
JSON

echo "G4 verification passed: $REPORT_FILE"
