package io.notdynamo.ratis;

import java.nio.file.Path;
import java.util.HashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.function.Function;

public record RatisMultiShardConsensusEngineConfig(
    String localNodeId,
    List<ShardRaftGroupConfig> shardGroups,
    Function<String, String> addressResolver,
    Path storageDir,
    long requestTimeoutMillis
) {
    public RatisMultiShardConsensusEngineConfig {
        if (localNodeId == null || localNodeId.isBlank()) {
            throw new IllegalArgumentException("localNodeId must not be blank");
        }
        Objects.requireNonNull(shardGroups, "shardGroups must not be null");
        if (shardGroups.isEmpty()) {
            throw new IllegalArgumentException("shardGroups must not be empty");
        }

        Set<Integer> shardIds = new HashSet<>();
        Set<String> groupNames = new HashSet<>();
        boolean localNodeInAtLeastOneGroup = false;
        for (ShardRaftGroupConfig shardGroup : shardGroups) {
            Objects.requireNonNull(shardGroup, "shardGroups must not contain null values");
            if (!shardIds.add(shardGroup.shardId())) {
                throw new IllegalArgumentException("duplicate shard ID in shardGroups: " + shardGroup.shardId());
            }
            if (!groupNames.add(shardGroup.groupName())) {
                throw new IllegalArgumentException("duplicate group name in shardGroups: " + shardGroup.groupName());
            }
            if (shardGroup.peerNodeIds().contains(localNodeId)) {
                localNodeInAtLeastOneGroup = true;
            }
        }
        if (!localNodeInAtLeastOneGroup) {
            throw new IllegalArgumentException("localNodeId must participate in at least one shard group");
        }

        Objects.requireNonNull(addressResolver, "addressResolver must not be null");
        Objects.requireNonNull(storageDir, "storageDir must not be null");
        if (requestTimeoutMillis <= 0) {
            throw new IllegalArgumentException("requestTimeoutMillis must be > 0");
        }
    }
}
