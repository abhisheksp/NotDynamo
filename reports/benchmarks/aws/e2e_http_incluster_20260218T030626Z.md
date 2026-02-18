# NotDynamo E2E HTTP In-Cluster Benchmark Report

- Status: **PASS**
- Timestamp (UTC): 2026-02-18T03:19:36Z
- Category: `in-cluster-job`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-http-20260218031439`

## Configuration

| Field | Value |
|---|---|
| Operations total (requested) | 20000 |
| Operations per pod | 6667 |
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
| Effective operations | 20001 |
| Aggregate throughput (rps) | 1253.72 |
| Aggregate success throughput (rps) | 1253.72 |
| Max pod p50 latency (ms) | 52.225 |
| Max pod p95 latency (ms) | 79.737 |
| Max pod p99 latency (ms) | 119.817 |
| Success count | 20001 |
| Error count | 0 |
| Error rate (%) | 0.0000 |
| Read count | 17933 |
| Write count | 2068 |
| Read not found count | 0 |
| Job completed | true |
| Pod count | 3 |
| Pod metric failures | 0 |

## Artifacts

- JSON report: `reports/benchmarks/aws/e2e_http_incluster_20260218T030626Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218031439`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218031439/job.yaml`
