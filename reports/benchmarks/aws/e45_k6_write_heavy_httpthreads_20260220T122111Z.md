# NotDynamo E2E HTTP In-Cluster Benchmark Report (k6)

- Status: **WARN**
- Timestamp (UTC): 2026-02-20T12:23:10Z
- Category: `in-cluster-job`
- Driver: `k6`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-k6-20260220122114`

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
| Effective operations | 16392 |
| Aggregate throughput (rps) | 173.98 |
| Aggregate success throughput (rps) | 106.98 |
| Max pod p50 latency (ms) | 69.832 |
| Max pod p95 latency (ms) | 5001.078 |
| Max pod p99 latency (ms) | 5001.401 |
| Success count | 10080 |
| Error count | 6312 |
| Error rate (%) | 38.5066 |
| Read count | 1629 |
| Write count | 14763 |
| Read not found count | 1074 |
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
| Generator CPU mcores sum | 200.000 |
| Generator CPU mcores avg | 18.182 |
| Service pod count (sampled) | 11 |
| Service CPU mcores sum | 9597.000 |
| Service CPU mcores avg | 872.455 |
| Generator/Service CPU ratio | 0.021 |
| Attribution hint | service-pressure-dominant |
| Attribution reason | data pod CPU sum is >= 1.5x benchmark pod CPU sum during sample window |
| Cluster node count (sampled) | 14 |
| Cluster CPU percent max | 89.000 |
| Cluster memory percent max | 71.000 |
| Write-stage telemetry samples | 11 |

## Write-Stage Telemetry Samples

- `notdynamo-data-0`: `{"node":"notdynamo-data-0","forward_to_leader":{"success":660,"error":404,"timeout":404,"latency_ms_avg":1957.010,"latency_ms_max":5775.847},"consensus_submit":{"success":1333,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":0,"error":1154,"timeout":1154,"latency_ms_avg":5009.568,"latency_ms_max":5726.768},"put_total":{"success":660,"error":1558,"timeout":1558,"latency_ms_avg":3545.814,"latency_ms_max":5934.569},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"1":6,"2":10,"9":11,"10":6,"12":7,"13":9,"20":12,"21":7,"23":8,"24":10,"31":9,"32":10,"34":10,"35":13,"42":3,"43":10,"45":10,"46":11,"53":8,"54":9,"56":6,"57":10,"64":8,"65":11,"67":15,"68":1,"75":16,"76":10,"78":10,"79":18,"86":8,"87":7,"89":7,"90":8,"97":6,"98":7,"100":7,"101":14,"109":5,"111":10,"119":9,"120":12,"122":9,"123":11},"consensus_reply_error_by_shard":{"0":99,"11":99,"22":91,"33":99,"44":99,"55":88,"66":97,"77":99,"88":92,"99":99,"110":99,"121":93},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":1154,"forward:STATUS_CODE_TIMEOUT":404,"put_total:STATUS_CODE_TIMEOUT":1558}}`
- `notdynamo-data-1`: `{"node":"notdynamo-data-1","forward_to_leader":{"success":778,"error":425,"timeout":425,"latency_ms_avg":1824.565,"latency_ms_max":5065.041},"consensus_submit":{"success":1379,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":0,"error":1163,"timeout":1163,"latency_ms_avg":5013.548,"latency_ms_max":7753.669},"put_total":{"success":778,"error":1588,"timeout":1588,"latency_ms_avg":3392.208,"latency_ms_max":7753.749},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":13,"2":8,"9":8,"10":3,"11":12,"13":13,"20":7,"21":13,"22":10,"24":14,"31":8,"32":13,"33":13,"35":9,"42":3,"43":11,"44":13,"46":14,"53":10,"54":13,"55":8,"57":10,"64":7,"65":6,"66":8,"75":6,"76":11,"77":9,"79":8,"86":4,"87":18,"88":10,"90":9,"97":11,"98":3,"99":5,"101":20,"108":4,"109":5,"110":14,"119":8,"120":13,"121":9,"123":11},"consensus_reply_error_by_shard":{"1":96,"12":99,"23":80,"34":99,"45":99,"56":96,"67":99,"78":99,"89":99,"100":99,"111":99,"122":99},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":1163,"forward:STATUS_CODE_TIMEOUT":425,"put_total:STATUS_CODE_TIMEOUT":1588}}`
- `notdynamo-data-10`: `{"node":"notdynamo-data-10","forward_to_leader":{"success":769,"error":403,"timeout":403,"latency_ms_avg":1739.977,"latency_ms_max":5102.709},"consensus_submit":{"success":1319,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":0,"error":1070,"timeout":1070,"latency_ms_avg":5001.015,"latency_ms_max":5148.321},"put_total":{"success":769,"error":1473,"timeout":1473,"latency_ms_avg":3296.539,"latency_ms_max":5250.315},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":11,"1":9,"2":8,"9":15,"11":10,"12":8,"13":10,"20":5,"22":2,"23":4,"24":8,"31":11,"33":7,"34":9,"35":8,"42":3,"44":6,"45":9,"46":7,"53":15,"55":5,"56":14,"57":10,"64":11,"66":8,"67":9,"75":6,"77":17,"78":11,"79":12,"86":6,"88":6,"89":11,"90":8,"97":9,"99":10,"100":6,"101":15,"108":2,"110":6,"111":14,"119":5,"121":10,"122":15,"123":12},"consensus_reply_error_by_shard":{"10":84,"21":99,"32":99,"43":99,"54":99,"65":99,"76":99,"87":99,"98":95,"109":99,"120":99},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":1070,"forward:STATUS_CODE_TIMEOUT":403,"put_total:STATUS_CODE_TIMEOUT":1473}}`
- `notdynamo-data-2`: `{"node":"notdynamo-data-2","forward_to_leader":{"success":736,"error":425,"timeout":425,"latency_ms_avg":1869.590,"latency_ms_max":5355.541},"consensus_submit":{"success":1402,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":207,"error":1000,"timeout":1000,"latency_ms_avg":4195.882,"latency_ms_max":6123.122},"put_total":{"success":943,"error":1425,"timeout":1425,"latency_ms_avg":3056.539,"latency_ms_max":6469.802},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":15,"1":7,"9":12,"10":8,"11":8,"12":12,"20":9,"21":10,"22":6,"23":6,"31":6,"32":15,"33":7,"34":11,"42":3,"43":9,"44":11,"45":9,"53":7,"54":9,"55":7,"56":14,"64":11,"65":14,"66":9,"67":13,"75":6,"76":10,"77":10,"78":9,"86":6,"87":20,"88":9,"89":4,"97":8,"98":4,"99":10,"100":8,"108":1,"109":12,"110":10,"111":13,"119":9,"120":6,"121":13,"122":9},"consensus_reply_error_by_shard":{"2":99,"13":99,"24":100,"35":99,"46":99,"57":99,"68":7,"79":99,"90":99,"101":99,"112":2,"123":99},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":1000,"forward:STATUS_CODE_TIMEOUT":425,"put_total:STATUS_CODE_TIMEOUT":1425}}`
- `notdynamo-data-3`: `{"node":"notdynamo-data-3","forward_to_leader":{"success":696,"error":557,"timeout":557,"latency_ms_avg":2245.292,"latency_ms_max":5106.738},"consensus_submit":{"success":1423,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":1423,"error":0,"timeout":0,"latency_ms_avg":11.938,"latency_ms_max":482.070},"put_total":{"success":2119,"error":557,"timeout":557,"latency_ms_avg":1057.844,"latency_ms_max":5180.750},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":12,"1":11,"2":10,"9":9,"10":8,"11":12,"12":11,"13":8,"20":10,"21":10,"22":14,"23":6,"24":9,"31":11,"32":10,"33":7,"34":15,"35":13,"42":2,"43":10,"44":8,"45":7,"46":13,"53":13,"54":10,"55":10,"56":7,"57":12,"64":9,"65":8,"66":7,"67":11,"75":11,"76":5,"77":5,"78":14,"79":9,"86":15,"87":11,"88":9,"89":12,"90":10,"97":7,"98":15,"99":13,"100":12,"101":14,"108":3,"109":13,"110":16,"111":7,"119":8,"120":9,"121":4,"122":14,"123":8},"consensus_reply_error_by_shard":{},"error_code_counts":{"forward:STATUS_CODE_TIMEOUT":557,"put_total:STATUS_CODE_TIMEOUT":557}}`
- `notdynamo-data-4`: `{"node":"notdynamo-data-4","forward_to_leader":{"success":699,"error":562,"timeout":562,"latency_ms_avg":2260.825,"latency_ms_max":5084.538},"consensus_submit":{"success":1471,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":1471,"error":0,"timeout":0,"latency_ms_avg":9.529,"latency_ms_max":292.026},"put_total":{"success":2170,"error":562,"timeout":562,"latency_ms_avg":1048.811,"latency_ms_max":5155.708},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":14,"1":8,"2":12,"9":4,"10":7,"11":9,"12":10,"13":8,"20":11,"21":13,"22":9,"23":4,"24":13,"31":11,"32":11,"33":15,"34":7,"35":6,"42":4,"43":15,"44":10,"45":7,"46":13,"53":10,"54":15,"55":5,"56":7,"57":16,"64":13,"65":7,"66":10,"67":11,"75":8,"76":7,"77":5,"78":19,"79":9,"86":15,"87":15,"88":7,"89":10,"90":11,"97":9,"98":15,"99":8,"100":8,"101":9,"108":6,"109":15,"110":8,"111":17,"119":13,"120":6,"121":10,"122":9,"123":8},"consensus_reply_error_by_shard":{},"error_code_counts":{"forward:STATUS_CODE_TIMEOUT":562,"put_total:STATUS_CODE_TIMEOUT":562}}`
- `notdynamo-data-5`: `{"node":"notdynamo-data-5","forward_to_leader":{"success":578,"error":536,"timeout":536,"latency_ms_avg":2426.785,"latency_ms_max":5089.845},"consensus_submit":{"success":1348,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":1348,"error":0,"timeout":0,"latency_ms_avg":10.907,"latency_ms_max":302.470},"put_total":{"success":1926,"error":536,"timeout":536,"latency_ms_avg":1104.207,"latency_ms_max":5178.793},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":6,"1":12,"2":4,"9":13,"10":8,"11":13,"12":6,"13":7,"20":7,"21":10,"22":11,"23":7,"24":7,"31":12,"32":3,"33":7,"34":18,"35":13,"42":1,"43":16,"44":10,"45":10,"46":9,"53":9,"54":6,"55":3,"56":7,"57":8,"64":17,"65":13,"66":3,"67":10,"75":16,"76":12,"77":16,"78":11,"79":9,"86":11,"87":13,"88":9,"89":12,"90":3,"97":12,"98":7,"99":8,"100":12,"101":13,"108":5,"109":9,"110":7,"111":12,"119":18,"120":10,"121":10,"122":8,"123":7},"consensus_reply_error_by_shard":{},"error_code_counts":{"forward:STATUS_CODE_TIMEOUT":536,"put_total:STATUS_CODE_TIMEOUT":536}}`
- `notdynamo-data-6`: `{"node":"notdynamo-data-6","forward_to_leader":{"success":649,"error":561,"timeout":561,"latency_ms_avg":2348.154,"latency_ms_max":5094.727},"consensus_submit":{"success":1365,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":1365,"error":0,"timeout":0,"latency_ms_avg":10.494,"latency_ms_max":297.345},"put_total":{"success":2014,"error":561,"timeout":561,"latency_ms_avg":1109.110,"latency_ms_max":5163.313},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":14,"1":7,"2":14,"9":14,"10":9,"11":10,"12":9,"13":10,"20":8,"21":8,"22":11,"23":8,"24":9,"31":13,"32":10,"33":8,"34":8,"35":8,"42":3,"43":16,"44":8,"45":10,"46":6,"53":8,"54":19,"55":7,"56":9,"57":12,"64":8,"65":5,"66":10,"67":11,"68":1,"75":8,"76":16,"77":12,"78":9,"79":9,"86":9,"87":17,"88":5,"89":8,"90":10,"97":9,"98":17,"99":9,"100":7,"101":7,"108":6,"109":10,"110":15,"111":20,"119":10,"120":10,"121":9,"122":8,"123":10},"consensus_reply_error_by_shard":{},"error_code_counts":{"forward:STATUS_CODE_TIMEOUT":561,"put_total:STATUS_CODE_TIMEOUT":561}}`
- `notdynamo-data-7`: `{"node":"notdynamo-data-7","forward_to_leader":{"success":738,"error":572,"timeout":572,"latency_ms_avg":2220.275,"latency_ms_max":5469.663},"consensus_submit":{"success":1205,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":1205,"error":0,"timeout":0,"latency_ms_avg":24.652,"latency_ms_max":1400.123},"put_total":{"success":1943,"error":572,"timeout":572,"latency_ms_avg":1168.622,"latency_ms_max":5623.227},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":10,"1":12,"2":12,"9":4,"10":7,"11":14,"12":6,"13":13,"20":8,"21":4,"22":10,"23":8,"24":9,"31":10,"32":12,"33":10,"34":8,"35":9,"43":7,"44":14,"45":11,"46":12,"53":18,"54":9,"55":12,"56":7,"57":19,"64":16,"65":10,"66":10,"67":17,"68":2,"75":10,"76":9,"77":15,"78":12,"79":11,"86":8,"87":15,"88":10,"89":16,"90":13,"97":5,"98":8,"99":10,"100":9,"101":10,"109":13,"110":13,"111":14,"119":10,"120":9,"121":9,"122":4,"123":9},"consensus_reply_error_by_shard":{},"error_code_counts":{"forward:STATUS_CODE_TIMEOUT":572,"put_total:STATUS_CODE_TIMEOUT":572}}`
- `notdynamo-data-8`: `{"node":"notdynamo-data-8","forward_to_leader":{"success":602,"error":520,"timeout":520,"latency_ms_avg":2335.130,"latency_ms_max":5094.602},"consensus_submit":{"success":1269,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":1269,"error":0,"timeout":0,"latency_ms_avg":9.433,"latency_ms_max":248.948},"put_total":{"success":1871,"error":520,"timeout":520,"latency_ms_avg":1100.909,"latency_ms_max":5164.422},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":9,"1":7,"2":6,"9":12,"10":4,"11":18,"12":10,"13":8,"20":9,"21":7,"22":5,"23":11,"24":5,"31":11,"32":13,"33":8,"34":9,"35":13,"42":2,"43":10,"44":2,"45":11,"46":12,"53":9,"54":11,"55":8,"56":8,"57":10,"64":16,"65":11,"66":7,"67":10,"68":1,"75":7,"76":9,"77":9,"78":13,"79":13,"86":11,"87":11,"88":8,"89":16,"90":8,"97":11,"98":4,"99":12,"100":6,"101":11,"109":11,"110":8,"111":13,"119":11,"120":9,"121":7,"122":8,"123":11},"consensus_reply_error_by_shard":{},"error_code_counts":{"forward:STATUS_CODE_TIMEOUT":520,"put_total:STATUS_CODE_TIMEOUT":520}}`
- `notdynamo-data-9`: `{"node":"notdynamo-data-9","forward_to_leader":{"success":810,"error":498,"timeout":498,"latency_ms_avg":1949.378,"latency_ms_max":5364.266},"consensus_submit":{"success":1249,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":177,"error":932,"timeout":932,"latency_ms_avg":4291.124,"latency_ms_max":5299.794},"put_total":{"success":987,"error":1430,"timeout":1430,"latency_ms_avg":3024.614,"latency_ms_max":5641.089},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":14,"1":11,"2":9,"10":9,"11":12,"12":12,"13":7,"21":10,"22":9,"23":10,"24":7,"32":8,"33":13,"34":11,"35":8,"43":12,"44":11,"45":15,"46":10,"54":14,"55":11,"56":7,"57":14,"65":13,"66":15,"67":14,"68":4,"76":10,"77":9,"78":12,"79":14,"87":15,"88":9,"89":8,"90":18,"98":7,"99":8,"100":15,"101":8,"109":13,"110":12,"111":8,"112":1,"120":15,"121":6,"122":10,"123":10},"consensus_reply_error_by_shard":{"9":99,"20":90,"31":99,"42":23,"53":99,"64":99,"75":99,"86":101,"97":98,"108":26,"119":99},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":932,"forward:STATUS_CODE_TIMEOUT":498,"put_total:STATUS_CODE_TIMEOUT":1430}}`

## Artifacts

- JSON report: `reports/benchmarks/aws/e45_k6_write_heavy_httpthreads_20260220T122111Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220122114`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220122114/job.yaml`
- Script configmap: `notdynamo-bench-k6-script-20260220122114`
- Pod placement snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220122114/pod_placement.txt`
- Pods top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220122114/telemetry/pods_top_snapshot.txt`
- Nodes top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220122114/telemetry/nodes_top_snapshot.txt`
- Generator top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220122114/telemetry/bench_top_summary.txt`
- Service top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220122114/telemetry/data_top_summary.txt`
- Nodes top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220122114/telemetry/nodes_top_summary.txt`
- Write-stage telemetry samples: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220122114/telemetry/write_stage_telemetry_samples.txt`
