# NotDynamo Write Gate Scorecard

- Input: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/aws/e2e_http_incluster_k6_latest.json`
- Timestamp (UTC): `2026-02-21T12:50:38Z`

## Key Metrics

| Metric | Value |
|---|---:|
| Success TPS | 338.23 |
| Error rate % | 6.6630 |
| Put timeout fraction of put errors | 0.02899728997289973 |
| Forward error split | 0.4078590785907859 |
| Consensus reply error split | 0.592140921409214 |
| Generator/service CPU ratio | 0.101 |

## Top Hotspot Shards

| Shard | Error events |
|---:|---:|
| 17 | 1644 |
| 14 | 1355 |
| 3 | 1129 |
| 21 | 898 |
| 20 | 425 |
| 1 | 53 |
| 13 | 48 |
| 26 | 45 |
| 28 | 27 |
| 19 | 27 |

## Acceptance Gate

- success_tps_gte_1000: false
- error_rate_percent_lte_15: true
- put_timeout_fraction_lte_0_60: true
- generator_ratio_lt_0_25: true
