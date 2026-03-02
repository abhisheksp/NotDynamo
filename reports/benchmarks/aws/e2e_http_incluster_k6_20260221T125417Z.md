# NotDynamo E2E HTTP In-Cluster Benchmark Report (k6)

- Status: **WARN**
- Timestamp (UTC): 2026-02-21T12:56:00Z
- Category: `in-cluster-job`
- Driver: `k6`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-k6-20260221125417`

## Configuration

| Field | Value |
|---|---|
| Parallelism | 3 |
| Completions | 3 |
| Benchmark node label | none |
| Benchmark taint effect | NoSchedule |
| k6 VUs per pod | 32 |
| k6 Duration | 90s |
| k6 Setup timeout | 10m |
| Keyspace | 20000 |
| Read ratio | 0.10 |
| Distribution | uniform |
| Value bytes | 256 |
| Preload | false |
| Skip main | false |
| Request timeout ms | 5000 |

## Results

| Metric | Value |
|---|---|
| Effective operations | 42603 |
| Aggregate throughput (rps) | 468.19 |
| Aggregate success throughput (rps) | 443.64 |
| Max pod p50 latency (ms) | 71.819 |
| Max pod p95 latency (ms) | 999.616 |
| Max pod p99 latency (ms) | 1760.278 |
| Success count | 40369 |
| Error count | 2234 |
| Error rate (%) | 5.2438 |
| Read count | 4290 |
| Write count | 38313 |
| Read not found count | 52 |
| Preload attempted | 0 |
| Preload success | 0 |
| Preload failed | 0 |
| Job completed | true |
| Pod count | 3 |
| Pod metric failures | 0 |

## Telemetry Summary

| Signal | Value |
|---|---|
| Sample attempts (used/configured) | 15 / 15 |
| Pods top available | true |
| Nodes top available | true |
| Generator pod count (sampled) | 3 |
| Generator CPU mcores sum | 287.000 |
| Generator CPU mcores avg | 95.667 |
| Service pod count (sampled) | 3 |
| Service CPU mcores sum | 2140.000 |
| Service CPU mcores avg | 713.333 |
| Generator/Service CPU ratio | 0.134 |
| Attribution hint | service-pressure-dominant |
| Attribution reason | data pod CPU sum is >= 1.5x benchmark pod CPU sum during sample window |
| Cluster node count (sampled) | 3 |
| Cluster CPU percent max | 50.000 |
| Cluster memory percent max | 23.000 |
| Write-stage telemetry samples | 3 |

## Write-Stage Telemetry Samples

- `notdynamo-data-0`: `{"node":"notdynamo-data-0","observed_leader_override_writes":31119,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":0,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"observed_leader_snapshot_refresh_failures":0,"write_backpressure_rejections":0,"write_backpressure_rejections_by_shard":{},"write_admission_wait_exhausted_count":25,"write_inflight_limit":256,"write_shard_inflight_min":8,"write_shard_inflight_limit":64,"write_inflight_current":1,"consensus_reject_due_to_inflight_limit":25,"consensus_reject_due_to_inflight_limit_by_shard":{"4":7,"19":6,"26":12},"consensus_inflight_by_shard":{"6":1},"write_total_requests":50585,"write_forwarded_requests":23339,"forward_hop_ratio":0.461382,"forward_to_leader":{"success":21801,"error":1513,"timeout":10,"latency_ms_avg":197.388,"latency_ms_max":5004.971},"consensus_submit":{"success":27221,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":27170,"error":76,"timeout":51,"latency_ms_avg":57.956,"latency_ms_max":5018.851},"put_total":{"success":48970,"error":1589,"timeout":61,"latency_ms_avg":122.282,"latency_ms_max":5018.951},"delete_total":{"success":1,"error":0,"timeout":0,"latency_ms_avg":70.064,"latency_ms_max":70.064},"forward_error_by_shard":{"1":321,"2":10,"3":24,"7":37,"8":47,"10":67,"11":72,"12":39,"13":106,"14":216,"16":122,"17":97,"18":1,"20":80,"21":19,"23":136,"26":4,"27":29,"28":39,"29":44,"31":3},"consensus_reply_error_by_shard":{"0":8,"1":14,"3":1,"4":11,"9":2,"12":1,"19":16,"26":23},"put_total_by_shard":{"0":1078,"1":1230,"2":3114,"3":1208,"4":3505,"5":3404,"6":3429,"7":1107,"8":847,"9":1114,"10":710,"11":760,"12":1079,"13":887,"14":950,"15":1036,"16":852,"17":880,"18":1035,"19":2950,"20":839,"21":1085,"22":821,"23":3133,"24":3944,"25":805,"26":2576,"27":979,"28":823,"29":806,"30":2694,"31":879},"put_timeout_by_shard":{"0":8,"1":14,"2":1,"3":1,"4":4,"9":2,"12":1,"14":2,"19":10,"20":7,"26":11},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":51,"consensus_reply:STATUS_CODE_UNAVAILABLE/cause=CONSENSUS_INFLIGHT_LIMIT":25,"forward:STATUS_CODE_TIMEOUT/grpc=DEADLINE_EXCEEDED":10,"forward:STATUS_CODE_UNAVAILABLE":1503,"put_total:STATUS_CODE_TIMEOUT":51,"put_total:STATUS_CODE_TIMEOUT/grpc=DEADLINE_EXCEEDED":10,"put_total:STATUS_CODE_UNAVAILABLE":1503,"put_total:STATUS_CODE_UNAVAILABLE/cause=CONSENSUS_INFLIGHT_LIMIT":25}}`
- `notdynamo-data-1`: `{"node":"notdynamo-data-1","observed_leader_override_writes":56941,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":0,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"observed_leader_snapshot_refresh_failures":0,"write_backpressure_rejections":5381,"write_backpressure_rejections_by_shard":{"0":2,"1":538,"3":436,"7":194,"8":180,"9":10,"10":145,"11":168,"12":175,"13":263,"14":793,"16":470,"17":600,"18":5,"20":278,"21":351,"22":14,"23":281,"25":1,"26":10,"27":104,"28":158,"29":189,"31":16},"write_admission_wait_exhausted_count":5386,"write_inflight_limit":256,"write_shard_inflight_min":8,"write_shard_inflight_limit":10,"write_inflight_current":62,"consensus_reject_due_to_inflight_limit":5,"consensus_reject_due_to_inflight_limit_by_shard":{"3":5},"consensus_inflight_by_shard":{"1":8,"7":2,"9":1,"10":3,"11":1,"12":7,"13":6,"14":10,"16":10,"17":1,"18":1,"20":4,"23":2,"28":3,"29":3},"write_total_requests":86410,"write_forwarded_requests":12002,"forward_hop_ratio":0.138896,"forward_to_leader":{"success":11971,"error":30,"timeout":11,"latency_ms_avg":34.342,"latency_ms_max":5365.130},"consensus_submit":{"success":69022,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":68943,"error":5404,"timeout":18,"latency_ms_avg":226.553,"latency_ms_max":5061.392},"put_total":{"success":80913,"error":5434,"timeout":29,"latency_ms_avg":200.019,"latency_ms_max":5365.325},"delete_total":{"success":1,"error":0,"timeout":0,"latency_ms_avg":49.294,"latency_ms_max":49.294},"forward_error_by_shard":{"2":10,"4":5,"19":7,"26":8},"consensus_reply_error_by_shard":{"0":2,"1":538,"3":441,"7":194,"8":180,"9":10,"10":145,"11":168,"12":175,"13":263,"14":795,"16":470,"17":600,"18":5,"20":294,"21":351,"22":14,"23":281,"25":1,"26":10,"27":104,"28":158,"29":189,"31":16},"put_total_by_shard":{"0":3143,"1":3629,"2":1374,"3":3566,"4":1568,"5":1245,"6":1286,"7":3395,"8":3279,"9":3345,"10":2721,"11":2834,"12":3284,"13":3319,"14":3507,"15":1153,"16":3550,"17":3368,"18":3153,"19":1193,"20":3122,"21":3041,"22":3509,"23":2062,"24":1474,"25":3391,"26":1699,"27":2972,"28":3287,"29":3148,"30":1190,"31":3540},"put_timeout_by_shard":{"4":4,"14":2,"19":4,"20":16,"26":3},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":18,"consensus_reply:STATUS_CODE_UNAVAILABLE/cause=BACKPRESSURE":5381,"consensus_reply:STATUS_CODE_UNAVAILABLE/cause=CONSENSUS_INFLIGHT_LIMIT":5,"forward:STATUS_CODE_TIMEOUT/grpc=DEADLINE_EXCEEDED":11,"forward:STATUS_CODE_UNAVAILABLE":19,"put_total:STATUS_CODE_TIMEOUT":18,"put_total:STATUS_CODE_TIMEOUT/grpc=DEADLINE_EXCEEDED":11,"put_total:STATUS_CODE_UNAVAILABLE":19,"put_total:STATUS_CODE_UNAVAILABLE/cause=BACKPRESSURE":5381,"put_total:STATUS_CODE_UNAVAILABLE/cause=CONSENSUS_INFLIGHT_LIMIT":5}}`
- `notdynamo-data-2`: `{"node":"notdynamo-data-2","observed_leader_override_writes":30279,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":0,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"observed_leader_snapshot_refresh_failures":0,"write_backpressure_rejections":0,"write_backpressure_rejections_by_shard":{},"write_admission_wait_exhausted_count":19,"write_inflight_limit":256,"write_shard_inflight_min":8,"write_shard_inflight_limit":64,"write_inflight_current":6,"consensus_reject_due_to_inflight_limit":19,"consensus_reject_due_to_inflight_limit_by_shard":{"2":19},"consensus_inflight_by_shard":{"8":3,"17":3},"write_total_requests":49251,"write_forwarded_requests":39520,"forward_hop_ratio":0.802420,"forward_to_leader":{"success":37249,"error":2258,"timeout":19,"latency_ms_avg":176.686,"latency_ms_max":5008.889},"consensus_submit":{"success":9712,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":9705,"error":20,"timeout":1,"latency_ms_avg":94.311,"latency_ms_max":5029.348},"put_total":{"success":46954,"error":2278,"timeout":20,"latency_ms_avg":160.473,"latency_ms_max":5029.412},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":1,"1":200,"3":250,"4":4,"7":75,"8":61,"9":5,"10":22,"11":23,"12":59,"13":53,"14":354,"16":197,"17":379,"18":2,"19":4,"20":155,"21":185,"22":8,"23":34,"26":17,"27":34,"28":51,"29":79,"31":6},"consensus_reply_error_by_shard":{"2":20},"put_total_by_shard":{"0":1239,"1":1460,"2":2530,"3":1426,"4":2616,"5":1543,"6":1315,"7":1366,"8":1506,"9":1423,"10":1103,"11":1320,"12":1309,"13":1384,"14":1641,"15":3201,"16":1395,"17":1572,"18":1245,"19":1223,"20":1473,"21":1197,"22":1390,"23":1831,"24":1527,"25":1354,"26":1557,"27":1188,"28":1232,"29":1411,"30":1902,"31":1353},"put_timeout_by_shard":{"2":1,"14":1,"19":2,"20":12,"26":4},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":1,"consensus_reply:STATUS_CODE_UNAVAILABLE/cause=CONSENSUS_INFLIGHT_LIMIT":19,"forward:STATUS_CODE_INTERNAL/grpc=CANCELLED":1,"forward:STATUS_CODE_TIMEOUT/grpc=DEADLINE_EXCEEDED":19,"forward:STATUS_CODE_UNAVAILABLE":2238,"put_total:STATUS_CODE_INTERNAL/grpc=CANCELLED":1,"put_total:STATUS_CODE_TIMEOUT":1,"put_total:STATUS_CODE_TIMEOUT/grpc=DEADLINE_EXCEEDED":19,"put_total:STATUS_CODE_UNAVAILABLE":2238,"put_total:STATUS_CODE_UNAVAILABLE/cause=CONSENSUS_INFLIGHT_LIMIT":19}}`

## Artifacts

- JSON report: `reports/benchmarks/aws/e2e_http_incluster_k6_20260221T125417Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221125417`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221125417/job.yaml`
- Script configmap: `notdynamo-bench-k6-script-20260221125417`
- Pod placement snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221125417/pod_placement.txt`
- Pods top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221125417/telemetry/pods_top_snapshot.txt`
- Nodes top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221125417/telemetry/nodes_top_snapshot.txt`
- Generator top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221125417/telemetry/bench_top_summary.txt`
- Service top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221125417/telemetry/data_top_summary.txt`
- Nodes top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221125417/telemetry/nodes_top_summary.txt`
- Write-stage telemetry samples: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221125417/telemetry/write_stage_telemetry_samples.txt`
