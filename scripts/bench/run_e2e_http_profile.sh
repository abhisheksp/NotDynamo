#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports/benchmarks/e2e"

BASE_URL="http://127.0.0.1:18080"
OPERATIONS=200000
KEYSPACE=20000
THREADS=32
READ_RATIO=0.90
DISTRIBUTION="uniform"
ZIPF_THETA=0.90
VALUE_BYTES=256
PRELOAD=true
CONNECT_TIMEOUT_MS=3000
REQUEST_TIMEOUT_MS=5000
OUTPUT_FILE=""
HUMAN_REPORT_FILE=""

usage() {
  cat <<'USAGE'
Usage: run_e2e_http_profile.sh [options]

Runs end-to-end HTTP benchmark against a running NotDynamo endpoint.

Options:
  --base-url <url>            Base URL (default: http://127.0.0.1:18080)
  --operations <n>            Total operations (default: 200000)
  --keyspace <n>              Keyspace size (default: 20000)
  --threads <n>               Concurrent threads (default: 32)
  --read-ratio <0..1>         Fraction of reads (default: 0.90)
  --distribution <name>       uniform|sequential|zipf (default: uniform)
  --zipf-theta <0..1>         Zipf theta when distribution=zipf (default: 0.90)
  --value-bytes <n>           PUT payload bytes (default: 256)
  --preload <true|false>      Preload keyspace before benchmark (default: true)
  --connect-timeout-ms <n>    HTTP connect timeout (default: 3000)
  --request-timeout-ms <n>    Per-request timeout (default: 5000)
  --output-file <path>        Output JSON file (default: reports/benchmarks/e2e/e2e_http_<timestamp>.json)
  --human-report-file <path>  Human-readable Markdown report path (default: <output-file>.md)
  --help                      Show this help message
USAGE
}

while (( $# > 0 )); do
  case "$1" in
    --base-url)
      BASE_URL="$2"
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
    --threads)
      THREADS="$2"
      shift 2
      ;;
    --read-ratio)
      READ_RATIO="$2"
      shift 2
      ;;
    --distribution)
      DISTRIBUTION="$2"
      shift 2
      ;;
    --zipf-theta)
      ZIPF_THETA="$2"
      shift 2
      ;;
    --value-bytes)
      VALUE_BYTES="$2"
      shift 2
      ;;
    --preload)
      PRELOAD="$2"
      shift 2
      ;;
    --connect-timeout-ms)
      CONNECT_TIMEOUT_MS="$2"
      shift 2
      ;;
    --request-timeout-ms)
      REQUEST_TIMEOUT_MS="$2"
      shift 2
      ;;
    --output-file)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --human-report-file)
      HUMAN_REPORT_FILE="$2"
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

for n in "$OPERATIONS" "$KEYSPACE" "$THREADS" "$VALUE_BYTES" "$CONNECT_TIMEOUT_MS" "$REQUEST_TIMEOUT_MS"; do
  if [[ ! "$n" =~ ^[0-9]+$ ]] || (( n <= 0 )); then
    echo "operations, keyspace, threads, value-bytes, and timeouts must be positive integers" >&2
    exit 1
  fi
done

if [[ "$DISTRIBUTION" != "uniform" && "$DISTRIBUTION" != "sequential" && "$DISTRIBUTION" != "zipf" ]]; then
  echo "--distribution must be one of: uniform, sequential, zipf" >&2
  exit 1
fi

case "$PRELOAD" in
  true|false)
    ;;
  *)
    echo "--preload must be true or false" >&2
    exit 1
    ;;
esac

mkdir -p "$REPORT_DIR"

TIMESTAMP_TAG="$(date -u +%Y%m%dT%H%M%SZ)"
if [[ -z "$OUTPUT_FILE" ]]; then
  OUTPUT_FILE="$REPORT_DIR/e2e_http_${TIMESTAMP_TAG}.json"
fi
if [[ -z "$HUMAN_REPORT_FILE" ]]; then
  if [[ "$OUTPUT_FILE" == *.json ]]; then
    HUMAN_REPORT_FILE="${OUTPUT_FILE%.json}.md"
  else
    HUMAN_REPORT_FILE="${OUTPUT_FILE}.md"
  fi
fi

