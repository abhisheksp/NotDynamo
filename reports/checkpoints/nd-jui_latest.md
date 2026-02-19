# Task Checkpoint

- Timestamp (UTC): `2026-02-19 09:00:40Z`
- Issue: `nd-jui`
- Claimed now: `0`
- Status override: `none`
- Closed now: `0`
- Note: `Completed benchmark-first chain through E43 and E40: E42 telemetry pack validated on EKS; E43 lockstep isolated run produced canonical 11/29/35 artifact bundle under reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z.*; E35 closed as superseded; single-AZ index refreshed.`

## Issue Snapshot

```text
◐ nd-jui [EPIC] · E21 Program: Single-AZ True Sharding and Replication   [● P1 · IN_PROGRESS]
Owner: Abhishek Srinivasa Raju Padmavathi · Assignee: Abhishek Srinivasa Raju Padmavathi · Type: epic
Created: 2026-02-18 · Updated: 2026-02-19

DESCRIPTION
Primary roadmap to align runtime behavior with agreed NotDynamo design: per-shard consensus, shard-aware routing, failure correctness, and benchmarkable scale behavior in single-AZ Kubernetes/EKS.

NOTES
[2026-02-18 07:01:30Z] Initialized Beads roadmap and checkpoint workflow
[2026-02-18 22:33:30Z] Benchmark-first roadmap refresh: added E41 (isolation), E42 (telemetry pack), E43 (isolated lockstep rerun n=11/29/35). E41 closed with validation artifacts; E42/E43 queued as P1 before remaining P2 benchmark tasks.
[2026-02-19 09:00:40Z] Completed benchmark-first chain through E43 and E40: E42 telemetry pack validated on EKS; E43 lockstep isolated run produced canonical 11/29/35 artifact bundle under reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z.*; E35 closed as superseded; single-AZ index refreshed.

ACCEPTANCE CRITERIA
All child E22-E33 tasks are closed with verification artifacts and benchmark reports.

LABELS: e21, roadmap, single-az

CHILDREN
  ↳ ✓ nd-jui.1: E22 Shard Metadata v2 (per-shard group + replica set) ● P1
  ↳ ✓ nd-jui.10: E31 Single-AZ horizontal scaling sweeps ● P2
  ↳ ✓ nd-jui.11: E32 EKS benchmark runbook (budget-safe setup/teardown) ● P2
  ↳ ○ nd-jui.12: (EPIC) E33 Multi-AZ resilience phase (deferred) ● P3
  ↳ ✓ nd-jui.13: E34 Lockstep sweep runner hardening ● P2
  ↳ ✓ nd-jui.14: E35 Single-AZ in-cluster lockstep sweep to 35 ● P2
  ↳ ○ nd-jui.15: E36 External-path NLB sweeps at representative scales ● P2
  ↳ ○ nd-jui.16: E37 Generator capacity validation ● P2
  ↳ ○ nd-jui.17: E38 Vertical + horizontal scaling matrix ● P2
  ↳ ✓ nd-jui.18: E39 Bottleneck attribution and optimization backlog ● P2
  ↳ ✓ nd-jui.19: E40 Reproducible benchmark runbook and report index ● P2
  ↳ ✓ nd-jui.2: E23 Multi-Raft runtime (one Raft group per shard) ● P1
  ↳ ✓ nd-jui.3: E24 True shard-aware write path (leader-targeted quorum) ● P1
  ↳ ✓ nd-jui.4: E25 Eventual read path with staleness contract ● P1
  ↳ ✓ nd-jui.5: E26 Rebalance planner for shard movement ● P1
  ↳ ✓ nd-jui.6: E27 Rebalance executor (stream/catchup/switch) ● P1
  ↳ ✓ nd-jui.7: E28 Failure injection harness (pod, leader, node, restart) ● P1
  ↳ ✓ nd-jui.8: E29 Correctness verification matrix for failure modes ● P1
  ↳ ✓ nd-jui.9: E30 External benchmark path via LoadBalancer/NLB ● P2

```

## Ready Work Snapshot

