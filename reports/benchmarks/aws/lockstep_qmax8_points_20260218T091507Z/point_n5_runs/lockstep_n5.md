# NotDynamo EKS Horizontal Scaling Sweep

- Timestamp (UTC): 2026-02-18T09:15:21Z
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Nodegroup: `notdynamo-ng`
- Node counts: `5`
- Data replicas: `5`
- Runs executed: `1`
- Status: `PASS`
- Restore on exit: `0`
- Best throughput run: `run=1 node_count=5 data_replicas=5 throughput_rps=154.88`

## Results Matrix

| Run | Node count | Data replicas | Status | Matrix exit | External mode | External TPS | External p99 (ms) | In-cluster TPS | In-cluster p99 (ms) | In-cluster error (%) | Report |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 5 | 5 | PASS | 0 | port-forward |  |  | 154.88 | 66.336 | 0.0000 | `reports/benchmarks/aws/lockstep_qmax8_points_20260218T091507Z/point_n5_runs/lockstep_n5_runs/run_1_nodes5_replicas5/benchmark_matrix.md` |

## Artifacts

- JSON summary: `reports/benchmarks/aws/lockstep_qmax8_points_20260218T091507Z/point_n5_runs/lockstep_n5.json`
- CSV summary: `reports/benchmarks/aws/lockstep_qmax8_points_20260218T091507Z/point_n5_runs/lockstep_n5.csv`
- Run reports root: `reports/benchmarks/aws/lockstep_qmax8_points_20260218T091507Z/point_n5_runs/lockstep_n5_runs`
