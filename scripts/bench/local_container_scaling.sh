#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
BUILD_LOG="/tmp/notdynamo-local-scaling-build.log"

SCENARIO="cluster-read"
OPERATIONS=250000
KEYSPACE=100000
THREADS_PER_CONTAINER=2
ZIPF_THETA=0.9
CONTAINER_COUNTS=""
JAVA_OPTS_PER_CONTAINER="-Xms256m -Xmx256m"

usage() {
  cat <<'USAGE'
Usage: local_container_scaling.sh [options]

Options:
  --scenario <cluster-read|hotkey-zipf|single-node-sanity>
  --operations <n>                Operations per container process (default: 250000)
  --keyspace <n>                  Keyspace size per process (default: 100000)
  --threads-per-container <n>     Threads per process (default: 2)
  --containers <csv>              Container counts, e.g. 1,2,4,6
  --zipf-theta <n>                Zipf theta when --scenario hotkey-zipf (default: 0.9)
  --java-opts <str>               BENCH_OPTS for each process (default: "-Xms256m -Xmx256m")
  --help                          Show this help message
USAGE
}

detect_logical_cpus() {
  if command -v getconf >/dev/null 2>&1; then
    getconf _NPROCESSORS_ONLN && return 0
  fi
  if command -v sysctl >/dev/null 2>&1; then
    sysctl -n hw.logicalcpu && return 0
  fi
  echo "1"
}

detect_physical_cpus() {
  if command -v sysctl >/dev/null 2>&1; then
    sysctl -n hw.physicalcpu && return 0
  fi
  detect_logical_cpus
}

build_default_container_counts() {
  local logical_cpus="$1"
  local max_reasonable=$((logical_cpus / 2))
  if (( max_reasonable < 1 )); then
    max_reasonable=1
  fi

  local -a counts=(1)
  local current=1
  while (( current * 2 < max_reasonable )); do
    current=$((current * 2))
    counts+=("$current")
  done
  if (( max_reasonable > counts[${#counts[@]} - 1] )); then
    counts+=("$max_reasonable")
  fi

  local IFS=,
  echo "${counts[*]}"
}

to_decimal() {
  awk -v value="$1" 'BEGIN { printf "%.6f", value }'
}

while (( $# > 0 )); do
  case "$1" in
    --scenario)
      SCENARIO="$2"
      shift 2
      ;;
    --operations)
      OPERATIONS="$2"
      shift 2
      ;;
    --keyspace)
      KEYSPACE="$2"
      shift 2
      ;;
    --threads-per-container)
      THREADS_PER_CONTAINER="$2"
      shift 2
      ;;
    --containers)
      CONTAINER_COUNTS="$2"
      shift 2
      ;;
    --zipf-theta)
      ZIPF_THETA="$2"
      shift 2
      ;;
    --java-opts)
      JAVA_OPTS_PER_CONTAINER="$2"
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

if [[ ! "$OPERATIONS" =~ ^[0-9]+$ ]] || (( OPERATIONS <= 0 )); then
  echo "operations must be a positive integer" >&2
  exit 1
fi
if [[ ! "$KEYSPACE" =~ ^[0-9]+$ ]] || (( KEYSPACE <= 0 )); then
  echo "keyspace must be a positive integer" >&2
  exit 1
fi
if [[ ! "$THREADS_PER_CONTAINER" =~ ^[0-9]+$ ]] || (( THREADS_PER_CONTAINER <= 0 )); then
  echo "threads-per-container must be a positive integer" >&2
  exit 1
fi

LOGICAL_CPUS="$(detect_logical_cpus)"
PHYSICAL_CPUS="$(detect_physical_cpus)"
if [[ -z "$CONTAINER_COUNTS" ]]; then
  CONTAINER_COUNTS="$(build_default_container_counts "$LOGICAL_CPUS")"
fi

