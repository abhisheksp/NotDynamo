#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
REPORT_FILE="$REPORT_DIR/g0.json"

mkdir -p "$REPORT_DIR"

pushd "$ROOT_DIR" >/dev/null
./gradlew clean build >/tmp/notdynamo-g0-build.log
popd >/dev/null

cat >"$REPORT_FILE" <<JSON
{
  "gate": "G0",
  "status": "PASS",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "command": "./gradlew clean build",
  "notes": "Foundation scaffold builds successfully"
}
JSON

echo "G0 verification passed: $REPORT_FILE"
