# NotDynamo E2E HTTP In-Cluster Benchmark Report

- Status: **PASS**
- Timestamp (UTC): 2026-02-19T18:32:41Z
- Category: `in-cluster-job`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-http-20260219182705`

## Configuration

| Field | Value |
|---|---|
| Operations total (requested) | 2200000 |
| Operations per pod | 200000 |
| Parallelism | 11 |
| Completions | 11 |
| Benchmark node label | notdynamo.io/workload=benchmark |
| Benchmark taint effect | NoSchedule |
| Keyspace | 20000 |
| Threads per pod | 32 |
| Read ratio | 1.0 |
| Distribution | uniform |
| Zipf theta | 0.90 |
| Value bytes | 256 |
| Preload | false |

## Results

| Metric | Value |
|---|---|
| Effective operations | 2200000 |
| Aggregate throughput (rps) | 6804.92 |
| Aggregate success throughput (rps) | 6804.92 |
| Max pod p50 latency (ms) | 50.081 |
| Max pod p95 latency (ms) | 60.471 |
| Max pod p99 latency (ms) | 78.785 |
| Success count | 2200000 |
| Error count | 0 |
| Error rate (%) | 0.0000 |
| Read count | 2200000 |
| Write count | 0 |
| Read not found count | 0 |
| Job completed | true |
| Pod count | 11 |
| Pod metric failures | 0 |

## Telemetry Summary

| Signal | Value |
|---|---|
| Sample attempts (used/configured) | 5 / 15 |
| Pods top available | true |
| Nodes top available | true |
| Generator pod count (sampled) | 11 |
| Generator CPU mcores sum | 4795.000 |
| Generator CPU mcores avg | 435.909 |
| Service pod count (sampled) | 3 |
| Service CPU mcores sum | 992.000 |
| Service CPU mcores avg | 330.667 |
| Generator/Service CPU ratio | 4.834 |
| Attribution hint | generator-pressure-dominant |
| Attribution reason | benchmark pod CPU sum is >= 1.5x data pod CPU sum during sample window |
| Cluster node count (sampled) | 14 |
| Cluster CPU percent max | 20.000 |
| Cluster memory percent max | 56.000 |

## Artifacts

- JSON report: `reports/benchmarks/aws/e47_read_hit_balanced_20260219T182702Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219182705`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219182705/job.yaml`
- Pod placement snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219182705/pod_placement.txt`
- Pods top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219182705/telemetry/pods_top_snapshot.txt`
- Nodes top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219182705/telemetry/nodes_top_snapshot.txt`
- Generator top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219182705/telemetry/bench_top_summary.txt`
- Service top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219182705/telemetry/data_top_summary.txt`
- Nodes top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219182705/telemetry/nodes_top_summary.txt`
