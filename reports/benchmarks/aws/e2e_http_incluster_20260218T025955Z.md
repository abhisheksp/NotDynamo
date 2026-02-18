# NotDynamo E2E HTTP In-Cluster Benchmark Report

- Status: **PASS**
- Timestamp (UTC): 2026-02-18T03:01:07Z
- Category: `in-cluster-job`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-http-20260218030045`

## Configuration

| Field | Value |
|---|---|
| Operations total (requested) | 4000 |
| Operations per pod | 2000 |
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
| Effective operations | 4000 |
| Aggregate throughput (rps) | 277.54 |
| Aggregate success throughput (rps) | 277.54 |
| Max pod p50 latency (ms) | 51.446 |
| Max pod p95 latency (ms) | 75.840 |
| Max pod p99 latency (ms) | 128.039 |
| Success count | 4000 |
| Error count | 0 |
| Error rate (%) | 0.0000 |
| Read count | 3610 |
| Write count | 390 |
| Read not found count | 736 |
| Job completed | true |
| Pod count | 2 |
| Pod metric failures | 0 |

## Artifacts

- JSON report: `reports/benchmarks/aws/e2e_http_incluster_20260218T025955Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218030045`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218030045/job.yaml`
