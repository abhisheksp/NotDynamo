#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
REPORT_FILE="$REPORT_DIR/g1.json"
TEST_LOG="/tmp/notdynamo-g1-test.log"
BENCH_LOG="/tmp/notdynamo-g1-bench.log"

mkdir -p "$REPORT_DIR"

pushd "$ROOT_DIR" >/dev/null
./gradlew clean :storage-rocksdb:test :node:test :it:test >"$TEST_LOG"
./gradlew :bench:run --args="--scenario single-node-sanity --operations 50000 --keyspace 5000" >"$BENCH_LOG"
popd >/dev/null

cat >"$REPORT_FILE" <<JSON
{
  "gate": "G1",
  "status": "PASS",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "tests_command": "./gradlew clean :storage-rocksdb:test :node:test :it:test",
  "bench_command": "./gradlew :bench:run --args=\"--scenario single-node-sanity --operations 50000 --keyspace 5000\"",
  "test_log": "$TEST_LOG",
  "bench_log": "$BENCH_LOG"
}
JSON

echo "G1 verification passed: $REPORT_FILE"
