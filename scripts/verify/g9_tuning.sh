#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
REPORT_FILE="$REPORT_DIR/g9_tuning.json"
LOCAL_SCALING_LOG="/tmp/notdynamo-g9-local-scaling.log"
LOCAL_SCALING_REPORT="$REPORT_DIR/local_container_scaling_latest.json"

mkdir -p "$REPORT_DIR"

pushd "$ROOT_DIR" >/dev/null
./scripts/bench/local_container_scaling.sh \
  --scenario cluster-read \
  --containers 1,2,4 \
  --operations 20000 \
  --keyspace 5000 \
  --threads-per-container 2 >"$LOCAL_SCALING_LOG"
popd >/dev/null

if [[ ! -f "$LOCAL_SCALING_REPORT" ]]; then
  echo "missing local scaling report: $LOCAL_SCALING_REPORT" >&2
  exit 1
fi

RECOMMENDED_CONTAINERS="$(rg '"recommended_container_count":' "$LOCAL_SCALING_REPORT" | head -n1 | sed -E 's/[^0-9]//g')"
MAX_AGG_TPS="$(rg '"max_aggregate_throughput_rps":' "$LOCAL_SCALING_REPORT" | head -n1 | sed -E 's/.*: ([0-9.]+),?/\1/')"
NINETY_PERCENT_TPS="$(rg '"ninety_percent_of_max_rps":' "$LOCAL_SCALING_REPORT" | head -n1 | sed -E 's/.*: ([0-9.]+),?/\1/')"
CSV_PATH="$(rg '"csv_report":' "$LOCAL_SCALING_REPORT" | head -n1 | sed -E 's/.*"csv_report": "([^"]+)".*/\1/')"

if [[ ! -f "$CSV_PATH" ]]; then
  echo "missing local scaling csv report: $CSV_PATH" >&2
  exit 1
fi

RECOMMENDED_MAX_P99="$(awk -F',' -v c="$RECOMMENDED_CONTAINERS" 'NR > 1 && $1 == c { print $3; exit }' "$CSV_PATH")"

awk -v containers="$RECOMMENDED_CONTAINERS" -v max_tps="$MAX_AGG_TPS" -v p99="$RECOMMENDED_MAX_P99" '
BEGIN {
  if (containers + 0 <= 0) { print "recommended containers missing or invalid"; exit 1 }
  if (max_tps + 0 <= 0) { print "max aggregate throughput missing or invalid"; exit 1 }
  if (p99 + 0 <= 0) { print "recommended p99 missing or invalid"; exit 1 }
}
'

cat >"$REPORT_FILE" <<JSON
{
  "gate": "G9_TUNING",
  "status": "PASS",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "local_scaling_command": "./scripts/bench/local_container_scaling.sh --scenario cluster-read --containers 1,2,4 --operations 20000 --keyspace 5000 --threads-per-container 2",
  "recommended_container_count": "$RECOMMENDED_CONTAINERS",
  "max_aggregate_throughput_rps": "$MAX_AGG_TPS",
  "ninety_percent_of_max_rps": "$NINETY_PERCENT_TPS",
  "recommended_container_max_p99_ms": "$RECOMMENDED_MAX_P99",
  "local_scaling_report": "$LOCAL_SCALING_REPORT",
  "local_scaling_csv": "$CSV_PATH",
  "local_scaling_log": "$LOCAL_SCALING_LOG"
}
JSON

echo "G9 tuning verification passed: $REPORT_FILE"
