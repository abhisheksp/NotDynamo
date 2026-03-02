# NotDynamo E2E HTTP In-Cluster Benchmark Report

- Status: **PASS**
- Timestamp (UTC): 2026-02-18T18:49:49Z
- Category: `in-cluster-job`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-http-20260218184807`

## Configuration

| Field | Value |
|---|---|
| Operations total (requested) | 200000 |
| Operations per pod | 50000 |
| Parallelism | 4 |
| Completions | 4 |
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
| Aggregate throughput (rps) | 2200.56 |
| Aggregate success throughput (rps) | 2200.56 |
| Max pod p50 latency (ms) | 50.958 |
| Max pod p95 latency (ms) | 89.484 |
| Max pod p99 latency (ms) | 148.871 |
| Success count | 200000 |
| Error count | 0 |
| Error rate (%) | 0.0000 |
| Read count | 180174 |
| Write count | 19826 |
| Read not found count | 113688 |
| Job completed | true |
| Pod count | 4 |
| Pod metric failures | 0 |

## Artifacts

- JSON report: `reports/benchmarks/aws/manual_highload_incluster_20260218T184750Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218184807`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218184807/job.yaml`
