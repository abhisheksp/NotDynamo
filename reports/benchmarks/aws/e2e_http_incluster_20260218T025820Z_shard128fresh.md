# NotDynamo E2E HTTP In-Cluster Benchmark Report

- Status: **PASS**
- Timestamp (UTC): 2026-02-18T02:59:02Z
- Category: `in-cluster-job`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-http-20260218025828`

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
| Aggregate throughput (rps) | 291.84 |
| Aggregate success throughput (rps) | 291.84 |
| Max pod p50 latency (ms) | 50.601 |
| Max pod p95 latency (ms) | 68.584 |
| Max pod p99 latency (ms) | 79.992 |
| Success count | 8000 |
| Error count | 0 |
| Error rate (%) | 0.0000 |
| Read count | 7184 |
| Write count | 816 |
| Read not found count | 5030 |
| Job completed | true |
| Pod count | 2 |
| Pod metric failures | 0 |

## Artifacts

- JSON report: `reports/benchmarks/aws/e2e_http_incluster_20260218T025820Z_shard128fresh.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218025828`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218025828/job.yaml`
