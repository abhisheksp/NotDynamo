package io.notdynamo.storage;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class RocksDbKeyValueStoreTest {
    @TempDir
    Path tempDir;

    @Test
    void putGetDeleteMaintainsVersionAndTombstoneSemantics() {
        byte[] key = "user-1".getBytes(StandardCharsets.UTF_8);
        byte[] valueV1 = "value-v1".getBytes(StandardCharsets.UTF_8);
        byte[] valueV2 = "value-v2".getBytes(StandardCharsets.UTF_8);

        try (RocksDbKeyValueStore store = RocksDbKeyValueStore.open(tempDir.resolve("db"))) {
            long putV1 = store.put(key, valueV1);
            assertEquals(1L, putV1);

            KeyValueStore.GetResult getV1 = store.get(key);
            assertTrue(getV1.found());
            assertEquals(1L, getV1.version());
            assertArrayEquals(valueV1, getV1.value());

            long deleteVersion = store.delete(key);
            assertEquals(2L, deleteVersion);

            KeyValueStore.GetResult afterDelete = store.get(key);
            assertFalse(afterDelete.found());
            assertEquals(2L, afterDelete.version());

            long putV2 = store.put(key, valueV2);
            assertEquals(3L, putV2);

            KeyValueStore.GetResult getV2 = store.get(key);
            assertTrue(getV2.found());
            assertEquals(3L, getV2.version());
            assertArrayEquals(valueV2, getV2.value());
        }
    }

    @Test
    void recoversStateAcrossRestart() {
        byte[] key = "recover-key".getBytes(StandardCharsets.UTF_8);
        byte[] value = "recover-value".getBytes(StandardCharsets.UTF_8);
        Path dbPath = tempDir.resolve("db-restart");

        try (RocksDbKeyValueStore writer = RocksDbKeyValueStore.open(dbPath)) {
            assertEquals(1L, writer.put(key, value));
        }

        try (RocksDbKeyValueStore reader = RocksDbKeyValueStore.open(dbPath)) {
            KeyValueStore.GetResult result = reader.get(key);
            assertTrue(result.found());
            assertEquals(1L, result.version());
            assertArrayEquals(value, result.value());
        }
    }

    @Test
    void rejectsEmptyKey() {
        try (RocksDbKeyValueStore store = RocksDbKeyValueStore.open(tempDir.resolve("db-invalid"))) {
            assertThrows(IllegalArgumentException.class, () -> store.get(new byte[0]));
            assertThrows(IllegalArgumentException.class, () -> store.put(new byte[0], new byte[] {1}));
            assertThrows(IllegalArgumentException.class, () -> store.delete(new byte[0]));
        }
    }
}
