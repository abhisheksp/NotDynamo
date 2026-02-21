# NotDynamo Write Gate Scorecard

- Input: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/aws/e2e_http_incluster_k6_latest.json`
- Timestamp (UTC): `2026-02-21T14:18:16Z`

## Key Metrics

| Metric | Value |
|---|---:|
| Success TPS | 1778.73 |
| Error rate % | 43.6383 |
| Put timeout fraction of put errors | 0.04773778191149018 |
| Forward error split | 0.5885493967638309 |
| Consensus reply error split | 0.4114506032361691 |
| Generator/service CPU ratio | 0.116 |

## Top Hotspot Shards

| Shard | Error events |
|---:|---:|
| 2 | 31200 |
| 3 | 30753 |
| 15 | 30255 |
| 7 | 28398 |
| 9 | 23629 |
| 1 | 23489 |
| 0 | 22528 |
| 29 | 22020 |
| 30 | 21295 |
| 5 | 21290 |

## Acceptance Gate

- success_tps_gte_1000: true
- error_rate_percent_lte_15: false
- put_timeout_fraction_lte_0_60: true
- generator_ratio_lt_0_25: true
