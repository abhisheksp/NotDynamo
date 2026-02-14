package io.notdynamo.node.shard;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import io.notdynamo.storage.KeyValueStore;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.Test;

class LocalShardRouterTest {
    @Test
    void routedStoreDelegatesOperationsToResolvedShard() {
        Set<Integer> shardIds = Set.of(0, 1, 2, 3);
        ConsistentHashRing ring = ConsistentHashRing.create(shardIds, 32);

        Map<Integer, TrackingStore> stores = new HashMap<>();
        Map<Integer, KeyValueStore> asKeyValueStore = new HashMap<>();
        for (int shardId : shardIds) {
            TrackingStore store = new TrackingStore();
            stores.put(shardId, store);
            asKeyValueStore.put(shardId, store);
        }

        LocalShardRouter router = new LocalShardRouter(ring, asKeyValueStore);
        try (RoutedKeyValueStore routed = new RoutedKeyValueStore(router)) {
            byte[] key = "customer:42".getBytes(StandardCharsets.UTF_8);
            byte[] value = "active".getBytes(StandardCharsets.UTF_8);

            int shardId = router.shardForKey(key);
            long putVersion = routed.put(key, value);
            assertEquals(1L, putVersion);

            KeyValueStore.GetResult result = routed.get(key);
            assertTrue(result.found());
            assertEquals(1L, result.version());
            assertArrayEquals(value, result.value());

            long deleteVersion = routed.delete(key);
            assertEquals(2L, deleteVersion);

            for (Map.Entry<Integer, TrackingStore> entry : stores.entrySet()) {
                if (entry.getKey() == shardId) {
                    assertEquals(1, entry.getValue().putCalls);
                    assertEquals(1, entry.getValue().getCalls);
                    assertEquals(1, entry.getValue().deleteCalls);
                } else {
                    assertEquals(0, entry.getValue().putCalls);
                    assertEquals(0, entry.getValue().getCalls);
                    assertEquals(0, entry.getValue().deleteCalls);
                }
            }
        }
    }

    @Test
    void rejectsShardStoreMapsMissingRingShards() {
        ConsistentHashRing ring = ConsistentHashRing.create(Set.of(0, 1), 16);
        Map<Integer, KeyValueStore> incomplete = Map.of(0, new TrackingStore());

        assertThrows(IllegalArgumentException.class, () -> new LocalShardRouter(ring, incomplete));
    }

    private static final class TrackingStore implements KeyValueStore {
        private final Map<String, Record> data = new HashMap<>();
        private int putCalls;
        private int getCalls;
        private int deleteCalls;

        @Override
        public GetResult get(byte[] key) {
            getCalls += 1;
            Record record = data.get(keyToString(key));
            if (record == null || record.tombstone) {
                long version = record == null ? 0L : record.version;
                return new GetResult(false, new byte[0], version);
            }
            return new GetResult(true, record.value, record.version);
        }

        @Override
        public long put(byte[] key, byte[] value) {
            putCalls += 1;
            String mapKey = keyToString(key);
            Record current = data.get(mapKey);
            long nextVersion = current == null ? 1L : current.version + 1;
            data.put(mapKey, new Record(nextVersion, false, value.clone()));
            return nextVersion;
        }

        @Override
        public long delete(byte[] key) {
            deleteCalls += 1;
            String mapKey = keyToString(key);
            Record current = data.get(mapKey);
            long nextVersion = current == null ? 1L : current.version + 1;
            data.put(mapKey, new Record(nextVersion, true, new byte[0]));
            return nextVersion;
        }

        @Override
        public void close() {
        }

        private static String keyToString(byte[] key) {
            return java.util.Base64.getEncoder().encodeToString(key);
        }

        private record Record(long version, boolean tombstone, byte[] value) {
        }
    }
}
