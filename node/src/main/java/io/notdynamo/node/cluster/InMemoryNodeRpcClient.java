package io.notdynamo.node.cluster;

import io.notdynamo.node.KvServiceHandler;
import io.notdynamo.proto.v1.DeleteRequest;
import io.notdynamo.proto.v1.DeleteResponse;
import io.notdynamo.proto.v1.Error;
import io.notdynamo.proto.v1.GetRequest;
import io.notdynamo.proto.v1.GetResponse;
import io.notdynamo.proto.v1.KvServiceGrpc;
import io.notdynamo.proto.v1.PutRequest;
import io.notdynamo.proto.v1.PutResponse;
import io.notdynamo.proto.v1.RaftAppendEntriesRequest;
import io.notdynamo.proto.v1.RaftAppendEntriesResponse;
import io.notdynamo.proto.v1.RaftConsensusServiceGrpc;
import io.notdynamo.proto.v1.RaftVoteRequest;
import io.notdynamo.proto.v1.RaftVoteResponse;
import io.notdynamo.proto.v1.StatusCode;
import java.util.Objects;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

public final class InMemoryNodeRpcClient implements NodeRpcClient {
    private final ConcurrentHashMap<String, KvServiceGrpc.KvServiceImplBase> handlersByNodeId = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, KvServiceHandler> replicaApplyHandlersByNodeId = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, RaftConsensusServiceGrpc.RaftConsensusServiceImplBase> raftHandlersByNodeId =
        new ConcurrentHashMap<>();
    private final AtomicLong getForwardedCalls = new AtomicLong();
    private final AtomicLong putForwardedCalls = new AtomicLong();
    private final AtomicLong deleteForwardedCalls = new AtomicLong();
    private final ConcurrentHashMap<String, AtomicLong> getCallsByNode = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, AtomicLong> putCallsByNode = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, AtomicLong> deleteCallsByNode = new ConcurrentHashMap<>();

    public void register(String nodeId, KvServiceGrpc.KvServiceImplBase handler) {
        String validatedNodeId = validateNodeId(nodeId);
        KvServiceGrpc.KvServiceImplBase validatedHandler = Objects.requireNonNull(handler, "handler must not be null");
        handlersByNodeId.put(validatedNodeId, validatedHandler);
        if (validatedHandler instanceof KvServiceHandler localHandler) {
            replicaApplyHandlersByNodeId.put(validatedNodeId, localHandler);
        }
    }

    public void registerReplicaApply(String nodeId, KvServiceHandler localHandler) {
        replicaApplyHandlersByNodeId.put(
            validateNodeId(nodeId),
            Objects.requireNonNull(localHandler, "localHandler must not be null")
        );
    }

    public void registerRaftConsensus(String nodeId, RaftConsensusServiceGrpc.RaftConsensusServiceImplBase handler) {
        raftHandlersByNodeId.put(validateNodeId(nodeId), Objects.requireNonNull(handler, "handler must not be null"));
    }

    public void unregister(String nodeId) {
        String validatedNodeId = validateNodeId(nodeId);
        handlersByNodeId.remove(validatedNodeId);
        replicaApplyHandlersByNodeId.remove(validatedNodeId);
        raftHandlersByNodeId.remove(validatedNodeId);
    }

