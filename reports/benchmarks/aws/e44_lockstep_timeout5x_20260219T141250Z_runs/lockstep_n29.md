# NotDynamo EKS Horizontal Scaling Sweep

- Timestamp (UTC): 2026-02-19T14:23:47Z
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
- Best throughput run: `run=1 node_count=29 data_replicas=29 throughput_rps=1.78`

## Results Matrix

| Run | Node count | Data replicas | Status | Matrix exit | External mode | External TPS | External p99 (ms) | In-cluster TPS | In-cluster p99 (ms) | In-cluster error (%) | Telem hint | Gen/Svc CPU ratio | Report |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 29 | 29 | WARN | 0 | port-forward |  |  | 1.78 | 7502.726 | 13.2000 | service-pressure-dominant | 0.007 | `reports/benchmarks/aws/e44_lockstep_timeout5x_20260219T141250Z_runs/lockstep_n29_runs/run_1_nodes29_replicas29/benchmark_matrix.json` |

## Artifacts

- JSON summary: `reports/benchmarks/aws/e44_lockstep_timeout5x_20260219T141250Z_runs/lockstep_n29.json`
- CSV summary: `reports/benchmarks/aws/e44_lockstep_timeout5x_20260219T141250Z_runs/lockstep_n29.csv`
- Run reports root: `reports/benchmarks/aws/e44_lockstep_timeout5x_20260219T141250Z_runs/lockstep_n29_runs`
