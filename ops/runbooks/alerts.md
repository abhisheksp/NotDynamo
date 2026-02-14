# NotDynamo Alert Runbook

## NotDynamoReadP99High
- Confirm whether p99 degradation is cluster-wide or shard-local.
- Check rebalance status and pause moves if active.
- Validate disk latency and compaction backlog before scaling traffic.

## NotDynamoReplicationLagHigh
- Inspect per-shard lag to find skewed or unhealthy replicas.
- Verify follower health and network path between leader and followers.
- Temporarily route freshness-sensitive reads to leaders.

## NotDynamoElectionChurnHigh
- Check for unstable nodes or network partitions.
- Verify heartbeat timeouts and recent control-plane changes.
- Stabilize leader placement before resuming rebalance.
