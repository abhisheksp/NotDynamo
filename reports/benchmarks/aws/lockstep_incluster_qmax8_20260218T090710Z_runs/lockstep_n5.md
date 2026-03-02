# NotDynamo EKS Horizontal Scaling Sweep

- Timestamp (UTC): 2026-02-18T09:07:23Z
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Nodegroup: `notdynamo-ng`
- Node counts: `5`
- Data replicas: `5`
- Runs executed: `1`
- Status: `FAIL`
- Restore on exit: `0`

## Results Matrix

| Run | Node count | Data replicas | Status | Matrix exit | External mode | External TPS | External p99 (ms) | In-cluster TPS | In-cluster p99 (ms) | In-cluster error (%) | Report |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 5 | 5 | FAIL | 1 | port-forward |  |  | 0.00 | 0.000 | 0.0000 | `reports/benchmarks/aws/lockstep_incluster_qmax8_20260218T090710Z_runs/lockstep_n5_runs/run_1_nodes5_replicas5/benchmark_matrix.md` |

## Artifacts

- JSON summary: `reports/benchmarks/aws/lockstep_incluster_qmax8_20260218T090710Z_runs/lockstep_n5.json`
- CSV summary: `reports/benchmarks/aws/lockstep_incluster_qmax8_20260218T090710Z_runs/lockstep_n5.csv`
- Run reports root: `reports/benchmarks/aws/lockstep_incluster_qmax8_20260218T090710Z_runs/lockstep_n5_runs`
