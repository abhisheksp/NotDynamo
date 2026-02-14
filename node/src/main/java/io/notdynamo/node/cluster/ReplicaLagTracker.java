package io.notdynamo.node.cluster;

import java.util.Map;
import java.util.Objects;
import java.util.concurrent.ConcurrentHashMap;

public final class ReplicaLagTracker {
    private final ConcurrentHashMap<ShardReplicaKey, Long> lagMillisByReplica = new ConcurrentHashMap<>();

    public void recordLagMillis(int shardId, String replicaNodeId, long lagMillis) {
        if (shardId < 0) {
            throw new IllegalArgumentException("shardId must be >= 0");
        }
        if (lagMillis < 0) {
            throw new IllegalArgumentException("lagMillis must be >= 0");
        }

        lagMillisByReplica.put(new ShardReplicaKey(shardId, validateNodeId(replicaNodeId)), lagMillis);
    }

    public long lagMillis(int shardId, String replicaNodeId) {
        if (shardId < 0) {
            throw new IllegalArgumentException("shardId must be >= 0");
        }

        return lagMillisByReplica.getOrDefault(
            new ShardReplicaKey(shardId, validateNodeId(replicaNodeId)),
            Long.MAX_VALUE
        );
    }

    public Map<ShardReplicaKey, Long> snapshot() {
        return Map.copyOf(lagMillisByReplica);
    }

    private static String validateNodeId(String nodeId) {
        if (nodeId == null || nodeId.isBlank()) {
            throw new IllegalArgumentException("replicaNodeId must not be blank");
        }
        return nodeId;
    }

    public record ShardReplicaKey(int shardId, String replicaNodeId) {
        public ShardReplicaKey {
            if (shardId < 0) {
                throw new IllegalArgumentException("shardId must be >= 0");
            }
            replicaNodeId = Objects.requireNonNull(replicaNodeId, "replicaNodeId must not be null");
            if (replicaNodeId.isBlank()) {
                throw new IllegalArgumentException("replicaNodeId must not be blank");
            }
        }
    }
}
