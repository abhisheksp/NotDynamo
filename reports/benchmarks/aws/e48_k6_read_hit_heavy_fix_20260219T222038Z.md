# NotDynamo E2E HTTP In-Cluster Benchmark Report (k6)

- Status: **PASS**
- Timestamp (UTC): 2026-02-19T22:27:58Z
- Category: `in-cluster-job`
- Driver: `k6`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-k6-20260219222110`

## Configuration

| Field | Value |
|---|---|
| Parallelism | 8 |
| Completions | 8 |
| Benchmark node label | notdynamo.io/workload=benchmark |
| Benchmark taint effect | NoSchedule |
| k6 VUs per pod | 64 |
| k6 Duration | 120s |
| k6 Setup timeout | 10m |
| Keyspace | 500 |
| Read ratio | 1.0 |
| Distribution | uniform |
| Value bytes | 256 |
| Preload | false |
| Skip main | false |
| Request timeout ms | 6000 |

## Results

| Metric | Value |
|---|---|
| Effective operations | 1186486 |
| Aggregate throughput (rps) | 9883.41 |
| Aggregate success throughput (rps) | 9883.41 |
| Max pod p50 latency (ms) | 50.078 |
| Max pod p95 latency (ms) | 61.183 |
| Max pod p99 latency (ms) | 77.536 |
| Success count | 1186486 |
| Error count | 0 |
| Error rate (%) | 0.0000 |
| Read count | 1186486 |
| Write count | 0 |
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
| Sample attempts (used/configured) | 1 / 15 |
| Pods top available | true |
| Nodes top available | true |
| Generator pod count (sampled) | 0 |
| Generator CPU mcores sum | 0.000 |
| Generator CPU mcores avg | 0.000 |
| Service pod count (sampled) | 3 |
| Service CPU mcores sum | 30.000 |
| Service CPU mcores avg | 10.000 |
| Generator/Service CPU ratio | 0.000 |
| Attribution hint | inconclusive |
| Attribution reason | insufficient pod-level telemetry |
| Cluster node count (sampled) | 14 |
| Cluster CPU percent max | 2.000 |
| Cluster memory percent max | 56.000 |

## Artifacts

- JSON report: `reports/benchmarks/aws/e48_k6_read_hit_heavy_fix_20260219T222038Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219222110`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219222110/job.yaml`
- Script configmap: `notdynamo-bench-k6-script-20260219222110`
- Pod placement snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219222110/pod_placement.txt`
- Pods top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219222110/telemetry/pods_top_snapshot.txt`
- Nodes top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219222110/telemetry/nodes_top_snapshot.txt`
- Generator top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219222110/telemetry/bench_top_summary.txt`
- Service top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219222110/telemetry/data_top_summary.txt`
- Nodes top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219222110/telemetry/nodes_top_summary.txt`
