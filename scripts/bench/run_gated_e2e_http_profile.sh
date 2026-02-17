#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATE_FIRST="true"
FORWARDED_ARGS=()

usage() {
  cat <<'USAGE'
Usage: run_gated_e2e_http_profile.sh [options] [-- <run_e2e_http_profile args>]

Runs aggregate correctness gate (G18) before executing E2E HTTP benchmark.

Options:
  --skip-gate    Skip correctness gate (not recommended)
  --help         Show this help message

Any other arguments are forwarded to scripts/bench/run_e2e_http_profile.sh.
USAGE
}

while (( $# > 0 )); do
  case "$1" in
    --skip-gate)
      GATE_FIRST="false"
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    --)
      shift
      while (( $# > 0 )); do
        FORWARDED_ARGS+=("$1")
        shift
      done
      ;;
    *)
      FORWARDED_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ "$GATE_FIRST" == "true" ]]; then
  "$ROOT_DIR/scripts/verify/g18.sh"
fi

"$ROOT_DIR/scripts/bench/run_e2e_http_profile.sh" "${FORWARDED_ARGS[@]}"

BENCH_JSON="$ROOT_DIR/reports/benchmarks/e2e/e2e_http_latest.json"
BENCH_MD="$ROOT_DIR/reports/benchmarks/e2e/e2e_http_latest.md"
GATE_JSON="$ROOT_DIR/reports/g18.json"

if [[ ! -f "$BENCH_JSON" ]]; then
  echo "benchmark output not found: $BENCH_JSON" >&2
  exit 1
fi

RUN_TS="$(date -u +%Y%m%dT%H%M%SZ)"
SUMMARY_MD="$ROOT_DIR/reports/benchmarks/e2e/gated_run_${RUN_TS}.md"
SUMMARY_JSON="$ROOT_DIR/reports/benchmarks/e2e/gated_run_${RUN_TS}.json"
LATEST_SUMMARY_MD="$ROOT_DIR/reports/benchmarks/e2e/gated_run_latest.md"
LATEST_SUMMARY_JSON="$ROOT_DIR/reports/benchmarks/e2e/gated_run_latest.json"

extract_json_value() {
  local file="$1"
  local key="$2"
  rg -o "\"${key}\":\\s*\"?[^\"]+\"?" "$file" | head -n1 | sed -E "s/\"${key}\":\\s*\"?([^\",}]+)\"?/\\1/"
}

GATE_STATUS="SKIPPED"
if [[ "$GATE_FIRST" == "true" && -f "$GATE_JSON" ]]; then
  GATE_STATUS="$(extract_json_value "$GATE_JSON" "status")"
fi

BENCH_STATUS="$(extract_json_value "$BENCH_JSON" "status")"
THROUGHPUT="$(extract_json_value "$BENCH_JSON" "throughput_rps")"
P99="$(extract_json_value "$BENCH_JSON" "latency_ms_p99")"
ERROR_RATE="$(extract_json_value "$BENCH_JSON" "error_rate_percent")"

cat >"$SUMMARY_JSON" <<JSON
{
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "g18_status": "$GATE_STATUS",
  "benchmark_status": "$BENCH_STATUS",
  "benchmark_latest_json": "${BENCH_JSON#$ROOT_DIR/}",
  "benchmark_latest_md": "${BENCH_MD#$ROOT_DIR/}",
  "throughput_rps": "$THROUGHPUT",
  "latency_ms_p99": "$P99",
  "error_rate_percent": "$ERROR_RATE"
}
JSON

cat >"$SUMMARY_MD" <<MD
# NotDynamo Gated E2E Benchmark Summary

- Timestamp (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)
- G18 status: **$GATE_STATUS**
- Benchmark status: **$BENCH_STATUS**
- Throughput (rps): $THROUGHPUT
- p99 latency (ms): $P99
- Error rate (%): $ERROR_RATE
- Benchmark report: \`${BENCH_MD#$ROOT_DIR/}\`
MD

cp "$SUMMARY_JSON" "$LATEST_SUMMARY_JSON"
cp "$SUMMARY_MD" "$LATEST_SUMMARY_MD"

echo "Gated E2E benchmark summary written:"
echo "  $SUMMARY_JSON"
echo "  $SUMMARY_MD"
