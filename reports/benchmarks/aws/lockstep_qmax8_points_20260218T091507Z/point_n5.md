# NotDynamo EKS Lockstep Sweep

- Timestamp (UTC): 2026-02-18T09:15:15Z
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Nodegroup: `notdynamo-ng`
- Lockstep counts: `5`
- RF: `3`
- Total shards: `128`
- Status: `PASS`
- Node hourly cost estimate: `0.0416` USD/hour
- Best in-cluster TPS point: `nodes=5 data_replicas=5 tps=154.88`

## Results

| Nodes | Data replicas | RF | Shard replicas/node | Est $/hour | Status | In-cluster TPS | In-cluster p95 (ms) | In-cluster p99 (ms) | Error % | Report |
|---|---|---|---|---|---|---|---|---|---|---|
| 5 | 5 | 3 | 76.80 | 0.365534 | PASS | 154.88 |  | 66.336 | 0.0000 | `reports/benchmarks/aws/lockstep_qmax8_points_20260218T091507Z/point_n5_runs/lockstep_n5.md` |

## Artifacts

- JSON summary: `reports/benchmarks/aws/lockstep_qmax8_points_20260218T091507Z/point_n5.json`
- CSV summary: `reports/benchmarks/aws/lockstep_qmax8_points_20260218T091507Z/point_n5.csv`
- Run reports root: `reports/benchmarks/aws/lockstep_qmax8_points_20260218T091507Z/point_n5_runs`
