package io.notdynamo.node.shard;

import io.notdynamo.storage.KeyValueStore;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Objects;

public final class RoutedKeyValueStore implements KeyValueStore {
    private final LocalShardRouter router;
    private final List<KeyValueStore> ownedStores;

    public RoutedKeyValueStore(LocalShardRouter router) {
        this.router = Objects.requireNonNull(router, "router must not be null");
        this.ownedStores = new ArrayList<>(new LinkedHashSet<>(router.shardStores().values()));
    }

    @Override
    public GetResult get(byte[] key) {
        return router.storeForKey(key).get(key);
    }

    @Override
    public long put(byte[] key, byte[] value) {
        return router.storeForKey(key).put(key, value);
    }

    @Override
    public long delete(byte[] key) {
        return router.storeForKey(key).delete(key);
    }

    @Override
    public void close() {
        RuntimeException failure = null;
        for (KeyValueStore store : ownedStores) {
            try {
                store.close();
            } catch (RuntimeException e) {
                if (failure == null) {
                    failure = new RuntimeException("failed to close routed shard stores", e);
                } else {
                    failure.addSuppressed(e);
                }
            }
        }

        if (failure != null) {
            throw failure;
        }
    }
}
