#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
REPORT_FILE="$REPORT_DIR/g12.json"
IT_LOG="/tmp/notdynamo-g12-it.log"

mkdir -p "$REPORT_DIR"

pushd "$ROOT_DIR" >/dev/null
./gradlew :it:test \
  --tests "io.notdynamo.it.LiveGrpcRoutingIT" \
  --tests "io.notdynamo.it.LiveHttpRoutingIT" \
  >"$IT_LOG"
popd >/dev/null

cat >"$REPORT_FILE" <<JSON
{
  "gate": "G12",
  "status": "PASS",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "integration_tests": "./gradlew :it:test --tests io.notdynamo.it.LiveGrpcRoutingIT --tests io.notdynamo.it.LiveHttpRoutingIT",
  "integration_log": "$IT_LOG",
  "notes": "Distributed HTTP->gRPC routing path validated across live multi-node servers"
}
JSON

echo "G12 verification passed: $REPORT_FILE"
