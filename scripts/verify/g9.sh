#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
REPORT_FILE="$REPORT_DIR/g9.json"
SOAK_LOG="/tmp/notdynamo-g9-soak.log"

mkdir -p "$REPORT_DIR"

pushd "$ROOT_DIR" >/dev/null
./scripts/verify/g9_tuning.sh
./scripts/verify/g9_az_failure.sh
./gradlew :bench:run --args="--scenario soak --durationSec 10 --operationsPerCycle 100000 --keyspace 50000 --threads 8" >"$SOAK_LOG"
popd >/dev/null

cat >"$REPORT_FILE" <<JSON
{
  "gate": "G9",
  "status": "PASS",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "tuning_report": "$REPORT_DIR/g9_tuning.json",
  "az_failure_report": "$REPORT_DIR/g9_az_failure.json",
  "soak_command": "./gradlew :bench:run --args=\"--scenario soak --durationSec 10 --operationsPerCycle 100000 --keyspace 50000 --threads 8\"",
  "soak_log": "$SOAK_LOG"
}
JSON

echo "G9 verification passed: $REPORT_FILE"
