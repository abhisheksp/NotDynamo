# NotDynamo E2E HTTP In-Cluster Benchmark Report

- Status: **WARN**
- Timestamp (UTC): 2026-02-19T08:40:57Z
- Category: `in-cluster-job`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-http-20260219083959`

## Configuration

| Field | Value |
|---|---|
| Operations total (requested) | 500 |
| Operations per pod | 500 |
| Parallelism | 1 |
| Completions | 1 |
| Benchmark node label | notdynamo.io/workload=benchmark |
| Benchmark taint effect | NoSchedule |
| Keyspace | 200 |
| Threads per pod | 2 |
| Read ratio | 0.90 |
| Distribution | uniform |
| Zipf theta | 0.90 |
| Value bytes | 256 |
| Preload | false |

## Results

| Metric | Value |
|---|---|
| Effective operations | 500 |
| Aggregate throughput (rps) | 9.96 |
| Aggregate success throughput (rps) | 9.02 |
| Max pod p50 latency (ms) | 50.005 |
| Max pod p95 latency (ms) | 1501.150 |
| Max pod p99 latency (ms) | 1502.477 |
| Success count | 453 |
| Error count | 47 |
| Error rate (%) | 9.4000 |
| Read count | 453 |
| Write count | 47 |
| Read not found count | 376 |
| Job completed | true |
| Pod count | 1 |
| Pod metric failures | 0 |

## Telemetry Summary

| Signal | Value |
|---|---|
| Sample attempts (used/configured) | 4 / 15 |
| Pods top available | true |
| Nodes top available | true |
| Generator pod count (sampled) | 1 |
| Generator CPU mcores sum | 165.000 |
| Generator CPU mcores avg | 165.000 |
| Service pod count (sampled) | 29 |
| Service CPU mcores sum | 800.000 |
| Service CPU mcores avg | 27.586 |
| Generator/Service CPU ratio | 0.206 |
| Attribution hint | service-pressure-dominant |
| Attribution reason | data pod CPU sum is >= 1.5x benchmark pod CPU sum during sample window |
| Cluster node count (sampled) | 31 |
| Cluster CPU percent max | 20.000 |
| Cluster memory percent max | 38.000 |

## Error Samples

- `HttpTimeoutException:request_timed_out`

## Artifacts

- JSON report: `reports/benchmarks/aws/e2e_http_incluster_20260219T083957Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219083959`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219083959/job.yaml`
- Pod placement snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219083959/pod_placement.txt`
- Pods top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219083959/telemetry/pods_top_snapshot.txt`
- Nodes top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219083959/telemetry/nodes_top_snapshot.txt`
- Generator top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219083959/telemetry/bench_top_summary.txt`
- Service top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219083959/telemetry/data_top_summary.txt`
- Nodes top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219083959/telemetry/nodes_top_summary.txt`