IFS=',' read -r -a CONTAINER_COUNTS_ARRAY <<<"$CONTAINER_COUNTS"
if (( ${#CONTAINER_COUNTS_ARRAY[@]} == 0 )); then
  echo "at least one container count is required" >&2
  exit 1
fi

for count in "${CONTAINER_COUNTS_ARRAY[@]}"; do
  if [[ ! "$count" =~ ^[0-9]+$ ]] || (( count <= 0 )); then
    echo "invalid container count: $count" >&2
    exit 1
  fi
done

mkdir -p "$REPORT_DIR"

pushd "$ROOT_DIR" >/dev/null
./gradlew :bench:installDist >"$BUILD_LOG"
popd >/dev/null

BENCH_BIN="$ROOT_DIR/bench/build/install/bench/bin/bench"
if [[ ! -x "$BENCH_BIN" ]]; then
  echo "benchmark binary not found: $BENCH_BIN" >&2
  exit 1
fi

TIMESTAMP_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TIMESTAMP_TAG="$(date -u +%Y%m%dT%H%M%SZ)"
CSV_FILE="$REPORT_DIR/local_container_scaling_${TIMESTAMP_TAG}.csv"
JSON_FILE="$REPORT_DIR/local_container_scaling_${TIMESTAMP_TAG}.json"
LATEST_JSON_FILE="$REPORT_DIR/local_container_scaling_latest.json"
RUN_LOG_ROOT="$REPORT_DIR/local_container_scaling_${TIMESTAMP_TAG}_logs"

declare -a RESULT_LINES=()
declare -a HUMAN_LINES=()
mkdir -p "$RUN_LOG_ROOT"

echo "containers,aggregate_throughput_rps,max_container_p99_ms,throughput_per_container_rps,log_dir" >"$CSV_FILE"

for count in "${CONTAINER_COUNTS_ARRAY[@]}"; do
  run_dir="$RUN_LOG_ROOT/containers-${count}"
  mkdir -p "$run_dir"
  echo "running sweep: containers=$count scenario=$SCENARIO operations=$OPERATIONS keyspace=$KEYSPACE threads_per_container=$THREADS_PER_CONTAINER"

  declare -a pids=()
  declare -a logs=()

  for i in $(seq 1 "$count"); do
    log_file="$run_dir/container-${i}.log"
    logs+=("$log_file")

    cmd=(
      "$BENCH_BIN"
      --scenario "$SCENARIO"
      --operations "$OPERATIONS"
      --keyspace "$KEYSPACE"
      --threads "$THREADS_PER_CONTAINER"
    )
    if [[ "$SCENARIO" == "hotkey-zipf" ]]; then
      cmd+=(--zipfTheta "$ZIPF_THETA")
    fi

    BENCH_OPTS="$JAVA_OPTS_PER_CONTAINER" "${cmd[@]}" >"$log_file" 2>&1 &
    pids+=("$!")
  done

  process_failed=0
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      process_failed=1
    fi
  done
  if (( process_failed != 0 )); then
    echo "one or more benchmark processes failed for container count $count" >&2
    exit 1
  fi

  aggregate_throughput="0.0"
  max_p99="0.0"
  for log_file in "${logs[@]}"; do
    throughput="$(rg '^throughput_rps=' "$log_file" | tail -n 1 | cut -d'=' -f2)"
    p99="$(rg '^latency_ms_p99=' "$log_file" | tail -n 1 | cut -d'=' -f2)"
    if [[ -z "$throughput" || -z "$p99" ]]; then
      echo "missing metrics in log: $log_file" >&2
      exit 1
    fi
    aggregate_throughput="$(awk -v a="$aggregate_throughput" -v b="$throughput" 'BEGIN { printf "%.6f", a + b }')"
    max_p99="$(awk -v current="$max_p99" -v candidate="$p99" 'BEGIN { if (candidate > current) printf "%.6f", candidate; else printf "%.6f", current }')"
  done

  throughput_per_container="$(awk -v total="$aggregate_throughput" -v c="$count" 'BEGIN { printf "%.6f", total / c }')"
  RESULT_LINES+=("$count,$aggregate_throughput,$max_p99,$throughput_per_container,$run_dir")
  HUMAN_LINES+=("containers=$count aggregate_tps=$aggregate_throughput max_p99_ms=$max_p99 per_container_tps=$throughput_per_container")
  echo "$count,$aggregate_throughput,$max_p99,$throughput_per_container,$run_dir" >>"$CSV_FILE"
  echo "completed sweep: containers=$count aggregate_tps=$aggregate_throughput max_p99_ms=$max_p99"
done

max_throughput="0.0"
for line in "${RESULT_LINES[@]}"; do
  IFS=',' read -r _ throughput _ _ _ <<<"$line"
  max_throughput="$(awk -v a="$max_throughput" -v b="$throughput" 'BEGIN { if (b > a) printf "%.6f", b; else printf "%.6f", a }')"
done

ninety_percent_of_max="$(awk -v max="$max_throughput" 'BEGIN { printf "%.6f", max * 0.90 }')"
recommended_containers=""
for line in "${RESULT_LINES[@]}"; do
  IFS=',' read -r containers throughput _ _ _ <<<"$line"
  if awk -v t="$throughput" -v floor="$ninety_percent_of_max" 'BEGIN { exit !(t >= floor) }'; then
    recommended_containers="$containers"
    break
  fi
done
if [[ -z "$recommended_containers" ]]; then
  last_index=$((${#RESULT_LINES[@]} - 1))
  IFS=',' read -r recommended_containers _ <<<"${RESULT_LINES[$last_index]}"
fi

{
  echo "{"
  echo "  \"benchmark\": \"local_container_scaling\","
  echo "  \"status\": \"PASS\","
  echo "  \"timestamp_utc\": \"$TIMESTAMP_UTC\","
  echo "  \"machine\": {"
  echo "    \"logical_cpus\": $LOGICAL_CPUS,"
  echo "    \"physical_cpus\": $PHYSICAL_CPUS"
  echo "  },"
  echo "  \"scenario\": \"$SCENARIO\","
  echo "  \"operations_per_container\": $OPERATIONS,"
  echo "  \"keyspace\": $KEYSPACE,"
  echo "  \"threads_per_container\": $THREADS_PER_CONTAINER,"
  echo "  \"zipf_theta\": $(to_decimal "$ZIPF_THETA"),"
  echo "  \"java_opts_per_container\": \"$JAVA_OPTS_PER_CONTAINER\","
  echo "  \"container_counts\": \"$CONTAINER_COUNTS\","
  echo "  \"recommended_container_count\": $recommended_containers,"
  echo "  \"max_aggregate_throughput_rps\": $(to_decimal "$max_throughput"),"
  echo "  \"ninety_percent_of_max_rps\": $(to_decimal "$ninety_percent_of_max"),"
  echo "  \"csv_report\": \"$CSV_FILE\","
  echo "  \"logs_root\": \"$RUN_LOG_ROOT\","
  echo "  \"build_log\": \"$BUILD_LOG\","
  echo "  \"results\": ["
  for i in "${!RESULT_LINES[@]}"; do
    IFS=',' read -r containers throughput max_p99 per_container_tps log_dir <<<"${RESULT_LINES[$i]}"
    comma=","
    if (( i == ${#RESULT_LINES[@]} - 1 )); then
      comma=""
    fi
    echo "    {\"containers\": $containers, \"aggregate_throughput_rps\": $(to_decimal "$throughput"), \"max_container_p99_ms\": $(to_decimal "$max_p99"), \"throughput_per_container_rps\": $(to_decimal "$per_container_tps"), \"log_dir\": \"$log_dir\"}$comma"
  done
  echo "  ]"
  echo "}"
} >"$JSON_FILE"

cp "$JSON_FILE" "$LATEST_JSON_FILE"

echo "Local container scaling benchmark complete."
echo "JSON report: $JSON_FILE"
echo "CSV report: $CSV_FILE"
for line in "${HUMAN_LINES[@]}"; do
  echo "$line"
done
echo "recommended_containers=$recommended_containers"
echo "max_aggregate_throughput_rps=$max_throughput"
