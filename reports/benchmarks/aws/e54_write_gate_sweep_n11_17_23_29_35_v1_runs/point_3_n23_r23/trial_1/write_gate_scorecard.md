# NotDynamo Write Gate Scorecard

- Input: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/aws/e2e_http_incluster_k6_latest.json`
- Timestamp (UTC): `2026-02-21T14:03:13Z`

## Key Metrics

| Metric | Value |
|---|---:|
| Success TPS | 1170.44 |
| Error rate % | 52.5110 |
| Put timeout fraction of put errors | 0.029783669245552653 |
| Forward error split | 0.5671348083904137 |
| Consensus reply error split | 0.43286519160958625 |
| Generator/service CPU ratio | 0.116 |

## Top Hotspot Shards

| Shard | Error events |
|---:|---:|
| 23 | 30622 |
| 3 | 28903 |
| 24 | 24439 |
| 14 | 23855 |
| 13 | 23162 |
| 1 | 22238 |
| 19 | 21978 |
| 20 | 21967 |
| 9 | 21904 |
| 2 | 21408 |

## Acceptance Gate

- success_tps_gte_1000: true
- error_rate_percent_lte_15: false
- put_timeout_fraction_lte_0_60: true
- generator_ratio_lt_0_25: true
