# NotDynamo Write Gate Scorecard

- Input: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/aws/e2e_http_incluster_k6_latest.json`
- Timestamp (UTC): `2026-02-21T14:05:25Z`

## Key Metrics

| Metric | Value |
|---|---:|
| Success TPS | 2010.02 |
| Error rate % | 49.6724 |
| Put timeout fraction of put errors | 0.0179923852132723 |
| Forward error split | 0.5528082190807397 |
| Consensus reply error split | 0.44719178091926026 |
| Generator/service CPU ratio | 0.200 |

## Top Hotspot Shards

| Shard | Error events |
|---:|---:|
| 23 | 75673 |
| 3 | 60984 |
| 13 | 60432 |
| 24 | 60319 |
| 19 | 57879 |
| 1 | 56725 |
| 9 | 52003 |
| 2 | 51554 |
| 0 | 51223 |
| 25 | 49880 |

## Acceptance Gate

- success_tps_gte_1000: true
- error_rate_percent_lte_15: false
- put_timeout_fraction_lte_0_60: true
- generator_ratio_lt_0_25: true
