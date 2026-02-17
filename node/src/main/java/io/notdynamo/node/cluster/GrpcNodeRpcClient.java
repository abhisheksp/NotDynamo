package io.notdynamo.node.cluster;

import io.grpc.ManagedChannel;
import io.grpc.ManagedChannelBuilder;
import io.grpc.Status;
import io.grpc.StatusRuntimeException;
import io.notdynamo.proto.v1.DeleteRequest;
import io.notdynamo.proto.v1.DeleteResponse;
import io.notdynamo.proto.v1.Error;
import io.notdynamo.proto.v1.GetRequest;
import io.notdynamo.proto.v1.GetResponse;
import io.notdynamo.proto.v1.KvServiceGrpc;
import io.notdynamo.proto.v1.PutRequest;
import io.notdynamo.proto.v1.PutResponse;
import io.notdynamo.proto.v1.ReplicaApplyServiceGrpc;
import io.notdynamo.proto.v1.StatusCode;
import java.util.Objects;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;
import java.util.function.Function;

public final class GrpcNodeRpcClient implements NodeRpcClient {
    private final Function<String, String> targetResolver;
    private final long timeoutMillis;
    private final ConcurrentHashMap<String, ManagedChannel> channelsByNodeId = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, KvServiceGrpc.KvServiceBlockingStub> stubsByNodeId = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, ReplicaApplyServiceGrpc.ReplicaApplyServiceBlockingStub> replicaStubsByNodeId =
        new ConcurrentHashMap<>();

    public GrpcNodeRpcClient(Function<String, String> targetResolver, long timeoutMillis) {
        this.targetResolver = Objects.requireNonNull(targetResolver, "targetResolver must not be null");
        if (timeoutMillis <= 0) {
            throw new IllegalArgumentException("timeoutMillis must be > 0");
        }
        this.timeoutMillis = timeoutMillis;
    }

    @Override
    public GetResponse get(String nodeId, GetRequest request) {
        String validatedNodeId = validateNodeId(nodeId);
        try {
            return stubFor(validatedNodeId).withDeadlineAfter(timeoutMillis, TimeUnit.MILLISECONDS).get(request);
        } catch (StatusRuntimeException e) {
            return GetResponse.newBuilder().setError(errorFromException(validatedNodeId, e)).build();
        } catch (RuntimeException e) {
            return GetResponse.newBuilder().setError(internal(validatedNodeId, e)).build();
        }
    }

    @Override
    public PutResponse put(String nodeId, PutRequest request) {
        String validatedNodeId = validateNodeId(nodeId);
        try {
            return stubFor(validatedNodeId).withDeadlineAfter(timeoutMillis, TimeUnit.MILLISECONDS).put(request);
        } catch (StatusRuntimeException e) {
            return PutResponse.newBuilder().setError(errorFromException(validatedNodeId, e)).build();
        } catch (RuntimeException e) {
            return PutResponse.newBuilder().setError(internal(validatedNodeId, e)).build();
        }
    }

    @Override
    public DeleteResponse delete(String nodeId, DeleteRequest request) {
        String validatedNodeId = validateNodeId(nodeId);
        try {
            return stubFor(validatedNodeId).withDeadlineAfter(timeoutMillis, TimeUnit.MILLISECONDS).delete(request);
        } catch (StatusRuntimeException e) {
            return DeleteResponse.newBuilder().setError(errorFromException(validatedNodeId, e)).build();
        } catch (RuntimeException e) {
            return DeleteResponse.newBuilder().setError(internal(validatedNodeId, e)).build();
        }
    }

    @Override
    public PutResponse applyReplicaPut(String nodeId, PutRequest request) {
        String validatedNodeId = validateNodeId(nodeId);
        try {
            return replicaStubFor(validatedNodeId).withDeadlineAfter(timeoutMillis, TimeUnit.MILLISECONDS).applyPut(request);
        } catch (StatusRuntimeException e) {
            return PutResponse.newBuilder().setError(errorFromException(validatedNodeId, e)).build();
        } catch (RuntimeException e) {
            return PutResponse.newBuilder().setError(internal(validatedNodeId, e)).build();
        }
    }

