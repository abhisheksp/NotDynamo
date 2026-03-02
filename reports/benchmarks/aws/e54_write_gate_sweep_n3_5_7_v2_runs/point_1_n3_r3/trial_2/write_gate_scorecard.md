# NotDynamo Write Gate Scorecard

- Input: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/aws/e2e_http_incluster_k6_latest.json`
- Timestamp (UTC): `2026-02-21T13:02:25Z`

## Key Metrics

| Metric | Value |
|---|---:|
| Success TPS | 463.57 |
| Error rate % | 0.5692 |
| Put timeout fraction of put errors | 0.07182966775854001 |
| Forward error split | 0.7201684604585868 |
| Consensus reply error split | 0.2798315395414132 |
| Generator/service CPU ratio | 0.181 |

## Top Hotspot Shards

| Shard | Error events |
|---:|---:|
| 17 | 697 |
| 3 | 666 |
| 1 | 549 |
| 12 | 503 |
| 14 | 408 |
| 22 | 365 |
| 8 | 295 |
| 5 | 281 |
| 29 | 247 |
| 16 | 211 |

## Acceptance Gate

- success_tps_gte_1000: false
- error_rate_percent_lte_15: true
- put_timeout_fraction_lte_0_60: true
- generator_ratio_lt_0_25: true
