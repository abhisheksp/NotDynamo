# NotDynamo Write Gate Scorecard

- Input: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/aws/e2e_http_incluster_k6_latest.json`
- Timestamp (UTC): `2026-02-21T13:18:28Z`

## Key Metrics

| Metric | Value |
|---|---:|
| Success TPS | 28.48 |
| Error rate % | 48.0640 |
| Put timeout fraction of put errors | 0.9289617486338798 |
| Forward error split | 0.5122444849220805 |
| Consensus reply error split | 0.4877555150779195 |
| Generator/service CPU ratio | 0.027 |

## Top Hotspot Shards

| Shard | Error events |
|---:|---:|
| 3 | 352 |
| 22 | 343 |
| 18 | 289 |
| 6 | 267 |
| 13 | 250 |
| 8 | 230 |
| 20 | 210 |
| 17 | 204 |
| 27 | 192 |
| 1 | 190 |

## Acceptance Gate

- success_tps_gte_1000: false
- error_rate_percent_lte_15: false
- put_timeout_fraction_lte_0_60: false
- generator_ratio_lt_0_25: true
