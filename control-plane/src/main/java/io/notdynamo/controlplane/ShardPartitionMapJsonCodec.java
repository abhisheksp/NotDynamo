package io.notdynamo.controlplane;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

public final class ShardPartitionMapJsonCodec {
    private static final int SCHEMA_VERSION = 2;
    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    private ShardPartitionMapJsonCodec() {
    }

    public static String toJson(ShardPartitionMap map) {
        Objects.requireNonNull(map, "map must not be null");
        try {
            return OBJECT_MAPPER.writeValueAsString(Payload.fromDomain(map));
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("failed to serialize shard partition map", e);
        }
    }

    public static ShardPartitionMap fromJson(String json) {
        if (json == null || json.isBlank()) {
            throw new IllegalArgumentException("json must not be blank");
        }
        try {
            Payload payload = OBJECT_MAPPER.readValue(json, Payload.class);
            return payload.toDomain();
        } catch (JsonProcessingException e) {
            throw new IllegalArgumentException("failed to parse shard partition map json", e);
        }
    }

    public static final class Payload {
        public int schemaVersion = SCHEMA_VERSION;
        public Version version;
        public int shardCount;
        public int virtualNodesPerShard;
        public Map<String, String> owners;
        public Map<String, ShardPayload> shards;

        static Payload fromDomain(ShardPartitionMap map) {
            Payload payload = new Payload();
            payload.schemaVersion = SCHEMA_VERSION;
            payload.version = new Version();
            payload.version.epoch = map.version().epoch();
            payload.shardCount = map.shardCount();
            payload.virtualNodesPerShard = map.virtualNodesPerShard();

            payload.owners = new LinkedHashMap<>(map.shardCount());
            payload.shards = new LinkedHashMap<>(map.shardCount());
            for (int shardId = 0; shardId < map.shardCount(); shardId++) {
                ShardDescriptor descriptor = map.descriptorForShard(shardId);
                payload.owners.put(Integer.toString(shardId), descriptor.leaderNodeId());

                ShardPayload shardPayload = new ShardPayload();
                shardPayload.shardId = descriptor.shardId();
                shardPayload.groupId = descriptor.groupId();
                shardPayload.leaderId = descriptor.leaderNodeId();
                shardPayload.replicas = descriptor.replicaNodeIds();
                shardPayload.ownershipHistory = descriptor.ownershipHistory();
                shardPayload.rebalanceState = descriptor.rebalanceState().name();
                payload.shards.put(Integer.toString(shardId), shardPayload);
            }
            return payload;
        }

        ShardPartitionMap toDomain() {
            if (version == null) {
                throw new IllegalArgumentException("partition map json missing version");
            }
            if (shardCount <= 0) {
                throw new IllegalArgumentException("partition map json shardCount must be > 0");
            }
            if (virtualNodesPerShard <= 0) {
                throw new IllegalArgumentException("partition map json virtualNodesPerShard must be > 0");
            }

            Map<Integer, ShardDescriptor> descriptors = new LinkedHashMap<>(shardCount);
            for (int shardId = 0; shardId < shardCount; shardId++) {
                String shardKey = Integer.toString(shardId);
                ShardPayload shardPayload = shards == null ? null : shards.get(shardKey);
                String ownerLeader = owners == null ? null : owners.get(shardKey);
                descriptors.put(shardId, toDescriptor(shardId, shardPayload, ownerLeader));
            }

            return new ShardPartitionMap(
                new PartitionMapVersion(version.epoch),
                shardCount,
                virtualNodesPerShard,
                descriptors
            );
        }

        private static ShardDescriptor toDescriptor(int shardId, ShardPayload shardPayload, String ownerLeader) {
            String leaderId;
            String groupId;
            List<String> replicas;
            List<String> ownershipHistory;
            ShardRebalanceState rebalanceState;

            if (shardPayload == null) {
                leaderId = requireNonBlank(ownerLeader, "missing owner leader for shard " + shardId);
                groupId = ShardPartitionMap.groupIdForShard(shardId);
                replicas = List.of(leaderId);
                ownershipHistory = List.of(leaderId);
                rebalanceState = ShardRebalanceState.STABLE;
            } else {
                leaderId = firstNonBlank(shardPayload.leaderId, ownerLeader);
                leaderId = requireNonBlank(leaderId, "missing leader for shard " + shardId);
                groupId = shardPayload.groupId == null || shardPayload.groupId.isBlank()
                    ? ShardPartitionMap.groupIdForShard(shardId)
                    : shardPayload.groupId;
                replicas = shardPayload.replicas == null || shardPayload.replicas.isEmpty()
                    ? List.of(leaderId)
                    : List.copyOf(shardPayload.replicas);
                ownershipHistory = shardPayload.ownershipHistory == null
                    ? List.of(leaderId)
                    : List.copyOf(shardPayload.ownershipHistory);
                rebalanceState = parseRebalanceState(shardPayload.rebalanceState);
            }

            return new ShardDescriptor(
                shardId,
                groupId,
                leaderId,
                replicas,
                ownershipHistory,
                rebalanceState
            );
        }

        private static String firstNonBlank(String preferred, String fallback) {
            if (preferred != null && !preferred.isBlank()) {
                return preferred;
            }
            return fallback;
        }

        private static String requireNonBlank(String value, String message) {
            if (value == null || value.isBlank()) {
                throw new IllegalArgumentException(message);
            }
            return value;
        }

        private static ShardRebalanceState parseRebalanceState(String value) {
            if (value == null || value.isBlank()) {
                return ShardRebalanceState.STABLE;
            }
            try {
                return ShardRebalanceState.valueOf(value);
            } catch (IllegalArgumentException e) {
                return ShardRebalanceState.STABLE;
            }
        }
    }

    public static final class Version {
        public long epoch;
    }

    public static final class ShardPayload {
        public int shardId;
        public String groupId;
        public String leaderId;
        public List<String> replicas = new ArrayList<>();
        public List<String> ownershipHistory = new ArrayList<>();
        public String rebalanceState;
    }
}
