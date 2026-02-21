# NotDynamo Write Gate Scorecard

- Input: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/aws/e2e_http_incluster_k6_latest.json`
- Timestamp (UTC): `2026-02-21T14:20:37Z`

## Key Metrics

| Metric | Value |
|---|---:|
| Success TPS | 2380.68 |
| Error rate % | 32.0219 |
| Put timeout fraction of put errors | 0.0475006038059602 |
| Forward error split | 0.5935376540606402 |
| Consensus reply error split | 0.40646234593935987 |
| Generator/service CPU ratio | 0.170 |

## Top Hotspot Shards

| Shard | Error events |
|---:|---:|
| 3 | 86439 |
| 7 | 62626 |
| 2 | 59768 |
| 9 | 50779 |
| 5 | 46219 |
| 21 | 45881 |
| 0 | 45792 |
| 1 | 41378 |
| 30 | 39147 |
| 29 | 38492 |

## Acceptance Gate

- success_tps_gte_1000: true
- error_rate_percent_lte_15: false
- put_timeout_fraction_lte_0_60: true
- generator_ratio_lt_0_25: true
