package io.notdynamo.ratis;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Objects;

public record ShardRaftGroupConfig(
    int shardId,
    String groupName,
    List<String> peerNodeIds
) {
    public ShardRaftGroupConfig {
        if (shardId < 0) {
            throw new IllegalArgumentException("shardId must be >= 0");
        }
        if (groupName == null || groupName.isBlank()) {
            throw new IllegalArgumentException("groupName must not be blank");
        }
        Objects.requireNonNull(peerNodeIds, "peerNodeIds must not be null");
        if (peerNodeIds.isEmpty()) {
            throw new IllegalArgumentException("peerNodeIds must not be empty");
        }
        LinkedHashSet<String> normalized = new LinkedHashSet<>();
        for (String peerNodeId : peerNodeIds) {
            if (peerNodeId == null || peerNodeId.isBlank()) {
                throw new IllegalArgumentException("peerNodeIds must not contain null/blank node IDs");
            }
            normalized.add(peerNodeId);
        }
        peerNodeIds = List.copyOf(new ArrayList<>(normalized));
    }
}
