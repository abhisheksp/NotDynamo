# NotDynamo EKS Write Gate Sweep

- Timestamp (UTC): `2026-02-21T13:35:06Z`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Nodegroup: `notdynamo-ng`
- Node type: `t3.large`
- Node counts: `11,17,23,29,35`
- Repeats per point: `2`
- Data replicas mode: `lockstep`
- Shard count effective: `33` (required min for sweep: `33`)
- Status: `PASS`
- Best median success TPS: `node_count=35 data_replicas=35 success_tps=2711.87`
- Cost guard: `max_daily_usd=20`, estimated max daily (compute+control only): `72.2880`

## Median By Point

| Point | Node count | Data replicas | Median success TPS | Median error % | Median timeout fraction | Median forward split | Median consensus split | Median forward-hop ratio | Median gen/service CPU ratio | Gate success>=1000 | Gate err<=15% | Gate timeout<=0.60 | Gate gen ratio<0.25 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|---|---|
| 1 | 11 | 11 | 195.86499999999998 | 42.50275 | 0.2316459013575923 | 0.9229961090467564 | 0.07700389095324352 | 0.7531550909090909 | 0.05500000000000001 | false | false | true | true |
| 2 | 17 | 17 | 1299.3000000000002 | 40.9808 | 0.06347975762620361 | 0.7142021193004681 | 0.28579788069953194 | 0.6676223823529412 | 0.127 | true | false | true | true |
| 3 | 23 | 23 | 1590.23 | 51.0917 | 0.023888027229412474 | 0.5599715137355767 | 0.44002848626442326 | 0.6126294782608696 | 0.158 | true | false | true | true |
| 4 | 29 | 29 | 2079.705 | 37.8301 | 0.04761919285872519 | 0.5910435254122355 | 0.4089564745877645 | 0.6355765172413792 | 0.14300000000000002 | true | false | true | true |
| 5 | 35 | 35 | 2711.87 | 35.14905 | 0.020982345615320204 | 0.6371072139898497 | 0.3628927860101503 | 0.6454783285714285 | 0.1265 | true | false | true | true |

## Trial Runs

| Point | Trial | Node count | Data replicas | Status | Success TPS | Error % | Timeout fraction | Forward split | Consensus split | Forward-hop ratio | Gen/Svc CPU ratio | Scorecard |
|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---|
| 1 | 1 | 11 | 11 | PASS | 95.20 | 45.9060 | 0.23191589319044656 | 0.9634889597115177 | 0.036511040288482295 | 0.7811416363636364 | 0.025 | `reports/benchmarks/aws/e54_write_gate_sweep_n11_17_23_29_35_v1_runs/point_1_n11_r11/trial_1/write_gate_scorecard.json` |
| 1 | 2 | 11 | 11 | PASS | 296.53 | 39.0995 | 0.23137590952473805 | 0.8825032583819953 | 0.11749674161800475 | 0.7251685454545455 | 0.085 | `reports/benchmarks/aws/e54_write_gate_sweep_n11_17_23_29_35_v1_runs/point_1_n11_r11/trial_2/write_gate_scorecard.json` |
| 2 | 1 | 17 | 17 | PASS | 1070.63 | 35.8906 | 0.09105781555690481 | 0.6977613618475792 | 0.3022386381524208 | 0.6635375294117648 | 0.083 | `reports/benchmarks/aws/e54_write_gate_sweep_n11_17_23_29_35_v1_runs/point_2_n17_r17/trial_1/write_gate_scorecard.json` |
| 2 | 2 | 17 | 17 | PASS | 1527.97 | 46.0710 | 0.03590169969550242 | 0.7306428767533569 | 0.269357123246643 | 0.6717072352941176 | 0.171 | `reports/benchmarks/aws/e54_write_gate_sweep_n11_17_23_29_35_v1_runs/point_2_n17_r17/trial_2/write_gate_scorecard.json` |
| 3 | 1 | 23 | 23 | PASS | 1170.44 | 52.5110 | 0.029783669245552653 | 0.5671348083904137 | 0.43286519160958625 | 0.6157843043478262 | 0.116 | `reports/benchmarks/aws/e54_write_gate_sweep_n11_17_23_29_35_v1_runs/point_3_n23_r23/trial_1/write_gate_scorecard.json` |
| 3 | 2 | 23 | 23 | PASS | 2010.02 | 49.6724 | 0.0179923852132723 | 0.5528082190807397 | 0.44719178091926026 | 0.609474652173913 | 0.200 | `reports/benchmarks/aws/e54_write_gate_sweep_n11_17_23_29_35_v1_runs/point_3_n23_r23/trial_2/write_gate_scorecard.json` |
| 4 | 1 | 29 | 29 | PASS | 1778.73 | 43.6383 | 0.04773778191149018 | 0.5885493967638309 | 0.4114506032361691 | 0.6371692758620688 | 0.116 | `reports/benchmarks/aws/e54_write_gate_sweep_n11_17_23_29_35_v1_runs/point_4_n29_r29/trial_1/write_gate_scorecard.json` |
| 4 | 2 | 29 | 29 | PASS | 2380.68 | 32.0219 | 0.0475006038059602 | 0.5935376540606402 | 0.40646234593935987 | 0.6339837586206896 | 0.170 | `reports/benchmarks/aws/e54_write_gate_sweep_n11_17_23_29_35_v1_runs/point_4_n29_r29/trial_2/write_gate_scorecard.json` |
| 5 | 1 | 35 | 35 | PASS | 2513.08 | 35.6507 | 0.027303705236059395 | 0.638929113225762 | 0.36107088677423804 | 0.6467183428571427 | 0.092 | `reports/benchmarks/aws/e54_write_gate_sweep_n11_17_23_29_35_v1_runs/point_5_n35_r35/trial_1/write_gate_scorecard.json` |
| 5 | 2 | 35 | 35 | PASS | 2910.66 | 34.6474 | 0.01466098599458101 | 0.6352853147539375 | 0.3647146852460625 | 0.6442383142857142 | 0.161 | `reports/benchmarks/aws/e54_write_gate_sweep_n11_17_23_29_35_v1_runs/point_5_n35_r35/trial_2/write_gate_scorecard.json` |

## Artifacts

- JSON summary: `reports/benchmarks/aws/e54_write_gate_sweep_n11_17_23_29_35_v1.json`
- CSV summary: `reports/benchmarks/aws/e54_write_gate_sweep_n11_17_23_29_35_v1.csv`
- Run reports root: `reports/benchmarks/aws/e54_write_gate_sweep_n11_17_23_29_35_v1_runs`
