# NotDynamo E2E HTTP In-Cluster Benchmark Report

- Status: **PASS**
- Timestamp (UTC): 2026-02-18T08:47:10Z
- Category: `in-cluster-job`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-http-20260218084615`

## Configuration

| Field | Value |
|---|---|
| Operations total (requested) | 2000 |
| Operations per pod | 2000 |
| Parallelism | 1 |
| Completions | 1 |
| Keyspace | 500 |
| Threads per pod | 8 |
| Read ratio | 0.90 |
| Distribution | uniform |
| Zipf theta | 0.90 |
| Value bytes | 256 |
| Preload | true |

## Results

| Metric | Value |
|---|---|
| Effective operations | 2000 |
| Aggregate throughput (rps) | 134.97 |
| Aggregate success throughput (rps) | 134.91 |
| Max pod p50 latency (ms) | 49.998 |
| Max pod p95 latency (ms) | 60.486 |
| Max pod p99 latency (ms) | 78.182 |
| Success count | 1999 |
| Error count | 1 |
| Error rate (%) | 0.0500 |
| Read count | 1808 |
| Write count | 192 |
| Read not found count | 0 |
| Job completed | true |
| Pod count | 1 |
| Pod metric failures | 0 |

## Error Samples

- `HttpTimeoutException:request_timed_out`

## Artifacts

- JSON report: `reports/benchmarks/aws/e2e_http_incluster_20260218T084607Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218084615`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218084615/job.yaml`
