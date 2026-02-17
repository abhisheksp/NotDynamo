#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
REPORT_FILE="$REPORT_DIR/g18.json"

mkdir -p "$REPORT_DIR"

pushd "$ROOT_DIR" >/dev/null
./scripts/verify/g10.sh
./scripts/verify/g11.sh
./scripts/verify/g12.sh
./scripts/verify/g13.sh
./scripts/verify/g14.sh
./scripts/verify/g15.sh
popd >/dev/null

read_status() {
  local file="$1"
  rg -o '"status":\s*"[A-Z_]+"' "$file" | head -n1 | sed -E 's/.*"([A-Z_]+)"/\1/'
}

G10_STATUS="$(read_status "$REPORT_DIR/g10.json")"
G11_STATUS="$(read_status "$REPORT_DIR/g11.json")"
G12_STATUS="$(read_status "$REPORT_DIR/g12.json")"
G13_STATUS="$(read_status "$REPORT_DIR/g13.json")"
G14_STATUS="$(read_status "$REPORT_DIR/g14.json")"
G15_STATUS="$(read_status "$REPORT_DIR/g15.json")"

AGG_STATUS="PASS"
for status in "$G10_STATUS" "$G11_STATUS" "$G12_STATUS" "$G13_STATUS" "$G14_STATUS" "$G15_STATUS"; do
  if [[ "$status" != "PASS" ]]; then
    AGG_STATUS="FAIL"
    break
  fi
done

cat >"$REPORT_FILE" <<JSON
{
  "gate": "G18",
  "status": "$AGG_STATUS",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "child_gates": {
    "G10": "$G10_STATUS",
    "G11": "$G11_STATUS",
    "G12": "$G12_STATUS",
    "G13": "$G13_STATUS",
    "G14": "$G14_STATUS",
    "G15": "$G15_STATUS"
  },
  "commands": [
    "./scripts/verify/g10.sh",
    "./scripts/verify/g11.sh",
    "./scripts/verify/g12.sh",
    "./scripts/verify/g13.sh",
    "./scripts/verify/g14.sh",
    "./scripts/verify/g15.sh"
  ],
  "notes": "Aggregate correctness gate before benchmark-focused optimization, including raft write-path coverage"
}
JSON

echo "G18 verification passed: $REPORT_FILE"
