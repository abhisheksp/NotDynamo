package io.notdynamo.controlplane.rebalance;

public record ShardMove(int shardId, String sourceNodeId, String targetNodeId) {
    public ShardMove {
        if (shardId < 0) {
            throw new IllegalArgumentException("shardId must be >= 0");
        }
        if (sourceNodeId == null || sourceNodeId.isBlank()) {
            throw new IllegalArgumentException("sourceNodeId must not be blank");
        }
        if (targetNodeId == null || targetNodeId.isBlank()) {
            throw new IllegalArgumentException("targetNodeId must not be blank");
        }
        if (sourceNodeId.equals(targetNodeId)) {
            throw new IllegalArgumentException("sourceNodeId and targetNodeId must be different");
        }
    }
}
