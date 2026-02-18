# Task Checkpoint

- Timestamp (UTC): `2026-02-18 07:13:27Z`
- Issue: `nd-jui.1`
- Claimed now: `0`
- Status override: `none`
- Closed now: `0`
- Note: `Implemented shard metadata v2 schema, control-plane JSON endpoint, node control-plane map fetch, and validation tests`

## Issue Snapshot

```text
◐ nd-jui.1 · E22 Shard Metadata v2 (per-shard group + replica set)   [● P1 · IN_PROGRESS]
Owner: Abhishek Srinivasa Raju Padmavathi · Assignee: Abhishek Srinivasa Raju Padmavathi · Type: feature
Created: 2026-02-18 · Updated: 2026-02-18

DESCRIPTION
Define shard-level metadata schema: shard id, replica members, leader hint, epoch/version, ownership history, and rebalance state. Persist and expose through control-plane endpoint consumed by nodes.

NOTES
[2026-02-18 07:06:02Z] Start E22: shard metadata v2 schema and control-plane endpoint consumption
[2026-02-18 07:13:27Z] Implemented shard metadata v2 schema, control-plane JSON endpoint, node control-plane map fetch, and validation tests

ACCEPTANCE CRITERIA
Nodes consume metadata v2 and route by shard descriptor; metadata versioning tested under update.

LABELS: core, roadmap, single-az

PARENT
  ↑ ◐ nd-jui: (EPIC) E21 Program: Single-AZ True Sharding and Replication ● P1

BLOCKS
  ← ○ nd-jui.2: E23 Multi-Raft runtime (one Raft group per shard) ● P1

```

## Ready Work Snapshot

```text

✨ No ready work found (all issues have blocking dependencies)

```

## Git Snapshot

```text
codex/e20-true-raft-integration
1a534c8 chore: checkpoint inflight benchmark and beads workspace state
 M control-plane/build.gradle.kts
 M control-plane/src/main/java/io/notdynamo/controlplane/ControlPlaneMain.java
 M control-plane/src/test/java/io/notdynamo/controlplane/ControlPlaneMainIT.java
 M deploy/k8s/base/deployment-control-plane.yaml
 M deploy/k8s/base/statefulset-data.yaml
 M it/src/test/java/io/notdynamo/it/PartitionMapConvergenceIT.java
 M node/src/main/java/io/notdynamo/node/NodeMain.java
 M reports/tasks/issues_latest.jsonl
 M reports/tasks/issues_latest_tree.txt
?? control-plane/src/main/java/io/notdynamo/controlplane/ShardDescriptor.java
?? control-plane/src/main/java/io/notdynamo/controlplane/ShardPartitionMap.java
?? control-plane/src/main/java/io/notdynamo/controlplane/ShardPartitionMapJsonCodec.java
?? control-plane/src/main/java/io/notdynamo/controlplane/ShardPartitionMapManager.java
?? control-plane/src/main/java/io/notdynamo/controlplane/ShardRebalanceState.java
?? control-plane/src/test/java/io/notdynamo/controlplane/ShardPartitionMapJsonCodecTest.java
?? control-plane/src/test/java/io/notdynamo/controlplane/ShardPartitionMapManagerTest.java
?? node/src/main/java/io/notdynamo/node/cluster/ControlPlanePartitionMapClient.java
?? node/src/test/java/io/notdynamo/node/cluster/ControlPlanePartitionMapClientTest.java
?? reports/checkpoints/nd-jui.1_20260218T070602Z.md
?? reports/checkpoints/nd-jui.1_20260218T071327Z.md
?? reports/checkpoints/nd-jui.1_latest.md
```
