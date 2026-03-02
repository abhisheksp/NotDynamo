# NotDynamo E2E HTTP In-Cluster Benchmark Report

- Status: **FAIL**
- Timestamp (UTC): 2026-02-19T08:07:54Z
- Category: `in-cluster-job`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-http-20260219080400`

## Configuration

| Field | Value |
|---|---|
| Operations total (requested) | 36000 |
| Operations per pod | 6000 |
| Parallelism | 6 |
| Completions | 6 |
| Benchmark node label | notdynamo.io/workload=benchmark |
| Benchmark taint effect | NoSchedule |
| Keyspace | 10000 |
| Threads per pod | 24 |
| Read ratio | 0.90 |
| Distribution | uniform |
| Zipf theta | 0.90 |
| Value bytes | 256 |
| Preload | false |

## Results

| Metric | Value |
|---|---|
| Effective operations | 0 |
| Aggregate throughput (rps) | 0.00 |
| Aggregate success throughput (rps) | 0.00 |
| Max pod p50 latency (ms) | 0.000 |
| Max pod p95 latency (ms) | 0.000 |
| Max pod p99 latency (ms) | 0.000 |
| Success count | 0 |
| Error count | 0 |
| Error rate (%) | 0.0000 |
| Read count | 0 |
| Write count | 0 |
| Read not found count | 0 |
| Job completed | false |
| Pod count | 5 |
| Pod metric failures | 5 |

## Telemetry Summary

| Signal | Value |
|---|---|
| Sample attempts (used/configured) | 6 / 15 |
| Pods top available | true |
| Nodes top available | true |
| Generator pod count (sampled) | 6 |
| Generator CPU mcores sum | 559.000 |
| Generator CPU mcores avg | 93.167 |
| Service pod count (sampled) | 11 |
| Service CPU mcores sum | 4532.000 |
| Service CPU mcores avg | 412.000 |
| Generator/Service CPU ratio | 0.123 |
| Attribution hint | service-pressure-dominant |
| Attribution reason | data pod CPU sum is >= 1.5x benchmark pod CPU sum during sample window |
| Cluster node count (sampled) | 13 |
| Cluster CPU percent max | 102.000 |
| Cluster memory percent max | 44.000 |

## Artifacts

- JSON report: `reports/benchmarks/aws/e2e_http_incluster_20260219T080357Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219080400`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219080400/job.yaml`
- Pod placement snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219080400/pod_placement.txt`
- Pods top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219080400/telemetry/pods_top_snapshot.txt`
- Nodes top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219080400/telemetry/nodes_top_snapshot.txt`
- Generator top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219080400/telemetry/bench_top_summary.txt`
- Service top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219080400/telemetry/data_top_summary.txt`
- Nodes top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219080400/telemetry/nodes_top_summary.txt`
