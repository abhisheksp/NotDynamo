# NotDynamo E2E HTTP In-Cluster Benchmark Report

- Status: **PASS**
- Timestamp (UTC): 2026-02-19T07:54:44Z
- Category: `in-cluster-job`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-http-20260219075411`

## Configuration

| Field | Value |
|---|---|
| Operations total (requested) | 8000 |
| Operations per pod | 4000 |
| Parallelism | 2 |
| Completions | 2 |
| Benchmark node label | notdynamo.io/workload=benchmark |
| Benchmark taint effect | NoSchedule |
| Keyspace | 2000 |
| Threads per pod | 8 |
| Read ratio | 0.90 |
| Distribution | uniform |
| Zipf theta | 0.90 |
| Value bytes | 256 |
| Preload | false |

## Results

| Metric | Value |
|---|---|
| Effective operations | 8000 |
| Aggregate throughput (rps) | 310.55 |
| Aggregate success throughput (rps) | 310.55 |
| Max pod p50 latency (ms) | 50.019 |
| Max pod p95 latency (ms) | 60.070 |
| Max pod p99 latency (ms) | 61.843 |
| Success count | 8000 |
| Error count | 0 |
| Error rate (%) | 0.0000 |
| Read count | 7187 |
| Write count | 813 |
| Read not found count | 7 |
| Job completed | true |
| Pod count | 2 |
| Pod metric failures | 0 |

## Telemetry Summary

| Signal | Value |
|---|---|
| Sample attempts (used/configured) | 4 / 20 |
| Pods top available | true |
| Nodes top available | true |
| Generator pod count (sampled) | 2 |
| Generator CPU mcores sum | 806.000 |
| Generator CPU mcores avg | 403.000 |
| Service pod count (sampled) | 3 |
| Service CPU mcores sum | 26.000 |
| Service CPU mcores avg | 8.667 |
| Generator/Service CPU ratio | 31.000 |
| Attribution hint | generator-pressure-dominant |
| Attribution reason | benchmark pod CPU sum is >= 1.5x data pod CPU sum during sample window |
| Cluster node count (sampled) | 5 |
| Cluster CPU percent max | 8.000 |
| Cluster memory percent max | 41.000 |

## Artifacts

- JSON report: `reports/benchmarks/aws/e2e_http_incluster_e42_validation_20260219T075408Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219075411`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219075411/job.yaml`
- Pod placement snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219075411/pod_placement.txt`
- Pods top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219075411/telemetry/pods_top_snapshot.txt`
- Nodes top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219075411/telemetry/nodes_top_snapshot.txt`
- Generator top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219075411/telemetry/bench_top_summary.txt`
- Service top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219075411/telemetry/data_top_summary.txt`
- Nodes top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219075411/telemetry/nodes_top_summary.txt`
