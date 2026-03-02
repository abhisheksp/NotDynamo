# NotDynamo E2E HTTP In-Cluster Benchmark Report

- Status: **PASS**
- Timestamp (UTC): 2026-02-18T18:55:30Z
- Category: `in-cluster-job`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-http-20260218185102`

## Configuration

| Field | Value |
|---|---|
| Operations total (requested) | 400000 |
| Operations per pod | 50000 |
| Parallelism | 8 |
| Completions | 8 |
| Keyspace | 20000 |
| Threads per pod | 64 |
| Read ratio | 0.90 |
| Distribution | uniform |
| Zipf theta | 0.90 |
| Value bytes | 256 |
| Preload | false |

## Results

| Metric | Value |
|---|---|
| Effective operations | 400000 |
| Aggregate throughput (rps) | 2926.86 |
| Aggregate success throughput (rps) | 2926.86 |
| Max pod p50 latency (ms) | 163.331 |
| Max pod p95 latency (ms) | 294.151 |
| Max pod p99 latency (ms) | 444.163 |
| Success count | 400000 |
| Error count | 0 |
| Error rate (%) | 0.0000 |
| Read count | 359858 |
| Write count | 40142 |
| Read not found count | 61790 |
| Job completed | true |
| Pod count | 8 |
| Pod metric failures | 0 |

## Artifacts

- JSON report: `reports/benchmarks/aws/manual_highload_incluster_p8_t64_20260218T185030Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218185102`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218185102/job.yaml`
