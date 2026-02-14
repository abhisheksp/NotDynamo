package io.notdynamo.controlplane;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;

public final class ClusterPartitionMap {
    private final PartitionMapVersion version;
    private final int shardCount;
    private final int virtualNodesPerShard;
    private final Map<Integer, String> shardToNodeId;

    public ClusterPartitionMap(
        PartitionMapVersion version,
        int shardCount,
        int virtualNodesPerShard,
        Map<Integer, String> shardToNodeId
    ) {
        this.version = Objects.requireNonNull(version, "version must not be null");
        if (shardCount <= 0) {
            throw new IllegalArgumentException("shardCount must be > 0");
        }
        if (virtualNodesPerShard <= 0) {
            throw new IllegalArgumentException("virtualNodesPerShard must be > 0");
        }
        Objects.requireNonNull(shardToNodeId, "shardToNodeId must not be null");

        if (shardToNodeId.size() != shardCount) {
            throw new IllegalArgumentException("shardToNodeId size must equal shardCount");
        }

        Map<Integer, String> normalized = new LinkedHashMap<>();
        for (int shardId = 0; shardId < shardCount; shardId++) {
            String nodeId = shardToNodeId.get(shardId);
            if (nodeId == null || nodeId.isBlank()) {
                throw new IllegalArgumentException("missing owner for shard " + shardId);
            }
            normalized.put(shardId, nodeId);
        }

        for (Integer shardId : shardToNodeId.keySet()) {
            if (shardId == null || shardId < 0 || shardId >= shardCount) {
                throw new IllegalArgumentException("invalid shard ID in map: " + shardId);
            }
        }

        this.shardCount = shardCount;
        this.virtualNodesPerShard = virtualNodesPerShard;
        this.shardToNodeId = Collections.unmodifiableMap(normalized);
    }

    public static ClusterPartitionMap roundRobin(
        PartitionMapVersion version,
        int shardCount,
        int virtualNodesPerShard,
        List<String> nodeIds
    ) {
        Objects.requireNonNull(nodeIds, "nodeIds must not be null");
        if (nodeIds.isEmpty()) {
            throw new IllegalArgumentException("nodeIds must not be empty");
        }

        List<String> normalizedNodeIds = new ArrayList<>();
        for (String nodeId : nodeIds) {
            if (nodeId == null || nodeId.isBlank()) {
                throw new IllegalArgumentException("nodeIds must not contain null/blank values");
            }
            normalizedNodeIds.add(nodeId);
        }

        Map<Integer, String> assignments = new LinkedHashMap<>();
        for (int shardId = 0; shardId < shardCount; shardId++) {
            assignments.put(shardId, normalizedNodeIds.get(shardId % normalizedNodeIds.size()));
        }

        return new ClusterPartitionMap(version, shardCount, virtualNodesPerShard, assignments);
    }

    public PartitionMapVersion version() {
        return version;
    }

    public int shardCount() {
        return shardCount;
    }

    public int virtualNodesPerShard() {
        return virtualNodesPerShard;
    }

    public Map<Integer, String> shardToNodeId() {
        return shardToNodeId;
    }

    public Optional<String> ownerForShard(int shardId) {
        if (shardId < 0 || shardId >= shardCount) {
            return Optional.empty();
        }
        return Optional.ofNullable(shardToNodeId.get(shardId));
    }

    public ClusterPartitionMap withVersion(PartitionMapVersion nextVersion) {
        return new ClusterPartitionMap(nextVersion, shardCount, virtualNodesPerShard, shardToNodeId);
    }
}
