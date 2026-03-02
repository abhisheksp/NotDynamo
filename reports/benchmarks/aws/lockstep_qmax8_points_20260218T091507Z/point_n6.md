# NotDynamo EKS Lockstep Sweep

- Timestamp (UTC): 2026-02-18T09:18:24Z
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Nodegroup: `notdynamo-ng`
- Lockstep counts: `6`
- RF: `3`
- Total shards: `128`
- Status: `PASS`
- Node hourly cost estimate: `0.0416` USD/hour
- Best in-cluster TPS point: `nodes=6 data_replicas=6 tps=151.80`

## Results

| Nodes | Data replicas | RF | Shard replicas/node | Est $/hour | Status | In-cluster TPS | In-cluster p95 (ms) | In-cluster p99 (ms) | Error % | Report |
|---|---|---|---|---|---|---|---|---|---|---|
| 6 | 6 | 3 | 64.00 | 0.418641 | PASS | 151.80 |  | 69.705 | 0.0000 | `reports/benchmarks/aws/lockstep_qmax8_points_20260218T091507Z/point_n6_runs/lockstep_n6.md` |

## Artifacts

- JSON summary: `reports/benchmarks/aws/lockstep_qmax8_points_20260218T091507Z/point_n6.json`
- CSV summary: `reports/benchmarks/aws/lockstep_qmax8_points_20260218T091507Z/point_n6.csv`
- Run reports root: `reports/benchmarks/aws/lockstep_qmax8_points_20260218T091507Z/point_n6_runs`
