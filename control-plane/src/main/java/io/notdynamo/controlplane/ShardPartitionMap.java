package io.notdynamo.controlplane;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;

public final class ShardPartitionMap {
    private final PartitionMapVersion version;
    private final int shardCount;
    private final int virtualNodesPerShard;
    private final Map<Integer, ShardDescriptor> descriptorsByShard;

    public ShardPartitionMap(
        PartitionMapVersion version,
        int shardCount,
        int virtualNodesPerShard,
        Map<Integer, ShardDescriptor> descriptorsByShard
    ) {
        this.version = Objects.requireNonNull(version, "version must not be null");
        if (shardCount <= 0) {
            throw new IllegalArgumentException("shardCount must be > 0");
        }
        if (virtualNodesPerShard <= 0) {
            throw new IllegalArgumentException("virtualNodesPerShard must be > 0");
        }
        Objects.requireNonNull(descriptorsByShard, "descriptorsByShard must not be null");
        if (descriptorsByShard.size() != shardCount) {
            throw new IllegalArgumentException("descriptorsByShard size must equal shardCount");
        }

        Map<Integer, ShardDescriptor> normalized = new LinkedHashMap<>(shardCount);
        for (int shardId = 0; shardId < shardCount; shardId++) {
            ShardDescriptor descriptor = descriptorsByShard.get(shardId);
            if (descriptor == null) {
                throw new IllegalArgumentException("missing descriptor for shard " + shardId);
            }
            if (descriptor.shardId() != shardId) {
                throw new IllegalArgumentException(
                    "descriptor shardId mismatch: key=" + shardId + " descriptor=" + descriptor.shardId()
                );
            }
            normalized.put(shardId, descriptor);
        }

        for (Integer key : descriptorsByShard.keySet()) {
            if (key == null || key < 0 || key >= shardCount) {
                throw new IllegalArgumentException("invalid shard key in descriptorsByShard: " + key);
            }
        }

        this.shardCount = shardCount;
        this.virtualNodesPerShard = virtualNodesPerShard;
        this.descriptorsByShard = Collections.unmodifiableMap(normalized);
    }

    public static ShardPartitionMap roundRobin(
        PartitionMapVersion version,
        int shardCount,
        int virtualNodesPerShard,
        List<String> nodeIds,
        int replicationFactor
    ) {
        Objects.requireNonNull(nodeIds, "nodeIds must not be null");
        if (nodeIds.isEmpty()) {
            throw new IllegalArgumentException("nodeIds must not be empty");
        }
        if (replicationFactor <= 0) {
            throw new IllegalArgumentException("replicationFactor must be > 0");
        }

        List<String> normalizedNodeIds = normalizeNodeIds(nodeIds);
        int effectiveReplicationFactor = Math.min(replicationFactor, normalizedNodeIds.size());

        Map<Integer, ShardDescriptor> descriptors = new LinkedHashMap<>(shardCount);
        for (int shardId = 0; shardId < shardCount; shardId++) {
            String leaderNodeId = normalizedNodeIds.get(shardId % normalizedNodeIds.size());
            List<String> replicas = new ArrayList<>(effectiveReplicationFactor);
            for (int i = 0; i < effectiveReplicationFactor; i++) {
                replicas.add(normalizedNodeIds.get((shardId + i) % normalizedNodeIds.size()));
            }
            descriptors.put(
                shardId,
                new ShardDescriptor(
                    shardId,
                    groupIdForShard(shardId),
                    leaderNodeId,
                    replicas,
                    List.of(leaderNodeId),
                    ShardRebalanceState.STABLE
                )
            );
        }

        return new ShardPartitionMap(version, shardCount, virtualNodesPerShard, descriptors);
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

    public Map<Integer, ShardDescriptor> descriptorsByShard() {
        return descriptorsByShard;
    }

    public ShardDescriptor descriptorForShard(int shardId) {
        if (shardId < 0 || shardId >= shardCount) {
            throw new IllegalArgumentException("unknown shard " + shardId);
        }
        return descriptorsByShard.get(shardId);
    }

    public Optional<String> leaderForShard(int shardId) {
        if (shardId < 0 || shardId >= shardCount) {
            return Optional.empty();
        }
        return Optional.ofNullable(descriptorsByShard.get(shardId)).map(ShardDescriptor::leaderNodeId);
    }

    public ClusterPartitionMap toClusterPartitionMap() {
        Map<Integer, String> owners = new LinkedHashMap<>(shardCount);
        for (int shardId = 0; shardId < shardCount; shardId++) {
            owners.put(shardId, descriptorForShard(shardId).leaderNodeId());
        }
        return new ClusterPartitionMap(version, shardCount, virtualNodesPerShard, owners);
    }

    public ReplicaPartitionMap toReplicaPartitionMap() {
        ClusterPartitionMap leaderMap = toClusterPartitionMap();
        Map<Integer, List<String>> replicas = new LinkedHashMap<>(shardCount);
        for (int shardId = 0; shardId < shardCount; shardId++) {
            replicas.put(shardId, descriptorForShard(shardId).replicaNodeIds());
        }
        return new ReplicaPartitionMap(leaderMap, replicas);
    }

    public ShardPartitionMap withVersion(PartitionMapVersion nextVersion) {
        return new ShardPartitionMap(nextVersion, shardCount, virtualNodesPerShard, descriptorsByShard);
    }

    public ShardPartitionMap withLeaderAssignments(Map<Integer, String> nextLeaders, PartitionMapVersion nextVersion) {
        Objects.requireNonNull(nextLeaders, "nextLeaders must not be null");
        Objects.requireNonNull(nextVersion, "nextVersion must not be null");
        if (nextLeaders.size() != shardCount) {
            throw new IllegalArgumentException("nextLeaders size must equal shardCount");
        }

        Map<Integer, ShardDescriptor> nextDescriptors = new LinkedHashMap<>(shardCount);
        for (int shardId = 0; shardId < shardCount; shardId++) {
            String nextLeader = nextLeaders.get(shardId);
            if (nextLeader == null || nextLeader.isBlank()) {
                throw new IllegalArgumentException("missing/blank next leader for shard " + shardId);
            }

            ShardDescriptor existing = descriptorForShard(shardId);
            if (nextLeader.equals(existing.leaderNodeId())) {
                nextDescriptors.put(shardId, existing);
            } else {
                nextDescriptors.put(shardId, existing.withLeader(nextLeader));
            }
        }

        return new ShardPartitionMap(nextVersion, shardCount, virtualNodesPerShard, nextDescriptors);
    }

    public static String groupIdForShard(int shardId) {
        if (shardId < 0) {
            throw new IllegalArgumentException("shardId must be >= 0");
        }
        return "shard-" + shardId;
    }

    private static List<String> normalizeNodeIds(List<String> nodeIds) {
        LinkedHashSet<String> normalized = new LinkedHashSet<>();
        for (String nodeId : nodeIds) {
            if (nodeId == null || nodeId.isBlank()) {
                throw new IllegalArgumentException("nodeIds must not contain null/blank values");
            }
            normalized.add(nodeId);
        }
        return new ArrayList<>(normalized);
    }
}
