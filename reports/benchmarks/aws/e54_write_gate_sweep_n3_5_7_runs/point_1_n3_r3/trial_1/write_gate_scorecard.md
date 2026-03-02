# NotDynamo Write Gate Scorecard

- Input: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/aws/e2e_http_incluster_k6_latest.json`
- Timestamp (UTC): `2026-02-21T12:54:13Z`

## Key Metrics

| Metric | Value |
|---|---:|
| Success TPS | 531.87 |
| Error rate % | 2.2559 |
| Put timeout fraction of put errors | 0.019533369506239826 |
| Forward error split | 0.4040513655272201 |
| Consensus reply error split | 0.5959486344727799 |
| Generator/service CPU ratio | 0.137 |

## Top Hotspot Shards

| Shard | Error events |
|---:|---:|
| 17 | 1676 |
| 14 | 1431 |
| 3 | 1152 |
| 21 | 906 |
| 20 | 753 |
| 29 | 443 |
| 7 | 433 |
| 12 | 419 |
| 8 | 397 |
| 28 | 339 |

## Acceptance Gate

- success_tps_gte_1000: false
- error_rate_percent_lte_15: true
- put_timeout_fraction_lte_0_60: true
- generator_ratio_lt_0_25: true
