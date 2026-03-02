# NotDynamo E2E HTTP In-Cluster Benchmark Report

- Status: **PASS**
- Timestamp (UTC): 2026-02-18T09:14:34Z
- Category: `in-cluster-job`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-http-20260218091421`

## Configuration

| Field | Value |
|---|---|
| Operations total (requested) | 1000 |
| Operations per pod | 1000 |
| Parallelism | 1 |
| Completions | 1 |
| Keyspace | 500 |
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
| Aggregate throughput (rps) | 147.26 |
| Aggregate success throughput (rps) | 147.26 |
| Max pod p50 latency (ms) | 50.066 |
| Max pod p95 latency (ms) | 60.454 |
| Max pod p99 latency (ms) | 78.236 |
| Success count | 1000 |
| Error count | 0 |
| Error rate (%) | 0.0000 |
| Read count | 903 |
| Write count | 97 |
| Read not found count | 447 |
| Job completed | true |
| Pod count | 1 |
| Pod metric failures | 0 |

## Artifacts

- JSON report: `reports/benchmarks/aws/calib_incluster_20260218T091413Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218091421`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218091421/job.yaml`
