#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
REPORT_FILE="$REPORT_DIR/g8.json"
NODE_TEST_LOG="/tmp/notdynamo-g8-node.log"
CONTROL_PLANE_TEST_LOG="/tmp/notdynamo-g8-control-plane.log"
ALERT_LOG="/tmp/notdynamo-g8-alerts.log"

mkdir -p "$REPORT_DIR"

pushd "$ROOT_DIR" >/dev/null
./gradlew :node:test \
  --tests "io.notdynamo.node.observability.TelemetryPropagationTest" \
  --tests "io.notdynamo.node.observability.PrometheusMetricsExportTest" \
  >"$NODE_TEST_LOG"

./gradlew :control-plane:test \
  --tests "io.notdynamo.controlplane.observability.AlertRuleEvaluatorTest" \
  >"$CONTROL_PLANE_TEST_LOG"

./scripts/ops/test-alerts.sh >"$ALERT_LOG"
popd >/dev/null

cat >"$REPORT_FILE" <<JSON
{
  "gate": "G8",
  "status": "PASS",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "node_tests": "./gradlew :node:test --tests io.notdynamo.node.observability.TelemetryPropagationTest --tests io.notdynamo.node.observability.PrometheusMetricsExportTest",
  "control_plane_tests": "./gradlew :control-plane:test --tests io.notdynamo.controlplane.observability.AlertRuleEvaluatorTest",
  "alert_validation": "./scripts/ops/test-alerts.sh",
  "node_test_log": "$NODE_TEST_LOG",
  "control_plane_test_log": "$CONTROL_PLANE_TEST_LOG",
  "alert_log": "$ALERT_LOG",
  "notes": "Telemetry propagation, metrics export, and alert rule/runbook coverage validated"
}
JSON

echo "G8 verification passed: $REPORT_FILE"
