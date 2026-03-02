# NotDynamo E2E HTTP In-Cluster Benchmark Report (k6)

- Status: **WARN**
- Timestamp (UTC): 2026-02-20T12:01:33Z
- Category: `in-cluster-job`
- Driver: `k6`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-k6-20260220115934`

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
| Effective operations | 6971 |
| Aggregate throughput (rps) | 73.86 |
| Aggregate success throughput (rps) | 1.08 |
| Max pod p50 latency (ms) | 4997.468 |
| Max pod p95 latency (ms) | 5048.823 |
| Max pod p99 latency (ms) | 5107.994 |
| Success count | 102 |
| Error count | 6869 |
| Error rate (%) | 98.5368 |
| Read count | 668 |
| Write count | 6303 |
| Read not found count | 11 |
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
| Generator CPU mcores sum | 100.000 |
| Generator CPU mcores avg | 9.091 |
| Service pod count (sampled) | 2 |
| Service CPU mcores sum | 2298.000 |
| Service CPU mcores avg | 1149.000 |
| Generator/Service CPU ratio | 0.044 |
| Attribution hint | service-pressure-dominant |
| Attribution reason | data pod CPU sum is >= 1.5x benchmark pod CPU sum during sample window |
| Cluster node count (sampled) | 14 |
| Cluster CPU percent max | 97.000 |
| Cluster memory percent max | 75.000 |
| Write-stage telemetry samples | 6 |

## Write-Stage Telemetry Samples

- `notdynamo-data-10`: `{"node":"notdynamo-data-10","forward_to_leader":{"success":2,"error":8,"timeout":1,"latency_ms_avg":894.210,"latency_ms_max":5018.891},"consensus_submit":{"success":21,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":0,"error":12,"timeout":12,"latency_ms_avg":5086.730,"latency_ms_max":5298.993},"put_total":{"success":2,"error":20,"timeout":13,"latency_ms_avg":3209.159,"latency_ms_max":5668.187},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"34":1,"45":1,"52":1,"59":1,"67":1,"79":2,"103":1},"consensus_reply_error_by_shard":{"32":3,"43":2,"76":2,"87":1,"98":1,"109":1,"120":2},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":12,"forward:STATUS_CODE_TIMEOUT":1,"forward:STATUS_CODE_UNAVAILABLE":7,"put_total:STATUS_CODE_TIMEOUT":13,"put_total:STATUS_CODE_UNAVAILABLE":7}}`
- `notdynamo-data-4`: `{"node":"notdynamo-data-4","forward_to_leader":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_submit":{"success":13,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":13,"error":0,"timeout":0,"latency_ms_avg":146.453,"latency_ms_max":863.528},"put_total":{"success":13,"error":0,"timeout":0,"latency_ms_avg":188.316,"latency_ms_max":1406.928},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{},"consensus_reply_error_by_shard":{},"error_code_counts":{}}`
- `notdynamo-data-5`: `{"node":"notdynamo-data-5","forward_to_leader":{"success":40,"error":156,"timeout":12,"latency_ms_avg":378.893,"latency_ms_max":5030.133},"consensus_submit":{"success":91,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":85,"error":6,"timeout":6,"latency_ms_avg":544.317,"latency_ms_max":5644.525},"put_total":{"success":125,"error":162,"timeout":18,"latency_ms_avg":432.318,"latency_ms_max":5644.601},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"1":5,"2":1,"3":3,"6":2,"7":1,"8":1,"9":2,"10":1,"11":4,"12":1,"13":6,"18":1,"19":1,"20":3,"22":1,"23":1,"24":2,"25":3,"26":1,"29":2,"31":2,"32":2,"33":3,"35":1,"36":4,"39":2,"40":1,"42":1,"43":2,"46":7,"47":3,"48":2,"53":2,"54":1,"56":1,"57":1,"58":1,"61":1,"64":1,"66":1,"68":1,"69":1,"70":1,"72":2,"75":3,"76":2,"77":2,"78":2,"79":2,"80":2,"81":1,"83":2,"85":1,"86":3,"87":3,"88":1,"89":5,"90":4,"94":1,"97":1,"98":2,"99":1,"101":4,"102":2,"105":1,"108":5,"109":1,"110":1,"111":2,"112":1,"114":2,"117":1,"118":1,"119":2,"120":4,"121":1,"122":2,"123":1,"124":1},"consensus_reply_error_by_shard":{"5":1,"71":2,"93":1,"115":1,"126":1},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":6,"forward:STATUS_CODE_TIMEOUT":12,"forward:STATUS_CODE_UNAVAILABLE":144,"put_total:STATUS_CODE_TIMEOUT":18,"put_total:STATUS_CODE_UNAVAILABLE":144}}`
- `notdynamo-data-6`: `{"node":"notdynamo-data-6","forward_to_leader":{"success":2,"error":13,"timeout":2,"latency_ms_avg":1019.003,"latency_ms_max":5005.955},"consensus_submit":{"success":9,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":9,"error":0,"timeout":0,"latency_ms_avg":329.118,"latency_ms_max":2317.476},"put_total":{"success":11,"error":13,"timeout":2,"latency_ms_avg":802.020,"latency_ms_max":5006.028},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"2":1,"14":1,"15":1,"25":1,"31":1,"45":1,"57":1,"59":1,"91":1,"92":1,"96":1,"101":1,"118":1},"consensus_reply_error_by_shard":{},"error_code_counts":{"forward:STATUS_CODE_TIMEOUT":2,"forward:STATUS_CODE_UNAVAILABLE":11,"put_total:STATUS_CODE_TIMEOUT":2,"put_total:STATUS_CODE_UNAVAILABLE":11}}`
- `notdynamo-data-7`: `{"node":"notdynamo-data-7","forward_to_leader":{"success":20,"error":130,"timeout":3,"latency_ms_avg":265.001,"latency_ms_max":5003.773},"consensus_submit":{"success":61,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":61,"error":0,"timeout":0,"latency_ms_avg":150.096,"latency_ms_max":4217.353},"put_total":{"success":81,"error":130,"timeout":3,"latency_ms_avg":232.384,"latency_ms_max":5003.831},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":2,"1":2,"4":2,"6":3,"9":2,"10":1,"11":3,"15":2,"16":1,"17":2,"19":1,"20":4,"21":1,"23":2,"24":1,"25":2,"26":1,"28":1,"32":3,"33":5,"34":1,"35":5,"36":1,"41":2,"42":2,"43":1,"44":1,"46":1,"47":2,"53":2,"55":1,"56":2,"57":2,"59":2,"60":2,"64":1,"65":3,"66":1,"67":1,"68":3,"70":1,"72":1,"76":1,"77":2,"78":5,"81":1,"86":1,"87":1,"89":1,"90":2,"91":1,"92":2,"93":1,"94":1,"98":1,"100":2,"101":1,"102":1,"105":1,"109":3,"110":1,"111":2,"112":1,"113":1,"114":3,"115":1,"116":2,"119":4,"120":2,"121":1,"123":2,"124":1,"125":1,"127":1},"consensus_reply_error_by_shard":{},"error_code_counts":{"forward:STATUS_CODE_TIMEOUT":3,"forward:STATUS_CODE_UNAVAILABLE":127,"put_total:STATUS_CODE_TIMEOUT":3,"put_total:STATUS_CODE_UNAVAILABLE":127}}`
- `notdynamo-data-8`: `{"node":"notdynamo-data-8","forward_to_leader":{"success":97,"error":543,"timeout":5,"latency_ms_avg":48.774,"latency_ms_max":5005.030},"consensus_submit":{"success":93,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":66,"error":27,"timeout":27,"latency_ms_avg":1949.670,"latency_ms_max":5468.433},"put_total":{"success":163,"error":570,"timeout":32,"latency_ms_avg":290.731,"latency_ms_max":5468.478},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":4,"1":5,"2":2,"3":4,"4":2,"5":1,"6":4,"7":6,"9":8,"10":3,"11":5,"12":4,"13":4,"14":6,"15":6,"16":1,"17":5,"20":2,"21":3,"22":6,"23":3,"24":8,"25":5,"26":8,"28":6,"29":2,"31":4,"32":5,"33":8,"34":5,"35":4,"36":6,"37":6,"39":3,"42":2,"43":8,"44":4,"45":1,"46":5,"47":6,"48":6,"49":4,"50":3,"51":1,"53":8,"54":8,"55":7,"56":3,"57":4,"58":7,"59":6,"61":3,"62":2,"64":7,"65":4,"66":4,"67":6,"68":6,"69":13,"70":6,"71":2,"72":5,"73":1,"75":3,"76":3,"77":5,"78":10,"79":6,"80":10,"81":3,"82":2,"83":4,"84":2,"86":6,"87":8,"88":1,"89":5,"90":5,"91":7,"92":4,"93":3,"94":4,"95":4,"97":7,"98":2,"99":6,"100":6,"101":9,"102":8,"103":4,"105":3,"106":1,"108":8,"109":7,"110":8,"111":6,"112":6,"113":3,"114":7,"115":1,"116":7,"117":1,"119":6,"120":4,"121":7,"122":7,"123":6,"124":7,"125":8,"127":7},"consensus_reply_error_by_shard":{"8":2,"19":6,"30":2,"41":3,"52":2,"63":2,"74":2,"85":3,"96":2,"107":1,"118":2},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":27,"forward:STATUS_CODE_TIMEOUT":5,"forward:STATUS_CODE_UNAVAILABLE":538,"put_total:STATUS_CODE_TIMEOUT":32,"put_total:STATUS_CODE_UNAVAILABLE":538}}`

## Artifacts

- JSON report: `reports/benchmarks/aws/e45_k6_write_heavy_scale11_spread_stable_20260220T115932Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220115934`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220115934/job.yaml`
- Script configmap: `notdynamo-bench-k6-script-20260220115934`
- Pod placement snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220115934/pod_placement.txt`
- Pods top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220115934/telemetry/pods_top_snapshot.txt`
- Nodes top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220115934/telemetry/nodes_top_snapshot.txt`
- Generator top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220115934/telemetry/bench_top_summary.txt`
- Service top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220115934/telemetry/data_top_summary.txt`
- Nodes top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220115934/telemetry/nodes_top_summary.txt`
- Write-stage telemetry samples: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220115934/telemetry/write_stage_telemetry_samples.txt`
