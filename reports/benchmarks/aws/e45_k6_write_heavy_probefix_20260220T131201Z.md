# NotDynamo E2E HTTP In-Cluster Benchmark Report (k6)

- Status: **WARN**
- Timestamp (UTC): 2026-02-20T13:14:01Z
- Category: `in-cluster-job`
- Driver: `k6`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Base URL: `http://notdynamo-data.notdynamo.svc.cluster.local:8080`
- Job: `notdynamo-bench-k6-20260220131204`

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
| Effective operations | 18731 |
| Aggregate throughput (rps) | 197.39 |
| Aggregate success throughput (rps) | 132.26 |
| Max pod p50 latency (ms) | 69.856 |
| Max pod p95 latency (ms) | 5001.060 |
| Max pod p99 latency (ms) | 5001.296 |
| Success count | 12550 |
| Error count | 6181 |
| Error rate (%) | 32.9988 |
| Read count | 1889 |
| Write count | 16842 |
| Read not found count | 736 |
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
| Generator CPU mcores sum | 212.000 |
| Generator CPU mcores avg | 19.273 |
| Service pod count (sampled) | 11 |
| Service CPU mcores sum | 6186.000 |
| Service CPU mcores avg | 562.364 |
| Generator/Service CPU ratio | 0.034 |
| Attribution hint | service-pressure-dominant |
| Attribution reason | data pod CPU sum is >= 1.5x benchmark pod CPU sum during sample window |
| Cluster node count (sampled) | 14 |
| Cluster CPU percent max | 78.000 |
| Cluster memory percent max | 80.000 |
| Write-stage telemetry samples | 11 |

## Write-Stage Telemetry Samples

