# NotDynamo E2E HTTP In-Cluster Benchmark Report (k6)

- Status: **WARN**
- Timestamp (UTC): 2026-02-21T12:50:38Z
- Category: `in-cluster-job`
- Driver: `k6`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-k6-20260221124853`

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
| Effective operations | 32868 |
| Aggregate throughput (rps) | 362.38 |
| Aggregate success throughput (rps) | 338.23 |
| Max pod p50 latency (ms) | 77.599 |
| Max pod p95 latency (ms) | 1219.971 |
| Max pod p99 latency (ms) | 3670.875 |
| Success count | 30678 |
| Error count | 2190 |
| Error rate (%) | 6.6630 |
| Read count | 3219 |
| Write count | 29649 |
| Read not found count | 1773 |
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
| Generator CPU mcores sum | 249.000 |
| Generator CPU mcores avg | 83.000 |
| Service pod count (sampled) | 3 |
| Service CPU mcores sum | 2458.000 |
| Service CPU mcores avg | 819.333 |
| Generator/Service CPU ratio | 0.101 |
| Attribution hint | service-pressure-dominant |
| Attribution reason | data pod CPU sum is >= 1.5x benchmark pod CPU sum during sample window |
| Cluster node count (sampled) | 3 |
| Cluster CPU percent max | 58.000 |
| Cluster memory percent max | 18.000 |
| Write-stage telemetry samples | 3 |

## Write-Stage Telemetry Samples

- `notdynamo-data-0`: `{"node":"notdynamo-data-0","observed_leader_override_writes":5483,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":0,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"observed_leader_snapshot_refresh_failures":0,"write_backpressure_rejections":0,"write_backpressure_rejections_by_shard":{},"write_admission_wait_exhausted_count":25,"write_inflight_limit":256,"write_shard_inflight_min":8,"write_shard_inflight_limit":28,"write_inflight_current":11,"consensus_reject_due_to_inflight_limit":25,"consensus_reject_due_to_inflight_limit_by_shard":{"4":7,"19":6,"26":12},"consensus_inflight_by_shard":{"1":7,"2":1,"3":2,"30":1},"write_total_requests":12274,"write_forwarded_requests":2827,"forward_hop_ratio":0.230324,"forward_to_leader":{"success":2546,"error":276,"timeout":9,"latency_ms_avg":292.353,"latency_ms_max":5004.971},"consensus_submit":{"success":9422,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":9362,"error":75,"timeout":50,"latency_ms_avg":133.172,"latency_ms_max":5018.851},"put_total":{"success":11907,"error":351,"timeout":59,"latency_ms_avg":169.890,"latency_ms_max":5018.951},"delete_total":{"success":1,"error":0,"timeout":0,"latency_ms_avg":70.064,"latency_ms_max":70.064},"forward_error_by_shard":{"1":1,"3":24,"8":1,"13":3,"14":88,"16":1,"17":97,"20":39,"21":19,"28":3},"consensus_reply_error_by_shard":{"0":8,"1":13,"3":1,"4":11,"9":2,"12":1,"19":16,"26":23},"put_total_by_shard":{"0":185,"1":174,"2":974,"3":171,"4":1064,"5":946,"6":908,"7":180,"8":167,"9":177,"10":137,"11":146,"12":188,"13":191,"14":199,"15":200,"16":170,"17":163,"18":162,"19":620,"20":195,"21":176,"22":172,"23":1050,"24":1011,"25":172,"26":898,"27":131,"28":169,"29":145,"30":842,"31":175},"put_timeout_by_shard":{"0":8,"1":13,"3":1,"4":4,"9":2,"12":1,"14":2,"19":10,"20":7,"26":11},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":50,"consensus_reply:STATUS_CODE_UNAVAILABLE/cause=CONSENSUS_INFLIGHT_LIMIT":25,"forward:STATUS_CODE_TIMEOUT/grpc=DEADLINE_EXCEEDED":9,"forward:STATUS_CODE_UNAVAILABLE":267,"put_total:STATUS_CODE_TIMEOUT":50,"put_total:STATUS_CODE_TIMEOUT/grpc=DEADLINE_EXCEEDED":9,"put_total:STATUS_CODE_UNAVAILABLE":267,"put_total:STATUS_CODE_UNAVAILABLE/cause=CONSENSUS_INFLIGHT_LIMIT":25}}`
- `notdynamo-data-1`: `{"node":"notdynamo-data-1","observed_leader_override_writes":12712,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":0,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"observed_leader_snapshot_refresh_failures":0,"write_backpressure_rejections":2087,"write_backpressure_rejections_by_shard":{"1":18,"3":435,"7":4,"8":5,"9":3,"10":1,"11":8,"12":3,"13":18,"14":486,"16":7,"17":600,"20":132,"21":351,"27":2,"28":10,"29":4},"write_admission_wait_exhausted_count":2092,"write_inflight_limit":256,"write_shard_inflight_min":8,"write_shard_inflight_limit":11,"write_inflight_current":47,"consensus_reject_due_to_inflight_limit":5,"consensus_reject_due_to_inflight_limit_by_shard":{"3":5},"consensus_inflight_by_shard":{"1":1,"3":11,"10":6,"11":7,"14":11,"16":2,"17":5,"21":3,"29":1},"write_total_requests":22271,"write_forwarded_requests":3007,"forward_hop_ratio":0.135019,"forward_to_leader":{"success":2986,"error":20,"timeout":11,"latency_ms_avg":60.980,"latency_ms_max":5365.130},"consensus_submit":{"success":17172,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":17108,"error":2110,"timeout":18,"latency_ms_avg":290.561,"latency_ms_max":5061.392},"put_total":{"success":20093,"error":2130,"timeout":29,"latency_ms_avg":259.778,"latency_ms_max":5365.325},"delete_total":{"success":1,"error":0,"timeout":0,"latency_ms_avg":49.294,"latency_ms_max":49.294},"forward_error_by_shard":{"4":5,"19":7,"26":8},"consensus_reply_error_by_shard":{"1":18,"3":440,"7":4,"8":5,"9":3,"10":1,"11":8,"12":3,"13":18,"14":488,"16":7,"17":600,"20":148,"21":351,"27":2,"28":10,"29":4},"put_total_by_shard":{"0":700,"1":900,"2":347,"3":820,"4":419,"5":330,"6":320,"7":835,"8":972,"9":767,"10":749,"11":805,"12":784,"13":943,"14":1022,"15":312,"16":947,"17":953,"18":748,"19":322,"20":949,"21":696,"22":964,"23":357,"24":341,"25":912,"26":315,"27":686,"28":906,"29":896,"30":278,"31":928},"put_timeout_by_shard":{"4":4,"14":2,"19":4,"20":16,"26":3},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":18,"consensus_reply:STATUS_CODE_UNAVAILABLE/cause=BACKPRESSURE":2087,"consensus_reply:STATUS_CODE_UNAVAILABLE/cause=CONSENSUS_INFLIGHT_LIMIT":5,"forward:STATUS_CODE_TIMEOUT/grpc=DEADLINE_EXCEEDED":11,"forward:STATUS_CODE_UNAVAILABLE":9,"put_total:STATUS_CODE_TIMEOUT":18,"put_total:STATUS_CODE_TIMEOUT/grpc=DEADLINE_EXCEEDED":11,"put_total:STATUS_CODE_UNAVAILABLE":9,"put_total:STATUS_CODE_UNAVAILABLE/cause=BACKPRESSURE":2087,"put_total:STATUS_CODE_UNAVAILABLE/cause=CONSENSUS_INFLIGHT_LIMIT":5}}`
- `notdynamo-data-2`: `{"node":"notdynamo-data-2","observed_leader_override_writes":10338,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":0,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"observed_leader_snapshot_refresh_failures":0,"write_backpressure_rejections":0,"write_backpressure_rejections_by_shard":{},"write_admission_wait_exhausted_count":0,"write_inflight_limit":256,"write_shard_inflight_min":8,"write_shard_inflight_limit":256,"write_inflight_current":0,"consensus_reject_due_to_inflight_limit":0,"consensus_reject_due_to_inflight_limit_by_shard":{},"consensus_inflight_by_shard":{},"write_total_requests":14966,"write_forwarded_requests":14153,"forward_hop_ratio":0.945677,"forward_to_leader":{"success":12907,"error":1209,"timeout":19,"latency_ms_avg":232.768,"latency_ms_max":5008.889},"consensus_submit":{"success":813,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":813,"error":0,"timeout":0,"latency_ms_avg":14.948,"latency_ms_max":414.467},"put_total":{"success":13720,"error":1209,"timeout":19,"latency_ms_avg":221.014,"latency_ms_max":5008.919},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"1":3,"3":229,"4":4,"7":3,"8":3,"9":2,"10":1,"11":2,"12":2,"13":9,"14":293,"16":4,"17":347,"19":4,"20":106,"21":177,"26":14,"27":2,"28":4},"consensus_reply_error_by_shard":{},"put_total_by_shard":{"0":368,"1":422,"2":650,"3":415,"4":504,"5":623,"6":392,"7":418,"8":555,"9":414,"10":304,"11":457,"12":415,"13":408,"14":587,"15":813,"16":411,"17":549,"18":384,"19":337,"20":562,"21":358,"22":423,"23":672,"24":452,"25":416,"26":607,"27":343,"28":389,"29":499,"30":370,"31":412},"put_timeout_by_shard":{"14":1,"19":2,"20":12,"26":4},"error_code_counts":{"forward:STATUS_CODE_INTERNAL/grpc=CANCELLED":1,"forward:STATUS_CODE_TIMEOUT/grpc=DEADLINE_EXCEEDED":19,"forward:STATUS_CODE_UNAVAILABLE":1189,"put_total:STATUS_CODE_INTERNAL/grpc=CANCELLED":1,"put_total:STATUS_CODE_TIMEOUT/grpc=DEADLINE_EXCEEDED":19,"put_total:STATUS_CODE_UNAVAILABLE":1189}}`

## Artifacts

- JSON report: `reports/benchmarks/aws/e2e_http_incluster_k6_20260221T124853Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221124853`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221124853/job.yaml`
- Script configmap: `notdynamo-bench-k6-script-20260221124853`
- Pod placement snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221124853/pod_placement.txt`
- Pods top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221124853/telemetry/pods_top_snapshot.txt`
- Nodes top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221124853/telemetry/nodes_top_snapshot.txt`
- Generator top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221124853/telemetry/bench_top_summary.txt`
- Service top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221124853/telemetry/data_top_summary.txt`
- Nodes top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221124853/telemetry/nodes_top_summary.txt`
- Write-stage telemetry samples: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221124853/telemetry/write_stage_telemetry_samples.txt`
