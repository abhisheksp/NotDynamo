# NotDynamo EKS Lockstep Sweep

- Timestamp (UTC): 2026-02-19T08:20:49Z
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Nodegroup: `notdynamo-bench-ng`
- Lockstep counts: `11,29,35`
- RF: `3`
- Total shards: `128`
- Status: `PASS`
- Node hourly cost estimate: `0.0416` USD/hour
- In-cluster image reuse: `139643733075.dkr.ecr.us-west-2.amazonaws.com/notdynamo/notdynamo-bench:bench-20260218T220656Z`
- In-cluster benchmark node label: `notdynamo.io/workload=benchmark` (`NoSchedule`)
- Best in-cluster TPS point: `nodes=29 data_replicas=29 tps=9.96`

## Results

| Nodes | Data replicas | RF | Shard replicas/node | Est $/hour | Status | In-cluster TPS | In-cluster p95 (ms) | In-cluster p99 (ms) | Error % | Telem hint | Gen/Svc CPU ratio | Report |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 11 | 11 | 3 | 34.91 | 0.684175 | WARN | 9.43 |  | 1501.988 | 10.4000 | service-pressure-dominant | 0.094 | `reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z_runs/lockstep_n11.json` |
| 29 | 29 | 3 | 13.24 | 1.640099 | WARN | 9.96 |  | 1502.477 | 9.4000 | service-pressure-dominant | 0.206 | `reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z_runs/lockstep_n29.json` |
| 35 | 35 | 3 | 10.97 | 1.958740 | WARN | 9.22 |  | 1502.245 | 10.2000 | service-pressure-dominant | 0.128 | `reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z_runs/lockstep_n35.json` |

## Artifacts

- JSON summary: `reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z.json`
- CSV summary: `reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z.csv`
- Run reports root: `reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z_runs`
