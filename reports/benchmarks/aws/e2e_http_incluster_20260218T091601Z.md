# NotDynamo E2E HTTP In-Cluster Benchmark Report

- Status: **PASS**
- Timestamp (UTC): 2026-02-18T09:17:26Z
- Category: `in-cluster-job`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-http-20260218091609`

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
| Aggregate throughput (rps) | 154.88 |
| Aggregate success throughput (rps) | 154.88 |
| Max pod p50 latency (ms) | 50.020 |
| Max pod p95 latency (ms) | 60.071 |
| Max pod p99 latency (ms) | 66.336 |
| Success count | 2000 |
| Error count | 0 |
| Error rate (%) | 0.0000 |
| Read count | 1820 |
| Write count | 180 |
| Read not found count | 448 |
| Job completed | true |
| Pod count | 1 |
| Pod metric failures | 0 |

## Artifacts

- JSON report: `reports/benchmarks/aws/e2e_http_incluster_20260218T091601Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218091609`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218091609/job.yaml`
