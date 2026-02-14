package io.notdynamo.node;

import java.nio.file.Path;
import java.util.Objects;

public record NodeConfig(String nodeId, String host, int grpcPort, int httpPort, Path dataDir) {
    public NodeConfig {
        nodeId = requireNonBlank(nodeId, "nodeId");
        host = requireNonBlank(host, "host");
        dataDir = Objects.requireNonNull(dataDir, "dataDir must not be null");

        if (grpcPort < 1 || grpcPort > 65535) {
            throw new IllegalArgumentException("grpcPort must be between 1 and 65535");
        }
        if (httpPort < 1 || httpPort > 65535) {
            throw new IllegalArgumentException("httpPort must be between 1 and 65535");
        }
        if (grpcPort == httpPort) {
            throw new IllegalArgumentException("grpcPort and httpPort must be different");
        }
    }

    private static String requireNonBlank(String value, String fieldName) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(fieldName + " must not be blank");
        }
        return value;
    }
}
