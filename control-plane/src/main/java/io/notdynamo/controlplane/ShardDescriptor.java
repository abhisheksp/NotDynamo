package io.notdynamo.controlplane;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Objects;

public record ShardDescriptor(
    int shardId,
    String groupId,
    String leaderNodeId,
    List<String> replicaNodeIds,
    List<String> ownershipHistory,
    ShardRebalanceState rebalanceState
) {
    public ShardDescriptor {
        if (shardId < 0) {
            throw new IllegalArgumentException("shardId must be >= 0");
        }
        if (groupId == null || groupId.isBlank()) {
            throw new IllegalArgumentException("groupId must not be blank");
        }
        if (leaderNodeId == null || leaderNodeId.isBlank()) {
            throw new IllegalArgumentException("leaderNodeId must not be blank");
        }

        Objects.requireNonNull(replicaNodeIds, "replicaNodeIds must not be null");
        if (replicaNodeIds.isEmpty()) {
            throw new IllegalArgumentException("replicaNodeIds must not be empty");
        }

        List<String> normalizedReplicas = normalizeNodeIds(replicaNodeIds, "replicaNodeIds");
        if (!normalizedReplicas.contains(leaderNodeId)) {
            throw new IllegalArgumentException("replicaNodeIds must include leaderNodeId");
        }
        replicaNodeIds = List.copyOf(normalizedReplicas);

        Objects.requireNonNull(ownershipHistory, "ownershipHistory must not be null");
        List<String> normalizedHistory = normalizeNodeIds(ownershipHistory, "ownershipHistory");
        if (normalizedHistory.isEmpty()) {
            normalizedHistory = List.of(leaderNodeId);
        }
        ownershipHistory = List.copyOf(normalizedHistory);

        rebalanceState = Objects.requireNonNull(rebalanceState, "rebalanceState must not be null");
    }

    public ShardDescriptor withLeader(String nextLeaderNodeId) {
        if (nextLeaderNodeId == null || nextLeaderNodeId.isBlank()) {
            throw new IllegalArgumentException("nextLeaderNodeId must not be blank");
        }

        List<String> nextReplicas = new ArrayList<>(replicaNodeIds.size() + 1);
        nextReplicas.add(nextLeaderNodeId);
        for (String replica : replicaNodeIds) {
            if (!replica.equals(nextLeaderNodeId)) {
                nextReplicas.add(replica);
            }
        }

        List<String> nextHistory = new ArrayList<>(ownershipHistory.size() + 1);
        nextHistory.addAll(ownershipHistory);
        if (nextHistory.isEmpty() || !nextHistory.get(nextHistory.size() - 1).equals(nextLeaderNodeId)) {
            nextHistory.add(nextLeaderNodeId);
        }

        return new ShardDescriptor(
            shardId,
            groupId,
            nextLeaderNodeId,
            nextReplicas,
            nextHistory,
            rebalanceState
        );
    }

    private static List<String> normalizeNodeIds(List<String> values, String fieldName) {
        LinkedHashSet<String> normalized = new LinkedHashSet<>();
        for (String value : values) {
            if (value == null || value.isBlank()) {
                throw new IllegalArgumentException(fieldName + " must not contain null/blank node IDs");
            }
            normalized.add(value);
        }
        return new ArrayList<>(normalized);
    }
}
