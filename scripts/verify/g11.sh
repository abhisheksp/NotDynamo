#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
REPORT_FILE="$REPORT_DIR/g11.json"
IT_LOG="/tmp/notdynamo-g11-it.log"
DRAIN_LOG="/tmp/notdynamo-g11-drain.log"
POD_DELETE_LOG="/tmp/notdynamo-g11-pod-delete.log"
LOCAL_FAILURE_LOG="/tmp/notdynamo-g11-local-failure.log"

mkdir -p "$REPORT_DIR"

pushd "$ROOT_DIR" >/dev/null
./gradlew :it:test \
  --tests "io.notdynamo.it.KubernetesManifestIT" \
  --tests "io.notdynamo.it.LiveGrpcRoutingIT" \
  >"$IT_LOG"

./scripts/k8s/drill-node-drain.sh --dry-run --node dummy-node --namespace notdynamo >"$DRAIN_LOG"
./scripts/k8s/drill-pod-delete.sh --dry-run --namespace notdynamo >"$POD_DELETE_LOG"
./scripts/local/kind_failure_pod_restart.sh --dry-run --namespace notdynamo >"$LOCAL_FAILURE_LOG"
popd >/dev/null

cat >"$REPORT_FILE" <<JSON
{
  "gate": "G11",
  "status": "PASS",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "integration_tests": "./gradlew :it:test --tests io.notdynamo.it.KubernetesManifestIT --tests io.notdynamo.it.LiveGrpcRoutingIT",
  "drain_dry_run_command": "./scripts/k8s/drill-node-drain.sh --dry-run --node dummy-node --namespace notdynamo",
  "pod_delete_dry_run_command": "./scripts/k8s/drill-pod-delete.sh --dry-run --namespace notdynamo",
  "local_failure_dry_run_command": "./scripts/local/kind_failure_pod_restart.sh --dry-run --namespace notdynamo",
  "integration_log": "$IT_LOG",
  "drain_log": "$DRAIN_LOG",
  "pod_delete_log": "$POD_DELETE_LOG",
  "local_failure_log": "$LOCAL_FAILURE_LOG",
  "notes": "Live gRPC routing path and failure-drill script coverage validated"
}
JSON

echo "G11 verification passed: $REPORT_FILE"
