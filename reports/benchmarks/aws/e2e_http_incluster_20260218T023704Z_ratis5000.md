# NotDynamo E2E HTTP In-Cluster Benchmark Report

- Status: **WARN**
- Timestamp (UTC): 2026-02-18T02:37:55Z
- Category: `in-cluster-job`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-http-20260218023711`

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
| Aggregate throughput (rps) | 217.93 |
| Aggregate success throughput (rps) | 205.49 |
| Max pod p50 latency (ms) | 53.242 |
| Max pod p95 latency (ms) | 200.667 |
| Max pod p99 latency (ms) | 289.423 |
| Success count | 7543 |
| Error count | 457 |
| Error rate (%) | 5.7125 |
| Read count | 7226 |
| Write count | 774 |
| Read not found count | 3856 |
| Job completed | true |
| Pod count | 2 |
| Pod metric failures | 0 |

## Error Samples

- `http_status=503`

## Artifacts

- JSON report: `reports/benchmarks/aws/e2e_http_incluster_20260218T023704Z_ratis5000.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218023711`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218023711/job.yaml`
