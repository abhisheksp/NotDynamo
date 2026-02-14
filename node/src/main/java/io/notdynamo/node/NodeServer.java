package io.notdynamo.node;

import io.notdynamo.storage.KeyValueStore;
import io.notdynamo.storage.RocksDbKeyValueStore;
import java.util.Objects;

public final class NodeServer implements AutoCloseable {
    private final NodeConfig config;
    private final KeyValueStore keyValueStore;
    private final KvServiceHandler kvService;

    private NodeServer(NodeConfig config, KeyValueStore keyValueStore) {
        this.config = Objects.requireNonNull(config, "config must not be null");
        this.keyValueStore = Objects.requireNonNull(keyValueStore, "keyValueStore must not be null");
        this.kvService = new KvServiceHandler(keyValueStore);
    }

    public static NodeServer open(NodeConfig config) {
        return new NodeServer(config, RocksDbKeyValueStore.open(config.dataDir()));
    }

    public NodeConfig config() {
        return config;
    }

    public KvServiceHandler kvService() {
        return kvService;
    }

    @Override
    public void close() {
        keyValueStore.close();
    }
}