    @Override
    public DeleteResponse applyReplicaDelete(String nodeId, DeleteRequest request) {
        String validatedNodeId = validateNodeId(nodeId);
        try {
            return replicaStubFor(validatedNodeId).withDeadlineAfter(timeoutMillis, TimeUnit.MILLISECONDS).applyDelete(request);
        } catch (StatusRuntimeException e) {
            return DeleteResponse.newBuilder().setError(errorFromException(validatedNodeId, e)).build();
        } catch (RuntimeException e) {
            return DeleteResponse.newBuilder().setError(internal(validatedNodeId, e)).build();
        }
    }

    @Override
    public void close() {
        for (ManagedChannel channel : channelsByNodeId.values()) {
            channel.shutdownNow();
        }
        channelsByNodeId.clear();
        stubsByNodeId.clear();
        replicaStubsByNodeId.clear();
    }

    private KvServiceGrpc.KvServiceBlockingStub stubFor(String nodeId) {
        return stubsByNodeId.computeIfAbsent(nodeId, id -> KvServiceGrpc.newBlockingStub(channelFor(id)));
    }

    private ReplicaApplyServiceGrpc.ReplicaApplyServiceBlockingStub replicaStubFor(String nodeId) {
        return replicaStubsByNodeId.computeIfAbsent(
            nodeId,
            id -> ReplicaApplyServiceGrpc.newBlockingStub(channelFor(id))
        );
    }

    private ManagedChannel channelFor(String nodeId) {
        return channelsByNodeId.computeIfAbsent(nodeId, id -> {
            String target = targetResolver.apply(id);
            if (target == null || target.isBlank()) {
                throw new IllegalArgumentException("resolved target is blank for nodeId=" + id);
            }
            return ManagedChannelBuilder.forTarget(target).usePlaintext().build();
        });
    }

    private static String validateNodeId(String nodeId) {
        if (nodeId == null || nodeId.isBlank()) {
            throw new IllegalArgumentException("nodeId must not be blank");
        }
        return nodeId;
    }

    private static Error errorFromException(String nodeId, StatusRuntimeException e) {
        Status.Code grpcCode = e.getStatus().getCode();
        return switch (grpcCode) {
            case INVALID_ARGUMENT -> Error.newBuilder()
                .setCode(StatusCode.STATUS_CODE_INVALID_ARGUMENT)
                .setMessage("remote invalid argument for node " + nodeId + ": " + safeMessage(e))
                .build();
            case NOT_FOUND -> Error.newBuilder()
                .setCode(StatusCode.STATUS_CODE_NOT_FOUND)
                .setMessage("remote key not found for node " + nodeId + ": " + safeMessage(e))
                .build();
            case DEADLINE_EXCEEDED -> Error.newBuilder()
                .setCode(StatusCode.STATUS_CODE_TIMEOUT)
                .setMessage("remote request timed out for node " + nodeId + ": " + safeMessage(e))
                .build();
            case UNAVAILABLE -> Error.newBuilder()
                .setCode(StatusCode.STATUS_CODE_UNAVAILABLE)
                .setMessage("remote node unavailable " + nodeId + ": " + safeMessage(e))
                .build();
            default -> Error.newBuilder()
                .setCode(StatusCode.STATUS_CODE_INTERNAL)
                .setMessage("remote request failed for node " + nodeId + ": " + safeMessage(e))
                .build();
        };
    }

    private static Error internal(String nodeId, RuntimeException e) {
        return Error.newBuilder()
            .setCode(StatusCode.STATUS_CODE_INTERNAL)
            .setMessage("internal rpc client error for node " + nodeId + ": " + safeMessage(e))
            .build();
    }

    private static String safeMessage(Throwable throwable) {
        String message = throwable.getMessage();
        if (message == null || message.isBlank()) {
            return throwable.getClass().getSimpleName();
        }
        return message;
    }
}
