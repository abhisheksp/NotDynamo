# NotDynamo E2E HTTP In-Cluster Benchmark Report (k6)

- Status: **WARN**
- Timestamp (UTC): 2026-02-20T12:51:16Z
- Category: `in-cluster-job`
- Driver: `k6`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-k6-20260220124921`

## Configuration

| Field | Value |
|---|---|
| Parallelism | 11 |
| Completions | 11 |
| Benchmark node label | notdynamo.io/workload=benchmark |
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
| Effective operations | 16261 |
| Aggregate throughput (rps) | 171.94 |
| Aggregate success throughput (rps) | 105.21 |
| Max pod p50 latency (ms) | 69.795 |
| Max pod p95 latency (ms) | 5001.068 |
| Max pod p99 latency (ms) | 5001.465 |
| Success count | 9950 |
| Error count | 6311 |
| Error rate (%) | 38.8107 |
| Read count | 1626 |
| Write count | 14635 |
| Read not found count | 709 |
| Preload attempted | 0 |
| Preload success | 0 |
| Preload failed | 0 |
| Job completed | true |
| Pod count | 11 |
| Pod metric failures | 0 |

## Telemetry Summary

| Signal | Value |
|---|---|
| Sample attempts (used/configured) | 15 / 15 |
| Pods top available | true |
| Nodes top available | true |
| Generator pod count (sampled) | 11 |
| Generator CPU mcores sum | 207.000 |
| Generator CPU mcores avg | 18.818 |
| Service pod count (sampled) | 11 |
| Service CPU mcores sum | 9700.000 |
| Service CPU mcores avg | 881.818 |
| Generator/Service CPU ratio | 0.021 |
| Attribution hint | service-pressure-dominant |
| Attribution reason | data pod CPU sum is >= 1.5x benchmark pod CPU sum during sample window |
| Cluster node count (sampled) | 14 |
| Cluster CPU percent max | 87.000 |
| Cluster memory percent max | 76.000 |
| Write-stage telemetry samples | 11 |

## Write-Stage Telemetry Samples

- `notdynamo-data-0`: `{"node":"notdynamo-data-0","observed_leader_override_writes":71,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":970,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"forward_to_leader":{"success":746,"error":483,"timeout":483,"latency_ms_avg":2032.197,"latency_ms_max":5328.698},"consensus_submit":{"success":1339,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":0,"error":1109,"timeout":1109,"latency_ms_avg":5009.114,"latency_ms_max":6377.166},"put_total":{"success":746,"error":1592,"timeout":1592,"latency_ms_avg":3444.468,"latency_ms_max":6392.702},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"1":9,"2":10,"9":11,"10":11,"12":9,"13":2,"20":7,"21":11,"23":11,"24":12,"31":5,"32":8,"34":13,"35":7,"42":5,"43":16,"45":6,"46":16,"53":10,"54":10,"55":36,"56":9,"57":9,"64":3,"65":10,"67":14,"68":3,"75":10,"76":7,"78":10,"79":11,"86":13,"87":19,"89":14,"90":10,"97":4,"98":12,"100":7,"101":12,"108":12,"109":6,"111":10,"112":14,"119":12,"120":7,"122":11,"123":9},"consensus_reply_error_by_shard":{"0":99,"11":99,"22":99,"33":99,"44":99,"55":87,"66":83,"77":99,"88":88,"99":86,"110":99,"121":72},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":1109,"forward:STATUS_CODE_TIMEOUT":483,"put_total:STATUS_CODE_TIMEOUT":1592}}`
- `notdynamo-data-1`: `{"node":"notdynamo-data-1","observed_leader_override_writes":38,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":962,"observed_leader_override_retry_attempts":29,"observed_leader_override_retry_success":0,"forward_to_leader":{"success":752,"error":460,"timeout":433,"latency_ms_avg":1920.639,"latency_ms_max":5108.430},"consensus_submit":{"success":1363,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":0,"error":1185,"timeout":1185,"latency_ms_avg":5002.560,"latency_ms_max":5363.983},"put_total":{"success":752,"error":1645,"timeout":1618,"latency_ms_avg":3444.314,"latency_ms_max":5364.136},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":11,"2":12,"9":11,"10":9,"11":17,"13":4,"20":5,"21":10,"22":13,"24":11,"31":5,"32":9,"33":12,"35":11,"42":13,"43":8,"44":8,"46":8,"53":11,"54":8,"55":7,"57":8,"64":3,"65":8,"66":7,"68":4,"75":11,"76":13,"77":10,"78":36,"79":5,"86":6,"87":16,"88":6,"90":8,"97":9,"98":12,"99":10,"101":11,"108":10,"109":9,"110":9,"112":8,"119":11,"120":6,"121":6,"123":15},"consensus_reply_error_by_shard":{"1":99,"12":99,"23":99,"34":99,"45":95,"56":99,"67":99,"78":98,"88":1,"89":99,"100":99,"109":1,"111":99,"122":99},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":1185,"forward:STATUS_CODE_INTERNAL":27,"forward:STATUS_CODE_TIMEOUT":433,"put_total:STATUS_CODE_INTERNAL":27,"put_total:STATUS_CODE_TIMEOUT":1618}}`
- `notdynamo-data-10`: `{"node":"notdynamo-data-10","observed_leader_override_writes":1753,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":898,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"forward_to_leader":{"success":727,"error":482,"timeout":407,"latency_ms_avg":2067.066,"latency_ms_max":5107.426},"consensus_submit":{"success":3031,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":1347,"error":1445,"timeout":1445,"latency_ms_avg":2596.752,"latency_ms_max":5097.542},"put_total":{"success":2074,"error":1927,"timeout":1852,"latency_ms_avg":2436.820,"latency_ms_max":5252.341},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":10,"1":12,"2":7,"9":3,"11":12,"12":14,"13":7,"20":4,"22":13,"23":5,"24":13,"33":9,"34":9,"35":10,"42":12,"44":8,"45":8,"46":7,"53":38,"55":5,"56":7,"57":10,"64":7,"66":6,"67":12,"68":7,"75":7,"77":11,"78":11,"79":4,"86":3,"88":8,"89":5,"90":12,"97":47,"99":7,"100":9,"101":12,"108":7,"110":11,"111":11,"112":10,"119":28,"121":5,"122":11,"123":8},"consensus_reply_error_by_shard":{"10":94,"20":23,"21":99,"31":47,"32":99,"42":49,"43":99,"53":26,"54":99,"64":1,"65":96,"75":32,"76":99,"86":47,"87":99,"97":49,"98":93,"108":73,"109":99,"119":44,"120":78},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":1445,"forward:STATUS_CODE_INTERNAL":75,"forward:STATUS_CODE_TIMEOUT":407,"put_total:STATUS_CODE_INTERNAL":75,"put_total:STATUS_CODE_TIMEOUT":1852}}`
- `notdynamo-data-2`: `{"node":"notdynamo-data-2","observed_leader_override_writes":1100,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":997,"observed_leader_override_retry_attempts":345,"observed_leader_override_retry_success":0,"forward_to_leader":{"success":847,"error":1491,"timeout":1117,"latency_ms_avg":3192.898,"latency_ms_max":5196.375},"consensus_submit":{"success":117,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":2,"error":86,"timeout":86,"latency_ms_avg":4918.326,"latency_ms_max":5970.266},"put_total":{"success":849,"error":1577,"timeout":1203,"latency_ms_avg":3255.537,"latency_ms_max":5970.378},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":4,"1":12,"2":95,"9":10,"10":8,"11":8,"12":11,"13":88,"20":5,"21":9,"22":9,"23":5,"24":86,"31":8,"32":13,"33":12,"34":11,"35":82,"42":4,"43":14,"44":8,"45":10,"46":93,"53":10,"54":10,"55":46,"56":8,"57":76,"64":8,"65":14,"66":4,"67":9,"68":55,"75":12,"76":8,"77":22,"78":42,"79":55,"86":13,"87":10,"88":9,"89":7,"90":92,"97":4,"98":9,"99":9,"100":5,"101":98,"108":17,"109":11,"110":10,"111":12,"112":80,"119":7,"120":7,"121":8,"122":8,"123":91},"consensus_reply_error_by_shard":{"2":11,"13":3,"24":10,"35":6,"46":7,"57":6,"68":20,"90":3,"101":3,"112":11,"122":1,"123":5},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":86,"forward:STATUS_CODE_INTERNAL":374,"forward:STATUS_CODE_TIMEOUT":1117,"put_total:STATUS_CODE_INTERNAL":374,"put_total:STATUS_CODE_TIMEOUT":1203}}`
- `notdynamo-data-3`: `{"node":"notdynamo-data-3","observed_leader_override_writes":627,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":868,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"forward_to_leader":{"success":543,"error":539,"timeout":481,"latency_ms_avg":2492.265,"latency_ms_max":5052.425},"consensus_submit":{"success":1901,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":1396,"error":492,"timeout":492,"latency_ms_avg":1322.789,"latency_ms_max":5043.385},"put_total":{"success":1939,"error":1031,"timeout":973,"latency_ms_avg":1748.976,"latency_ms_max":5163.694},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":10,"1":9,"2":29,"9":7,"10":6,"11":16,"12":8,"13":41,"20":7,"21":11,"22":11,"23":13,"24":11,"31":10,"32":13,"33":11,"34":11,"35":5,"42":4,"43":10,"44":10,"45":4,"46":8,"53":6,"54":12,"55":9,"56":13,"57":6,"64":3,"65":6,"66":10,"67":9,"68":2,"75":12,"76":6,"77":11,"78":3,"79":3,"86":6,"87":5,"88":10,"89":14,"97":7,"98":9,"99":8,"100":11,"101":8,"108":10,"109":11,"110":12,"111":11,"112":1,"119":12,"120":13,"121":6,"122":9},"consensus_reply_error_by_shard":{"2":9,"13":60,"24":33,"35":46,"57":27,"68":41,"79":1,"90":83,"101":17,"112":76,"123":99},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":492,"forward:STATUS_CODE_INTERNAL":58,"forward:STATUS_CODE_TIMEOUT":481,"put_total:STATUS_CODE_INTERNAL":58,"put_total:STATUS_CODE_TIMEOUT":973}}`
- `notdynamo-data-4`: `{"node":"notdynamo-data-4","observed_leader_override_writes":1564,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":1020,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"forward_to_leader":{"success":1467,"error":528,"timeout":527,"latency_ms_avg":1344.126,"latency_ms_max":5155.961},"consensus_submit":{"success":1215,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":542,"error":628,"timeout":628,"latency_ms_avg":2702.150,"latency_ms_max":5137.144},"put_total":{"success":2009,"error":1156,"timeout":1155,"latency_ms_avg":1846.396,"latency_ms_max":5343.016},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":9,"1":7,"2":3,"9":10,"10":11,"11":13,"12":7,"13":9,"20":5,"21":8,"22":15,"23":16,"24":3,"31":5,"32":13,"33":7,"34":12,"35":2,"42":5,"43":11,"44":10,"45":11,"53":10,"54":15,"55":14,"56":12,"57":3,"64":5,"65":14,"66":11,"67":9,"68":6,"75":15,"76":11,"77":13,"78":11,"86":11,"87":16,"88":12,"89":14,"90":9,"97":5,"98":9,"99":5,"100":19,"101":1,"108":8,"109":9,"110":10,"111":9,"112":7,"119":5,"120":8,"121":8,"122":10,"123":12},"consensus_reply_error_by_shard":{"2":85,"13":2,"24":80,"35":49,"46":99,"57":75,"68":26,"79":67,"90":23,"101":99,"112":14,"123":9},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":628,"forward:STATUS_CODE_INTERNAL":1,"forward:STATUS_CODE_TIMEOUT":527,"put_total:STATUS_CODE_INTERNAL":1,"put_total:STATUS_CODE_TIMEOUT":1155}}`
- `notdynamo-data-5`: `{"node":"notdynamo-data-5","observed_leader_override_writes":974,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":904,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"forward_to_leader":{"success":1363,"error":514,"timeout":514,"latency_ms_avg":1385.679,"latency_ms_max":5093.591},"consensus_submit":{"success":602,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":602,"error":0,"timeout":0,"latency_ms_avg":9.144,"latency_ms_max":292.913},"put_total":{"success":1965,"error":514,"timeout":514,"latency_ms_avg":1051.520,"latency_ms_max":5164.333},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":9,"1":9,"2":8,"9":17,"10":8,"11":12,"12":7,"13":6,"20":6,"21":13,"22":7,"23":6,"24":7,"31":5,"32":9,"33":9,"34":5,"35":8,"42":9,"43":14,"44":14,"45":12,"46":10,"53":8,"54":17,"55":7,"56":10,"57":5,"64":2,"65":4,"66":12,"67":9,"68":7,"75":9,"76":12,"77":11,"78":8,"79":4,"86":9,"87":14,"88":8,"89":12,"90":11,"97":5,"98":5,"99":10,"100":9,"101":15,"108":7,"109":8,"110":7,"111":7,"112":7,"119":11,"120":5,"121":5,"122":10,"123":14},"consensus_reply_error_by_shard":{},"error_code_counts":{"forward:STATUS_CODE_TIMEOUT":514,"put_total:STATUS_CODE_TIMEOUT":514}}`
- `notdynamo-data-6`: `{"node":"notdynamo-data-6","observed_leader_override_writes":2487,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":978,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"forward_to_leader":{"success":1193,"error":568,"timeout":568,"latency_ms_avg":1647.798,"latency_ms_max":5103.614},"consensus_submit":{"success":2188,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":2188,"error":0,"timeout":0,"latency_ms_avg":8.809,"latency_ms_max":428.992},"put_total":{"success":3381,"error":568,"timeout":568,"latency_ms_avg":739.771,"latency_ms_max":5159.373},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":13,"1":8,"2":8,"9":9,"10":11,"11":13,"12":9,"13":8,"20":7,"21":4,"22":10,"23":10,"24":5,"31":8,"32":11,"33":12,"34":8,"35":10,"42":9,"43":11,"44":11,"45":10,"46":11,"53":14,"54":12,"55":11,"56":6,"57":10,"64":2,"65":10,"66":10,"67":12,"68":12,"75":11,"76":10,"77":15,"78":9,"79":5,"86":6,"87":15,"88":9,"89":12,"90":13,"97":6,"98":10,"99":7,"100":9,"101":8,"108":13,"109":16,"110":11,"111":15,"112":12,"119":10,"120":4,"121":11,"122":12,"123":4},"consensus_reply_error_by_shard":{},"error_code_counts":{"forward:STATUS_CODE_TIMEOUT":568,"put_total:STATUS_CODE_TIMEOUT":568}}`
- `notdynamo-data-7`: `{"node":"notdynamo-data-7","observed_leader_override_writes":322,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":921,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"forward_to_leader":{"success":784,"error":526,"timeout":526,"latency_ms_avg":2050.422,"latency_ms_max":5313.793},"consensus_submit":{"success":994,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":994,"error":0,"timeout":0,"latency_ms_avg":39.418,"latency_ms_max":1840.605},"put_total":{"success":1778,"error":526,"timeout":526,"latency_ms_avg":1183.268,"latency_ms_max":5457.178},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":14,"1":10,"2":6,"9":10,"10":10,"11":8,"12":8,"13":6,"20":3,"21":11,"22":7,"23":8,"24":8,"31":8,"32":5,"33":12,"34":18,"35":14,"42":5,"43":10,"44":15,"45":9,"46":11,"53":9,"54":6,"55":7,"56":10,"57":11,"64":5,"65":6,"66":8,"67":16,"68":5,"75":9,"76":13,"77":16,"78":6,"79":4,"86":5,"87":14,"88":9,"89":9,"90":6,"97":4,"98":7,"99":5,"100":10,"101":14,"108":7,"109":12,"110":13,"111":10,"112":5,"119":10,"120":6,"121":8,"122":8,"123":17},"consensus_reply_error_by_shard":{},"error_code_counts":{"forward:STATUS_CODE_TIMEOUT":526,"put_total:STATUS_CODE_TIMEOUT":526}}`
- `notdynamo-data-8`: `{"node":"notdynamo-data-8","observed_leader_override_writes":2095,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":1099,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"forward_to_leader":{"success":1734,"error":583,"timeout":583,"latency_ms_avg":1279.505,"latency_ms_max":5107.957},"consensus_submit":{"success":1017,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":1017,"error":0,"timeout":0,"latency_ms_avg":22.384,"latency_ms_max":2256.502},"put_total":{"success":2751,"error":583,"timeout":583,"latency_ms_avg":896.103,"latency_ms_max":5154.882},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":13,"1":14,"2":13,"9":4,"10":9,"11":14,"12":9,"13":8,"20":6,"21":13,"22":14,"23":15,"24":12,"31":6,"32":14,"33":11,"34":16,"35":15,"42":12,"43":18,"44":10,"45":7,"46":9,"53":14,"54":10,"55":7,"56":8,"57":5,"64":1,"65":8,"66":6,"67":15,"68":14,"75":18,"76":13,"77":10,"78":10,"79":6,"86":7,"87":12,"88":7,"89":10,"90":5,"97":6,"98":9,"99":8,"100":11,"101":7,"108":12,"109":17,"110":8,"111":9,"112":11,"119":8,"120":4,"121":6,"122":5,"123":14},"consensus_reply_error_by_shard":{},"error_code_counts":{"forward:STATUS_CODE_TIMEOUT":583,"put_total:STATUS_CODE_TIMEOUT":583}}`
- `notdynamo-data-9`: `{"node":"notdynamo-data-9","observed_leader_override_writes":855,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":934,"observed_leader_override_retry_attempts":166,"observed_leader_override_retry_success":0,"forward_to_leader":{"success":890,"error":862,"timeout":696,"latency_ms_avg":2520.395,"latency_ms_max":5585.191},"consensus_submit":{"success":868,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":244,"error":586,"timeout":586,"latency_ms_avg":3626.399,"latency_ms_max":5478.477},"put_total":{"success":1134,"error":1448,"timeout":1282,"latency_ms_avg":2877.163,"latency_ms_max":5788.090},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":9,"1":9,"2":12,"10":7,"11":6,"12":9,"13":4,"20":19,"21":11,"22":8,"23":9,"24":11,"31":42,"32":10,"33":14,"34":10,"35":3,"42":45,"43":9,"44":10,"45":8,"46":17,"53":48,"54":10,"55":8,"56":9,"57":12,"64":1,"65":6,"66":5,"67":14,"68":13,"75":29,"76":7,"77":12,"78":13,"79":6,"86":40,"87":13,"88":7,"89":9,"90":15,"97":85,"98":5,"99":8,"100":10,"101":9,"108":57,"109":12,"110":14,"111":7,"112":11,"119":56,"120":9,"121":6,"122":6,"123":8},"consensus_reply_error_by_shard":{"9":99,"20":40,"31":18,"42":38,"53":88,"64":45,"75":91,"86":42,"97":12,"108":43,"119":70},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":586,"forward:STATUS_CODE_INTERNAL":166,"forward:STATUS_CODE_TIMEOUT":696,"put_total:STATUS_CODE_INTERNAL":166,"put_total:STATUS_CODE_TIMEOUT":1282}}`

## Artifacts

- JSON report: `reports/benchmarks/aws/e45_k6_write_heavy_leaderroute_retry_20260220T124918Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220124921`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220124921/job.yaml`
- Script configmap: `notdynamo-bench-k6-script-20260220124921`
- Pod placement snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220124921/pod_placement.txt`
- Pods top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220124921/telemetry/pods_top_snapshot.txt`
- Nodes top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220124921/telemetry/nodes_top_snapshot.txt`
- Generator top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220124921/telemetry/bench_top_summary.txt`
- Service top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220124921/telemetry/data_top_summary.txt`
- Nodes top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220124921/telemetry/nodes_top_summary.txt`
- Write-stage telemetry samples: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220124921/telemetry/write_stage_telemetry_samples.txt`
