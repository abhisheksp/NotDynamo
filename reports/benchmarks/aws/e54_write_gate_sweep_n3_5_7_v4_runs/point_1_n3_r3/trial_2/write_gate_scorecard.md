# NotDynamo Write Gate Scorecard

- Input: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/aws/e2e_http_incluster_k6_latest.json`
- Timestamp (UTC): `2026-02-21T13:14:14Z`

## Key Metrics

| Metric | Value |
|---|---:|
| Success TPS | 236.32 |
| Error rate % | 3.5114 |
| Put timeout fraction of put errors | 0.4020586721564591 |
| Forward error split | 0.7084920226453937 |
| Consensus reply error split | 0.29150797735460626 |
| Generator/service CPU ratio | 0.120 |

## Top Hotspot Shards

| Shard | Error events |
|---:|---:|
| 22 | 879 |
| 8 | 764 |
| 5 | 635 |
| 17 | 588 |
| 26 | 586 |
| 14 | 565 |
| 13 | 541 |
| 27 | 501 |
| 0 | 494 |
| 12 | 482 |

## Acceptance Gate

- success_tps_gte_1000: false
- error_rate_percent_lte_15: true
- put_timeout_fraction_lte_0_60: true
- generator_ratio_lt_0_25: true
