package io.notdynamo.ratis;

import java.nio.file.Path;
import java.util.List;
import java.util.Objects;
import java.util.function.Function;

public record RatisConsensusEngineConfig(
    String localNodeId,
    List<String> peerNodeIds,
    Function<String, String> addressResolver,
    Path storageDir,
    String groupName,
    long requestTimeoutMillis
) {
    public RatisConsensusEngineConfig {
        if (localNodeId == null || localNodeId.isBlank()) {
            throw new IllegalArgumentException("localNodeId must not be blank");
        }
        Objects.requireNonNull(peerNodeIds, "peerNodeIds must not be null");
        if (peerNodeIds.isEmpty()) {
            throw new IllegalArgumentException("peerNodeIds must not be empty");
        }
        if (!peerNodeIds.contains(localNodeId)) {
            throw new IllegalArgumentException("peerNodeIds must contain localNodeId");
        }
        Objects.requireNonNull(addressResolver, "addressResolver must not be null");
        Objects.requireNonNull(storageDir, "storageDir must not be null");
        if (groupName == null || groupName.isBlank()) {
            throw new IllegalArgumentException("groupName must not be blank");
        }
        if (requestTimeoutMillis <= 0) {
            throw new IllegalArgumentException("requestTimeoutMillis must be > 0");
        }
    }
}
