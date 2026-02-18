# Task Checkpoint

- Timestamp (UTC): `2026-02-18 07:28:14Z`
- Issue: `nd-jui.4`
- Claimed now: `0`
- Status override: `none`
- Closed now: `1`
- Note: `Acceptance met: eventual reads honor freshness budget with leader fallback, and strong leader-read mode is configurable`

## Issue Snapshot

```text
✓ nd-jui.4 · E25 Eventual read path with staleness contract   [● P1 · CLOSED]
Owner: Abhishek Srinivasa Raju Padmavathi · Assignee: Abhishek Srinivasa Raju Padmavathi · Type: feature
Created: 2026-02-18 · Updated: 2026-02-18
Close reason: Closed

DESCRIPTION
Serve reads from any replica using replica freshness metadata and bounded-staleness policy. Add controls for strong/leader reads vs eventual replica reads.

NOTES
[2026-02-18 07:25:40Z] Start E25: integrate eventual read consistency and freshness budget into runtime RAFT path
[2026-02-18 07:28:10Z] Added runtime read consistency controls (eventual vs leader), 1s freshness budget wiring, and RatisKvRouter freshness/fallback tests
[2026-02-18 07:28:14Z] Acceptance met: eventual reads honor freshness budget with leader fallback, and strong leader-read mode is configurable

ACCEPTANCE CRITERIA
Eventual reads pass correctness tests with stale-read target under 1s in steady state.

LABELS: reads, roadmap, single-az

PARENT
  ↑ ◐ nd-jui: (EPIC) E21 Program: Single-AZ True Sharding and Replication ● P1

DEPENDS ON
  → ✓ nd-jui.3: E24 True shard-aware write path (leader-targeted quorum) ● P1

BLOCKS
  ← ○ nd-jui.5: E26 Rebalance planner for shard movement ● P1

```

## Ready Work Snapshot

```text

📋 Ready work (1 issues with no blockers):

1. [● P1] [feature] nd-jui.5: E26 Rebalance planner for shard movement

```

## Git Snapshot

```text
codex/e20-true-raft-integration
32c2f03 e24: route shard writes to leader and verify multi-shard leader forwarding
 M deploy/k8s/base/statefulset-data.yaml
 M node/src/main/java/io/notdynamo/node/NodeMain.java
 M node/src/main/java/io/notdynamo/node/cluster/RatisKvRouter.java
 M node/src/test/java/io/notdynamo/node/cluster/RatisKvRouterTest.java
 M reports/tasks/issues_latest.jsonl
 M reports/tasks/issues_latest_tree.txt
?? reports/checkpoints/nd-jui.4_20260218T072540Z.md
?? reports/checkpoints/nd-jui.4_20260218T072810Z.md
?? reports/checkpoints/nd-jui.4_20260218T072814Z.md
?? reports/checkpoints/nd-jui.4_latest.md
```
