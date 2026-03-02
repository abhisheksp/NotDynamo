# Task Checkpoint

- Timestamp (UTC): `2026-02-18 22:48:16Z`
- Issue: `nd-jui.14`
- Claimed now: `0`
- Status override: `open`
- Closed now: `0`
- Note: `WIP normalization: moved back to open; original lockstep-to-35 scope is being superseded by isolated benchmark-first chain (E42->E43). Existing artifacts retained for reference.`

## Issue Snapshot

```text
○ nd-jui.14 · E35 Single-AZ in-cluster lockstep sweep to 35   [● P2 · OPEN]
Owner: Abhishek Srinivasa Raju Padmavathi · Assignee: Abhishek Srinivasa Raju Padmavathi · Type: task
Created: 2026-02-18 · Updated: 2026-02-18

DESCRIPTION
Execute in-cluster sweep at lockstep points 11,17,23,29,35 with RF=3 and data replicas=node count; capture throughput/latency/errors and cost context.

NOTES
[2026-02-18 08:49:55Z] Start E35: run lockstep in-cluster sweep at quota-feasible counts (3,4,5,6,7,8); account quota blocks >=11 nodes on t3.medium
[2026-02-18 09:44:49Z] Progress: quota pre-check enforced (max_nodes=8 on current account/region for t3.medium on-demand). Lockstep point runs completed for n=5 and n=6 under reports/benchmarks/aws/lockstep_qmax8_points_20260218T091507Z; n=7/n=8 remain pending due long-running benchmark jobs and operational churn.
[2026-02-18 22:48:16Z] WIP normalization: moved back to open; original lockstep-to-35 scope is being superseded by isolated benchmark-first chain (E42->E43). Existing artifacts retained for reference.

ACCEPTANCE CRITERIA
Report bundle includes per-point artifacts and summary matrix with TPS, p95/p99, error rate, shard replicas per node, and estimated hourly cost.

LABELS: benchmark, roadmap, single-az

PARENT
  ↑ ◐ nd-jui: (EPIC) E21 Program: Single-AZ True Sharding and Replication ● P1

```

## Ready Work Snapshot

```text

📋 Ready work (6 issues with no blockers):

1. [● P3] [epic] nd-jui.12: E33 Multi-AZ resilience phase (deferred)
2. [● P2] [task] nd-jui.14: E35 Single-AZ in-cluster lockstep sweep to 35
   Assignee: Abhishek Srinivasa Raju Padmavathi
3. [● P2] [task] nd-jui.15: E36 External-path NLB sweeps at representative scales
4. [● P2] [task] nd-jui.16: E37 Generator capacity validation
5. [● P2] [task] nd-jui.17: E38 Vertical + horizontal scaling matrix
6. [● P1] [task] nd-jui.21: E42 Benchmark saturation telemetry pack

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
?? reports/checkpoints/nd-jui.14_latest.md
?? reports/checkpoints/nd-jui.18_20260218T094504Z.md
?? reports/checkpoints/nd-jui.18_latest.md
?? reports/checkpoints/nd-jui.19_20260218T094506Z.md
?? reports/checkpoints/nd-jui.19_latest.md
?? reports/checkpoints/nd-jui.20_20260218T223255Z.md
?? reports/checkpoints/nd-jui.20_20260218T223256Z.md
?? reports/checkpoints/nd-jui.20_latest.md
?? reports/checkpoints/nd-jui_20260218T223330Z.md
?? scripts/eks/eks_bench_nodegroup_up.sh
?? scripts/eks/eks_lockstep_sweep.sh
?? scripts/eks/eks_single_az_index.sh
```
