# NotDynamo EKS Lockstep Sweep

- Timestamp (UTC): 2026-02-18T08:45:21Z
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Nodegroup: `notdynamo-ng`
- Lockstep counts: `3`
- RF: `3`
- Total shards: `128`
- Status: `PASS`
- Node hourly cost estimate: `0.0416` USD/hour
- Best in-cluster TPS point: `nodes=3 data_replicas=3 tps=134.97`

## Results

| Nodes | Data replicas | RF | Shard replicas/node | Est $/hour | Status | In-cluster TPS | In-cluster p95 (ms) | In-cluster p99 (ms) | Error % | Report |
|---|---|---|---|---|---|---|---|---|---|---|
| 3 | 3 | 3 | 128.00 | 0.259321 | PASS | 134.97 |  | 78.182 | 0.0500 | `reports/benchmarks/aws/lockstep_smoke_20260218T084516Z_runs/lockstep_n3.md` |

## Artifacts

- JSON summary: `reports/benchmarks/aws/lockstep_smoke_20260218T084516Z.json`
- CSV summary: `reports/benchmarks/aws/lockstep_smoke_20260218T084516Z.csv`
- Run reports root: `reports/benchmarks/aws/lockstep_smoke_20260218T084516Z_runs`
