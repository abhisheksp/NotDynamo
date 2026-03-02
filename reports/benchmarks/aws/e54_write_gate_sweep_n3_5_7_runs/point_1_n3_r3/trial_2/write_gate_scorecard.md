# NotDynamo Write Gate Scorecard

- Input: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/aws/e2e_http_incluster_k6_latest.json`
- Timestamp (UTC): `2026-02-21T12:56:00Z`

## Key Metrics

| Metric | Value |
|---|---:|
| Success TPS | 443.64 |
| Error rate % | 5.2438 |
| Put timeout fraction of put errors | 0.011826685302655628 |
| Forward error split | 0.4086657348672186 |
| Consensus reply error split | 0.5913342651327814 |
| Generator/service CPU ratio | 0.134 |

## Top Hotspot Shards

| Shard | Error events |
|---:|---:|
| 14 | 2158 |
| 17 | 1676 |
| 1 | 1611 |
| 16 | 1259 |
| 3 | 1152 |
| 21 | 906 |
| 20 | 807 |
| 23 | 732 |
| 13 | 685 |
| 29 | 501 |

## Acceptance Gate

- success_tps_gte_1000: false
- error_rate_percent_lte_15: true
- put_timeout_fraction_lte_0_60: true
- generator_ratio_lt_0_25: true
