# NotDynamo E2E HTTP In-Cluster Benchmark Report

- Status: **PASS**
- Timestamp (UTC): 2026-02-18T22:03:48Z
- Category: `in-cluster-job`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-http-20260218220043`

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
| Aggregate throughput (rps) | 2303.56 |
| Aggregate success throughput (rps) | 2303.56 |
| Max pod p50 latency (ms) | 50.404 |
| Max pod p95 latency (ms) | 78.960 |
| Max pod p99 latency (ms) | 109.855 |
| Success count | 200000 |
| Error count | 0 |
| Error rate (%) | 0.0000 |
| Read count | 179784 |
| Write count | 20216 |
| Read not found count | 292 |
| Job completed | true |
| Pod count | 4 |
| Pod metric failures | 0 |

## Artifacts

- JSON report: `reports/benchmarks/aws/manual_highload_splitinfra_keepjob_20260218T220011Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218220043`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218220043/job.yaml`
