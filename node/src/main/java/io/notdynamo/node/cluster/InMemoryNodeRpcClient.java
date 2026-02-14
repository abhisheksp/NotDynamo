package io.notdynamo.node.cluster;

import io.notdynamo.node.KvServiceHandler;
import io.notdynamo.proto.v1.DeleteRequest;
import io.notdynamo.proto.v1.DeleteResponse;
import io.notdynamo.proto.v1.Error;
import io.notdynamo.proto.v1.GetRequest;
import io.notdynamo.proto.v1.GetResponse;
import io.notdynamo.proto.v1.PutRequest;
import io.notdynamo.proto.v1.PutResponse;
import io.notdynamo.proto.v1.StatusCode;
import java.util.Objects;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

public final class InMemoryNodeRpcClient implements NodeRpcClient {
    private final ConcurrentHashMap<String, KvServiceHandler> handlersByNodeId = new ConcurrentHashMap<>();
    private final AtomicLong getForwardedCalls = new AtomicLong();
    private final AtomicLong putForwardedCalls = new AtomicLong();
    private final AtomicLong deleteForwardedCalls = new AtomicLong();

    public void register(String nodeId, KvServiceHandler handler) {
        handlersByNodeId.put(validateNodeId(nodeId), Objects.requireNonNull(handler, "handler must not be null"));
    }

    public void unregister(String nodeId) {
        handlersByNodeId.remove(validateNodeId(nodeId));
    }

    @Override
    public GetResponse get(String nodeId, GetRequest request) {
        getForwardedCalls.incrementAndGet();

        KvServiceHandler handler = handlersByNodeId.get(validateNodeId(nodeId));
        if (handler == null) {
            return GetResponse.newBuilder().setError(unavailable("no handler for node " + nodeId)).build();
        }

        SyncResponseObserver<GetResponse> observer = new SyncResponseObserver<>();
        handler.get(request, observer);

        if (observer.error() != null || observer.value() == null || !observer.completed()) {
            return GetResponse.newBuilder().setError(internal("remote get failed for node " + nodeId)).build();
        }
        return observer.value();
    }

    @Override
    public PutResponse put(String nodeId, PutRequest request) {
        putForwardedCalls.incrementAndGet();

        KvServiceHandler handler = handlersByNodeId.get(validateNodeId(nodeId));
        if (handler == null) {
            return PutResponse.newBuilder().setError(unavailable("no handler for node " + nodeId)).build();
        }

        SyncResponseObserver<PutResponse> observer = new SyncResponseObserver<>();
        handler.put(request, observer);

        if (observer.error() != null || observer.value() == null || !observer.completed()) {
            return PutResponse.newBuilder().setError(internal("remote put failed for node " + nodeId)).build();
        }
        return observer.value();
    }

    @Override
    public DeleteResponse delete(String nodeId, DeleteRequest request) {
        deleteForwardedCalls.incrementAndGet();

        KvServiceHandler handler = handlersByNodeId.get(validateNodeId(nodeId));
        if (handler == null) {
            return DeleteResponse.newBuilder().setError(unavailable("no handler for node " + nodeId)).build();
        }

        SyncResponseObserver<DeleteResponse> observer = new SyncResponseObserver<>();
        handler.delete(request, observer);

        if (observer.error() != null || observer.value() == null || !observer.completed()) {
            return DeleteResponse.newBuilder().setError(internal("remote delete failed for node " + nodeId)).build();
        }
        return observer.value();
    }

    public long getForwardedCalls() {
        return getForwardedCalls.get();
    }

    public long putForwardedCalls() {
        return putForwardedCalls.get();
    }

    public long deleteForwardedCalls() {
        return deleteForwardedCalls.get();
    }

    private static String validateNodeId(String nodeId) {
        if (nodeId == null || nodeId.isBlank()) {
            throw new IllegalArgumentException("nodeId must not be blank");
        }
        return nodeId;
    }

    private static Error unavailable(String message) {
        return Error.newBuilder().setCode(StatusCode.STATUS_CODE_UNAVAILABLE).setMessage(message).build();
    }

    private static Error internal(String message) {
        return Error.newBuilder().setCode(StatusCode.STATUS_CODE_INTERNAL).setMessage(message).build();
    }
}
