# NotDynamo Write Gate Scorecard

- Input: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/aws/e2e_http_incluster_k6_latest.json`
- Timestamp (UTC): `2026-02-21T13:52:23Z`

## Key Metrics

| Metric | Value |
|---|---:|
| Success TPS | 1527.97 |
| Error rate % | 46.0710 |
| Put timeout fraction of put errors | 0.03590169969550242 |
| Forward error split | 0.7306428767533569 |
| Consensus reply error split | 0.269357123246643 |
| Generator/service CPU ratio | 0.171 |

## Top Hotspot Shards

| Shard | Error events |
|---:|---:|
| 32 | 176916 |
| 15 | 98388 |
| 3 | 65086 |
| 4 | 43977 |
| 17 | 42765 |
| 0 | 39154 |
| 1 | 37225 |
| 25 | 37009 |
| 21 | 33573 |
| 9 | 33137 |

## Acceptance Gate

- success_tps_gte_1000: true
- error_rate_percent_lte_15: false
- put_timeout_fraction_lte_0_60: true
- generator_ratio_lt_0_25: true
