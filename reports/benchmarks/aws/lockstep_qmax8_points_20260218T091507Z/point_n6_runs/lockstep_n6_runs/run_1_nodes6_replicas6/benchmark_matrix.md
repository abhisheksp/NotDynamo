# NotDynamo EKS Benchmark Matrix

- Status: **PASS**
- Timestamp (UTC): 2026-02-18T09:26:36Z
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- External mode: `port-forward`

## Categories

| Category | Enabled | Status | Throughput (rps) | p99 (ms) | Error rate (%) | Report |
|---|---|---|---|---|---|---|
| External client via port-forward | 0 | SKIPPED |  |  |  |  |
| In-cluster benchmark job | 1 | PASS | 151.80 | 69.705 | 0.0000 | `reports/benchmarks/aws/e2e_http_incluster_20260218T092150Z.md` |
