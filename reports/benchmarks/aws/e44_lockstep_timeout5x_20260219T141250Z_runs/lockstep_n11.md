# NotDynamo EKS Horizontal Scaling Sweep

- Timestamp (UTC): 2026-02-19T14:13:03Z
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Nodegroup: `notdynamo-bench-ng`
- Node counts: `11`
- Data replicas: `11`
- Runs executed: `1`
- Status: `WARN`
- Restore on exit: `0`
- In-cluster image reuse: `139643733075.dkr.ecr.us-west-2.amazonaws.com/notdynamo/notdynamo-bench:bench-20260218T220656Z`
- In-cluster benchmark node label: `notdynamo.io/workload=benchmark` (`NoSchedule`)
- Best throughput run: `run=1 node_count=11 data_replicas=11 throughput_rps=1.99`

## Results Matrix

| Run | Node count | Data replicas | Status | Matrix exit | External mode | External TPS | External p99 (ms) | In-cluster TPS | In-cluster p99 (ms) | In-cluster error (%) | Telem hint | Gen/Svc CPU ratio | Report |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 11 | 11 | WARN | 0 | port-forward |  |  | 1.99 | 7503.154 | 11.6000 | service-pressure-dominant | 0.059 | `reports/benchmarks/aws/e44_lockstep_timeout5x_20260219T141250Z_runs/lockstep_n11_runs/run_1_nodes11_replicas11/benchmark_matrix.json` |

## Artifacts

- JSON summary: `reports/benchmarks/aws/e44_lockstep_timeout5x_20260219T141250Z_runs/lockstep_n11.json`
- CSV summary: `reports/benchmarks/aws/e44_lockstep_timeout5x_20260219T141250Z_runs/lockstep_n11.csv`
- Run reports root: `reports/benchmarks/aws/e44_lockstep_timeout5x_20260219T141250Z_runs/lockstep_n11_runs`
