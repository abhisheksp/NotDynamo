# NotDynamo EKS Benchmark Matrix

- Status: **WARN**
- Timestamp (UTC): 2026-02-19T14:40:18Z
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- External mode: `port-forward`
- In-cluster image reuse: `139643733075.dkr.ecr.us-west-2.amazonaws.com/notdynamo/notdynamo-bench:bench-20260218T220656Z`
- In-cluster benchmark node label: `notdynamo.io/workload=benchmark` (`NoSchedule`)

## Categories

| Category | Enabled | Status | Throughput (rps) | p99 (ms) | Error rate (%) | Report |
|---|---|---|---|---|---|---|
| External client via port-forward | 0 | SKIPPED |  |  |  |  |
| In-cluster benchmark job | 1 | WARN | 1.78 | 7502.726 | 13.2000 | `reports/benchmarks/aws/e2e_http_incluster_20260219T143527Z.md` |

## In-Cluster Telemetry Signals

| Signal | Value |
|---|---|
| Attribution hint | service-pressure-dominant |
| Generator/Service CPU ratio | 0.007 |
