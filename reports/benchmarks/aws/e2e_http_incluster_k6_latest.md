# NotDynamo E2E HTTP In-Cluster Benchmark Report (k6)

- Status: **PASS**
- Timestamp (UTC): 2026-02-19T22:31:52Z
- Category: `in-cluster-job`
- Driver: `k6`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-k6-20260219222921`

## Configuration

| Field | Value |
|---|---|
| Parallelism | 2 |
| Completions | 2 |
| Benchmark node label | notdynamo.io/workload=benchmark |
| Benchmark taint effect | NoSchedule |
| k6 VUs per pod | 8 |
| k6 Duration | 60s |
| k6 Setup timeout | 10m |
| Keyspace | 200 |
| Read ratio | 0.95 |
| Distribution | uniform |
| Value bytes | 256 |
| Preload | true |
| Skip main | true |
| Request timeout ms | 6000 |

## Results

| Metric | Value |
|---|---|
| Effective operations | 400 |
| Aggregate throughput (rps) | 5.70 |
| Aggregate success throughput (rps) | 0.00 |
| Max pod p50 latency (ms) | 49.814 |
| Max pod p95 latency (ms) | 59.855 |
| Max pod p99 latency (ms) | 60.023 |
| Success count | 0 |
| Error count | 0 |
| Error rate (%) | 0.0000 |
| Read count | 0 |
| Write count | 0 |
| Read not found count | 0 |
| Preload attempted | 400 |
| Preload success | 400 |
| Preload failed | 0 |
| Job completed | true |
| Pod count | 2 |
| Pod metric failures | 0 |

## Telemetry Summary

| Signal | Value |
|---|---|
| Sample attempts (used/configured) | 1 / 15 |
| Pods top available | true |
| Nodes top available | true |
| Generator pod count (sampled) | 0 |
| Generator CPU mcores sum | 0.000 |
| Generator CPU mcores avg | 0.000 |
| Service pod count (sampled) | 3 |
| Service CPU mcores sum | 27.000 |
| Service CPU mcores avg | 9.000 |
| Generator/Service CPU ratio | 0.000 |
| Attribution hint | inconclusive |
| Attribution reason | insufficient pod-level telemetry |
| Cluster node count (sampled) | 14 |
| Cluster CPU percent max | 2.000 |
| Cluster memory percent max | 56.000 |

## Artifacts

- JSON report: `reports/benchmarks/aws/e48_k6_preload_seed_fix_20260219T222849Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219222921`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219222921/job.yaml`
- Script configmap: `notdynamo-bench-k6-script-20260219222921`
- Pod placement snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219222921/pod_placement.txt`
- Pods top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219222921/telemetry/pods_top_snapshot.txt`
- Nodes top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219222921/telemetry/nodes_top_snapshot.txt`
- Generator top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219222921/telemetry/bench_top_summary.txt`
- Service top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219222921/telemetry/data_top_summary.txt`
- Nodes top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219222921/telemetry/nodes_top_summary.txt`
