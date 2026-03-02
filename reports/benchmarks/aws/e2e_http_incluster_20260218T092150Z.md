# NotDynamo E2E HTTP In-Cluster Benchmark Report

- Status: **PASS**
- Timestamp (UTC): 2026-02-18T09:26:35Z
- Category: `in-cluster-job`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-http-20260218092158`

## Configuration

| Field | Value |
|---|---|
| Operations total (requested) | 2000 |
| Operations per pod | 2000 |
| Parallelism | 1 |
| Completions | 1 |
| Keyspace | 1000 |
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
| Aggregate throughput (rps) | 151.80 |
| Aggregate success throughput (rps) | 151.80 |
| Max pod p50 latency (ms) | 50.037 |
| Max pod p95 latency (ms) | 60.101 |
| Max pod p99 latency (ms) | 69.705 |
| Success count | 2000 |
| Error count | 0 |
| Error rate (%) | 0.0000 |
| Read count | 1788 |
| Write count | 212 |
| Read not found count | 894 |
| Job completed | true |
| Pod count | 1 |
| Pod metric failures | 0 |

## Artifacts

- JSON report: `reports/benchmarks/aws/e2e_http_incluster_20260218T092150Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218092158`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218092158/job.yaml`
