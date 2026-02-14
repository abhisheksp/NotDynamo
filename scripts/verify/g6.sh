#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
REPORT_FILE="$REPORT_DIR/g6.json"
CONTROL_PLANE_LOG="/tmp/notdynamo-g6-control-plane.log"
IT_LOG="/tmp/notdynamo-g6-it.log"

mkdir -p "$REPORT_DIR"

pushd "$ROOT_DIR" >/dev/null
./gradlew :control-plane:test \
  --tests "io.notdynamo.controlplane.rebalance.RebalancePlannerTest" \
  --tests "io.notdynamo.controlplane.rebalance.RebalanceThrottlerTest" \
  >"$CONTROL_PLANE_LOG"

./gradlew :it:test \
  --tests "io.notdynamo.it.LearnerSyncIT" \
  --tests "io.notdynamo.it.ReplicaMoveRollbackIT" \
  --tests "io.notdynamo.it.RebalanceThrottlingIT" \
  >"$IT_LOG"
popd >/dev/null

cat >"$REPORT_FILE" <<JSON
{
  "gate": "G6",
  "status": "PASS",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "control_plane_tests": "./gradlew :control-plane:test --tests io.notdynamo.controlplane.rebalance.RebalancePlannerTest --tests io.notdynamo.controlplane.rebalance.RebalanceThrottlerTest",
  "integration_tests": "./gradlew :it:test --tests io.notdynamo.it.LearnerSyncIT --tests io.notdynamo.it.ReplicaMoveRollbackIT --tests io.notdynamo.it.RebalanceThrottlingIT",
  "control_plane_log": "$CONTROL_PLANE_LOG",
  "integration_log": "$IT_LOG",
  "notes": "Planner balance, learner sync lifecycle, rollback safety, and SLO throttling validated"
}
JSON

echo "G6 verification passed: $REPORT_FILE"
