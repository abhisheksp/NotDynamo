# NotDynamo EKS Benchmark Matrix

- Status: **FAIL**
- Timestamp (UTC): 2026-02-18T09:38:54Z
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- External mode: `port-forward`

## Categories

| Category | Enabled | Status | Throughput (rps) | p99 (ms) | Error rate (%) | Report |
|---|---|---|---|---|---|---|
| External client via port-forward | 0 | SKIPPED |  |  |  |  |
| In-cluster benchmark job | 1 | FAIL | 0.00 | 0.000 | 0.0000 | `reports/benchmarks/aws/e2e_http_incluster_20260218T093512Z.md` |
