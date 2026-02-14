package io.notdynamo.node;

import io.notdynamo.storage.KeyValueStore;
import io.notdynamo.storage.RocksDbKeyValueStore;
import io.notdynamo.node.shard.ConsistentHashRing;
import io.notdynamo.node.shard.LocalShardRouter;
import io.notdynamo.node.shard.RocksDbShardStoreFactory;
import io.notdynamo.node.shard.RoutedKeyValueStore;
import java.util.Set;
import java.util.TreeSet;
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

    public static NodeServer openSharded(NodeConfig config, int shardCount, int virtualNodesPerShard) {
        if (shardCount <= 0) {
            throw new IllegalArgumentException("shardCount must be > 0");
        }
        if (virtualNodesPerShard <= 0) {
            throw new IllegalArgumentException("virtualNodesPerShard must be > 0");
        }

        Set<Integer> shardIds = new TreeSet<>();
        for (int shardId = 0; shardId < shardCount; shardId++) {
            shardIds.add(shardId);
        }

        ConsistentHashRing ring = ConsistentHashRing.create(shardIds, virtualNodesPerShard);
        LocalShardRouter router = new LocalShardRouter(ring, RocksDbShardStoreFactory.open(config.dataDir(), shardIds));
        return new NodeServer(config, new RoutedKeyValueStore(router));
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
