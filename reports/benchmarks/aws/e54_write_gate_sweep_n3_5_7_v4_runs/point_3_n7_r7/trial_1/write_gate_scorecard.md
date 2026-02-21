# NotDynamo Write Gate Scorecard

- Input: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/aws/e2e_http_incluster_k6_latest.json`
- Timestamp (UTC): `2026-02-21T13:25:57Z`

## Key Metrics

| Metric | Value |
|---|---:|
| Success TPS | 144.01 |
| Error rate % | 24.3219 |
| Put timeout fraction of put errors | 0.5973333333333334 |
| Forward error split | 0.5409855072463768 |
| Consensus reply error split | 0.4590144927536232 |
| Generator/service CPU ratio | 0.042 |

## Top Hotspot Shards

| Shard | Error events |
|---:|---:|
| 6 | 1091 |
| 7 | 1091 |
| 3 | 1077 |
| 17 | 1050 |
| 2 | 638 |
| 23 | 466 |
| 26 | 398 |
| 29 | 333 |
| 15 | 321 |
| 9 | 274 |

## Acceptance Gate

- success_tps_gte_1000: false
- error_rate_percent_lte_15: false
- put_timeout_fraction_lte_0_60: true
- generator_ratio_lt_0_25: true
