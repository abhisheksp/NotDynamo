package io.notdynamo.controlplane.rebalance;

import io.notdynamo.controlplane.PartitionMapVersion;
import io.notdynamo.controlplane.ReplicaPartitionMap;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

public final class ReplicaRebalanceCoordinator {
    private final long learnerLagThresholdMillis;
    private final int maxConcurrentMoves;

    private ReplicaPartitionMap currentMap;
    private final Map<ShardMove, MoveContext> activeMoves = new HashMap<>();

    public ReplicaRebalanceCoordinator(
        ReplicaPartitionMap initialMap,
        long learnerLagThresholdMillis,
        int maxConcurrentMoves
    ) {
        this.currentMap = Objects.requireNonNull(initialMap, "initialMap must not be null");
        if (learnerLagThresholdMillis < 0) {
            throw new IllegalArgumentException("learnerLagThresholdMillis must be >= 0");
        }
        if (maxConcurrentMoves <= 0) {
            throw new IllegalArgumentException("maxConcurrentMoves must be > 0");
        }

        this.learnerLagThresholdMillis = learnerLagThresholdMillis;
        this.maxConcurrentMoves = maxConcurrentMoves;
    }

    public synchronized ReplicaPartitionMap currentMap() {
        return currentMap;
    }

    public synchronized int activeMoveCount() {
        return activeMoves.size();
    }

    public synchronized void startMove(ShardMove move, double currentReadP99Ms, RebalanceThrottler throttler) {
        Objects.requireNonNull(move, "move must not be null");
        Objects.requireNonNull(throttler, "throttler must not be null");

        if (!throttler.allowMove(currentReadP99Ms)) {
            throw new IllegalStateException("rebalance paused by SLO throttler");
        }
        if (activeMoves.size() >= maxConcurrentMoves) {
            throw new IllegalStateException("max concurrent moves reached");
        }
        if (activeMoves.containsKey(move)) {
            throw new IllegalStateException("move already active: " + move);
        }

        List<String> currentReplicas = currentMap.replicasForShard(move.shardId());
        if (!currentReplicas.contains(move.sourceNodeId())) {
            throw new IllegalStateException("source replica not present for shard " + move.shardId());
        }
        if (currentReplicas.contains(move.targetNodeId())) {
            throw new IllegalStateException("target replica already present for shard " + move.shardId());
        }
        if (move.sourceNodeId().equals(currentMap.leaderForShard(move.shardId()))) {
            throw new IllegalStateException("leader move is not supported in learner workflow");
        }

        List<String> updatedReplicas = new ArrayList<>(currentReplicas);
        updatedReplicas.add(move.targetNodeId());
        currentMap = currentMap.withUpdatedShardReplicas(
            move.shardId(),
            updatedReplicas,
            currentMap.version().next()
        );

        activeMoves.put(
            move,
            new MoveContext(MoveStage.LEARNER_ADDED, Long.MAX_VALUE, List.copyOf(currentReplicas))
        );
    }

    public synchronized void markSnapshotTransferred(ShardMove move) {
        MoveContext context = requireActiveMove(move);
        if (context.stage != MoveStage.LEARNER_ADDED) {
            throw new IllegalStateException("snapshot transfer can only follow learner add");
        }

        activeMoves.put(move, context.withStage(MoveStage.SNAPSHOT_TRANSFERRED));
    }

    public synchronized void markCatchupComplete(ShardMove move) {
        MoveContext context = requireActiveMove(move);
        if (context.stage != MoveStage.SNAPSHOT_TRANSFERRED) {
            throw new IllegalStateException("catchup completion can only follow snapshot transfer");
        }
        activeMoves.put(move, context.withStage(MoveStage.CATCHUP_COMPLETE));
    }

    public synchronized void recordLearnerLagMillis(ShardMove move, long lagMillis) {
        if (lagMillis < 0) {
            throw new IllegalArgumentException("lagMillis must be >= 0");
        }

        MoveContext context = requireActiveMove(move);
        activeMoves.put(move, context.withLagMillis(lagMillis));
    }

    public synchronized boolean readyToPromote(ShardMove move) {
        MoveContext context = requireActiveMove(move);
        return context.stage.ordinal() >= MoveStage.CATCHUP_COMPLETE.ordinal()
            && context.learnerLagMillis <= learnerLagThresholdMillis;
    }

    public synchronized void finalizeMove(ShardMove move) {
        MoveContext context = requireActiveMove(move);
        if (!readyToPromote(move)) {
            throw new IllegalStateException("move is not ready to promote: " + move);
        }

        List<String> currentReplicas = new ArrayList<>(currentMap.replicasForShard(move.shardId()));
        currentReplicas.remove(move.sourceNodeId());
        if (!currentReplicas.contains(move.targetNodeId())) {
            currentReplicas.add(move.targetNodeId());
        }

        currentMap = currentMap.withUpdatedShardReplicas(
            move.shardId(),
            currentReplicas,
            currentMap.version().next()
        );
        activeMoves.remove(move);
    }

    public synchronized void rollbackMove(ShardMove move) {
        MoveContext context = requireActiveMove(move);

        currentMap = currentMap.withUpdatedShardReplicas(
            move.shardId(),
            context.originalReplicas,
            currentMap.version().next()
        );
        activeMoves.remove(move);
    }

    private MoveContext requireActiveMove(ShardMove move) {
        Objects.requireNonNull(move, "move must not be null");
        MoveContext context = activeMoves.get(move);
        if (context == null) {
            throw new IllegalStateException("move is not active: " + move);
        }
        return context;
    }

    private enum MoveStage {
        LEARNER_ADDED,
        SNAPSHOT_TRANSFERRED,
        CATCHUP_COMPLETE
    }

    private record MoveContext(MoveStage stage, long learnerLagMillis, List<String> originalReplicas) {
        private MoveContext {
            Objects.requireNonNull(stage, "stage must not be null");
            Objects.requireNonNull(originalReplicas, "originalReplicas must not be null");
            originalReplicas = List.copyOf(originalReplicas);
        }

        private MoveContext withStage(MoveStage nextStage) {
            return new MoveContext(nextStage, learnerLagMillis, originalReplicas);
        }

        private MoveContext withLagMillis(long nextLagMillis) {
            return new MoveContext(stage, nextLagMillis, originalReplicas);
        }
    }
}
