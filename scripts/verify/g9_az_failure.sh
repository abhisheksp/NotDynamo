#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
REPORT_FILE="$REPORT_DIR/g9_az_failure.json"
IT_LOG="/tmp/notdynamo-g9-az-failure.log"

mkdir -p "$REPORT_DIR"

pushd "$ROOT_DIR" >/dev/null
./gradlew :it:test --tests "io.notdynamo.it.AzFailureSimulationIT" >"$IT_LOG"
popd >/dev/null

cat >"$REPORT_FILE" <<JSON
{
  "gate": "G9_AZ_FAILURE",
  "status": "PASS",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "integration_tests": "./gradlew :it:test --tests io.notdynamo.it.AzFailureSimulationIT",
  "integration_log": "$IT_LOG"
}
JSON

echo "G9 AZ failure verification passed: $REPORT_FILE"
