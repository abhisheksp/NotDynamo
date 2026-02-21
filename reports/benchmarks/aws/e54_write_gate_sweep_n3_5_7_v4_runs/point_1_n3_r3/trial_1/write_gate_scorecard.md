# NotDynamo Write Gate Scorecard

- Input: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/aws/e2e_http_incluster_k6_latest.json`
- Timestamp (UTC): `2026-02-21T13:12:24Z`

## Key Metrics

| Metric | Value |
|---|---:|
| Success TPS | 64.31 |
| Error rate % | 17.0519 |
| Put timeout fraction of put errors | 0.3797513746115228 |
| Forward error split | 0.7575902462347598 |
| Consensus reply error split | 0.24240975376524027 |
| Generator/service CPU ratio | 0.022 |

## Top Hotspot Shards

| Shard | Error events |
|---:|---:|
| 22 | 801 |
| 8 | 638 |
| 5 | 588 |
| 17 | 566 |
| 14 | 543 |
| 13 | 529 |
| 26 | 505 |
| 27 | 494 |
| 12 | 459 |
| 0 | 427 |

## Acceptance Gate

- success_tps_gte_1000: false
- error_rate_percent_lte_15: false
- put_timeout_fraction_lte_0_60: true
- generator_ratio_lt_0_25: true
