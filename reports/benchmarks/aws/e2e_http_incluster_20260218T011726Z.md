# NotDynamo E2E HTTP In-Cluster Benchmark Report

- Status: **WARN**
- Timestamp (UTC): 2026-02-18T01:18:07Z
- Category: `in-cluster-job`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-http-20260218011733`

## Configuration

| Field | Value |
|---|---|
| Operations total (requested) | 6000 |
| Operations per pod | 3000 |
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
| Effective operations | 6000 |
| Aggregate throughput (rps) | 225.04 |
| Aggregate success throughput (rps) | 208.06 |
| Max pod p50 latency (ms) | 50.622 |
| Max pod p95 latency (ms) | 189.910 |
| Max pod p99 latency (ms) | 241.793 |
| Success count | 5547 |
| Error count | 453 |
| Error rate (%) | 7.5500 |
| Read count | 5420 |
| Write count | 580 |
| Read not found count | 4255 |
| Job completed | true |
| Pod count | 2 |
| Pod metric failures | 0 |

## Error Samples

- `http_status=503`

## Artifacts

- JSON report: `reports/benchmarks/aws/e2e_http_incluster_20260218T011726Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218011733`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218011733/job.yaml`
