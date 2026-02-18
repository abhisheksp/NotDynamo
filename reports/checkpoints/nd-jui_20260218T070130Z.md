# Task Checkpoint

- Timestamp (UTC): `2026-02-18 07:01:30Z`
- Issue: `nd-jui`
- Claimed now: `1`
- Status override: `in_progress`
- Closed now: `0`
- Note: `Initialized Beads roadmap and checkpoint workflow`

## Issue Snapshot

```text
◐ nd-jui [EPIC] · E21 Program: Single-AZ True Sharding and Replication   [● P1 · IN_PROGRESS]
Owner: Abhishek Srinivasa Raju Padmavathi · Assignee: Abhishek Srinivasa Raju Padmavathi · Type: epic
Created: 2026-02-18 · Updated: 2026-02-18

DESCRIPTION
Primary roadmap to align runtime behavior with agreed NotDynamo design: per-shard consensus, shard-aware routing, failure correctness, and benchmarkable scale behavior in single-AZ Kubernetes/EKS.

NOTES
[2026-02-18 07:01:30Z] Initialized Beads roadmap and checkpoint workflow

ACCEPTANCE CRITERIA
All child E22-E33 tasks are closed with verification artifacts and benchmark reports.

LABELS: e21, roadmap, single-az

CHILDREN
  ↳ ○ nd-jui.1: E22 Shard Metadata v2 (per-shard group + replica set) ● P1
  ↳ ○ nd-jui.10: E31 Single-AZ horizontal scaling sweeps ● P2
  ↳ ○ nd-jui.11: E32 EKS benchmark runbook (budget-safe setup/teardown) ● P2
  ↳ ○ nd-jui.12: (EPIC) E33 Multi-AZ resilience phase (deferred) ● P3
  ↳ ○ nd-jui.2: E23 Multi-Raft runtime (one Raft group per shard) ● P1
  ↳ ○ nd-jui.3: E24 True shard-aware write path (leader-targeted quorum) ● P1
  ↳ ○ nd-jui.4: E25 Eventual read path with staleness contract ● P1
  ↳ ○ nd-jui.5: E26 Rebalance planner for shard movement ● P1
  ↳ ○ nd-jui.6: E27 Rebalance executor (stream/catchup/switch) ● P1
  ↳ ○ nd-jui.7: E28 Failure injection harness (pod, leader, node, restart) ● P1
  ↳ ○ nd-jui.8: E29 Correctness verification matrix for failure modes ● P1
  ↳ ○ nd-jui.9: E30 External benchmark path via LoadBalancer/NLB ● P2

```

## Ready Work Snapshot

```text

📋 Ready work (1 issues with no blockers):

1. [● P1] [feature] nd-jui.1: E22 Shard Metadata v2 (per-shard group + replica set)

```

## Git Snapshot

```text
codex/e20-true-raft-integration
677572a e20: add eks benchmark categories and in-cluster job runner
 M .dockerignore
 M Dockerfile.bench
 M README.md
 M control-plane/src/main/java/io/notdynamo/controlplane/ControlPlaneMain.java
 M deploy/k8s/base/configmap.yaml
 M deploy/k8s/base/deployment-control-plane.yaml
 M deploy/k8s/base/statefulset-data.yaml
 M node/src/main/java/io/notdynamo/node/NodeMain.java
 M node/src/main/java/io/notdynamo/node/cluster/RatisKvRouter.java
 M raft-ratis/src/main/java/io/notdynamo/ratis/RatisConsensusEngine.java
 M reports/benchmarks/aws/e2e_http_latest.json
 M reports/benchmarks/aws/e2e_http_latest.md
 M reports/g15.json
 M scripts/eks/eks_bench_matrix.sh
 M scripts/eks/eks_deploy.sh
 M scripts/local/kind_deploy.sh
 M scripts/local/smoke_http.sh
?? .beads/
?? AGENTS.md
?? docs/
?? reports/benchmarks/aws/benchmark_matrix_20260218T022719Z.json
?? reports/benchmarks/aws/benchmark_matrix_20260218T022719Z.md
?? reports/benchmarks/aws/benchmark_matrix_20260218T023313Z.json
?? reports/benchmarks/aws/benchmark_matrix_20260218T023313Z.md
?? reports/benchmarks/aws/benchmark_matrix_20260218T025955Z.json
?? reports/benchmarks/aws/benchmark_matrix_20260218T025955Z.md
?? reports/benchmarks/aws/benchmark_matrix_20260218T030626Z.json
?? reports/benchmarks/aws/benchmark_matrix_20260218T030626Z.md
?? reports/benchmarks/aws/benchmark_matrix_latest.json
?? reports/benchmarks/aws/benchmark_matrix_latest.md
?? reports/benchmarks/aws/e2e_http_external_20260218T022719Z.json
?? reports/benchmarks/aws/e2e_http_external_20260218T022719Z.md
?? reports/benchmarks/aws/e2e_http_external_20260218T023313Z.json
?? reports/benchmarks/aws/e2e_http_external_20260218T023313Z.md
?? reports/benchmarks/aws/e2e_http_external_20260218T025917Z_shard128fresh.json
?? reports/benchmarks/aws/e2e_http_external_20260218T025917Z_shard128fresh.md
?? reports/benchmarks/aws/e2e_http_external_20260218T025955Z.json
?? reports/benchmarks/aws/e2e_http_external_20260218T025955Z.md
?? reports/benchmarks/aws/e2e_http_external_20260218T030626Z.json
?? reports/benchmarks/aws/e2e_http_external_20260218T030626Z.md
?? reports/benchmarks/aws/e2e_http_external_latest.json
?? reports/benchmarks/aws/e2e_http_external_latest.md
?? reports/benchmarks/aws/e2e_http_incluster_20260218T011726Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260218T011726Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260218T021154Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260218T021154Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260218T022719Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260218T022719Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260218T023704Z_ratis5000.json
?? reports/benchmarks/aws/e2e_http_incluster_20260218T023704Z_ratis5000.md
?? reports/benchmarks/aws/e2e_http_incluster_20260218T024846Z_retrybudget.json
?? reports/benchmarks/aws/e2e_http_incluster_20260218T024846Z_retrybudget.md
?? reports/benchmarks/aws/e2e_http_incluster_20260218T025820Z_shard128fresh.json
?? reports/benchmarks/aws/e2e_http_incluster_20260218T025820Z_shard128fresh.md
?? reports/benchmarks/aws/e2e_http_incluster_20260218T025955Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260218T025955Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260218T030626Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260218T030626Z.md
?? reports/benchmarks/aws/e2e_http_incluster_latest.json
?? reports/benchmarks/aws/e2e_http_incluster_latest.md
?? reports/benchmarks/aws/incluster_runs/
?? reports/checkpoints/
?? reports/tasks/
?? scripts/tasks/
```
