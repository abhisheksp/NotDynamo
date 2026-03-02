# NotDynamo E2E HTTP In-Cluster Benchmark Report

- Status: **PASS**
- Timestamp (UTC): 2026-02-18T21:53:05Z
- Category: `in-cluster-job`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-http-20260218214957`

## Configuration

| Field | Value |
|---|---|
| Operations total (requested) | 200000 |
| Operations per pod | 50000 |
| Parallelism | 4 |
| Completions | 4 |
| Benchmark node label | notdynamo.io/workload=benchmark |
| Benchmark taint effect | NoSchedule |
| Keyspace | 20000 |
| Threads per pod | 32 |
| Read ratio | 0.90 |
| Distribution | uniform |
| Zipf theta | 0.90 |
| Value bytes | 256 |
| Preload | false |

## Results

| Metric | Value |
|---|---|
| Effective operations | 200000 |
| Aggregate throughput (rps) | 2335.57 |
| Aggregate success throughput (rps) | 2335.57 |
| Max pod p50 latency (ms) | 50.415 |
| Max pod p95 latency (ms) | 70.209 |
| Max pod p99 latency (ms) | 97.086 |
| Success count | 200000 |
| Error count | 0 |
| Error rate (%) | 0.0000 |
| Read count | 179982 |
| Write count | 20018 |
| Read not found count | 913 |
| Job completed | true |
| Pod count | 4 |
| Pod metric failures | 0 |

## Artifacts

- JSON report: `reports/benchmarks/aws/manual_highload_splitinfra_20260218T214925Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218214957`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218214957/job.yaml`
