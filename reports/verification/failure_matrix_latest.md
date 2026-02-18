# NotDynamo Failure Verification Matrix

- Timestamp (UTC): `2026-02-18T07:38:38Z`
- Namespace: `notdynamo`
- Mode: `dry-run`
- Overall: `PASS`
- Harness Log: `/tmp/notdynamo-failure-matrix-20260218T073838Z.log`
- Harness JSON: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/failures/failure_harness_latest.json`
- Harness Markdown: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/failures/failure_harness_latest.md`

## Assertions

- Availability after injected fault (cross-node PUT/GET recovery smoke)
- Recovery of Kubernetes workload readiness after failure
- Reproducible command path with per-scenario logs

## Scenario Status

- pod-restart: PASS
- leader-restart: PASS
- process-restart: PASS
- node-drain: PASS
