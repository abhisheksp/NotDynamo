#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
REPORT_FILE="$REPORT_DIR/g9_tuning.json"
LOCAL_SCALING_LOG="/tmp/notdynamo-g9-local-scaling.log"
LOCAL_SCALING_REPORT_REL="reports/local_container_scaling_latest.json"
LOCAL_SCALING_REPORT="$ROOT_DIR/$LOCAL_SCALING_REPORT_REL"
PROFILE_FILE_REL="scripts/bench/profiles/local_tuning_v1.env"
PROFILE_FILE="$ROOT_DIR/$PROFILE_FILE_REL"

mkdir -p "$REPORT_DIR"

if [[ ! -f "$PROFILE_FILE" ]]; then
  echo "missing profile file: $PROFILE_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$PROFILE_FILE"

resolve_path() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    echo "$path"
  else
    echo "$ROOT_DIR/$path"
  fi
}

pushd "$ROOT_DIR" >/dev/null
./scripts/bench/local_container_scaling.sh \
  --scenario cluster-read \
  --containers "$CONTAINER_COUNTS" \
  --operations "$OPERATIONS_PER_CONTAINER" \
  --keyspace "$KEYSPACE" \
  --threads-per-container "$THREADS_PER_CONTAINER" \
  --java-opts "$JAVA_OPTS_PER_CONTAINER" >"$LOCAL_SCALING_LOG"
popd >/dev/null

if [[ ! -f "$LOCAL_SCALING_REPORT" ]]; then
  echo "missing local scaling report: $LOCAL_SCALING_REPORT" >&2
  exit 1
fi

RECOMMENDED_CONTAINERS="$(rg '"recommended_container_count":' "$LOCAL_SCALING_REPORT" | head -n1 | sed -E 's/[^0-9]//g')"
MAX_AGG_TPS="$(rg '"max_aggregate_throughput_rps":' "$LOCAL_SCALING_REPORT" | head -n1 | sed -E 's/.*: ([0-9.]+),?/\1/')"
NINETY_PERCENT_TPS="$(rg '"ninety_percent_of_max_rps":' "$LOCAL_SCALING_REPORT" | head -n1 | sed -E 's/.*: ([0-9.]+),?/\1/')"
CSV_PATH="$(rg '"csv_report":' "$LOCAL_SCALING_REPORT" | head -n1 | sed -E 's/.*"csv_report": "([^"]+)".*/\1/')"
CSV_PATH_ABS="$(resolve_path "$CSV_PATH")"

if [[ ! -f "$CSV_PATH_ABS" ]]; then
  echo "missing local scaling csv report: $CSV_PATH_ABS" >&2
  exit 1
fi

RECOMMENDED_MAX_P99="$(awk -F',' -v c="$RECOMMENDED_CONTAINERS" 'NR > 1 && $1 == c { print $3; exit }' "$CSV_PATH_ABS")"

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
  "profile_file": "$PROFILE_FILE_REL",
  "profile_name": "$PROFILE_NAME",
  "local_scaling_command": "./scripts/bench/local_container_scaling.sh --scenario cluster-read --containers $CONTAINER_COUNTS --operations $OPERATIONS_PER_CONTAINER --keyspace $KEYSPACE --threads-per-container $THREADS_PER_CONTAINER --java-opts \"$JAVA_OPTS_PER_CONTAINER\"",
  "recommended_container_count": "$RECOMMENDED_CONTAINERS",
  "max_aggregate_throughput_rps": "$MAX_AGG_TPS",
  "ninety_percent_of_max_rps": "$NINETY_PERCENT_TPS",
  "recommended_container_max_p99_ms": "$RECOMMENDED_MAX_P99",
  "local_scaling_report": "$LOCAL_SCALING_REPORT_REL",
  "local_scaling_csv": "$CSV_PATH",
  "local_scaling_log": "$LOCAL_SCALING_LOG"
}
JSON

echo "G9 tuning verification passed: $REPORT_FILE"
