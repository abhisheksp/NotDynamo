# NotDynamo E2E HTTP In-Cluster Benchmark Report

- Status: **WARN**
- Timestamp (UTC): 2026-02-19T14:56:54Z
- Category: `in-cluster-job`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-http-20260219145320`

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
| Aggregate throughput (rps) | 2.41 |
| Aggregate success throughput (rps) | 2.22 |
| Max pod p50 latency (ms) | 50.009 |
| Max pod p95 latency (ms) | 7501.560 |
| Max pod p99 latency (ms) | 7502.850 |
| Success count | 460 |
| Error count | 40 |
| Error rate (%) | 8.0000 |
| Read count | 460 |
| Write count | 40 |
| Read not found count | 403 |
| Job completed | true |
| Pod count | 1 |
| Pod metric failures | 0 |

## Telemetry Summary

| Signal | Value |
|---|---|
| Sample attempts (used/configured) | 5 / 15 |
| Pods top available | true |
| Nodes top available | true |
| Generator pod count (sampled) | 1 |
| Generator CPU mcores sum | 18.000 |
| Generator CPU mcores avg | 18.000 |
| Service pod count (sampled) | 35 |
| Service CPU mcores sum | 1830.000 |
| Service CPU mcores avg | 52.286 |
| Generator/Service CPU ratio | 0.010 |
| Attribution hint | service-pressure-dominant |
| Attribution reason | data pod CPU sum is >= 1.5x benchmark pod CPU sum during sample window |
| Cluster node count (sampled) | 37 |
| Cluster CPU percent max | 51.000 |
| Cluster memory percent max | 41.000 |

## Error Samples

- `HttpTimeoutException:request_timed_out`

## Artifacts

- JSON report: `reports/benchmarks/aws/e2e_http_incluster_20260219T145317Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219145320`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219145320/job.yaml`
- Pod placement snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219145320/pod_placement.txt`
- Pods top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219145320/telemetry/pods_top_snapshot.txt`
- Nodes top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219145320/telemetry/nodes_top_snapshot.txt`
- Generator top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219145320/telemetry/bench_top_summary.txt`
- Service top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219145320/telemetry/data_top_summary.txt`
- Nodes top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219145320/telemetry/nodes_top_summary.txt`
