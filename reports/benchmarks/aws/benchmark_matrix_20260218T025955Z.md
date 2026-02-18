# NotDynamo EKS Benchmark Matrix

- Status: **PASS**
- Timestamp (UTC): 2026-02-18T03:01:07Z
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`

## Categories

| Category | Enabled | Status | Throughput (rps) | p99 (ms) | Error rate (%) | Report |
|---|---|---|---|---|---|---|
| External client via port-forward | 1 | PASS | 106.39 | 111.163 | 0.0000 | `reports/benchmarks/aws/e2e_http_external_20260218T025955Z.md` |
| In-cluster benchmark job | 1 | PASS | 277.54 | 128.039 | 0.0000 | `reports/benchmarks/aws/e2e_http_incluster_20260218T025955Z.md` |
