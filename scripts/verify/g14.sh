#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
REPORT_FILE="$REPORT_DIR/g14.json"
CONTROL_PLANE_LOG="/tmp/notdynamo-g14-control-plane.log"
IT_LOG="/tmp/notdynamo-g14-it.log"

mkdir -p "$REPORT_DIR"

pushd "$ROOT_DIR" >/dev/null
./gradlew :control-plane:test \
  --tests "io.notdynamo.controlplane.ControlPlaneMainIT" \
  >"$CONTROL_PLANE_LOG"

./gradlew :it:test \
  --tests "io.notdynamo.it.KubernetesManifestIT" \
  >"$IT_LOG"
popd >/dev/null

cat >"$REPORT_FILE" <<JSON
{
  "gate": "G14",
  "status": "PASS",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "control_plane_tests": "./gradlew :control-plane:test --tests io.notdynamo.controlplane.ControlPlaneMainIT",
  "integration_tests": "./gradlew :it:test --tests io.notdynamo.it.KubernetesManifestIT",
  "control_plane_log": "$CONTROL_PLANE_LOG",
  "integration_log": "$IT_LOG",
  "notes": "Control-plane runtime process and Kubernetes manifests validated"
}
JSON

echo "G14 verification passed: $REPORT_FILE"
