# NotDynamo Benchmark Bottleneck Backlog (Single-AZ)

Timestamp (UTC): 2026-02-18

## P1 Bottlenecks

1. AWS EC2 vCPU quota ceiling blocks target node counts.
- Evidence: lockstep pre-check fails at count >=11 with `t3.medium` + on-demand quota `16 vCPU` (`max_nodes=8`).
- Expected impact: blocks high-node lockstep scale validation entirely until lifted.
- Risk: benchmark roadmap stalls and produces misleading scale conclusions from low-node-only data.
- Next action: request quota increase or switch account/region with higher quotas.
- Verification metric: `eks_lockstep_sweep.sh --counts 11,...,35` completes all points with no quota-precheck abort.

2. StatefulSet zone spread deadlock with AZ-pinned PVCs.
- Evidence: repeated `FailedScheduling` (`volume node affinity conflict` + `topology spread constraints`) during scale/restart.
- Expected impact: prevents deterministic pod placement and causes intermittent run failures.
- Risk: partial rollouts bias results and increase benchmark flakiness.
- Next action: EKS overlay uses `ScheduleAnyway` for data StatefulSet topology spread.
- Verification metric: 5 consecutive scale transitions complete with zero `FailedScheduling` events.

3. Benchmark orchestration churn causes nodegroup update conflicts.
- Evidence: `ResourceInUseException` during overlapping nodegroup scale operations.
- Expected impact: failed points reduce usable data and extend total execution time.
- Risk: automation retries may thrash cluster state and increase cloud cost.
- Next action: strictly serialize one benchmark operation at a time; no overlapping restore/run loops.
- Verification metric: full sweep log contains zero `ResourceInUseException`.

## P2 Bottlenecks

1. In-cluster benchmark setup overhead is high per point.
- Evidence: each point rebuilds/pushes benchmark image by default before running job.
- Expected impact: shorter point setup time and lower failure surface for long sweeps.
- Risk: stale benchmark image may hide code changes if image reuse is not controlled.
- Next action: reuse prebuilt benchmark image (`--skip-build --image`) in matrix/sweep path.
- Verification metric: median per-point setup time decreases by >=50% vs baseline.

2. Long-running benchmark pod completion variability.
- Evidence: in-cluster jobs intermittently take several minutes even with low operation counts.
- Expected impact: predictable runtime envelope enables larger automated sweeps.
- Risk: aggressive timeouts can prematurely fail valid runs under transient load.
- Next action: add configurable in-cluster wait timeout passthrough and stricter small/medium/large profiles.
- Verification metric: 95% of runs in each profile finish within defined runtime SLO bounds.
