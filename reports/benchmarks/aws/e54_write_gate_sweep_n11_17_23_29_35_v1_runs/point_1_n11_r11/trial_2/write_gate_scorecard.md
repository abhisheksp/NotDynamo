# NotDynamo Write Gate Scorecard

- Input: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/aws/e2e_http_incluster_k6_latest.json`
- Timestamp (UTC): `2026-02-21T13:42:02Z`

## Key Metrics

| Metric | Value |
|---|---:|
| Success TPS | 296.53 |
| Error rate % | 39.0995 |
| Put timeout fraction of put errors | 0.23137590952473805 |
| Forward error split | 0.8825032583819953 |
| Consensus reply error split | 0.11749674161800475 |
| Generator/service CPU ratio | 0.085 |

## Top Hotspot Shards

| Shard | Error events |
|---:|---:|
| 28 | 57738 |
| 14 | 33497 |
| 16 | 33221 |
| 25 | 21981 |
| 3 | 4794 |
| 22 | 4752 |
| 24 | 4357 |
| 26 | 4307 |
| 2 | 4022 |
| 0 | 3955 |

## Acceptance Gate

- success_tps_gte_1000: false
- error_rate_percent_lte_15: false
- put_timeout_fraction_lte_0_60: true
- generator_ratio_lt_0_25: true