    @Override
    public GetResponse get(String nodeId, GetRequest request) {
        String validatedNodeId = validateNodeId(nodeId);
        getForwardedCalls.incrementAndGet();
        getCallsByNode.computeIfAbsent(validatedNodeId, ignored -> new AtomicLong()).incrementAndGet();

        KvServiceGrpc.KvServiceImplBase handler = handlersByNodeId.get(validatedNodeId);
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
        String validatedNodeId = validateNodeId(nodeId);
        putForwardedCalls.incrementAndGet();
        putCallsByNode.computeIfAbsent(validatedNodeId, ignored -> new AtomicLong()).incrementAndGet();

        KvServiceGrpc.KvServiceImplBase handler = handlersByNodeId.get(validatedNodeId);
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
        String validatedNodeId = validateNodeId(nodeId);
        deleteForwardedCalls.incrementAndGet();
        deleteCallsByNode.computeIfAbsent(validatedNodeId, ignored -> new AtomicLong()).incrementAndGet();

        KvServiceGrpc.KvServiceImplBase handler = handlersByNodeId.get(validatedNodeId);
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

    @Override
    public PutResponse applyReplicaPut(String nodeId, PutRequest request) {
        String validatedNodeId = validateNodeId(nodeId);
        KvServiceHandler localHandler = replicaApplyHandlersByNodeId.get(validatedNodeId);
        if (localHandler == null) {
            return PutResponse.newBuilder().setError(unavailable("no replica-apply handler for node " + nodeId)).build();
        }

        SyncResponseObserver<PutResponse> observer = new SyncResponseObserver<>();
        localHandler.put(request, observer);
        if (observer.error() != null || observer.value() == null || !observer.completed()) {
            return PutResponse.newBuilder().setError(internal("replica put failed for node " + nodeId)).build();
        }
        return observer.value();
    }

    @Override
    public DeleteResponse applyReplicaDelete(String nodeId, DeleteRequest request) {
        String validatedNodeId = validateNodeId(nodeId);
        KvServiceHandler localHandler = replicaApplyHandlersByNodeId.get(validatedNodeId);
        if (localHandler == null) {
            return DeleteResponse.newBuilder().setError(unavailable("no replica-apply handler for node " + nodeId)).build();
        }

        SyncResponseObserver<DeleteResponse> observer = new SyncResponseObserver<>();
        localHandler.delete(request, observer);
        if (observer.error() != null || observer.value() == null || !observer.completed()) {
            return DeleteResponse.newBuilder().setError(internal("replica delete failed for node " + nodeId)).build();
        }
        return observer.value();
    }

    @Override
    public RaftVoteResponse requestVote(String nodeId, RaftVoteRequest request) {
        String validatedNodeId = validateNodeId(nodeId);
        RaftConsensusServiceGrpc.RaftConsensusServiceImplBase handler = raftHandlersByNodeId.get(validatedNodeId);
        if (handler == null) {
            return RaftVoteResponse.newBuilder()
                .setTerm(request.getTerm())
                .setVoteGranted(false)
                .setLeaderId("")
                .build();
        }

        SyncResponseObserver<RaftVoteResponse> observer = new SyncResponseObserver<>();
        handler.requestVote(request, observer);
        if (observer.error() != null || observer.value() == null || !observer.completed()) {
            return RaftVoteResponse.newBuilder()
                .setTerm(request.getTerm())
                .setVoteGranted(false)
                .setLeaderId("")
                .build();
        }
        return observer.value();
    }

    @Override
    public RaftAppendEntriesResponse appendEntries(String nodeId, RaftAppendEntriesRequest request) {
        String validatedNodeId = validateNodeId(nodeId);
        RaftConsensusServiceGrpc.RaftConsensusServiceImplBase handler = raftHandlersByNodeId.get(validatedNodeId);
        if (handler == null) {
            return RaftAppendEntriesResponse.newBuilder()
                .setTerm(request.getTerm())
                .setSuccess(false)
                .setMatchIndex(0)
                .setLeaderId("")
                .build();
        }

        SyncResponseObserver<RaftAppendEntriesResponse> observer = new SyncResponseObserver<>();
        handler.appendEntries(request, observer);
        if (observer.error() != null || observer.value() == null || !observer.completed()) {
            return RaftAppendEntriesResponse.newBuilder()
                .setTerm(request.getTerm())
                .setSuccess(false)
                .setMatchIndex(0)
                .setLeaderId("")
                .build();
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

    public long getForwardedCallsTo(String nodeId) {
        return getCallsByNode.getOrDefault(validateNodeId(nodeId), new AtomicLong()).get();
    }

    public long putForwardedCallsTo(String nodeId) {
        return putCallsByNode.getOrDefault(validateNodeId(nodeId), new AtomicLong()).get();
    }

    public long deleteForwardedCallsTo(String nodeId) {
        return deleteCallsByNode.getOrDefault(validateNodeId(nodeId), new AtomicLong()).get();
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
