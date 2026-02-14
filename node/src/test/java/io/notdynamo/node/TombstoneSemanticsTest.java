package io.notdynamo.node;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.google.protobuf.ByteString;
import io.notdynamo.proto.v1.DeleteRequest;
import io.notdynamo.proto.v1.GetRequest;
import io.notdynamo.proto.v1.GetResponse;
import io.notdynamo.proto.v1.PutRequest;
import io.notdynamo.storage.RocksDbKeyValueStore;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class TombstoneSemanticsTest {
    @TempDir
    Path tempDir;

    @Test
    void deleteCreatesTombstoneAndReinsertIncrementsVersion() {
        byte[] key = "order-42".getBytes(StandardCharsets.UTF_8);

        try (RocksDbKeyValueStore store = RocksDbKeyValueStore.open(tempDir.resolve("db"))) {
            KvServiceHandler handler = new KvServiceHandler(store);

            long v1 = callPut(handler, key, "pending".getBytes(StandardCharsets.UTF_8));
            assertEquals(1L, v1);

            long v2 = callDelete(handler, key);
            assertEquals(2L, v2);

            GetResponse afterDelete = callGet(handler, key);
            assertFalse(afterDelete.getFound());
            assertEquals(2L, afterDelete.getVersion());

            long v3 = callPut(handler, key, "shipped".getBytes(StandardCharsets.UTF_8));
            assertEquals(3L, v3);

            GetResponse finalRead = callGet(handler, key);
            assertTrue(finalRead.getFound());
            assertEquals(3L, finalRead.getVersion());
            assertArrayEquals("shipped".getBytes(StandardCharsets.UTF_8), finalRead.getValue().toByteArray());
        }
    }

    @Test
    void deleteMissingKeyCreatesVersionOneTombstone() {
        byte[] key = "never-written".getBytes(StandardCharsets.UTF_8);

        try (RocksDbKeyValueStore store = RocksDbKeyValueStore.open(tempDir.resolve("db2"))) {
            KvServiceHandler handler = new KvServiceHandler(store);

            long deleteVersion = callDelete(handler, key);
            assertEquals(1L, deleteVersion);

            GetResponse getResponse = callGet(handler, key);
            assertFalse(getResponse.getFound());
            assertEquals(1L, getResponse.getVersion());
        }
    }

    private static long callPut(KvServiceHandler handler, byte[] key, byte[] value) {
        ObserverCapture<io.notdynamo.proto.v1.PutResponse> capture = new ObserverCapture<>();
        handler.put(PutRequest.newBuilder().setKey(ByteString.copyFrom(key)).setValue(ByteString.copyFrom(value)).build(), capture);
        assertNoRpcFailure(capture);
        return capture.value().getVersion();
    }

    private static long callDelete(KvServiceHandler handler, byte[] key) {
        ObserverCapture<io.notdynamo.proto.v1.DeleteResponse> capture = new ObserverCapture<>();
        handler.delete(DeleteRequest.newBuilder().setKey(ByteString.copyFrom(key)).build(), capture);
        assertNoRpcFailure(capture);
        return capture.value().getVersion();
    }

    private static GetResponse callGet(KvServiceHandler handler, byte[] key) {
        ObserverCapture<GetResponse> capture = new ObserverCapture<>();
        handler.get(GetRequest.newBuilder().setKey(ByteString.copyFrom(key)).build(), capture);
        assertNoRpcFailure(capture);
        return capture.value();
    }

    private static <T> void assertNoRpcFailure(ObserverCapture<T> capture) {
        assertTrue(capture.completed());
        assertNotNull(capture.value());
        assertEquals(null, capture.error());
    }
}
