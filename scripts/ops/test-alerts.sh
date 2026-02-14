#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RULES_FILE="$ROOT_DIR/ops/alerts/prometheus-rules.yaml"
RUNBOOK_FILE="$ROOT_DIR/ops/runbooks/alerts.md"

[[ -f "$RULES_FILE" ]] || { echo "missing rules file: $RULES_FILE"; exit 1; }
[[ -f "$RUNBOOK_FILE" ]] || { echo "missing runbook file: $RUNBOOK_FILE"; exit 1; }

rg -q "NotDynamoReadP99High" "$RULES_FILE"
rg -q "NotDynamoReplicationLagHigh" "$RULES_FILE"
rg -q "NotDynamoElectionChurnHigh" "$RULES_FILE"

rg -q "NotDynamoReadP99High" "$RUNBOOK_FILE"
rg -q "NotDynamoReplicationLagHigh" "$RUNBOOK_FILE"
rg -q "NotDynamoElectionChurnHigh" "$RUNBOOK_FILE"

echo "Alert rules and runbook validation passed"
