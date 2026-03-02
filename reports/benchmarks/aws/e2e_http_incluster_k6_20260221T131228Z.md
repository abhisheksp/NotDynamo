# NotDynamo E2E HTTP In-Cluster Benchmark Report (k6)

- Status: **WARN**
- Timestamp (UTC): 2026-02-21T13:14:14Z
- Category: `in-cluster-job`
- Driver: `k6`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-k6-20260221131228`

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
| Effective operations | 23125 |
| Aggregate throughput (rps) | 244.91 |
| Aggregate success throughput (rps) | 236.32 |
| Max pod p50 latency (ms) | 69.943 |
| Max pod p95 latency (ms) | 1439.451 |
| Max pod p99 latency (ms) | 5000.706 |
| Success count | 22313 |
| Error count | 812 |
| Error rate (%) | 3.5114 |
| Read count | 2291 |
| Write count | 20834 |
| Read not found count | 0 |
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
| Generator CPU mcores sum | 304.000 |
| Generator CPU mcores avg | 101.333 |
| Service pod count (sampled) | 3 |
| Service CPU mcores sum | 2535.000 |
| Service CPU mcores avg | 845.000 |
| Generator/Service CPU ratio | 0.120 |
| Attribution hint | service-pressure-dominant |
| Attribution reason | data pod CPU sum is >= 1.5x benchmark pod CPU sum during sample window |
| Cluster node count (sampled) | 3 |
| Cluster CPU percent max | 57.000 |
| Cluster memory percent max | 29.000 |
| Write-stage telemetry samples | 3 |

## Write-Stage Telemetry Samples

- `notdynamo-data-0`: `{"node":"notdynamo-data-0","observed_leader_override_writes":35903,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":0,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"observed_leader_snapshot_refresh_failures":0,"write_backpressure_rejections":984,"write_backpressure_rejections_by_shard":{"0":43,"1":130,"2":1,"3":158,"5":97,"8":88,"12":160,"17":114,"22":121,"24":2,"27":4,"29":66},"write_admission_wait_exhausted_count":995,"write_inflight_limit":256,"write_shard_inflight_min":8,"write_shard_inflight_limit":128,"write_inflight_current":0,"consensus_reject_due_to_inflight_limit":11,"consensus_reject_due_to_inflight_limit_by_shard":{"1":1,"3":3,"15":1,"22":6},"consensus_inflight_by_shard":{},"write_total_requests":59212,"write_forwarded_requests":14099,"forward_hop_ratio":0.238111,"forward_to_leader":{"success":11442,"error":2634,"timeout":1035,"latency_ms_avg":1104.820,"latency_ms_max":5051.691},"consensus_submit":{"success":44118,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":43754,"error":1359,"timeout":364,"latency_ms_avg":252.586,"latency_ms_max":5016.821},"put_total":{"success":55196,"error":3993,"timeout":1399,"latency_ms_avg":455.332,"latency_ms_max":5051.767},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":174,"1":24,"2":114,"3":15,"4":10,"5":190,"6":161,"7":24,"8":210,"9":10,"10":147,"11":37,"12":35,"13":256,"14":147,"15":15,"16":55,"17":120,"18":25,"19":36,"20":27,"21":14,"22":272,"23":31,"24":30,"25":30,"26":36,"27":222,"28":29,"29":4,"30":93,"31":41},"consensus_reply_error_by_shard":{"0":43,"1":133,"2":7,"3":192,"4":26,"5":120,"6":9,"7":7,"8":94,"9":5,"10":1,"12":194,"13":1,"14":4,"15":26,"16":3,"17":134,"18":26,"19":1,"20":2,"21":40,"22":148,"23":3,"24":26,"26":1,"27":23,"28":1,"29":72,"30":12,"31":5},"put_total_by_shard":{"0":2099,"1":2622,"2":1631,"3":2617,"4":1352,"5":2051,"6":1096,"7":1075,"8":2281,"9":2508,"10":1767,"11":1794,"12":2358,"13":2321,"14":1406,"15":1481,"16":2509,"17":2731,"18":1033,"19":892,"20":1922,"21":1391,"22":3113,"23":1213,"24":1212,"25":2452,"26":1053,"27":1510,"28":2311,"29":2391,"30":1540,"31":1457},"put_timeout_by_shard":{"0":61,"1":26,"2":36,"3":43,"4":34,"5":71,"6":90,"7":29,"8":34,"9":15,"10":39,"11":10,"12":60,"13":81,"14":106,"15":37,"16":40,"17":39,"18":31,"19":23,"20":27,"21":50,"22":95,"23":28,"24":41,"25":28,"26":21,"27":96,"28":18,"29":10,"30":52,"31":28},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":364,"consensus_reply:STATUS_CODE_UNAVAILABLE/cause=BACKPRESSURE":984,"consensus_reply:STATUS_CODE_UNAVAILABLE/cause=CONSENSUS_INFLIGHT_LIMIT":11,"forward:STATUS_CODE_INTERNAL/grpc=CANCELLED":1432,"forward:STATUS_CODE_TIMEOUT":1,"forward:STATUS_CODE_TIMEOUT/grpc=DEADLINE_EXCEEDED":1034,"forward:STATUS_CODE_UNAVAILABLE":152,"forward:STATUS_CODE_UNAVAILABLE/grpc=UNAVAILABLE":15,"put_total:STATUS_CODE_INTERNAL/grpc=CANCELLED":1432,"put_total:STATUS_CODE_TIMEOUT":365,"put_total:STATUS_CODE_TIMEOUT/grpc=DEADLINE_EXCEEDED":1034,"put_total:STATUS_CODE_UNAVAILABLE":152,"put_total:STATUS_CODE_UNAVAILABLE/cause=BACKPRESSURE":984,"put_total:STATUS_CODE_UNAVAILABLE/cause=CONSENSUS_INFLIGHT_LIMIT":11,"put_total:STATUS_CODE_UNAVAILABLE/grpc=UNAVAILABLE":15}}`
- `notdynamo-data-1`: `{"node":"notdynamo-data-1","observed_leader_override_writes":9527,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":0,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"observed_leader_snapshot_refresh_failures":0,"write_backpressure_rejections":0,"write_backpressure_rejections_by_shard":{},"write_admission_wait_exhausted_count":9,"write_inflight_limit":256,"write_shard_inflight_min":8,"write_shard_inflight_limit":23,"write_inflight_current":49,"consensus_reject_due_to_inflight_limit":9,"consensus_reject_due_to_inflight_limit_by_shard":{"6":1,"12":2,"22":5,"25":1},"consensus_inflight_by_shard":{"6":14,"12":13,"22":14},"write_total_requests":16173,"write_forwarded_requests":10788,"forward_hop_ratio":0.667038,"forward_to_leader":{"success":8813,"error":1970,"timeout":682,"latency_ms_avg":1213.130,"latency_ms_max":5048.048},"consensus_submit":{"success":5376,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":4897,"error":440,"timeout":431,"latency_ms_avg":611.328,"latency_ms_max":5071.196},"put_total":{"success":13710,"error":2410,"timeout":1113,"latency_ms_avg":1013.962,"latency_ms_max":5071.282},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":137,"1":50,"2":107,"3":21,"4":18,"5":9,"6":110,"7":16,"8":43,"9":5,"10":8,"11":104,"12":28,"13":10,"14":128,"15":23,"16":16,"17":42,"18":28,"19":38,"20":15,"21":12,"22":278,"23":78,"24":31,"25":144,"26":246,"27":12,"28":113,"29":8,"30":70,"31":22},"consensus_reply_error_by_shard":{"0":36,"1":36,"2":3,"3":1,"4":3,"5":2,"6":51,"8":2,"9":10,"10":2,"12":26,"13":10,"14":1,"15":4,"16":41,"17":5,"18":6,"19":22,"20":6,"21":1,"22":32,"23":2,"24":1,"25":52,"28":41,"29":2,"31":42},"put_total_by_shard":{"0":509,"1":549,"2":572,"3":793,"4":899,"5":382,"6":527,"7":452,"8":400,"9":357,"10":343,"11":379,"12":789,"13":790,"14":492,"15":332,"16":457,"17":460,"18":391,"19":772,"20":462,"21":358,"22":671,"23":467,"24":374,"25":597,"26":595,"27":309,"28":448,"29":347,"30":425,"31":422},"put_timeout_by_shard":{"0":75,"1":47,"2":26,"3":22,"4":15,"5":7,"6":92,"7":15,"8":34,"9":15,"10":8,"11":18,"12":48,"13":19,"14":21,"15":25,"16":45,"17":22,"18":17,"19":32,"20":21,"21":13,"22":107,"23":32,"24":15,"25":118,"26":16,"27":7,"28":107,"29":6,"30":23,"31":45},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":431,"consensus_reply:STATUS_CODE_UNAVAILABLE/cause=CONSENSUS_INFLIGHT_LIMIT":9,"forward:STATUS_CODE_INTERNAL/grpc=CANCELLED":1140,"forward:STATUS_CODE_TIMEOUT":1,"forward:STATUS_CODE_TIMEOUT/grpc=DEADLINE_EXCEEDED":681,"forward:STATUS_CODE_UNAVAILABLE":148,"put_total:STATUS_CODE_INTERNAL/grpc=CANCELLED":1140,"put_total:STATUS_CODE_TIMEOUT":432,"put_total:STATUS_CODE_TIMEOUT/grpc=DEADLINE_EXCEEDED":681,"put_total:STATUS_CODE_UNAVAILABLE":148,"put_total:STATUS_CODE_UNAVAILABLE/cause=CONSENSUS_INFLIGHT_LIMIT":9}}`
- `notdynamo-data-2`: `{"node":"notdynamo-data-2","observed_leader_override_writes":11671,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":0,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"observed_leader_snapshot_refresh_failures":0,"write_backpressure_rejections":405,"write_backpressure_rejections_by_shard":{"1":4,"2":4,"4":11,"5":16,"6":7,"7":1,"8":45,"10":8,"11":67,"12":8,"13":1,"15":4,"16":40,"18":52,"20":3,"23":12,"24":37,"25":5,"26":31,"27":3,"28":37,"29":9},"write_admission_wait_exhausted_count":406,"write_inflight_limit":256,"write_shard_inflight_min":8,"write_shard_inflight_limit":14,"write_inflight_current":17,"consensus_reject_due_to_inflight_limit":1,"consensus_reject_due_to_inflight_limit_by_shard":{"23":1},"consensus_inflight_by_shard":{"9":2,"11":4,"13":6,"23":2,"24":2},"write_total_requests":21110,"write_forwarded_requests":6564,"forward_hop_ratio":0.310943,"forward_to_leader":{"success":4270,"error":2279,"timeout":767,"latency_ms_avg":2000.568,"latency_ms_max":5276.897},"consensus_submit":{"success":14140,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":13497,"error":1033,"timeout":627,"latency_ms_avg":620.881,"latency_ms_max":5034.789},"put_total":{"success":17767,"error":3312,"timeout":1394,"latency_ms_avg":1049.657,"latency_ms_max":5338.122},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":31,"1":50,"2":2,"3":17,"4":9,"5":175,"6":24,"7":10,"8":178,"9":4,"10":132,"11":76,"12":15,"13":234,"14":229,"15":13,"16":9,"17":141,"18":20,"19":45,"21":25,"22":18,"23":53,"24":17,"25":147,"26":224,"27":227,"28":112,"30":28,"31":14},"consensus_reply_error_by_shard":{"0":30,"1":18,"2":10,"3":1,"4":14,"5":26,"6":60,"7":38,"8":104,"9":6,"10":21,"11":88,"12":16,"13":29,"14":56,"15":7,"16":78,"17":32,"18":57,"19":4,"20":47,"22":10,"23":67,"24":57,"25":32,"26":48,"27":10,"28":39,"29":19,"30":8,"31":1},"put_total_by_shard":{"0":818,"1":399,"2":466,"3":319,"4":457,"5":968,"6":679,"7":809,"8":1039,"9":775,"10":767,"11":809,"12":358,"13":654,"14":1176,"15":366,"16":725,"17":608,"18":781,"19":390,"20":811,"21":327,"22":369,"23":1001,"24":848,"25":881,"26":1052,"27":554,"28":795,"29":431,"30":290,"31":357},"put_timeout_by_shard":{"0":50,"1":25,"2":7,"3":18,"4":12,"5":46,"6":75,"7":47,"8":71,"9":10,"10":44,"11":32,"12":23,"13":93,"14":139,"15":15,"16":47,"17":48,"18":25,"19":19,"20":44,"21":25,"22":24,"23":64,"24":37,"25":100,"26":22,"27":92,"28":81,"29":10,"30":34,"31":15},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":627,"consensus_reply:STATUS_CODE_UNAVAILABLE/cause=BACKPRESSURE":405,"consensus_reply:STATUS_CODE_UNAVAILABLE/cause=CONSENSUS_INFLIGHT_LIMIT":1,"forward:STATUS_CODE_INTERNAL/grpc=CANCELLED":1502,"forward:STATUS_CODE_TIMEOUT/grpc=DEADLINE_EXCEEDED":767,"forward:STATUS_CODE_UNAVAILABLE":8,"forward:STATUS_CODE_UNAVAILABLE/grpc=UNAVAILABLE":2,"put_total:STATUS_CODE_INTERNAL/grpc=CANCELLED":1502,"put_total:STATUS_CODE_TIMEOUT":627,"put_total:STATUS_CODE_TIMEOUT/grpc=DEADLINE_EXCEEDED":767,"put_total:STATUS_CODE_UNAVAILABLE":8,"put_total:STATUS_CODE_UNAVAILABLE/cause=BACKPRESSURE":405,"put_total:STATUS_CODE_UNAVAILABLE/cause=CONSENSUS_INFLIGHT_LIMIT":1,"put_total:STATUS_CODE_UNAVAILABLE/grpc=UNAVAILABLE":2}}`

## Artifacts

- JSON report: `reports/benchmarks/aws/e2e_http_incluster_k6_20260221T131228Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221131228`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221131228/job.yaml`
- Script configmap: `notdynamo-bench-k6-script-20260221131228`
- Pod placement snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221131228/pod_placement.txt`
- Pods top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221131228/telemetry/pods_top_snapshot.txt`
- Nodes top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221131228/telemetry/nodes_top_snapshot.txt`
- Generator top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221131228/telemetry/bench_top_summary.txt`
- Service top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221131228/telemetry/data_top_summary.txt`
- Nodes top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221131228/telemetry/nodes_top_summary.txt`
- Write-stage telemetry samples: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221131228/telemetry/write_stage_telemetry_samples.txt`
