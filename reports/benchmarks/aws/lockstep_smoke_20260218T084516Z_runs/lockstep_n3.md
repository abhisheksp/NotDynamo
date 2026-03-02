# NotDynamo EKS Horizontal Scaling Sweep

- Timestamp (UTC): 2026-02-18T08:45:27Z
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Nodegroup: `notdynamo-ng`
- Node counts: `3`
- Data replicas: `3`
- Runs executed: `1`
- Status: `PASS`
- Restore on exit: `0`
- Best throughput run: `run=1 node_count=3 data_replicas=3 throughput_rps=134.97`

## Results Matrix

| Run | Node count | Data replicas | Status | Matrix exit | External mode | External TPS | External p99 (ms) | In-cluster TPS | In-cluster p99 (ms) | In-cluster error (%) | Report |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 3 | 3 | PASS | 0 | port-forward |  |  | 134.97 | 78.182 | 0.0500 | `reports/benchmarks/aws/lockstep_smoke_20260218T084516Z_runs/lockstep_n3_runs/run_1_nodes3_replicas3/benchmark_matrix.md` |

## Artifacts

- JSON summary: `reports/benchmarks/aws/lockstep_smoke_20260218T084516Z_runs/lockstep_n3.json`
- CSV summary: `reports/benchmarks/aws/lockstep_smoke_20260218T084516Z_runs/lockstep_n3.csv`
- Run reports root: `reports/benchmarks/aws/lockstep_smoke_20260218T084516Z_runs/lockstep_n3_runs`