OUTPUT_DIR="$(dirname "$OUTPUT_FILE")"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$(dirname "$HUMAN_REPORT_FILE")"

LATEST_JSON_FILE="$OUTPUT_DIR/e2e_http_latest.json"
LATEST_MD_FILE="$(dirname "$HUMAN_REPORT_FILE")/e2e_http_latest.md"

LOG_FILE="/tmp/notdynamo-e2e-http-${TIMESTAMP_TAG}.log"
RUN_COMMAND="./gradlew :bench:run --args='--scenario e2e-http --baseUrl $BASE_URL --operations $OPERATIONS --keyspace $KEYSPACE --threads $THREADS --readRatio $READ_RATIO --distribution $DISTRIBUTION --zipfTheta $ZIPF_THETA --valueBytes $VALUE_BYTES --preload $PRELOAD --connectTimeoutMs $CONNECT_TIMEOUT_MS --requestTimeoutMs $REQUEST_TIMEOUT_MS'"

pushd "$ROOT_DIR" >/dev/null
./gradlew :bench:run --args="--scenario e2e-http --baseUrl $BASE_URL --operations $OPERATIONS --keyspace $KEYSPACE --threads $THREADS --readRatio $READ_RATIO --distribution $DISTRIBUTION --zipfTheta $ZIPF_THETA --valueBytes $VALUE_BYTES --preload $PRELOAD --connectTimeoutMs $CONNECT_TIMEOUT_MS --requestTimeoutMs $REQUEST_TIMEOUT_MS" >"$LOG_FILE"
popd >/dev/null

extract_metric() {
  local key="$1"
  rg "^${key}=" "$LOG_FILE" | tail -n1 | cut -d'=' -f2-
}

SCENARIO="$(extract_metric scenario)"
THROUGHPUT_RPS="$(extract_metric throughput_rps)"
SUCCESS_THROUGHPUT_RPS="$(extract_metric success_throughput_rps)"
P50_MS="$(extract_metric latency_ms_p50)"
P95_MS="$(extract_metric latency_ms_p95)"
P99_MS="$(extract_metric latency_ms_p99)"
SUCCESS_COUNT="$(extract_metric success_count)"
ERROR_COUNT="$(extract_metric error_count)"
ERROR_RATE_PERCENT="$(extract_metric error_rate_percent)"
READ_COUNT="$(extract_metric read_count)"
WRITE_COUNT="$(extract_metric write_count)"
READ_NOT_FOUND_COUNT="$(extract_metric read_not_found_count)"
PRELOAD_ATTEMPTED="$(extract_metric preload_attempted)"
PRELOAD_SUCCESS="$(extract_metric preload_success)"
PRELOAD_FAILED="$(extract_metric preload_failed)"
DISTRIBUTION_EFFECTIVE="$(extract_metric distribution)"

ERROR_SAMPLE_LINES="$( (rg '^error_sample_[0-9]+=' "$LOG_FILE" | sed -E 's/^error_sample_[0-9]+=//') || true )"

if [[ -z "$SCENARIO" || -z "$THROUGHPUT_RPS" || -z "$P99_MS" ]]; then
  echo "benchmark output missing required metrics. See $LOG_FILE" >&2
  exit 1
fi

RUN_STATUS="PASS"
if awk -v e="$ERROR_RATE_PERCENT" 'BEGIN { exit !(e > 1.0) }'; then
  RUN_STATUS="WARN"
fi

