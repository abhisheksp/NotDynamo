# NotDynamo E2E HTTP In-Cluster Benchmark Report (k6)

- Status: **PASS**
- Timestamp (UTC): 2026-02-19T22:45:09Z
- Category: `in-cluster-job`
- Driver: `k6`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-k6-20260219224135`

## Configuration

| Field | Value |
|---|---|
| Parallelism | 8 |
| Completions | 8 |
| Benchmark node label | notdynamo.io/workload=benchmark |
| Benchmark taint effect | NoSchedule |
| k6 VUs per pod | 64 |
| k6 Duration | 60s |
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
| Effective operations | 18532 |
| Aggregate throughput (rps) | 301.77 |
| Aggregate success throughput (rps) | 301.77 |
| Max pod p50 latency (ms) | 1679.722 |
| Max pod p95 latency (ms) | 2124.506 |
| Max pod p99 latency (ms) | 3400.145 |
| Success count | 18532 |
| Error count | 0 |
| Error rate (%) | 0.0000 |
| Read count | 0 |
| Write count | 18532 |
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
| Sample attempts (used/configured) | 12 / 15 |
| Pods top available | true |
| Nodes top available | true |
| Generator pod count (sampled) | 0 |
| Generator CPU mcores sum | 0.000 |
| Generator CPU mcores avg | 0.000 |
| Service pod count (sampled) | 3 |
| Service CPU mcores sum | 823.000 |
| Service CPU mcores avg | 274.333 |
| Generator/Service CPU ratio | 0.000 |
| Attribution hint | inconclusive |
| Attribution reason | insufficient pod-level telemetry |
| Cluster node count (sampled) | 14 |
| Cluster CPU percent max | 13.000 |
| Cluster memory percent max | 57.000 |

## Artifacts

- JSON report: `reports/benchmarks/aws/e45_k6_write_heavy_telemetryfix_20260219T224117Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219224135`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219224135/job.yaml`
- Script configmap: `notdynamo-bench-k6-script-20260219224135`
- Pod placement snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219224135/pod_placement.txt`
- Pods top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219224135/telemetry/pods_top_snapshot.txt`
- Nodes top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219224135/telemetry/nodes_top_snapshot.txt`
- Generator top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219224135/telemetry/bench_top_summary.txt`
- Service top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219224135/telemetry/data_top_summary.txt`
- Nodes top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219224135/telemetry/nodes_top_summary.txt`
