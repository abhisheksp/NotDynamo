# Task Checkpoint

- Timestamp (UTC): `2026-02-18 08:49:55Z`
- Issue: `nd-jui.14`
- Claimed now: `1`
- Status override: `in_progress`
- Closed now: `0`
- Note: `Start E35: run lockstep in-cluster sweep at quota-feasible counts (3,4,5,6,7,8); account quota blocks >=11 nodes on t3.medium`

## Issue Snapshot

```text
◐ nd-jui.14 · E35 Single-AZ in-cluster lockstep sweep to 35   [● P2 · IN_PROGRESS]
Owner: Abhishek Srinivasa Raju Padmavathi · Assignee: Abhishek Srinivasa Raju Padmavathi · Type: task
Created: 2026-02-18 · Updated: 2026-02-18

DESCRIPTION
Execute in-cluster sweep at lockstep points 11,17,23,29,35 with RF=3 and data replicas=node count; capture throughput/latency/errors and cost context.

NOTES
[2026-02-18 08:49:55Z] Start E35: run lockstep in-cluster sweep at quota-feasible counts (3,4,5,6,7,8); account quota blocks >=11 nodes on t3.medium

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
2. [● P2] [task] nd-jui.15: E36 External-path NLB sweeps at representative scales
3. [● P2] [task] nd-jui.16: E37 Generator capacity validation
4. [● P2] [task] nd-jui.17: E38 Vertical + horizontal scaling matrix
5. [● P2] [task] nd-jui.18: E39 Bottleneck attribution and optimization backlog
6. [● P2] [task] nd-jui.19: E40 Reproducible benchmark runbook and report index

```

## Git Snapshot

```text
codex/e20-true-raft-integration
b125143 e32: add budget-safe eks runbook and cleanup audit
 M reports/benchmarks/aws/benchmark_matrix_latest.json
 M reports/benchmarks/aws/benchmark_matrix_latest.md
 M reports/benchmarks/aws/e2e_http_incluster_latest.json
 M reports/benchmarks/aws/e2e_http_incluster_latest.md
 M reports/tasks/issues_latest.jsonl
 M reports/tasks/issues_latest_tree.txt
 M scripts/eks/eks_scaling_sweep.sh
?? reports/benchmarks/aws/e2e_http_incluster_20260218T084607Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260218T084607Z.md
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218084615/
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
?? scripts/eks/eks_lockstep_sweep.sh
```
