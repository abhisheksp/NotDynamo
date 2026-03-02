# NotDynamo E2E HTTP In-Cluster Benchmark Report

- Status: **PASS**
- Timestamp (UTC): 2026-02-18T18:22:53Z
- Category: `in-cluster-job`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-http-20260218182151`

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
| Aggregate throughput (rps) | 140.35 |
| Aggregate success throughput (rps) | 140.35 |
| Max pod p50 latency (ms) | 50.054 |
| Max pod p95 latency (ms) | 62.191 |
| Max pod p99 latency (ms) | 199.724 |
| Success count | 1000 |
| Error count | 0 |
| Error rate (%) | 0.0000 |
| Read count | 900 |
| Write count | 100 |
| Read not found count | 892 |
| Job completed | true |
| Pod count | 1 |
| Pod metric failures | 0 |

## Artifacts

- JSON report: `reports/benchmarks/aws/manual_lockstep_n11_29_35_fast_20260218T181946Z/point_n11.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218182151`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218182151/job.yaml`
