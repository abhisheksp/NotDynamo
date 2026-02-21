# NotDynamo Write Gate Scorecard

- Input: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/aws/e2e_http_incluster_k6_latest.json`
- Timestamp (UTC): `2026-02-21T13:20:22Z`

## Key Metrics

| Metric | Value |
|---|---:|
| Success TPS | 32.12 |
| Error rate % | 67.2782 |
| Put timeout fraction of put errors | 0.44809094809094807 |
| Forward error split | 0.6587301587301587 |
| Consensus reply error split | 0.3412698412698413 |
| Generator/service CPU ratio | 0.047 |

## Top Hotspot Shards

| Shard | Error events |
|---:|---:|
| 18 | 5064 |
| 17 | 1946 |
| 27 | 1596 |
| 1 | 1077 |
| 6 | 1067 |
| 22 | 994 |
| 13 | 938 |
| 8 | 931 |
| 3 | 926 |
| 25 | 886 |

## Acceptance Gate

- success_tps_gte_1000: false
- error_rate_percent_lte_15: false
- put_timeout_fraction_lte_0_60: true
- generator_ratio_lt_0_25: true
