package io.notdynamo.node.shard;

import io.notdynamo.storage.KeyValueStore;
import io.notdynamo.storage.RocksDbKeyValueStore;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

public final class RocksDbShardStoreFactory {
    private RocksDbShardStoreFactory() {
    }

    public static Map<Integer, KeyValueStore> open(Path dataDir, Set<Integer> shardIds) {
        Objects.requireNonNull(dataDir, "dataDir must not be null");
        Objects.requireNonNull(shardIds, "shardIds must not be null");
        if (shardIds.isEmpty()) {
            throw new IllegalArgumentException("shardIds must not be empty");
        }

        Map<Integer, KeyValueStore> stores = new LinkedHashMap<>();
        try {
            for (int shardId : shardIds) {
                Path shardPath = dataDir.resolve("shards").resolve("shard-" + shardId);
                stores.put(shardId, RocksDbKeyValueStore.open(shardPath));
            }
            return stores;
        } catch (RuntimeException e) {
            closeQuietly(stores.values());
            throw e;
        }
    }

    private static void closeQuietly(Iterable<KeyValueStore> stores) {
        for (KeyValueStore store : stores) {
            try {
                store.close();
            } catch (RuntimeException ignored) {
            }
        }
    }
}
