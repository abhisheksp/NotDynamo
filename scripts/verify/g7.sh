#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
REPORT_FILE="$REPORT_DIR/g7.json"
IT_LOG="/tmp/notdynamo-g7-it.log"
DRILL_LOG="/tmp/notdynamo-g7-drill.log"

mkdir -p "$REPORT_DIR"

pushd "$ROOT_DIR" >/dev/null
./gradlew :it:test \
  --tests "io.notdynamo.it.K8sLeaseLeaderElectionIT" \
  --tests "io.notdynamo.it.KubernetesManifestIT" \
  >"$IT_LOG"

./scripts/k8s/drill-node-drain.sh --dry-run --node dummy-node --namespace notdynamo >"$DRILL_LOG"
popd >/dev/null

cat >"$REPORT_FILE" <<JSON
{
  "gate": "G7",
  "status": "PASS",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "integration_tests": "./gradlew :it:test --tests io.notdynamo.it.K8sLeaseLeaderElectionIT --tests io.notdynamo.it.KubernetesManifestIT",
  "drill_command": "./scripts/k8s/drill-node-drain.sh --dry-run --node dummy-node --namespace notdynamo",
  "integration_log": "$IT_LOG",
  "drill_log": "$DRILL_LOG",
  "notes": "Kubernetes manifests, lease-based leader election, and dry-run disruption drill validated"
}
JSON

echo "G7 verification passed: $REPORT_FILE"
