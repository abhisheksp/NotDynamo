# NotDynamo Benchmark Wrap-Up (Single-AZ EKS)

- Generated (UTC): `2026-02-22T22:08:01Z`
- Formal benchmark path: `in-cluster-k6`
- Throughput semantics: **cluster-wide aggregate TPS**

## Executive Summary

- Read upper-bound evidence (existing single-point read-hit k6 run) best median success TPS: `N=3 => 9883.41` (attempted: `9883.41`)
- Write upper-bound baseline (E54 write-heavy mixed, 90% writes / 10% reads) best median cluster success TPS: `N=35 => 2711.87`
- Write attempted TPS split is reported as exact only if preserved by sweep artifacts; for E54 it may be estimated from success TPS + error rate + configured mix.

## Methodology and Benchmark Categories

- Read upper-bound: existing single-point read-hit-heavy in-cluster k6 artifact reused for wrap-up (budget-limited fallback; no new E56 N-sweep in this session).
- Write upper-bound baseline: reused E54 in-cluster write-heavy mixed sweep (formal gate profile).
- External LoadBalancer/NLB path remains a visibility benchmark, not a gating benchmark, for this wrap-up.

## Read Upper-Bound Results

- Source (Read k6 artifact): `reports/benchmarks/aws/e48_k6_read_hit_heavy_fix_20260219T222038Z.json`

| N (nodes=data replicas) | Success TPS | Attempted TPS | Error % | p95 (ms) | p99 (ms) | Read misses | Write count | Gen/Svc CPU ratio |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 3 | 9883.41 | 9883.41 | 0 | 61.183 | 77.536 | 0 | 0 | 0 |

## Write Upper-Bound Baseline Results (E54, Write-Heavy Mixed)

- Source: `reports/benchmarks/aws/e54_write_gate_sweep_n11_17_23_29_35_v1.json`
- Profile caveat: `read_ratio=0.10` (not pure 100% write throughput)
- Attempted TPS split fallback method (when exact not preserved): attempted_total_tps = success_tps / (1 - error_rate_percent/100); split by configured read/write ratio

| N | Success TPS | Attempted TPS (total) | Attempted TPS (write) | Error % | Timeout frac | Forward split | Consensus split | Forward-hop ratio | Gen/Svc CPU ratio | Split mode |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 11 | 195.865 | 340.651 | 306.586 | 42.503 | 0.232 | 0.923 | 0.077 | 0.753 | 0.055 | estimated_from_success_tps_error_rate_and_configured_mix |
| 17 | 1299.3 | 2201.487 | 1981.338 | 40.981 | 0.063 | 0.714 | 0.286 | 0.668 | 0.127 | estimated_from_success_tps_error_rate_and_configured_mix |
| 23 | 1590.23 | 3251.452 | 2926.307 | 51.092 | 0.024 | 0.56 | 0.44 | 0.613 | 0.158 | estimated_from_success_tps_error_rate_and_configured_mix |
| 29 | 2079.705 | 3345.196 | 3010.676 | 37.83 | 0.048 | 0.591 | 0.409 | 0.636 | 0.143 | estimated_from_success_tps_error_rate_and_configured_mix |
| 35 | 2711.87 | 4181.697 | 3763.527 | 35.149 | 0.021 | 0.637 | 0.363 | 0.645 | 0.127 | estimated_from_success_tps_error_rate_and_configured_mix |

## Write Error Interpretation

- Client-visible k6 error rate is operation-level failure rate (non-success GET/PUT outcomes from the benchmark perspective).
- Internal write attribution in E54 comes from sampled service telemetry and splits write-stage failures into:
  - `forward_to_leader` failures
  - `consensus_reply` failures
- Lower timeout fraction at higher N indicates fewer timeout-dominant failures; remaining failures are still materially non-timeout and forward-path-heavy.
- `forward_hop_ratio_avg` tracks how often writes were forwarded to another node (proxy for leader-unaware routing pressure).

## Bottleneck Analysis (Known vs Unknown)

### Known (from current data)

- Horizontal scaling improves cluster success TPS substantially in E54.
- Write error rate remains materially above a 15% SLA gate across tested N values.
- Timeout fraction falls at higher N, implying non-timeout failures dominate remaining errors.
- Forward path metrics (forward_error_fraction and forward_hop_ratio_avg) remain high, indicating routing/leader-forward pressure.

### Evidence by Point (Write Path)

| N | Success TPS | Error % | Timeout frac | Forward split | Consensus split | Forward-hop ratio | Gen/Svc CPU ratio |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 11 | 195.865 | 42.503 | 0.232 | 0.923 | 0.077 | 0.753 | 0.055 |
| 17 | 1299.3 | 40.981 | 0.063 | 0.714 | 0.286 | 0.668 | 0.127 |
| 23 | 1590.23 | 51.092 | 0.024 | 0.56 | 0.44 | 0.613 | 0.158 |
| 29 | 2079.705 | 37.83 | 0.048 | 0.591 | 0.409 | 0.636 | 0.143 |
| 35 | 2711.87 | 35.149 | 0.021 | 0.637 | 0.363 | 0.645 | 0.127 |

### Unknown / Not Proven Yet

- Pure 100% write throughput ceiling has not been measured in the same lockstep N sweep format.
- External-LB production-path overhead is not included in the formal gating numbers shown here.

## Benchmark Caveats

- Read benchmark is an in-cluster path (benchmark pods inside EKS); it does not include external LB ingress hop.
- Read upper-bound currently reflects **existing single-point evidence** only because the planned read N-sweep was skipped to stay within AWS spend limits.
- k6 GET `404` counts as success in the workload script. Read-hit upper-bound runs therefore explicitly report `read_not_found_count` and expect it to be zero (or documented if non-zero).
- E54 write attempted read/write TPS split may be estimated if exact per-trial k6 JSONs were not preserved by the sweep artifacts.

## Next Engineering Steps

1. Reduce write forward-hop pressure — Write errors are still forward-path heavy; improving leader-aware routing and reducing forwarding should lower non-timeout failures.
1. Add exact attempted write/read TPS capture to write sweep artifacts — E54 required derived attempted TPS because per-trial k6 JSON paths were not preserved in the sweep run artifacts.
1. Run external-LB visibility benchmark after in-cluster baseline — Validates production-like ingress path overhead without changing in-cluster gating methodology.

## Artifacts

- Wrap-up JSON: `reports/benchmarks/aws/benchmark_wrapup_20260222_v1.json`
- Wrap-up CSV: `reports/benchmarks/aws/benchmark_wrapup_20260222_v1.csv`
- Read k6 artifact: `reports/benchmarks/aws/e48_k6_read_hit_heavy_fix_20260219T222038Z.json`
- Write sweep JSON: `reports/benchmarks/aws/e54_write_gate_sweep_n11_17_23_29_35_v1.json`
