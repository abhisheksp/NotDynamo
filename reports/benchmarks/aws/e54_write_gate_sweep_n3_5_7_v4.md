# NotDynamo EKS Write Gate Sweep

- Timestamp (UTC): `2026-02-21T13:09:37Z`
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Namespace: `notdynamo`
- Nodegroup: `notdynamo-ng`
- Node type: `t3.large`
- Node counts: `3,5,7`
- Repeats per point: `2`
- Data replicas mode: `lockstep`
- Status: `PASS`
- Best median success TPS: `node_count=7 data_replicas=7 success_tps=295.15`
- Cost guard: `max_daily_usd=20`, estimated max daily (compute+control only): `16.3776`

## Median By Point

| Point | Node count | Data replicas | Median success TPS | Median error % | Median timeout fraction | Median forward split | Median consensus split | Median forward-hop ratio | Median gen/service CPU ratio | Gate success>=1000 | Gate err<=15% | Gate timeout<=0.60 | Gate gen ratio<0.25 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|---|---|
| 1 | 3 | 3 | 150.315 | 10.281649999999999 | 0.3909050233839909 | 0.7330411344400767 | 0.26695886555992326 | 0.4339955 | 0.071 | false | true | true | true |
| 2 | 5 | 5 | 30.299999999999997 | 57.671099999999996 | 0.688526348362414 | 0.5854873218261196 | 0.4145126781738804 | 0.5797325 | 0.037 | false | false | false | true |
| 3 | 7 | 7 | 295.15 | 23.157249999999998 | 0.4509487811884032 | 0.6565430314587455 | 0.3434569685412546 | 0.6379130714285715 | 0.059 | false | false | true | true |

## Trial Runs

| Point | Trial | Node count | Data replicas | Status | Success TPS | Error % | Timeout fraction | Forward split | Consensus split | Forward-hop ratio | Gen/Svc CPU ratio | Scorecard |
|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---|
| 1 | 1 | 3 | 3 | PASS | 64.31 | 17.0519 | 0.3797513746115228 | 0.7575902462347598 | 0.24240975376524027 | 0.46262699999999995 | 0.022 | `reports/benchmarks/aws/e54_write_gate_sweep_n3_5_7_v4_runs/point_1_n3_r3/trial_1/write_gate_scorecard.json` |
| 1 | 2 | 3 | 3 | PASS | 236.32 | 3.5114 | 0.4020586721564591 | 0.7084920226453937 | 0.29150797735460626 | 0.405364 | 0.120 | `reports/benchmarks/aws/e54_write_gate_sweep_n3_5_7_v4_runs/point_1_n3_r3/trial_2/write_gate_scorecard.json` |
| 2 | 1 | 5 | 5 | PASS | 28.48 | 48.0640 | 0.9289617486338798 | 0.5122444849220805 | 0.4877555150779195 | 0.5395492 | 0.027 | `reports/benchmarks/aws/e54_write_gate_sweep_n3_5_7_v4_runs/point_2_n5_r5/trial_1/write_gate_scorecard.json` |
| 2 | 2 | 5 | 5 | PASS | 32.12 | 67.2782 | 0.44809094809094807 | 0.6587301587301587 | 0.3412698412698413 | 0.6199158 | 0.047 | `reports/benchmarks/aws/e54_write_gate_sweep_n3_5_7_v4_runs/point_2_n5_r5/trial_2/write_gate_scorecard.json` |
| 3 | 1 | 7 | 7 | PASS | 144.01 | 24.3219 | 0.5973333333333334 | 0.5409855072463768 | 0.4590144927536232 | 0.6210534285714286 | 0.042 | `reports/benchmarks/aws/e54_write_gate_sweep_n3_5_7_v4_runs/point_3_n7_r7/trial_1/write_gate_scorecard.json` |
| 3 | 2 | 7 | 7 | PASS | 446.29 | 21.9926 | 0.3045642290434731 | 0.772100555671114 | 0.22789944432888598 | 0.6547727142857143 | 0.076 | `reports/benchmarks/aws/e54_write_gate_sweep_n3_5_7_v4_runs/point_3_n7_r7/trial_2/write_gate_scorecard.json` |

## Artifacts

- JSON summary: `reports/benchmarks/aws/e54_write_gate_sweep_n3_5_7_v4.json`
- CSV summary: `reports/benchmarks/aws/e54_write_gate_sweep_n3_5_7_v4.csv`
- Run reports root: `reports/benchmarks/aws/e54_write_gate_sweep_n3_5_7_v4_runs`
