# NotDynamo Write Gate Scorecard

- Input: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/aws/e2e_http_incluster_k6_latest.json`
- Timestamp (UTC): `2026-02-21T13:00:38Z`

## Key Metrics

| Metric | Value |
|---|---:|
| Success TPS | 393.01 |
| Error rate % | 2.8239 |
| Put timeout fraction of put errors | 0.07984395318595579 |
| Forward error split | 0.7513654096228869 |
| Consensus reply error split | 0.24863459037711313 |
| Generator/service CPU ratio | 0.115 |

## Top Hotspot Shards

| Shard | Error events |
|---:|---:|
| 17 | 697 |
| 1 | 520 |
| 3 | 463 |
| 14 | 405 |
| 12 | 369 |
| 8 | 292 |
| 5 | 261 |
| 29 | 217 |
| 16 | 211 |
| 21 | 185 |

## Acceptance Gate

- success_tps_gte_1000: false
- error_rate_percent_lte_15: true
- put_timeout_fraction_lte_0_60: true
- generator_ratio_lt_0_25: true
