package io.notdynamo.node.cluster;

import java.util.List;
import java.util.Objects;

public final class FreshReplicaPicker {
    public String pickFreshFollower(
        int shardId,
        String leaderNodeId,
        List<String> replicas,
        ReplicaLagTracker lagTracker,
        long freshnessBudgetMillis
    ) {
        if (shardId < 0) {
            throw new IllegalArgumentException("shardId must be >= 0");
        }
        if (freshnessBudgetMillis < 0) {
            throw new IllegalArgumentException("freshnessBudgetMillis must be >= 0");
        }
        Objects.requireNonNull(replicas, "replicas must not be null");
        Objects.requireNonNull(lagTracker, "lagTracker must not be null");
        validateNodeId(leaderNodeId, "leaderNodeId");

        String bestReplica = null;
        long bestLag = Long.MAX_VALUE;

        for (String replica : replicas) {
            validateNodeId(replica, "replicaNodeId");
            if (replica.equals(leaderNodeId)) {
                continue;
            }

            long lagMillis = lagTracker.lagMillis(shardId, replica);
            if (lagMillis <= freshnessBudgetMillis && lagMillis < bestLag) {
                bestReplica = replica;
                bestLag = lagMillis;
            }
        }

        return bestReplica;
    }

    private static void validateNodeId(String nodeId, String label) {
        if (nodeId == null || nodeId.isBlank()) {
            throw new IllegalArgumentException(label + " must not be blank");
        }
    }
}
