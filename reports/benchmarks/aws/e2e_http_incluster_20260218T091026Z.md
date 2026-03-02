# NotDynamo E2E HTTP In-Cluster Benchmark Report

- Status: **FAIL**
- Timestamp (UTC): 2026-02-18T09:13:43Z
- Category: `in-cluster-job`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-http-20260218091033`

## Configuration

| Field | Value |
|---|---|
| Operations total (requested) | 10000 |
| Operations per pod | 3334 |
| Parallelism | 3 |
| Completions | 3 |
| Keyspace | 5000 |
| Threads per pod | 24 |
| Read ratio | 0.90 |
| Distribution | uniform |
| Zipf theta | 0.90 |
| Value bytes | 256 |
| Preload | true |

## Results

| Metric | Value |
|---|---|
| Effective operations | 0 |
| Aggregate throughput (rps) | 0.00 |
| Aggregate success throughput (rps) | 0.00 |
| Max pod p50 latency (ms) | 0.000 |
| Max pod p95 latency (ms) | 0.000 |
| Max pod p99 latency (ms) | 0.000 |
| Success count | 0 |
| Error count | 0 |
| Error rate (%) | 0.0000 |
| Read count | 0 |
| Write count | 0 |
| Read not found count | 0 |
| Job completed | false |
| Pod count | 3 |
| Pod metric failures | 3 |

## Artifacts

- JSON report: `reports/benchmarks/aws/e2e_http_incluster_20260218T091026Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218091033`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218091033/job.yaml`
