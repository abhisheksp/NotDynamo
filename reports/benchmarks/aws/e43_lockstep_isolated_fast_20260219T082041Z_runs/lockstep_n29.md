# NotDynamo EKS Horizontal Scaling Sweep

- Timestamp (UTC): 2026-02-19T08:27:35Z
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Nodegroup: `notdynamo-bench-ng`
- Node counts: `29`
- Data replicas: `29`
- Runs executed: `1`
- Status: `WARN`
- Restore on exit: `0`
- In-cluster image reuse: `139643733075.dkr.ecr.us-west-2.amazonaws.com/notdynamo/notdynamo-bench:bench-20260218T220656Z`
- In-cluster benchmark node label: `notdynamo.io/workload=benchmark` (`NoSchedule`)
- Best throughput run: `run=1 node_count=29 data_replicas=29 throughput_rps=9.96`

## Results Matrix

| Run | Node count | Data replicas | Status | Matrix exit | External mode | External TPS | External p99 (ms) | In-cluster TPS | In-cluster p99 (ms) | In-cluster error (%) | Telem hint | Gen/Svc CPU ratio | Report |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 29 | 29 | WARN | 0 | port-forward |  |  | 9.96 | 1502.477 | 9.4000 | service-pressure-dominant | 0.206 | `reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z_runs/lockstep_n29_runs/run_1_nodes29_replicas29/benchmark_matrix.json` |

## Artifacts

- JSON summary: `reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z_runs/lockstep_n29.json`
- CSV summary: `reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z_runs/lockstep_n29.csv`
- Run reports root: `reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z_runs/lockstep_n29_runs`
