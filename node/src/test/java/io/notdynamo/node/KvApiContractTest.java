package io.notdynamo.node;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.google.protobuf.ByteString;
import io.notdynamo.proto.v1.DeleteRequest;
import io.notdynamo.proto.v1.DeleteResponse;
import io.notdynamo.proto.v1.GetRequest;
import io.notdynamo.proto.v1.GetResponse;
import io.notdynamo.proto.v1.PutRequest;
import io.notdynamo.proto.v1.PutResponse;
import io.notdynamo.proto.v1.StatusCode;
import io.notdynamo.storage.RocksDbKeyValueStore;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class KvApiContractTest {
    @TempDir
    Path tempDir;

    @Test
    void supportsPutGetDeleteRoundTrip() {
        byte[] key = "customer:1".getBytes(StandardCharsets.UTF_8);
        byte[] value = "active".getBytes(StandardCharsets.UTF_8);

        try (RocksDbKeyValueStore store = RocksDbKeyValueStore.open(tempDir.resolve("db"))) {
            KvServiceHandler handler = new KvServiceHandler(store);

            PutResponse put = callPut(handler, key, value);
            assertFalse(put.hasError());
            assertEquals(1L, put.getVersion());

            GetResponse get = callGet(handler, key);
            assertFalse(get.hasError());
            assertTrue(get.getFound());
            assertEquals(1L, get.getVersion());
            assertArrayEquals(value, get.getValue().toByteArray());

            DeleteResponse delete = callDelete(handler, key);
            assertFalse(delete.hasError());
            assertEquals(2L, delete.getVersion());

            GetResponse getAfterDelete = callGet(handler, key);
            assertFalse(getAfterDelete.hasError());
            assertFalse(getAfterDelete.getFound());
            assertEquals(2L, getAfterDelete.getVersion());
        }
    }

    @Test
    void returnsInvalidArgumentForEmptyKey() {
        try (RocksDbKeyValueStore store = RocksDbKeyValueStore.open(tempDir.resolve("db-invalid"))) {
            KvServiceHandler handler = new KvServiceHandler(store);

            GetResponse get = callGet(handler, new byte[0]);
            assertTrue(get.hasError());
            assertEquals(StatusCode.STATUS_CODE_INVALID_ARGUMENT, get.getError().getCode());

            PutResponse put = callPut(handler, new byte[0], "v".getBytes(StandardCharsets.UTF_8));
            assertTrue(put.hasError());
            assertEquals(StatusCode.STATUS_CODE_INVALID_ARGUMENT, put.getError().getCode());

            DeleteResponse delete = callDelete(handler, new byte[0]);
            assertTrue(delete.hasError());
            assertEquals(StatusCode.STATUS_CODE_INVALID_ARGUMENT, delete.getError().getCode());
        }
    }

    @Test
    void returnsNotFoundShapeForMissingKey() {
        try (RocksDbKeyValueStore store = RocksDbKeyValueStore.open(tempDir.resolve("db-missing"))) {
            KvServiceHandler handler = new KvServiceHandler(store);

            GetResponse get = callGet(handler, "missing".getBytes(StandardCharsets.UTF_8));
            assertFalse(get.hasError());
            assertFalse(get.getFound());
            assertEquals(0L, get.getVersion());
        }
    }

    private static PutResponse callPut(KvServiceHandler handler, byte[] key, byte[] value) {
        ObserverCapture<PutResponse> capture = new ObserverCapture<>();
        handler.put(PutRequest.newBuilder().setKey(ByteString.copyFrom(key)).setValue(ByteString.copyFrom(value)).build(), capture);
        assertNoRpcFailure(capture);
        return capture.value();
    }

    private static GetResponse callGet(KvServiceHandler handler, byte[] key) {
        ObserverCapture<GetResponse> capture = new ObserverCapture<>();
        handler.get(GetRequest.newBuilder().setKey(ByteString.copyFrom(key)).build(), capture);
        assertNoRpcFailure(capture);
        return capture.value();
    }

    private static DeleteResponse callDelete(KvServiceHandler handler, byte[] key) {
        ObserverCapture<DeleteResponse> capture = new ObserverCapture<>();
        handler.delete(DeleteRequest.newBuilder().setKey(ByteString.copyFrom(key)).build(), capture);
        assertNoRpcFailure(capture);
        return capture.value();
    }

    private static <T> void assertNoRpcFailure(ObserverCapture<T> capture) {
        assertTrue(capture.completed());
        assertNotNull(capture.value());
        assertEquals(null, capture.error());
    }
}
