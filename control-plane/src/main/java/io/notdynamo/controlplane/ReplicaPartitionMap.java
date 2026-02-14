package io.notdynamo.controlplane;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;

public final class ReplicaPartitionMap {
    private final ClusterPartitionMap leaderMap;
    private final Map<Integer, List<String>> replicasByShard;

    public ReplicaPartitionMap(ClusterPartitionMap leaderMap, Map<Integer, List<String>> replicasByShard) {
        this.leaderMap = Objects.requireNonNull(leaderMap, "leaderMap must not be null");
        Objects.requireNonNull(replicasByShard, "replicasByShard must not be null");

        if (replicasByShard.size() != leaderMap.shardCount()) {
            throw new IllegalArgumentException("replicasByShard size must equal shardCount");
        }

        Map<Integer, List<String>> normalized = new LinkedHashMap<>();
        for (int shardId = 0; shardId < leaderMap.shardCount(); shardId++) {
            List<String> replicas = replicasByShard.get(shardId);
            if (replicas == null || replicas.isEmpty()) {
                throw new IllegalArgumentException("replicas missing for shard " + shardId);
            }

            String leader = leaderMap.ownerForShard(shardId).orElseThrow();
            List<String> orderedReplicas = normalizeReplicas(replicas);
            if (!orderedReplicas.contains(leader)) {
                throw new IllegalArgumentException("replica list for shard " + shardId + " must include leader " + leader);
            }

            normalized.put(shardId, Collections.unmodifiableList(orderedReplicas));
        }

        this.replicasByShard = Collections.unmodifiableMap(normalized);
    }

    public static ReplicaPartitionMap withUniformReplicas(ClusterPartitionMap leaderMap, List<String> replicaNodeIds) {
        Objects.requireNonNull(replicaNodeIds, "replicaNodeIds must not be null");
        if (replicaNodeIds.isEmpty()) {
            throw new IllegalArgumentException("replicaNodeIds must not be empty");
        }

        List<String> normalizedReplicaNodes = normalizeReplicas(replicaNodeIds);
        Map<Integer, List<String>> byShard = new LinkedHashMap<>();

        for (int shardId = 0; shardId < leaderMap.shardCount(); shardId++) {
            String leader = leaderMap.ownerForShard(shardId).orElseThrow();
            LinkedHashSet<String> ordered = new LinkedHashSet<>();
            ordered.add(leader);
            ordered.addAll(normalizedReplicaNodes);
            byShard.put(shardId, List.copyOf(ordered));
        }

        return new ReplicaPartitionMap(leaderMap, byShard);
    }

    public ClusterPartitionMap leaderMap() {
        return leaderMap;
    }

    public PartitionMapVersion version() {
        return leaderMap.version();
    }

    public int shardCount() {
        return leaderMap.shardCount();
    }

    public int virtualNodesPerShard() {
        return leaderMap.virtualNodesPerShard();
    }

    public String leaderForShard(int shardId) {
        return leaderMap.ownerForShard(shardId).orElseThrow();
    }

    public List<String> replicasForShard(int shardId) {
        List<String> replicas = replicasByShard.get(shardId);
        if (replicas == null) {
            throw new IllegalArgumentException("unknown shard " + shardId);
        }
        return replicas;
    }

    public ReplicaPartitionMap withUpdatedShardReplicas(
        int shardId,
        List<String> updatedReplicas,
        PartitionMapVersion nextVersion
    ) {
        if (shardId < 0 || shardId >= shardCount()) {
            throw new IllegalArgumentException("unknown shard " + shardId);
        }
        Objects.requireNonNull(updatedReplicas, "updatedReplicas must not be null");
        Objects.requireNonNull(nextVersion, "nextVersion must not be null");

        Map<Integer, List<String>> nextReplicaMap = new LinkedHashMap<>(replicasByShard);
        nextReplicaMap.put(shardId, List.copyOf(updatedReplicas));
        return new ReplicaPartitionMap(leaderMap.withVersion(nextVersion), nextReplicaMap);
    }

    private static List<String> normalizeReplicas(List<String> replicas) {
        LinkedHashSet<String> normalized = new LinkedHashSet<>();
        for (String replica : replicas) {
            if (replica == null || replica.isBlank()) {
                throw new IllegalArgumentException("replica IDs must not be null/blank");
            }
            normalized.add(replica);
        }

        return new ArrayList<>(normalized);
    }
}
