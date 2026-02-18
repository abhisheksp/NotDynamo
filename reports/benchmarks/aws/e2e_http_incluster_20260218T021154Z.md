# NotDynamo E2E HTTP In-Cluster Benchmark Report

- Status: **WARN**
- Timestamp (UTC): 2026-02-18T02:12:39Z
- Category: `in-cluster-job`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-http-20260218021201`

## Configuration

| Field | Value |
|---|---|
| Operations total (requested) | 6000 |
| Operations per pod | 3000 |
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
| Effective operations | 6000 |
| Aggregate throughput (rps) | 218.59 |
| Aggregate success throughput (rps) | 207.81 |
| Max pod p50 latency (ms) | 52.070 |
| Max pod p95 latency (ms) | 194.627 |
| Max pod p99 latency (ms) | 247.687 |
| Success count | 5704 |
| Error count | 296 |
| Error rate (%) | 4.9333 |
| Read count | 5392 |
| Write count | 608 |
| Read not found count | 4508 |
| Job completed | true |
| Pod count | 2 |
| Pod metric failures | 0 |

## Error Samples

- `http_status=503`

## Artifacts

- JSON report: `reports/benchmarks/aws/e2e_http_incluster_20260218T021154Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218021201`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218021201/job.yaml`