```text

📋 Ready work (4 issues with no blockers):

1. [● P3] [epic] nd-jui.12: E33 Multi-AZ resilience phase (deferred)
2. [● P2] [task] nd-jui.15: E36 External-path NLB sweeps at representative scales
3. [● P2] [task] nd-jui.16: E37 Generator capacity validation
4. [● P2] [task] nd-jui.17: E38 Vertical + horizontal scaling matrix

```

## Git Snapshot

```text
codex/e20-true-raft-integration
b125143 e32: add budget-safe eks runbook and cleanup audit
 M deploy/k8s/overlays/eks/kustomization.yaml
 M reports/benchmarks/aws/benchmark_matrix_latest.json
 M reports/benchmarks/aws/benchmark_matrix_latest.md
 M reports/benchmarks/aws/e2e_http_incluster_latest.json
 M reports/benchmarks/aws/e2e_http_incluster_latest.md
 M reports/checkpoints/nd-jui_latest.md
 M reports/tasks/issues_latest.jsonl
 M reports/tasks/issues_latest_tree.txt
 M scripts/eks/BENCHMARK_PLAN.md
 M scripts/eks/README.md
 M scripts/eks/eks_bench_job_up.sh
 M scripts/eks/eks_bench_matrix.sh
 M scripts/eks/eks_runbook.sh
 M scripts/eks/eks_scaling_sweep.sh
?? deploy/k8s/overlays/eks/patch-eks-scheduling.yaml
?? docs/benchmark/
?? reports/benchmarks/aws/calib_incluster_20260218T091413Z.json
?? reports/benchmarks/aws/calib_incluster_20260218T091413Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260218T084607Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260218T084607Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260218T085108Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260218T085108Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260218T091026Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260218T091026Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260218T091601Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260218T091601Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260218T092150Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260218T092150Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260218T093512Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260218T093512Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260219T080357Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260219T080357Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260219T082626Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260219T082626Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260219T083957Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260219T083957Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260219T085355Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260219T085355Z.md
?? reports/benchmarks/aws/e2e_http_incluster_e42_validation_20260219T075408Z.json
?? reports/benchmarks/aws/e2e_http_incluster_e42_validation_20260219T075408Z.md
?? reports/benchmarks/aws/e43_lockstep_isolated_20260219T075725Z.csv
?? reports/benchmarks/aws/e43_lockstep_isolated_20260219T075725Z_runs/
?? reports/benchmarks/aws/e43_lockstep_isolated_20260219T080941Z.csv
?? reports/benchmarks/aws/e43_lockstep_isolated_20260219T080941Z_runs/
?? reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z.csv
?? reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z.json
?? reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z.md
?? reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z_runs/
?? reports/benchmarks/aws/e43_probe_20260219T081912Z.json
?? reports/benchmarks/aws/e43_probe_20260219T081912Z.md
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218084615/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218085116/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218091033/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218091421/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218091609/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218092158/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218093520/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218165352/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218182151/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218182533/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218182651/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218184807/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218185102/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218190935/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218214957/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218220043/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218220733/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219075411/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219080400/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219081512/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219081914/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219082629/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219083959/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219085357/
?? reports/benchmarks/aws/lockstep_incluster_qmax8_20260218T085005Z.csv
?? reports/benchmarks/aws/lockstep_incluster_qmax8_20260218T085005Z_runs/
?? reports/benchmarks/aws/lockstep_incluster_qmax8_20260218T085732Z.csv
?? reports/benchmarks/aws/lockstep_incluster_qmax8_20260218T085732Z_runs/
?? reports/benchmarks/aws/lockstep_incluster_qmax8_20260218T090710Z.csv
?? reports/benchmarks/aws/lockstep_incluster_qmax8_20260218T090710Z_runs/
?? reports/benchmarks/aws/lockstep_n11_29_35_fast_20260218T170753Z.csv
?? reports/benchmarks/aws/lockstep_n11_29_35_fast_20260218T170753Z_runs/
?? reports/benchmarks/aws/lockstep_qmax8_points_20260218T091507Z/
?? reports/benchmarks/aws/lockstep_smoke_20260218T083836Z.csv
?? reports/benchmarks/aws/lockstep_smoke_20260218T083836Z_runs/
?? reports/benchmarks/aws/lockstep_smoke_20260218T084516Z.csv
?? reports/benchmarks/aws/lockstep_smoke_20260218T084516Z.json
?? reports/benchmarks/aws/lockstep_smoke_20260218T084516Z.md
?? reports/benchmarks/aws/lockstep_smoke_20260218T084516Z_runs/
?? reports/benchmarks/aws/lockstep_sweep_20260218T164732Z.csv
?? reports/benchmarks/aws/lockstep_sweep_20260218T164732Z_runs/
?? reports/benchmarks/aws/lockstep_sweep_latest.csv
?? reports/benchmarks/aws/lockstep_sweep_latest.json
?? reports/benchmarks/aws/lockstep_sweep_latest.md
?? reports/benchmarks/aws/lockstep_to35_20260218T082855Z/
?? reports/benchmarks/aws/manual_highload_incluster_20260218T184750Z.json
?? reports/benchmarks/aws/manual_highload_incluster_20260218T184750Z.md
?? reports/benchmarks/aws/manual_highload_incluster_p8_t64_20260218T185030Z.json
?? reports/benchmarks/aws/manual_highload_incluster_p8_t64_20260218T185030Z.md
?? reports/benchmarks/aws/manual_highload_splitinfra_20260218T214925Z.json
?? reports/benchmarks/aws/manual_highload_splitinfra_20260218T214925Z.md
?? reports/benchmarks/aws/manual_highload_splitinfra_keepjob_20260218T220011Z.json
?? reports/benchmarks/aws/manual_highload_splitinfra_keepjob_20260218T220011Z.md
?? reports/benchmarks/aws/manual_lockstep_n11_29_35_fast_20260218T181946Z/
?? reports/benchmarks/aws/notdynamo-bench-splitprobe-20260218T215356.yaml
?? reports/benchmarks/aws/notdynamo-bench-splitprobe-20260218T215500.yaml
?? reports/benchmarks/aws/notdynamo-manual-bench-20260218191042.summary.json
?? reports/benchmarks/aws/notdynamo-manual-bench-20260218191208.pod_metrics.txt
?? reports/benchmarks/aws/scaling_sweep_latest.csv
?? reports/benchmarks/aws/scaling_sweep_latest.json
?? reports/benchmarks/aws/scaling_sweep_latest.md
?? reports/checkpoints/nd-jui.13_20260218T083352Z.md
?? reports/checkpoints/nd-jui.13_20260218T084800Z.md
?? reports/checkpoints/nd-jui.13_latest.md
?? reports/checkpoints/nd-jui.14_20260218T084955Z.md
?? reports/checkpoints/nd-jui.14_20260218T094449Z.md
?? reports/checkpoints/nd-jui.14_20260218T224816Z.md
?? reports/checkpoints/nd-jui.14_20260219T085709Z.md
?? reports/checkpoints/nd-jui.14_latest.md
?? reports/checkpoints/nd-jui.18_20260218T094504Z.md
?? reports/checkpoints/nd-jui.18_20260218T224819Z.md
?? reports/checkpoints/nd-jui.18_latest.md
?? reports/checkpoints/nd-jui.19_20260218T094506Z.md
?? reports/checkpoints/nd-jui.19_20260218T224818Z.md
?? reports/checkpoints/nd-jui.19_20260219T090021Z.md
?? reports/checkpoints/nd-jui.19_latest.md
?? reports/checkpoints/nd-jui.20_20260218T223255Z.md
?? reports/checkpoints/nd-jui.20_20260218T223256Z.md
?? reports/checkpoints/nd-jui.20_latest.md
?? reports/checkpoints/nd-jui.21_20260218T224821Z.md
?? reports/checkpoints/nd-jui.21_20260219T061614Z.md
?? reports/checkpoints/nd-jui.21_20260219T075711Z.md
?? reports/checkpoints/nd-jui.21_latest.md
?? reports/checkpoints/nd-jui.22_20260219T075712Z.md
?? reports/checkpoints/nd-jui.22_20260219T085653Z.md
?? reports/checkpoints/nd-jui.22_latest.md
?? reports/checkpoints/nd-jui_20260218T223330Z.md
?? reports/checkpoints/nd-jui_20260219T090040Z.md
?? scripts/eks/eks_bench_nodegroup_up.sh
?? scripts/eks/eks_lockstep_sweep.sh
?? scripts/eks/eks_single_az_index.sh
```
