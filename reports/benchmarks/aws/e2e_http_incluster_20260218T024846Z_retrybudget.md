# NotDynamo E2E HTTP In-Cluster Benchmark Report

- Status: **WARN**
- Timestamp (UTC): 2026-02-18T02:49:36Z
- Category: `in-cluster-job`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-http-20260218024853`

## Configuration

| Field | Value |
|---|---|
| Operations total (requested) | 8000 |
| Operations per pod | 4000 |
| Parallelism | 2 |
| Completions | 2 |
| Keyspace | 1000 |
| Threads per pod | 8 |
| Read ratio | 0.90 |
| Distribution | uniform |
| Zipf theta | 0.90 |
| Value bytes | 256 |
| Preload | false |

## Results

| Metric | Value |
|---|---|
| Effective operations | 8000 |
| Aggregate throughput (rps) | 224.11 |
| Aggregate success throughput (rps) | 210.94 |
| Max pod p50 latency (ms) | 51.192 |
| Max pod p95 latency (ms) | 198.901 |
| Max pod p99 latency (ms) | 254.952 |
| Success count | 7530 |
| Error count | 470 |
| Error rate (%) | 5.8750 |
| Read count | 7191 |
| Write count | 809 |
| Read not found count | 3104 |
| Job completed | true |
| Pod count | 2 |
| Pod metric failures | 0 |

## Error Samples

- `http_status=503`

## Artifacts

- JSON report: `reports/benchmarks/aws/e2e_http_incluster_20260218T024846Z_retrybudget.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218024853`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218024853/job.yaml`