- `notdynamo-data-0`: `{"node":"notdynamo-data-0","observed_leader_override_writes":123,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":1118,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"forward_to_leader":{"success":947,"error":500,"timeout":422,"latency_ms_avg":1923.032,"latency_ms_max":11423.307},"consensus_submit":{"success":1500,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":0,"error":1178,"timeout":1178,"latency_ms_avg":5020.417,"latency_ms_max":7744.552},"put_total":{"success":947,"error":1678,"timeout":1600,"latency_ms_avg":3313.506,"latency_ms_max":11423.389},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"1":10,"2":2,"9":19,"10":11,"12":12,"14":1,"20":11,"21":10,"23":14,"24":3,"27":1,"31":8,"32":8,"34":11,"38":1,"39":1,"42":8,"43":10,"44":108,"45":11,"47":1,"48":1,"49":1,"51":1,"53":10,"54":13,"56":14,"57":2,"64":12,"65":8,"67":11,"68":1,"71":1,"75":11,"76":4,"78":13,"79":1,"86":14,"87":12,"89":13,"90":4,"97":12,"98":13,"100":8,"101":2,"107":1,"108":8,"109":7,"111":12,"112":3,"114":1,"115":1,"119":4,"120":6,"122":13,"123":1},"consensus_reply_error_by_shard":{"0":99,"11":99,"22":99,"33":99,"44":99,"55":93,"66":99,"77":99,"88":99,"99":99,"110":99,"121":95},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":1178,"forward:STATUS_CODE_INTERNAL":78,"forward:STATUS_CODE_TIMEOUT":422,"put_total:STATUS_CODE_INTERNAL":78,"put_total:STATUS_CODE_TIMEOUT":1600}}`
- `notdynamo-data-1`: `{"node":"notdynamo-data-1","observed_leader_override_writes":0,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":1152,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"forward_to_leader":{"success":995,"error":549,"timeout":467,"latency_ms_avg":1818.205,"latency_ms_max":5165.600},"consensus_submit":{"success":1615,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":0,"error":1188,"timeout":1188,"latency_ms_avg":5004.359,"latency_ms_max":5440.846},"put_total":{"success":995,"error":1737,"timeout":1655,"latency_ms_avg":3203.976,"latency_ms_max":5601.509},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":17,"2":2,"9":15,"10":11,"11":23,"13":1,"20":8,"21":15,"22":12,"24":4,"31":14,"32":10,"33":16,"42":6,"43":12,"44":116,"53":20,"54":16,"55":11,"57":1,"64":10,"65":14,"66":12,"68":2,"75":15,"76":19,"77":13,"79":2,"86":19,"87":7,"88":11,"90":1,"97":9,"98":4,"99":14,"101":3,"108":12,"109":12,"110":20,"119":6,"120":8,"121":5,"123":1},"consensus_reply_error_by_shard":{"1":99,"12":99,"23":99,"34":99,"45":99,"56":99,"67":99,"78":99,"89":99,"100":99,"111":99,"122":99},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":1188,"forward:STATUS_CODE_INTERNAL":82,"forward:STATUS_CODE_TIMEOUT":467,"put_total:STATUS_CODE_INTERNAL":82,"put_total:STATUS_CODE_TIMEOUT":1655}}`
- `notdynamo-data-10`: `{"node":"notdynamo-data-10","observed_leader_override_writes":608,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":1065,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"forward_to_leader":{"success":928,"error":1152,"timeout":667,"latency_ms_avg":2787.572,"latency_ms_max":5077.400},"consensus_submit":{"success":1953,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":45,"error":1515,"timeout":1515,"latency_ms_avg":4905.947,"latency_ms_max":5051.100},"put_total":{"success":973,"error":2667,"timeout":2182,"latency_ms_avg":3695.588,"latency_ms_max":5131.383},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":14,"1":11,"9":9,"11":12,"12":9,"13":1,"20":99,"22":10,"23":16,"24":2,"31":281,"33":15,"34":12,"35":2,"42":5,"44":10,"45":11,"53":55,"55":11,"56":17,"57":3,"64":25,"66":8,"67":11,"75":52,"77":18,"78":12,"79":1,"86":4,"88":10,"89":12,"90":1,"97":80,"99":9,"100":11,"101":1,"108":150,"110":8,"111":12,"119":106,"121":7,"122":9},"consensus_reply_error_by_shard":{"10":99,"20":45,"21":99,"31":99,"32":99,"42":47,"43":99,"53":69,"54":99,"64":31,"65":99,"75":3,"76":99,"86":58,"87":99,"97":9,"98":99,"108":62,"109":99,"119":3,"120":99},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":1515,"forward:STATUS_CODE_INTERNAL":485,"forward:STATUS_CODE_TIMEOUT":667,"put_total:STATUS_CODE_INTERNAL":485,"put_total:STATUS_CODE_TIMEOUT":2182}}`
- `notdynamo-data-2`: `{"node":"notdynamo-data-2","observed_leader_override_writes":975,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":1004,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"forward_to_leader":{"success":1425,"error":798,"timeout":527,"latency_ms_avg":1990.858,"latency_ms_max":5144.815},"consensus_submit":{"success":1241,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":1070,"error":171,"timeout":171,"latency_ms_avg":973.209,"latency_ms_max":5273.508},"put_total":{"success":2495,"error":969,"timeout":698,"latency_ms_avg":1626.434,"latency_ms_max":5273.619},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":9,"1":6,"9":16,"10":7,"11":17,"12":8,"20":13,"21":12,"22":7,"23":13,"31":9,"32":8,"33":7,"34":10,"35":309,"42":9,"43":11,"44":8,"45":13,"53":11,"54":12,"55":6,"56":15,"64":8,"65":13,"66":9,"67":14,"75":10,"76":14,"77":11,"78":12,"86":6,"87":12,"88":10,"89":10,"97":10,"98":10,"99":6,"100":13,"108":7,"109":14,"110":10,"111":16,"119":7,"120":16,"121":8,"122":16},"consensus_reply_error_by_shard":{"2":19,"13":6,"24":36,"46":3,"57":23,"68":5,"79":20,"90":14,"101":23,"112":18,"123":4},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":171,"forward:STATUS_CODE_INTERNAL":271,"forward:STATUS_CODE_TIMEOUT":527,"put_total:STATUS_CODE_INTERNAL":271,"put_total:STATUS_CODE_TIMEOUT":698}}`
- `notdynamo-data-3`: `{"node":"notdynamo-data-3","observed_leader_override_writes":1172,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":1056,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"forward_to_leader":{"success":1683,"error":512,"timeout":512,"latency_ms_avg":1230.589,"latency_ms_max":5096.909},"consensus_submit":{"success":728,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":713,"error":15,"timeout":15,"latency_ms_avg":205.996,"latency_ms_max":5124.155},"put_total":{"success":2396,"error":527,"timeout":527,"latency_ms_avg":975.716,"latency_ms_max":5183.969},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":15,"1":14,"2":2,"9":13,"10":11,"11":7,"12":12,"13":1,"20":3,"21":10,"22":7,"23":14,"24":3,"31":17,"32":7,"33":19,"34":14,"42":9,"43":13,"44":17,"45":16,"46":2,"53":9,"54":10,"55":5,"56":4,"57":2,"64":5,"65":16,"66":6,"67":7,"68":1,"75":8,"76":15,"77":11,"78":15,"86":4,"87":14,"88":12,"89":7,"97":10,"98":11,"99":10,"100":17,"101":2,"108":13,"109":4,"110":16,"111":6,"112":4,"119":10,"120":11,"121":9,"122":12},"consensus_reply_error_by_shard":{"2":1,"13":1,"24":1,"35":2,"46":1,"57":1,"68":2,"79":2,"90":1,"101":1,"112":1,"123":1},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":15,"forward:STATUS_CODE_TIMEOUT":512,"put_total:STATUS_CODE_TIMEOUT":527}}`
- `notdynamo-data-4`: `{"node":"notdynamo-data-4","observed_leader_override_writes":1516,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":1165,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"forward_to_leader":{"success":2334,"error":852,"timeout":581,"latency_ms_avg":1491.912,"latency_ms_max":5079.031},"consensus_submit":{"success":901,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":885,"error":16,"timeout":16,"latency_ms_avg":179.683,"latency_ms_max":5024.416},"put_total":{"success":3219,"error":868,"timeout":597,"latency_ms_avg":1202.717,"latency_ms_max":5111.032},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":9,"1":11,"2":3,"9":12,"10":9,"11":10,"12":9,"20":10,"21":7,"22":12,"23":7,"24":8,"31":10,"32":13,"33":17,"34":10,"35":306,"42":12,"43":14,"44":10,"45":14,"46":1,"53":11,"54":16,"55":10,"56":9,"57":2,"64":9,"65":15,"66":14,"67":18,"68":1,"75":13,"76":10,"77":13,"78":14,"79":1,"86":15,"87":27,"88":8,"89":8,"90":1,"97":8,"98":8,"99":7,"100":11,"101":1,"108":9,"109":19,"110":8,"111":8,"112":3,"119":10,"120":10,"121":10,"122":11},"consensus_reply_error_by_shard":{"2":1,"13":1,"24":1,"35":2,"46":1,"57":2,"68":1,"79":1,"90":1,"101":2,"112":2,"123":1},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":16,"forward:STATUS_CODE_INTERNAL":271,"forward:STATUS_CODE_TIMEOUT":581,"put_total:STATUS_CODE_INTERNAL":271,"put_total:STATUS_CODE_TIMEOUT":597}}`
- `notdynamo-data-5`: `{"node":"notdynamo-data-5","observed_leader_override_writes":2842,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":1020,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"forward_to_leader":{"success":2090,"error":528,"timeout":528,"latency_ms_avg":1085.119,"latency_ms_max":5169.945},"consensus_submit":{"success":1405,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":1405,"error":0,"timeout":0,"latency_ms_avg":11.195,"latency_ms_max":1147.169},"put_total":{"success":3495,"error":528,"timeout":528,"latency_ms_avg":710.355,"latency_ms_max":5290.873},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":9,"1":10,"2":1,"9":8,"10":14,"11":15,"12":11,"20":10,"21":7,"22":8,"23":10,"24":2,"31":9,"32":9,"33":11,"34":11,"35":1,"42":7,"43":10,"44":16,"45":17,"53":7,"54":15,"55":10,"56":14,"57":3,"64":11,"65":10,"66":12,"67":15,"68":1,"75":9,"76":13,"77":16,"78":8,"79":2,"86":9,"87":14,"88":14,"89":15,"97":8,"98":14,"99":8,"100":8,"101":2,"108":17,"109":9,"110":8,"111":11,"112":2,"119":6,"120":18,"121":14,"122":9},"consensus_reply_error_by_shard":{},"error_code_counts":{"forward:STATUS_CODE_TIMEOUT":528,"put_total:STATUS_CODE_TIMEOUT":528}}`
- `notdynamo-data-6`: `{"node":"notdynamo-data-6","observed_leader_override_writes":2911,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":1180,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"forward_to_leader":{"success":2036,"error":563,"timeout":563,"latency_ms_avg":1198.055,"latency_ms_max":5422.206},"consensus_submit":{"success":1714,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":1714,"error":0,"timeout":0,"latency_ms_avg":43.439,"latency_ms_max":2270.083},"put_total":{"success":3750,"error":563,"timeout":563,"latency_ms_avg":739.543,"latency_ms_max":5611.037},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":8,"1":12,"2":1,"9":19,"10":12,"11":15,"12":9,"13":1,"20":10,"21":18,"22":19,"23":12,"24":4,"31":17,"32":13,"33":14,"34":14,"42":9,"43":12,"44":20,"45":9,"46":1,"53":14,"54":10,"55":7,"56":11,"57":4,"64":11,"65":12,"66":13,"67":9,"75":13,"76":8,"77":12,"78":8,"79":2,"86":8,"87":16,"88":8,"89":7,"90":1,"97":6,"98":9,"99":13,"100":18,"101":2,"108":12,"109":17,"110":10,"111":9,"112":2,"119":7,"120":16,"121":11,"122":8},"consensus_reply_error_by_shard":{},"error_code_counts":{"forward:STATUS_CODE_TIMEOUT":563,"put_total:STATUS_CODE_TIMEOUT":563}}`
- `notdynamo-data-7`: `{"node":"notdynamo-data-7","observed_leader_override_writes":2528,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":1143,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"forward_to_leader":{"success":1533,"error":539,"timeout":539,"latency_ms_avg":1376.353,"latency_ms_max":5129.959},"consensus_submit":{"success":2157,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":2157,"error":0,"timeout":0,"latency_ms_avg":25.255,"latency_ms_max":2388.927},"put_total":{"success":3690,"error":539,"timeout":539,"latency_ms_avg":687.427,"latency_ms_max":5278.221},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":14,"1":4,"2":1,"9":12,"10":10,"11":8,"12":9,"20":7,"21":6,"22":10,"23":9,"24":5,"31":12,"32":14,"33":10,"34":20,"35":1,"42":12,"43":10,"44":13,"45":15,"46":1,"53":10,"54":13,"55":10,"56":7,"57":1,"64":12,"65":18,"66":10,"67":15,"68":2,"75":10,"76":12,"77":13,"78":12,"79":7,"86":8,"87":14,"88":10,"89":10,"97":8,"98":10,"99":16,"100":11,"101":4,"108":13,"109":13,"110":11,"111":18,"112":2,"119":10,"120":5,"121":8,"122":12,"123":1},"consensus_reply_error_by_shard":{},"error_code_counts":{"forward:STATUS_CODE_TIMEOUT":539,"put_total:STATUS_CODE_TIMEOUT":539}}`
- `notdynamo-data-8`: `{"node":"notdynamo-data-8","observed_leader_override_writes":1976,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":1181,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"forward_to_leader":{"success":2036,"error":529,"timeout":529,"latency_ms_avg":1112.094,"latency_ms_max":5107.322},"consensus_submit":{"success":753,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":753,"error":0,"timeout":0,"latency_ms_avg":16.779,"latency_ms_max":2247.482},"put_total":{"success":2789,"error":529,"timeout":529,"latency_ms_avg":863.721,"latency_ms_max":5155.115},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":11,"1":15,"2":4,"9":9,"10":9,"11":9,"12":14,"13":2,"20":12,"21":8,"22":11,"23":11,"24":2,"31":10,"32":7,"33":9,"34":8,"35":1,"42":8,"43":8,"44":10,"45":11,"53":17,"54":9,"55":11,"56":15,"57":1,"64":8,"65":18,"66":12,"67":16,"75":9,"76":13,"77":13,"78":12,"79":3,"86":10,"87":16,"88":10,"89":12,"90":3,"97":12,"98":6,"99":11,"100":9,"108":15,"109":14,"110":12,"111":13,"112":2,"119":6,"120":14,"121":6,"122":10,"123":2},"consensus_reply_error_by_shard":{},"error_code_counts":{"forward:STATUS_CODE_TIMEOUT":529,"put_total:STATUS_CODE_TIMEOUT":529}}`
- `notdynamo-data-9`: `{"node":"notdynamo-data-9","observed_leader_override_writes":3175,"observed_leader_lookup_failures":0,"observed_leader_lookup_skipped_non_replica":1152,"observed_leader_override_retry_attempts":0,"observed_leader_override_retry_success":0,"forward_to_leader":{"success":866,"error":1586,"timeout":985,"latency_ms_avg":3292.113,"latency_ms_max":5305.578},"consensus_submit":{"success":2850,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"consensus_reply":{"success":1961,"error":812,"timeout":812,"latency_ms_avg":1506.145,"latency_ms_max":5062.714},"put_total":{"success":2827,"error":2398,"timeout":1797,"latency_ms_avg":2344.623,"latency_ms_max":5411.968},"delete_total":{"success":0,"error":0,"timeout":0,"latency_ms_avg":0.000,"latency_ms_max":0.000},"forward_error_by_shard":{"0":2,"1":12,"2":2,"10":14,"11":14,"12":15,"20":133,"21":8,"22":12,"23":11,"24":1,"31":369,"32":14,"33":14,"34":24,"42":41,"43":12,"44":18,"45":12,"46":1,"53":108,"54":7,"55":2,"56":15,"57":3,"64":45,"65":12,"66":8,"67":12,"75":35,"76":8,"77":10,"78":13,"79":2,"86":47,"87":20,"88":11,"89":9,"90":3,"97":82,"98":11,"99":8,"100":15,"101":1,"108":203,"109":16,"110":12,"111":13,"112":2,"119":97,"120":9,"121":9,"122":9},"consensus_reply_error_by_shard":{"9":99,"20":55,"31":39,"42":55,"53":71,"64":77,"75":102,"86":60,"97":94,"108":69,"119":91},"error_code_counts":{"consensus_reply:STATUS_CODE_TIMEOUT":812,"forward:STATUS_CODE_INTERNAL":601,"forward:STATUS_CODE_TIMEOUT":985,"put_total:STATUS_CODE_INTERNAL":601,"put_total:STATUS_CODE_TIMEOUT":1797}}`

## Artifacts

- JSON report: `reports/benchmarks/aws/e45_k6_write_heavy_probefix_20260220T131201Z.json`
- Run directory: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220131204`
- Job manifest: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220131204/job.yaml`
- Script configmap: `notdynamo-bench-k6-script-20260220131204`
- Pod placement snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220131204/pod_placement.txt`
- Pods top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220131204/telemetry/pods_top_snapshot.txt`
- Nodes top snapshot: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220131204/telemetry/nodes_top_snapshot.txt`
- Generator top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220131204/telemetry/bench_top_summary.txt`
- Service top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220131204/telemetry/data_top_summary.txt`
- Nodes top summary: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220131204/telemetry/nodes_top_summary.txt`
- Write-stage telemetry samples: `reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220131204/telemetry/write_stage_telemetry_samples.txt`
