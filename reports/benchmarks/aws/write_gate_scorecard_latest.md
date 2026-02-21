# NotDynamo Write Gate Scorecard

- Input: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/aws/e2e_http_incluster_k6_latest.json`
- Timestamp (UTC): `2026-02-21T14:42:16Z`

## Key Metrics

| Metric | Value |
|---|---:|
| Success TPS | 2910.66 |
| Error rate % | 34.6474 |
| Put timeout fraction of put errors | 0.01466098599458101 |
| Forward error split | 0.6352853147539375 |
| Consensus reply error split | 0.3647146852460625 |
| Generator/service CPU ratio | 0.161 |

## Top Hotspot Shards

| Shard | Error events |
|---:|---:|
| 5 | 101088 |
| 3 | 98528 |
| 14 | 80058 |
| 25 | 79208 |
| 7 | 77051 |
| 0 | 75334 |
| 4 | 74038 |
| 1 | 65049 |
| 9 | 63169 |
| 15 | 58027 |

## Acceptance Gate

- success_tps_gte_1000: true
- error_rate_percent_lte_15: false
- put_timeout_fraction_lte_0_60: true
- generator_ratio_lt_0_25: true
