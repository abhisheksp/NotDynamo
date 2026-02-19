# NotDynamo E2E HTTP In-Cluster Benchmark Report (k6)

- Status: **PASS**
- Timestamp (UTC): 2026-02-19T22:47:27Z
- Category: `in-cluster-job`
- Driver: `k6`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-k6-20260219224629`

## Configuration

| Field | Value |
|---|---|
| Parallelism | 8 |
| Completions | 8 |
| Benchmark node label | notdynamo.io/workload=benchmark |
| Benchmark taint effect | NoSchedule |
| k6 VUs per pod | 64 |
| k6 Duration | 45s |
| k6 Setup timeout | 10m |
| Keyspace | 2000 |
| Read ratio | 0.0 |
| Distribution | uniform |
| Value bytes | 256 |
| Preload | false |
| Skip main | false |
| Request timeout ms | 6000 |

## Results

| Metric | Value |
|---|---|
| Effective operations | 14109 |
| Aggregate throughput (rps) | 304.07 |
| Aggregate success throughput (rps) | 304.07 |
| Max pod p50 latency (ms) | 1629.620 |
| Max pod p95 latency (ms) | 2272.682 |
| Max pod p99 latency (ms) | 3433.230 |
| Success count | 14109 |
| Error count | 0 |
| Error rate (%) | 0.0000 |
| Read count | 0 |
| Write count | 14109 |
| Read not found count | 0 |
| Preload attempted | 0 |
| Preload success | 0 |
| Preload failed | 0 |
| Job completed | true |
| Pod count | 8 |
| Pod metric failures | 0 |

## Telemetry Summary

| Signal | Value |
|---|---|
| Sample attempts (used/configured) | 11 / 15 |
| Pods top available | true |
| Nodes top available | true |
| Generator pod count (sampled) | 8 |
| Generator CPU mcores sum | 227.000 |
| Generator CPU mcores avg | 28.375 |
| Service pod count (sampled) | 3 |
| Service CPU mcores sum | 832.000 |
| Service CPU mcores avg | 277.333 |
| Generator/Service CPU ratio | 0.273 |
| Attribution hint | service-pressure-dominant |
| Attribution reason | data pod CPU sum is >= 1.5x benchmark pod CPU sum during sample window |
| Cluster node count (sampled) | 14 |
| Cluster CPU percent max | 25.000 |
| Cluster memory percent max | 57.000 |

## Artifacts

- JSON report: `reports/benchmarks/aws/e45_k6_write_heavy_telemetryfix2_20260219T224627Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219224629`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219224629/job.yaml`
- Script configmap: `notdynamo-bench-k6-script-20260219224629`
- Pod placement snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219224629/pod_placement.txt`
- Pods top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219224629/telemetry/pods_top_snapshot.txt`
- Nodes top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219224629/telemetry/nodes_top_snapshot.txt`
- Generator top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219224629/telemetry/bench_top_summary.txt`
- Service top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219224629/telemetry/data_top_summary.txt`
- Nodes top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219224629/telemetry/nodes_top_summary.txt`
