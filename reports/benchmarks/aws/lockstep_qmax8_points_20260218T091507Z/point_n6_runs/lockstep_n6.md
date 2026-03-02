# NotDynamo EKS Horizontal Scaling Sweep

- Timestamp (UTC): 2026-02-18T09:18:30Z
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Nodegroup: `notdynamo-ng`
- Node counts: `6`
- Data replicas: `6`
- Runs executed: `1`
- Status: `PASS`
- Restore on exit: `0`
- Best throughput run: `run=1 node_count=6 data_replicas=6 throughput_rps=151.80`

## Results Matrix

| Run | Node count | Data replicas | Status | Matrix exit | External mode | External TPS | External p99 (ms) | In-cluster TPS | In-cluster p99 (ms) | In-cluster error (%) | Report |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 6 | 6 | PASS | 0 | port-forward |  |  | 151.80 | 69.705 | 0.0000 | `reports/benchmarks/aws/lockstep_qmax8_points_20260218T091507Z/point_n6_runs/lockstep_n6_runs/run_1_nodes6_replicas6/benchmark_matrix.md` |

## Artifacts

- JSON summary: `reports/benchmarks/aws/lockstep_qmax8_points_20260218T091507Z/point_n6_runs/lockstep_n6.json`
- CSV summary: `reports/benchmarks/aws/lockstep_qmax8_points_20260218T091507Z/point_n6_runs/lockstep_n6.csv`
- Run reports root: `reports/benchmarks/aws/lockstep_qmax8_points_20260218T091507Z/point_n6_runs/lockstep_n6_runs`
