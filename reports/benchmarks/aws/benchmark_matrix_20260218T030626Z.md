# NotDynamo EKS Benchmark Matrix

- Status: **PASS**
- Timestamp (UTC): 2026-02-18T03:19:36Z
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`

## Categories

| Category | Enabled | Status | Throughput (rps) | p99 (ms) | Error rate (%) | Report |
|---|---|---|---|---|---|---|
| External client via port-forward | 1 | PASS | 308.86 | 99.886 | 0.0000 | `reports/benchmarks/aws/e2e_http_external_20260218T030626Z.md` |
| In-cluster benchmark job | 1 | PASS | 1253.72 | 119.817 | 0.0000 | `reports/benchmarks/aws/e2e_http_incluster_20260218T030626Z.md` |
