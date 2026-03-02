# NotDynamo E2E HTTP In-Cluster Benchmark Report (k6)

- Status: **PASS**
- Timestamp (UTC): 2026-02-21T13:02:25Z
- Category: `in-cluster-job`
- Driver: `k6`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-k6-20260221130042`

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
| Effective operations | 42164 |
| Aggregate throughput (rps) | 466.23 |
| Aggregate success throughput (rps) | 463.57 |
| Max pod p50 latency (ms) | 99.708 |
| Max pod p95 latency (ms) | 768.143 |
| Max pod p99 latency (ms) | 1170.643 |
| Success count | 41924 |
| Error count | 240 |
| Error rate (%) | 0.5692 |
| Read count | 4262 |
| Write count | 37902 |
| Read not found count | 2 |
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
| Generator CPU mcores sum | 354.000 |
| Generator CPU mcores avg | 118.000 |
| Service pod count (sampled) | 3 |
| Service CPU mcores sum | 1953.000 |
| Service CPU mcores avg | 651.000 |
| Generator/Service CPU ratio | 0.181 |
| Attribution hint | service-pressure-dominant |
| Attribution reason | data pod CPU sum is >= 1.5x benchmark pod CPU sum during sample window |
| Cluster node count (sampled) | 4 |
| Cluster CPU percent max | 39.000 |
| Cluster memory percent max | 28.000 |
| Write-stage telemetry samples | 3 |

## Write-Stage Telemetry Samples

- `notdynamo-data-0`: `{"node":"notdynamo-data-0","observed_leader_override_writes":27870,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":0,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"observed_leader_snapshot_refresh_failures":0,"write_backpressure_rejections":977,"write_backpressure_rejections_by_shard":{"0":43,"1":130,"3":158,"5":97,"8":88,"12":160,"17":114,"22":121,"29":66},"write_admission_wait_exhausted_count":982,"write_inflight_limit":256,"write_shard_inflight_min":8,"write_shard_inflight_limit":15,"write_inflight_current":49,"consensus_reject_due_to_inflight_limit":5,"consensus_reject_due_to_inflight_limit_by_shard":{"1":1,"3":3,"22":1},"consensus_inflight_by_shard":{"0":7,"1":4,"3":10,"5":7,"8":2,"11":1,"12":2,"22":6,"24":1,"25":1,"29":8},"write_total_requests":44474,"write_forwarded_requests":6712,"forward_hop_ratio":0.150920,"forward_to_leader":{"success":6662,"error":50,"timeout":28,"latency_ms_avg":122.662,"latency_ms_max":5013.862},"consensus_submit":{"success":36780,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":36666,"error":1047,"timeout":65,"latency_ms_avg":234.708,"latency_ms_max":5016.821},"put_total":{"success":43328,"error":1097,"timeout":93,"latency_ms_avg":217.867,"latency_ms_max":5016.889},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"6":1,"14":12,"19":20,"23":3,"26":14},"consensus_reply_error_by_shard":{"0":43,"1":131,"2":1,"3":161,"4":6,"5":119,"7":1,"8":90,"12":175,"17":131,"22":123,"29":66},"put_total_by_shard":{"0":1724,"1":1888,"2":809,"3":2315,"4":947,"5":1641,"6":766,"7":722,"8":1854,"9":2234,"10":1441,"11":1576,"12":2037,"13":1830,"14":807,"15":749,"16":2220,"17":1899,"18":768,"19":682,"20":1704,"21":717,"22":2176,"23":930,"24":912,"25":2212,"26":812,"27":707,"28":2078,"29":1732,"30":753,"31":783},"put_timeout_by_shard":{"2":1,"4":6,"5":22,"6":1,"7":1,"8":2,"12":15,"14":10,"17":17,"19":6,"22":1,"26":11},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":65,"consensus_reply:STATUS_CODE_UNAVAILABLE/cause=BACKPRESSURE":977,"consensus_reply:STATUS_CODE_UNAVAILABLE/cause=CONSENSUS_INFLIGHT_LIMIT":5,"forward:STATUS_CODE_TIMEOUT/grpc=DEADLINE_EXCEEDED":28,"forward:STATUS_CODE_UNAVAILABLE":22,"put_total:STATUS_CODE_TIMEOUT":65,"put_total:STATUS_CODE_TIMEOUT/grpc=DEADLINE_EXCEEDED":28,"put_total:STATUS_CODE_UNAVAILABLE":22,"put_total:STATUS_CODE_UNAVAILABLE/cause=BACKPRESSURE":977,"put_total:STATUS_CODE_UNAVAILABLE/cause=CONSENSUS_INFLIGHT_LIMIT":5}}`
- `notdynamo-data-1`: `{"node":"notdynamo-data-1","observed_leader_override_writes":23139,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":0,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"observed_leader_snapshot_refresh_failures":0,"write_backpressure_rejections":0,"write_backpressure_rejections_by_shard":{},"write_admission_wait_exhausted_count":0,"write_inflight_limit":256,"write_shard_inflight_min":8,"write_shard_inflight_limit":-1,"write_inflight_current":0,"consensus_reject_due_to_inflight_limit":0,"consensus_reject_due_to_inflight_limit_by_shard":{},"consensus_inflight_by_shard":{},"write_total_requests":29027,"write_forwarded_requests":29027,"forward_hop_ratio":1.000000,"forward_to_leader":{"success":28455,"error":559,"timeout":53,"latency_ms_avg":181.510,"latency_ms_max":5058.866},"consensus_submit":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"put_total":{"success":28455,"error":559,"timeout":53,"latency_ms_avg":181.554,"latency_ms_max":5099.393},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":18,"1":69,"3":55,"5":64,"8":45,"12":70,"14":9,"17":70,"19":48,"21":2,"22":72,"23":3,"26":4,"29":29,"30":1},"consensus_reply_error_by_shard":{},"put_total_by_shard":{"0":818,"1":885,"2":821,"3":842,"4":1005,"5":766,"6":808,"7":794,"8":888,"9":840,"10":665,"11":731,"12":735,"13":891,"14":892,"15":744,"16":1325,"17":890,"18":803,"19":1212,"20":787,"21":735,"22":1229,"23":884,"24":937,"25":1285,"26":757,"27":777,"28":1194,"29":821,"30":804,"31":1449},"put_timeout_by_shard":{"5":12,"12":7,"14":5,"17":8,"19":16,"22":1,"26":3,"29":1},"error_code_counts":{"forward:STATUS_CODE_INTERNAL/grpc=CANCELLED":3,"forward:STATUS_CODE_TIMEOUT/grpc=DEADLINE_EXCEEDED":53,"forward:STATUS_CODE_UNAVAILABLE":503,"put_total:STATUS_CODE_INTERNAL/grpc=CANCELLED":3,"put_total:STATUS_CODE_TIMEOUT/grpc=DEADLINE_EXCEEDED":53,"put_total:STATUS_CODE_UNAVAILABLE":503}}`
- `notdynamo-data-2`: `{"node":"notdynamo-data-2","observed_leader_override_writes":51717,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":0,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"observed_leader_snapshot_refresh_failures":0,"write_backpressure_rejections":52,"write_backpressure_rejections_by_shard":{"14":7,"19":30,"21":1,"23":11,"26":3},"write_admission_wait_exhausted_count":80,"write_inflight_limit":256,"write_shard_inflight_min":8,"write_shard_inflight_limit":17,"write_inflight_current":12,"consensus_reject_due_to_inflight_limit":28,"consensus_reject_due_to_inflight_limit_by_shard":{"2":19,"14":2,"19":2,"21":1,"23":2,"26":1,"30":1},"consensus_inflight_by_shard":{"0":1,"1":2,"7":1,"14":1,"15":1,"17":2,"21":1,"24":1,"30":1,"31":1},"write_total_requests":88164,"write_forwarded_requests":45416,"forward_hop_ratio":0.515131,"forward_to_leader":{"success":42934,"error":2469,"timeout":92,"latency_ms_avg":191.183,"latency_ms_max":5020.647},"consensus_submit":{"success":42668,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":42588,"error":149,"timeout":69,"latency_ms_avg":112.236,"latency_ms_max":5029.348},"put_total":{"success":85522,"error":2618,"timeout":161,"latency_ms_avg":152.954,"latency_ms_max":5029.412},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":13,"1":219,"3":292,"4":4,"5":1,"7":75,"8":69,"9":11,"10":24,"11":26,"12":98,"13":56,"14":354,"16":211,"17":381,"18":2,"19":4,"20":160,"21":185,"22":49,"23":34,"25":5,"26":17,"27":34,"28":54,"29":85,"31":6},"consensus_reply_error_by_shard":{"0":1,"2":20,"6":1,"8":3,"10":1,"11":1,"13":1,"14":26,"17":1,"19":54,"20":1,"21":2,"23":15,"26":20,"29":1,"30":1},"put_total_by_shard":{"0":1842,"1":2151,"2":4769,"3":2078,"4":4667,"5":2100,"6":2945,"7":2913,"8":2154,"9":2037,"10":1622,"11":1880,"12":1881,"13":2022,"14":4075,"15":4781,"16":2014,"17":2275,"18":2856,"19":3165,"20":2107,"21":2662,"22":2001,"23":4392,"24":3415,"25":1954,"26":3712,"27":2708,"28":1810,"29":2020,"30":3508,"31":3624},"put_timeout_by_shard":{"0":10,"1":10,"2":1,"3":5,"5":1,"6":1,"8":6,"9":5,"10":3,"11":4,"12":6,"13":2,"14":18,"16":8,"17":3,"19":24,"20":17,"22":6,"23":2,"25":4,"26":20,"28":3,"29":2},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":69,"consensus_reply:STATUS_CODE_UNAVAILABLE/cause=BACKPRESSURE":52,"consensus_reply:STATUS_CODE_UNAVAILABLE/cause=CONSENSUS_INFLIGHT_LIMIT":28,"forward:STATUS_CODE_INTERNAL/grpc=CANCELLED":2,"forward:STATUS_CODE_TIMEOUT/grpc=DEADLINE_EXCEEDED":92,"forward:STATUS_CODE_UNAVAILABLE":2363,"forward:STATUS_CODE_UNAVAILABLE/grpc=UNAVAILABLE":12,"put_total:STATUS_CODE_INTERNAL/grpc=CANCELLED":2,"put_total:STATUS_CODE_TIMEOUT":69,"put_total:STATUS_CODE_TIMEOUT/grpc=DEADLINE_EXCEEDED":92,"put_total:STATUS_CODE_UNAVAILABLE":2363,"put_total:STATUS_CODE_UNAVAILABLE/cause=BACKPRESSURE":52,"put_total:STATUS_CODE_UNAVAILABLE/cause=CONSENSUS_INFLIGHT_LIMIT":28,"put_total:STATUS_CODE_UNAVAILABLE/grpc=UNAVAILABLE":12}}`

## Artifacts

- JSON report: `reports/benchmarks/aws/e2e_http_incluster_k6_20260221T130042Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221130042`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221130042/job.yaml`
- Script configmap: `notdynamo-bench-k6-script-20260221130042`
- Pod placement snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221130042/pod_placement.txt`
- Pods top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221130042/telemetry/pods_top_snapshot.txt`
- Nodes top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221130042/telemetry/nodes_top_snapshot.txt`
- Generator top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221130042/telemetry/bench_top_summary.txt`
- Service top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221130042/telemetry/data_top_summary.txt`
- Nodes top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221130042/telemetry/nodes_top_summary.txt`
- Write-stage telemetry samples: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221130042/telemetry/write_stage_telemetry_samples.txt`
