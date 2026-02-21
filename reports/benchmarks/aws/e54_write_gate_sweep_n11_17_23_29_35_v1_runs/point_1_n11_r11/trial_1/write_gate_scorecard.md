# NotDynamo Write Gate Scorecard

- Input: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/aws/e2e_http_incluster_k6_latest.json`
- Timestamp (UTC): `2026-02-21T13:40:01Z`

## Key Metrics

| Metric | Value |
|---|---:|
| Success TPS | 95.20 |
| Error rate % | 45.9060 |
| Put timeout fraction of put errors | 0.23191589319044656 |
| Forward error split | 0.9634889597115177 |
| Consensus reply error split | 0.036511040288482295 |
| Generator/service CPU ratio | 0.025 |

## Top Hotspot Shards

| Shard | Error events |
|---:|---:|
| 28 | 57738 |
| 14 | 32580 |
| 16 | 32004 |
| 25 | 21981 |
| 22 | 1339 |
| 23 | 1087 |
| 27 | 984 |
| 15 | 943 |
| 3 | 941 |
| 0 | 895 |

## Acceptance Gate

- success_tps_gte_1000: false
- error_rate_percent_lte_15: false
- put_timeout_fraction_lte_0_60: true
- generator_ratio_lt_0_25: true
