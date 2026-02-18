# NotDynamo Failure Harness Report

- Run ID: `20260218T073838Z`
- Timestamp (UTC): `2026-02-18T07:38:38Z`
- Namespace: `notdynamo`
- Overall: `PASS`

## Scenario Results

- pod-restart: PASS
  command: `./scripts/local/kind_failure_pod_restart.sh --namespace notdynamo --failed-pod notdynamo-data-0 --timeout-sec 600 --value failure-harness-value`
  log: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/failures/20260218T073838Z/logs/pod-restart.log`
- leader-restart: PASS
  command: `./scripts/local/kind_failure_pod_restart.sh --namespace notdynamo --failed-pod leader-pod-placeholder --timeout-sec 600 --value failure-harness-value`
  log: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/failures/20260218T073838Z/logs/leader-restart.log`
- process-restart: PASS
  command: `kind_cross_node_smoke + kubectl exec notdynamo-data-0 kill 1 + wait ready + kind_cross_node_smoke`
  log: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/failures/20260218T073838Z/logs/process-restart.log`
- node-drain: PASS
  command: `./scripts/local/kind_failure_node_drain.sh --namespace notdynamo --timeout-sec 600 --value failure-harness-value`
  log: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/failures/20260218T073838Z/logs/node-drain.log`
