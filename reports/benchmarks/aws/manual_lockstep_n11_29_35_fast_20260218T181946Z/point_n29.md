# NotDynamo E2E HTTP In-Cluster Benchmark Report

- Status: **PASS**
- Timestamp (UTC): 2026-02-18T18:25:52Z
- Category: `in-cluster-job`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-http-20260218182533`

## Configuration

| Field | Value |
|---|---|
| Operations total (requested) | 1000 |
| Operations per pod | 1000 |
| Parallelism | 1 |
| Completions | 1 |
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
| Effective operations | 1000 |
| Aggregate throughput (rps) | 144.81 |
| Aggregate success throughput (rps) | 144.81 |
| Max pod p50 latency (ms) | 50.092 |
| Max pod p95 latency (ms) | 60.737 |
| Max pod p99 latency (ms) | 141.468 |
| Success count | 1000 |
| Error count | 0 |
| Error rate (%) | 0.0000 |
| Read count | 889 |
| Write count | 111 |
| Read not found count | 872 |
| Job completed | true |
| Pod count | 1 |
| Pod metric failures | 0 |

## Artifacts

- JSON report: `reports/benchmarks/aws/manual_lockstep_n11_29_35_fast_20260218T181946Z/point_n29.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218182533`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218182533/job.yaml`
