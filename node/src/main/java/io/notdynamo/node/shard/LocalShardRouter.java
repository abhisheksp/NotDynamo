package io.notdynamo.node.shard;

import io.notdynamo.storage.KeyValueStore;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.Objects;

public final class LocalShardRouter {
    private final ConsistentHashRing ring;
    private final Map<Integer, KeyValueStore> shardStores;

    public LocalShardRouter(ConsistentHashRing ring, Map<Integer, KeyValueStore> shardStores) {
        this.ring = Objects.requireNonNull(ring, "ring must not be null");
        Objects.requireNonNull(shardStores, "shardStores must not be null");
        if (shardStores.isEmpty()) {
            throw new IllegalArgumentException("shardStores must not be empty");
        }
        if (!shardStores.keySet().containsAll(ring.shardIds())) {
            throw new IllegalArgumentException("shardStores must contain all ring shard IDs");
        }

        this.shardStores = Collections.unmodifiableMap(new HashMap<>(shardStores));
    }

    public int shardForKey(byte[] key) {
        return ring.shardForKey(key);
    }

    public KeyValueStore storeForKey(byte[] key) {
        int shardId = shardForKey(key);
        KeyValueStore store = shardStores.get(shardId);
        if (store == null) {
            throw new IllegalStateException("no store found for shard " + shardId);
        }
        return store;
    }

    public ConsistentHashRing ring() {
        return ring;
    }

    public Map<Integer, KeyValueStore> shardStores() {
        return shardStores;
    }
}
