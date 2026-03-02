# NotDynamo EKS Benchmark Matrix

- Status: **PASS**
- Timestamp (UTC): 2026-02-18T08:47:10Z
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- External mode: `port-forward`

## Categories

| Category | Enabled | Status | Throughput (rps) | p99 (ms) | Error rate (%) | Report |
|---|---|---|---|---|---|---|
| External client via port-forward | 0 | SKIPPED |  |  |  |  |
| In-cluster benchmark job | 1 | PASS | 134.97 | 78.182 | 0.0500 | `reports/benchmarks/aws/e2e_http_incluster_20260218T084607Z.md` |
