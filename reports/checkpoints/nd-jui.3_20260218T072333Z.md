# Task Checkpoint

- Timestamp (UTC): `2026-02-18 07:23:33Z`
- Issue: `nd-jui.3`
- Claimed now: `1`
- Status override: `in_progress`
- Closed now: `0`
- Note: `Start E24: leader-targeted shard write path for Raft router`

## Issue Snapshot

```text
◐ nd-jui.3 · E24 True shard-aware write path (leader-targeted quorum)   [● P1 · IN_PROGRESS]
Owner: Abhishek Srinivasa Raju Padmavathi · Assignee: Abhishek Srinivasa Raju Padmavathi · Type: feature
Created: 2026-02-18 · Updated: 2026-02-18

DESCRIPTION
Route PUT/DELETE to the leader of the target shard Raft group. Enforce quorum ack policy (rf=3, majority) at shard scope and preserve durability semantics.

NOTES
[2026-02-18 07:23:33Z] Start E24: leader-targeted shard write path for Raft router

ACCEPTANCE CRITERIA
Writes for multiple shards are accepted by their respective shard leaders; per-shard quorum behavior verified.

LABELS: data-path, roadmap, single-az

PARENT
  ↑ ◐ nd-jui: (EPIC) E21 Program: Single-AZ True Sharding and Replication ● P1

DEPENDS ON
  → ✓ nd-jui.2: E23 Multi-Raft runtime (one Raft group per shard) ● P1

BLOCKS
  ← ○ nd-jui.4: E25 Eventual read path with staleness contract ● P1

```

## Ready Work Snapshot

```text

✨ No ready work found (all issues have blocking dependencies)

```

## Git Snapshot

```text
codex/e20-true-raft-integration
3fc75fd e23: implement multi-shard ratis runtime and shard-specific consensus writes
 M it/src/test/java/io/notdynamo/it/RatisRoutingIT.java
 M node/src/main/java/io/notdynamo/node/cluster/RatisKvRouter.java
 M reports/tasks/issues_latest.jsonl
 M reports/tasks/issues_latest_tree.txt
?? reports/checkpoints/nd-jui.3_20260218T072333Z.md
```
