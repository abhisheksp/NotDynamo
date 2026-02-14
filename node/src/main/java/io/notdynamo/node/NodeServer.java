package io.notdynamo.node;

public final class NodeServer {
    private final NodeConfig config;

    public NodeServer(NodeConfig config) {
        this.config = config;
    }

    public NodeConfig config() {
        return config;
    }
}
