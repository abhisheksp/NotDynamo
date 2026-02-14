#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
REPORT_FILE="$REPORT_DIR/g3.json"
CONTROL_PLANE_LOG="/tmp/notdynamo-g3-control-plane.log"
IT_LOG="/tmp/notdynamo-g3-it.log"

mkdir -p "$REPORT_DIR"

pushd "$ROOT_DIR" >/dev/null
./gradlew :control-plane:test \
  --tests "io.notdynamo.controlplane.MembershipTest" \
  --tests "io.notdynamo.controlplane.PartitionMapEpochTest" \
  >"$CONTROL_PLANE_LOG"

./gradlew :it:test \
  --tests "io.notdynamo.it.MultiNodeRoutingIT" \
  --tests "io.notdynamo.it.PartitionMapConvergenceIT" \
  >"$IT_LOG"
popd >/dev/null

cat >"$REPORT_FILE" <<JSON
{
  "gate": "G3",
  "status": "PASS",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "control_plane_tests": "./gradlew :control-plane:test --tests io.notdynamo.controlplane.MembershipTest --tests io.notdynamo.controlplane.PartitionMapEpochTest",
  "integration_tests": "./gradlew :it:test --tests io.notdynamo.it.MultiNodeRoutingIT --tests io.notdynamo.it.PartitionMapConvergenceIT",
  "control_plane_log": "$CONTROL_PLANE_LOG",
  "integration_log": "$IT_LOG",
  "notes": "Membership liveness, partition-map epochs, multi-node routing, and rolling convergence validated"
}
JSON

echo "G3 verification passed: $REPORT_FILE"
