# NotDynamo E2E HTTP In-Cluster Benchmark Report

- Status: **WARN**
- Timestamp (UTC): 2026-02-18T02:29:43Z
- Category: `in-cluster-job`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-http-20260218022856`

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
| Aggregate throughput (rps) | 221.67 |
| Aggregate success throughput (rps) | 203.92 |
| Max pod p50 latency (ms) | 50.910 |
| Max pod p95 latency (ms) | 208.185 |
| Max pod p99 latency (ms) | 270.708 |
| Success count | 7360 |
| Error count | 640 |
| Error rate (%) | 8.0000 |
| Read count | 7169 |
| Write count | 831 |
| Read not found count | 4511 |
| Job completed | true |
| Pod count | 2 |
| Pod metric failures | 0 |

## Error Samples

- `http_status=503`

## Artifacts

- JSON report: `reports/benchmarks/aws/e2e_http_incluster_20260218T022719Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218022856`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218022856/job.yaml`
