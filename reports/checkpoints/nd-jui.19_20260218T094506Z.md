# Task Checkpoint

- Timestamp (UTC): `2026-02-18 09:45:06Z`
- Issue: `nd-jui.19`
- Claimed now: `1`
- Status override: `in_progress`
- Closed now: `0`
- Note: `Start E40: added single-AZ artifact index generator scripts/eks/eks_single_az_index.sh and generated docs/benchmark/SINGLE_AZ_INDEX.md`

## Issue Snapshot

```text
◐ nd-jui.19 · E40 Reproducible benchmark runbook and report index   [● P2 · IN_PROGRESS]
Owner: Abhishek Srinivasa Raju Padmavathi · Assignee: Abhishek Srinivasa Raju Padmavathi · Type: task
Created: 2026-02-18 · Updated: 2026-02-18

DESCRIPTION
Provide one-command reproducible benchmark execution and consolidated index of generated reports/artifacts for single-AZ path.

NOTES
[2026-02-18 09:45:06Z] Start E40: added single-AZ artifact index generator scripts/eks/eks_single_az_index.sh and generated docs/benchmark/SINGLE_AZ_INDEX.md

ACCEPTANCE CRITERIA
Runbook commands succeed from clean context and report index points to all current single-AZ benchmark artifacts.

LABELS: benchmark, roadmap, single-az

PARENT
  ↑ ◐ nd-jui: (EPIC) E21 Program: Single-AZ True Sharding and Replication ● P1

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
 M reports/tasks/issues_latest.jsonl
 M reports/tasks/issues_latest_tree.txt
 M scripts/eks/BENCHMARK_PLAN.md
 M scripts/eks/README.md
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
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218084615/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218085116/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218091033/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218091421/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218091609/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218092158/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218093520/
?? reports/benchmarks/aws/lockstep_incluster_qmax8_20260218T085005Z.csv
?? reports/benchmarks/aws/lockstep_incluster_qmax8_20260218T085005Z_runs/
?? reports/benchmarks/aws/lockstep_incluster_qmax8_20260218T085732Z.csv
?? reports/benchmarks/aws/lockstep_incluster_qmax8_20260218T085732Z_runs/
?? reports/benchmarks/aws/lockstep_incluster_qmax8_20260218T090710Z.csv
?? reports/benchmarks/aws/lockstep_incluster_qmax8_20260218T090710Z_runs/
?? reports/benchmarks/aws/lockstep_qmax8_points_20260218T091507Z/
?? reports/benchmarks/aws/lockstep_smoke_20260218T083836Z.csv
?? reports/benchmarks/aws/lockstep_smoke_20260218T083836Z_runs/
?? reports/benchmarks/aws/lockstep_smoke_20260218T084516Z.csv
?? reports/benchmarks/aws/lockstep_smoke_20260218T084516Z.json
?? reports/benchmarks/aws/lockstep_smoke_20260218T084516Z.md
?? reports/benchmarks/aws/lockstep_smoke_20260218T084516Z_runs/
?? reports/benchmarks/aws/lockstep_sweep_latest.csv
?? reports/benchmarks/aws/lockstep_sweep_latest.json
?? reports/benchmarks/aws/lockstep_sweep_latest.md
?? reports/benchmarks/aws/lockstep_to35_20260218T082855Z/
?? reports/benchmarks/aws/scaling_sweep_latest.csv
?? reports/benchmarks/aws/scaling_sweep_latest.json
?? reports/benchmarks/aws/scaling_sweep_latest.md
?? reports/checkpoints/nd-jui.13_20260218T083352Z.md
?? reports/checkpoints/nd-jui.13_20260218T084800Z.md
?? reports/checkpoints/nd-jui.13_latest.md
?? reports/checkpoints/nd-jui.14_20260218T084955Z.md
?? reports/checkpoints/nd-jui.14_20260218T094449Z.md
?? reports/checkpoints/nd-jui.14_latest.md
?? reports/checkpoints/nd-jui.18_20260218T094504Z.md
?? reports/checkpoints/nd-jui.18_latest.md
?? reports/checkpoints/nd-jui.19_20260218T094506Z.md
?? scripts/eks/eks_lockstep_sweep.sh
?? scripts/eks/eks_single_az_index.sh
```
