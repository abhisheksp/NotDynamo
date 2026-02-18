# Task Checkpoint

- Timestamp (UTC): `2026-02-18 07:20:38Z`
- Issue: `nd-jui.2`
- Claimed now: `0`
- Status override: `none`
- Closed now: `0`
- Note: `Implemented multi-shard Ratis engine (per-shard groups), wired NodeMain RAFT path to shard descriptors, and added independent leader/log validation test`

## Issue Snapshot

```text
◐ nd-jui.2 · E23 Multi-Raft runtime (one Raft group per shard)   [● P1 · IN_PROGRESS]
Owner: Abhishek Srinivasa Raju Padmavathi · Assignee: Abhishek Srinivasa Raju Padmavathi · Type: feature
Created: 2026-02-18 · Updated: 2026-02-18

DESCRIPTION
Integrate Apache Ratis runtime so each shard is backed by its own Raft group (not one global group). Support shard group bootstrap, restart, and local persistence.

NOTES
[2026-02-18 07:14:51Z] Start E23: evaluate and implement multi-Raft runtime with per-shard groups
[2026-02-18 07:20:38Z] Implemented multi-shard Ratis engine (per-shard groups), wired NodeMain RAFT path to shard descriptors, and added independent leader/log validation test

ACCEPTANCE CRITERIA
At least 2 distinct shards have independent leaders and replication logs validated in tests.

LABELS: raft, roadmap, single-az

PARENT
  ↑ ◐ nd-jui: (EPIC) E21 Program: Single-AZ True Sharding and Replication ● P1

DEPENDS ON
  → ✓ nd-jui.1: E22 Shard Metadata v2 (per-shard group + replica set) ● P1

BLOCKS
  ← ○ nd-jui.3: E24 True shard-aware write path (leader-targeted quorum) ● P1

```

## Ready Work Snapshot

```text

✨ No ready work found (all issues have blocking dependencies)

```

## Git Snapshot

```text
codex/e20-true-raft-integration
977bb89 e22: add shard metadata v2 and control-plane partition map consumption
 M node/src/main/java/io/notdynamo/node/NodeMain.java
 M node/src/main/java/io/notdynamo/node/cluster/RatisKvRouter.java
 M raft-ratis/src/main/java/io/notdynamo/ratis/ConsensusEngine.java
 M reports/tasks/issues_latest.jsonl
 M reports/tasks/issues_latest_tree.txt
?? raft-ratis/src/main/java/io/notdynamo/ratis/RatisMultiShardConsensusEngine.java
?? raft-ratis/src/main/java/io/notdynamo/ratis/RatisMultiShardConsensusEngineConfig.java
?? raft-ratis/src/main/java/io/notdynamo/ratis/ShardRaftGroupConfig.java
?? raft-ratis/src/test/java/io/notdynamo/ratis/RatisMultiShardConsensusEngineIT.java
?? reports/checkpoints/nd-jui.2_20260218T071451Z.md
?? reports/checkpoints/nd-jui.2_20260218T072038Z.md
?? reports/checkpoints/nd-jui.2_latest.md
```
