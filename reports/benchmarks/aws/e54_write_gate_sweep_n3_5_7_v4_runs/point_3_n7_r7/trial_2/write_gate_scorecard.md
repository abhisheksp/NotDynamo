# NotDynamo Write Gate Scorecard

- Input: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/aws/e2e_http_incluster_k6_latest.json`
- Timestamp (UTC): `2026-02-21T13:27:52Z`

## Key Metrics

| Metric | Value |
|---|---:|
| Success TPS | 446.29 |
| Error rate % | 21.9926 |
| Put timeout fraction of put errors | 0.3045642290434731 |
| Forward error split | 0.772100555671114 |
| Consensus reply error split | 0.22789944432888598 |
| Generator/service CPU ratio | 0.076 |

## Top Hotspot Shards

| Shard | Error events |
|---:|---:|
| 5 | 17291 |
| 26 | 13793 |
| 19 | 13474 |
| 17 | 5736 |
| 3 | 5601 |
| 6 | 4633 |
| 7 | 2565 |
| 2 | 2209 |
| 0 | 1849 |
| 25 | 1609 |

## Acceptance Gate

- success_tps_gte_1000: false
- error_rate_percent_lte_15: false
- put_timeout_fraction_lte_0_60: true
- generator_ratio_lt_0_25: true