cat >"$OUTPUT_FILE" <<JSON
{
  "benchmark": "e2e_http",
  "status": "$RUN_STATUS",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "scenario": "$SCENARIO",
  "base_url": "$BASE_URL",
  "config": {
    "operations": "$OPERATIONS",
    "keyspace": "$KEYSPACE",
    "threads": "$THREADS",
    "read_ratio": "$READ_RATIO",
    "distribution": "$DISTRIBUTION",
    "zipf_theta": "$ZIPF_THETA",
    "value_bytes": "$VALUE_BYTES",
    "preload": "$PRELOAD",
    "connect_timeout_ms": "$CONNECT_TIMEOUT_MS",
    "request_timeout_ms": "$REQUEST_TIMEOUT_MS"
  },
  "results": {
    "throughput_rps": "$THROUGHPUT_RPS",
    "success_throughput_rps": "$SUCCESS_THROUGHPUT_RPS",
    "latency_ms_p50": "$P50_MS",
    "latency_ms_p95": "$P95_MS",
    "latency_ms_p99": "$P99_MS",
    "success_count": "$SUCCESS_COUNT",
    "error_count": "$ERROR_COUNT",
    "error_rate_percent": "$ERROR_RATE_PERCENT",
    "read_count": "$READ_COUNT",
    "write_count": "$WRITE_COUNT",
    "read_not_found_count": "$READ_NOT_FOUND_COUNT",
    "preload_attempted": "$PRELOAD_ATTEMPTED",
    "preload_success": "$PRELOAD_SUCCESS",
    "preload_failed": "$PRELOAD_FAILED",
    "distribution_effective": "$DISTRIBUTION_EFFECTIVE"
  },
  "command": "$RUN_COMMAND",
  "log_file": "$LOG_FILE",
  "human_report": "$HUMAN_REPORT_FILE"
}
JSON

{
  echo "# NotDynamo E2E HTTP Benchmark Report"
  echo
  echo "- Status: **$RUN_STATUS**"
  echo "- Timestamp (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "- Scenario: \`$SCENARIO\`"
  echo "- Endpoint: \`$BASE_URL\`"
  echo
  echo "## Configuration"
  echo
  echo "| Field | Value |"
  echo "|---|---|"
  echo "| Operations | $OPERATIONS |"
  echo "| Keyspace | $KEYSPACE |"
  echo "| Threads | $THREADS |"
  echo "| Read ratio | $READ_RATIO |"
  echo "| Distribution | $DISTRIBUTION |"
  echo "| Zipf theta | $ZIPF_THETA |"
  echo "| Value bytes | $VALUE_BYTES |"
  echo "| Preload | $PRELOAD |"
  echo "| Connect timeout ms | $CONNECT_TIMEOUT_MS |"
  echo "| Request timeout ms | $REQUEST_TIMEOUT_MS |"
  echo
  echo "## Results"
  echo
  echo "| Metric | Value |"
  echo "|---|---|"
  echo "| Throughput (rps) | $THROUGHPUT_RPS |"
  echo "| Success throughput (rps) | $SUCCESS_THROUGHPUT_RPS |"
  echo "| p50 latency (ms) | $P50_MS |"
  echo "| p95 latency (ms) | $P95_MS |"
  echo "| p99 latency (ms) | $P99_MS |"
  echo "| Success count | $SUCCESS_COUNT |"
  echo "| Error count | $ERROR_COUNT |"
  echo "| Error rate (%) | $ERROR_RATE_PERCENT |"
  echo "| Read count | $READ_COUNT |"
  echo "| Write count | $WRITE_COUNT |"
  echo "| Read not found count | $READ_NOT_FOUND_COUNT |"
  echo "| Preload attempted | $PRELOAD_ATTEMPTED |"
  echo "| Preload success | $PRELOAD_SUCCESS |"
  echo "| Preload failed | $PRELOAD_FAILED |"
  echo "| Effective distribution | $DISTRIBUTION_EFFECTIVE |"

  if [[ -n "$ERROR_SAMPLE_LINES" ]]; then
    echo
    echo "## Error Samples"
    echo
    while IFS= read -r sample; do
      [[ -n "$sample" ]] && echo "- \`$sample\`"
    done <<<"$ERROR_SAMPLE_LINES"
  fi

  echo
  echo "## Artifacts"
  echo
  echo "- JSON report: \`$OUTPUT_FILE\`"
  echo "- Raw log: \`$LOG_FILE\`"
  echo "- Command:"
  echo
  echo '```bash'
  echo "$RUN_COMMAND"
  echo '```'
} >"$HUMAN_REPORT_FILE"

cp "$OUTPUT_FILE" "$LATEST_JSON_FILE"
cp "$HUMAN_REPORT_FILE" "$LATEST_MD_FILE"

echo "E2E HTTP benchmark complete."
echo "JSON report: $OUTPUT_FILE"
echo "Human report: $HUMAN_REPORT_FILE"
echo "Latest JSON: $LATEST_JSON_FILE"
echo "Latest human report: $LATEST_MD_FILE"
echo "Log: $LOG_FILE"
