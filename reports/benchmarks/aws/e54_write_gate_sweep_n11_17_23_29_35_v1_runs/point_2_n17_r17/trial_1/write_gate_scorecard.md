# NotDynamo Write Gate Scorecard

- Input: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/aws/e2e_http_incluster_k6_latest.json`
- Timestamp (UTC): `2026-02-21T13:50:19Z`

## Key Metrics

| Metric | Value |
|---|---:|
| Success TPS | 1070.63 |
| Error rate % | 35.8906 |
| Put timeout fraction of put errors | 0.09105781555690481 |
| Forward error split | 0.6977613618475792 |
| Consensus reply error split | 0.3022386381524208 |
| Generator/service CPU ratio | 0.083 |

## Top Hotspot Shards

| Shard | Error events |
|---:|---:|
| 32 | 42614 |
| 15 | 24182 |
| 3 | 20067 |
| 0 | 13929 |
| 17 | 12687 |
| 16 | 11988 |
| 9 | 11937 |
| 4 | 11867 |
| 1 | 11248 |
| 19 | 11022 |

## Acceptance Gate

- success_tps_gte_1000: true
- error_rate_percent_lte_15: false
- put_timeout_fraction_lte_0_60: true
- generator_ratio_lt_0_25: true
