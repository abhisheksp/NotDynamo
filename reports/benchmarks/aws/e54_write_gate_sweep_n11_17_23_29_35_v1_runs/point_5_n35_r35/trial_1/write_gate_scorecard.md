# NotDynamo Write Gate Scorecard

- Input: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/aws/e2e_http_incluster_k6_latest.json`
- Timestamp (UTC): `2026-02-21T14:39:51Z`

## Key Metrics

| Metric | Value |
|---|---:|
| Success TPS | 2513.08 |
| Error rate % | 35.6507 |
| Put timeout fraction of put errors | 0.027303705236059395 |
| Forward error split | 0.638929113225762 |
| Consensus reply error split | 0.36107088677423804 |
| Generator/service CPU ratio | 0.092 |

## Top Hotspot Shards

| Shard | Error events |
|---:|---:|
| 3 | 51022 |
| 2 | 36753 |
| 14 | 35824 |
| 25 | 35377 |
| 7 | 35350 |
| 5 | 34946 |
| 0 | 33748 |
| 1 | 30870 |
| 9 | 29329 |
| 15 | 26621 |

## Acceptance Gate

- success_tps_gte_1000: true
- error_rate_percent_lte_15: false
- put_timeout_fraction_lte_0_60: true
- generator_ratio_lt_0_25: true
