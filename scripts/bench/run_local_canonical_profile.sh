#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports/benchmarks/local"
PROFILE_FILE="$ROOT_DIR/scripts/bench/profiles/local_canonical_v1.env"

to_repo_relative() {
  local path="$1"
  if [[ "$path" == "$ROOT_DIR/"* ]]; then
    echo "${path#"$ROOT_DIR/"}"
  elif [[ "$path" == "$ROOT_DIR" ]]; then
    echo "."
  else
    echo "$path"
  fi
}

usage() {
  cat <<'USAGE'
Usage: run_local_canonical_profile.sh [options]

Options:
  --profile <path>     Profile env file (default: scripts/bench/profiles/local_canonical_v1.env)
  --report-dir <path>  Output directory (default: reports/benchmarks/local)
  --help               Show this help message
USAGE
}

while (( $# > 0 )); do
  case "$1" in
    --profile)
      PROFILE_FILE="$2"
      shift 2
      ;;
    --report-dir)
      REPORT_DIR="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "$PROFILE_FILE" ]]; then
  echo "profile file not found: $PROFILE_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$PROFILE_FILE"

for required in PROFILE_NAME CONTAINER_COUNTS OPERATIONS_PER_CONTAINER KEYSPACE THREADS_PER_CONTAINER ZIPF_THETA JAVA_OPTS_PER_CONTAINER; do
  if [[ -z "${!required:-}" ]]; then
    echo "missing profile value: $required" >&2
    exit 1
  fi
done

mkdir -p "$REPORT_DIR"

CLUSTER_PREFIX="$REPORT_DIR/cluster_read"
HOTKEY_PREFIX="$REPORT_DIR/hotkey_zipf"
SUMMARY_FILE="$REPORT_DIR/summary.json"
PROFILE_FILE_OUT="$(to_repo_relative "$PROFILE_FILE")"
CLUSTER_JSON_OUT="$(to_repo_relative "$CLUSTER_PREFIX.json")"
CLUSTER_CSV_OUT="$(to_repo_relative "$CLUSTER_PREFIX.csv")"
HOTKEY_JSON_OUT="$(to_repo_relative "$HOTKEY_PREFIX.json")"
HOTKEY_CSV_OUT="$(to_repo_relative "$HOTKEY_PREFIX.csv")"
SUMMARY_FILE_OUT="$(to_repo_relative "$SUMMARY_FILE")"

pushd "$ROOT_DIR" >/dev/null
./scripts/bench/local_container_scaling.sh \
  --scenario cluster-read \
  --containers "$CONTAINER_COUNTS" \
  --operations "$OPERATIONS_PER_CONTAINER" \
  --keyspace "$KEYSPACE" \
  --threads-per-container "$THREADS_PER_CONTAINER" \
  --java-opts "$JAVA_OPTS_PER_CONTAINER" \
  --output-prefix "$CLUSTER_PREFIX" \
  --latest-json "$REPORT_DIR/latest_cluster_read.json"

./scripts/bench/local_container_scaling.sh \
  --scenario hotkey-zipf \
  --containers "$CONTAINER_COUNTS" \
  --operations "$OPERATIONS_PER_CONTAINER" \
  --keyspace "$KEYSPACE" \
  --threads-per-container "$THREADS_PER_CONTAINER" \
  --zipf-theta "$ZIPF_THETA" \
  --java-opts "$JAVA_OPTS_PER_CONTAINER" \
  --output-prefix "$HOTKEY_PREFIX" \
  --latest-json "$REPORT_DIR/latest_hotkey_zipf.json"
popd >/dev/null

CLUSTER_MAX_TPS="$(rg '"max_aggregate_throughput_rps":' "$CLUSTER_PREFIX.json" | head -n1 | sed -E 's/.*: ([0-9.]+),?/\1/')"
CLUSTER_RECOMMENDED="$(rg '"recommended_container_count":' "$CLUSTER_PREFIX.json" | head -n1 | sed -E 's/[^0-9]//g')"
HOTKEY_MAX_TPS="$(rg '"max_aggregate_throughput_rps":' "$HOTKEY_PREFIX.json" | head -n1 | sed -E 's/.*: ([0-9.]+),?/\1/')"
HOTKEY_RECOMMENDED="$(rg '"recommended_container_count":' "$HOTKEY_PREFIX.json" | head -n1 | sed -E 's/[^0-9]//g')"

cat >"$SUMMARY_FILE" <<JSON
{
  "benchmark_suite": "local_canonical_profile",
  "status": "PASS",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "profile_file": "$PROFILE_FILE_OUT",
  "profile_name": "$PROFILE_NAME",
  "profile": {
    "container_counts": "$CONTAINER_COUNTS",
    "operations_per_container": "$OPERATIONS_PER_CONTAINER",
    "keyspace": "$KEYSPACE",
    "threads_per_container": "$THREADS_PER_CONTAINER",
    "zipf_theta": "$ZIPF_THETA",
    "java_opts_per_container": "$JAVA_OPTS_PER_CONTAINER"
  },
  "reports": {
    "cluster_read_json": "$CLUSTER_JSON_OUT",
    "cluster_read_csv": "$CLUSTER_CSV_OUT",
    "hotkey_zipf_json": "$HOTKEY_JSON_OUT",
    "hotkey_zipf_csv": "$HOTKEY_CSV_OUT"
  },
  "highlights": {
    "cluster_read_max_aggregate_throughput_rps": "$CLUSTER_MAX_TPS",
    "cluster_read_recommended_container_count": "$CLUSTER_RECOMMENDED",
    "hotkey_zipf_max_aggregate_throughput_rps": "$HOTKEY_MAX_TPS",
    "hotkey_zipf_recommended_container_count": "$HOTKEY_RECOMMENDED"
  }
}
JSON

echo "Local canonical benchmark profile complete."
echo "Profile: $PROFILE_NAME"
echo "Summary: $SUMMARY_FILE_OUT"
