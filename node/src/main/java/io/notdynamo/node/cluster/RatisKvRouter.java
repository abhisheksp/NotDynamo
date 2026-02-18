package io.notdynamo.node.cluster;

import io.notdynamo.controlplane.ReplicaPartitionMap;
import io.notdynamo.node.KvServiceHandler;
import io.notdynamo.node.shard.ConsistentHashRing;
import io.notdynamo.proto.v1.DeleteRequest;
import io.notdynamo.proto.v1.DeleteResponse;
import io.notdynamo.proto.v1.Error;
import io.notdynamo.proto.v1.GetRequest;
import io.notdynamo.proto.v1.GetResponse;
import io.notdynamo.proto.v1.PutRequest;
import io.notdynamo.proto.v1.PutResponse;
import io.notdynamo.proto.v1.StatusCode;
import io.notdynamo.ratis.ConsensusEngine;
import java.util.HashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;

public final class RatisKvRouter {
    private static final int MAX_CONSENSUS_WRITE_ATTEMPTS = 4;
    private static final long CONSENSUS_RETRY_BACKOFF_MS = 20L;
    private static final long MAX_CONSENSUS_WRITE_DURATION_MS = 2500L;

    private final String localNodeId;
    private final KvServiceHandler localService;
    private final NodeRpcClient rpcClient;
    private final ReplicaPartitionMap replicaMap;
    private final ConsensusEngine consensusEngine;

    private volatile long ringEpoch = Long.MIN_VALUE;
    private volatile ConsistentHashRing ring;

    public RatisKvRouter(
        String localNodeId,
        KvServiceHandler localService,
        NodeRpcClient rpcClient,
        ReplicaPartitionMap replicaMap,
        ConsensusEngine consensusEngine
    ) {
        this.localNodeId = validateNodeId(localNodeId, "localNodeId");
        this.localService = Objects.requireNonNull(localService, "localService must not be null");
        this.rpcClient = Objects.requireNonNull(rpcClient, "rpcClient must not be null");
        this.replicaMap = Objects.requireNonNull(replicaMap, "replicaMap must not be null");
        this.consensusEngine = Objects.requireNonNull(consensusEngine, "consensusEngine must not be null");
    }

    public GetResponse get(GetRequest request) {
        if (request.getKey().isEmpty()) {
            return GetResponse.newBuilder().setError(invalidArgument("key must not be empty")).build();
        }

        int shardId = shardForKey(request.getKey().toByteArray());
        List<String> replicas = replicaMap.replicasForShard(shardId);
        String readNodeId = replicas.contains(localNodeId) ? localNodeId : replicaMap.leaderForShard(shardId);
        if (readNodeId == null || readNodeId.isBlank()) {
            return GetResponse.newBuilder().setError(unavailable("no read node available for shard " + shardId)).build();
        }

        if (localNodeId.equals(readNodeId)) {
            return invokeLocalGet(request);
        }
        return rpcClient.get(readNodeId, request);
    }

    public PutResponse put(PutRequest request) {
        if (request.getKey().isEmpty()) {
            return PutResponse.newBuilder().setError(invalidArgument("key must not be empty")).build();
        }

        int shardId = shardForKey(request.getKey().toByteArray());
        String leaderNodeId = replicaMap.leaderForShard(shardId);
        if (leaderNodeId == null || leaderNodeId.isBlank()) {
            return PutResponse.newBuilder().setError(unavailable("no leader for shard " + shardId)).build();
        }
        if (!localNodeId.equals(leaderNodeId)) {
            return rpcClient.put(leaderNodeId, request);
        }

        try {
            long version = writeWithRetry(
                () -> consensusEngine.put(shardId, request.getKey().toByteArray(), request.getValue().toByteArray())
            );
            return PutResponse.newBuilder().setVersion(version).build();
        } catch (IllegalArgumentException e) {
            return PutResponse.newBuilder().setError(invalidArgument(e.getMessage())).build();
        } catch (RuntimeException e) {
            return PutResponse.newBuilder().setError(unavailable("ratis put failed: " + safeMessage(e))).build();
        }
    }

    public DeleteResponse delete(DeleteRequest request) {
        if (request.getKey().isEmpty()) {
            return DeleteResponse.newBuilder().setError(invalidArgument("key must not be empty")).build();
        }

        int shardId = shardForKey(request.getKey().toByteArray());
        String leaderNodeId = replicaMap.leaderForShard(shardId);
        if (leaderNodeId == null || leaderNodeId.isBlank()) {
            return DeleteResponse.newBuilder().setError(unavailable("no leader for shard " + shardId)).build();
        }
        if (!localNodeId.equals(leaderNodeId)) {
            return rpcClient.delete(leaderNodeId, request);
        }

        try {
            long version = writeWithRetry(() -> consensusEngine.delete(shardId, request.getKey().toByteArray()));
            return DeleteResponse.newBuilder().setVersion(version).build();
        } catch (IllegalArgumentException e) {
            return DeleteResponse.newBuilder().setError(invalidArgument(e.getMessage())).build();
        } catch (RuntimeException e) {
            return DeleteResponse.newBuilder().setError(unavailable("ratis delete failed: " + safeMessage(e))).build();
        }
    }

    private int shardForKey(byte[] key) {
        return ringFor(replicaMap).shardForKey(key);
    }

    private ConsistentHashRing ringFor(ReplicaPartitionMap map) {
        long epoch = map.version().epoch();
        ConsistentHashRing cachedRing = ring;
        if (cachedRing != null && ringEpoch == epoch) {
            return cachedRing;
        }

        synchronized (this) {
            if (ring != null && ringEpoch == epoch) {
                return ring;
            }

            Set<Integer> shardIds = new HashSet<>();
            for (int shard = 0; shard < map.shardCount(); shard++) {
                shardIds.add(shard);
            }

            ring = ConsistentHashRing.create(shardIds, map.virtualNodesPerShard());
            ringEpoch = epoch;
            return ring;
        }
    }

    private GetResponse invokeLocalGet(GetRequest request) {
        SyncResponseObserver<GetResponse> observer = new SyncResponseObserver<>();
        localService.get(request, observer);
        if (observer.error() != null || observer.value() == null || !observer.completed()) {
            return GetResponse.newBuilder().setError(internal("local get invocation failed")).build();
        }
        return observer.value();
    }

    private long writeWithRetry(ConsensusWrite write) {
        long deadlineNanos = System.nanoTime() + java.util.concurrent.TimeUnit.MILLISECONDS.toNanos(MAX_CONSENSUS_WRITE_DURATION_MS);
        RuntimeException lastFailure = null;
        for (int attempt = 1; attempt <= MAX_CONSENSUS_WRITE_ATTEMPTS; attempt++) {
            try {
                return write.execute();
            } catch (RuntimeException e) {
                lastFailure = e;
                if (attempt == MAX_CONSENSUS_WRITE_ATTEMPTS) {
                    break;
                }
                if (System.nanoTime() >= deadlineNanos) {
                    break;
                }
                sleepBeforeRetry(attempt, deadlineNanos);
            }
        }
        throw lastFailure == null ? new IllegalStateException("consensus write failed without exception") : lastFailure;
    }

    private static void sleepBeforeRetry(int attempt, long deadlineNanos) {
        long delayMillis = CONSENSUS_RETRY_BACKOFF_MS * attempt;
        long remainingMillis = java.util.concurrent.TimeUnit.NANOSECONDS.toMillis(deadlineNanos - System.nanoTime());
        if (remainingMillis <= 0) {
            return;
        }
        try {
            Thread.sleep(Math.min(delayMillis, remainingMillis));
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("interrupted while retrying consensus write", e);
        }
    }

    private static String validateNodeId(String nodeId, String label) {
        if (nodeId == null || nodeId.isBlank()) {
            throw new IllegalArgumentException(label + " must not be blank");
        }
        return nodeId;
    }

    private static Error invalidArgument(String message) {
        return Error.newBuilder().setCode(StatusCode.STATUS_CODE_INVALID_ARGUMENT).setMessage(message).build();
    }

    private static Error unavailable(String message) {
        return Error.newBuilder().setCode(StatusCode.STATUS_CODE_UNAVAILABLE).setMessage(message).build();
    }

    private static Error internal(String message) {
        return Error.newBuilder().setCode(StatusCode.STATUS_CODE_INTERNAL).setMessage(message).build();
    }

    private static String safeMessage(Throwable throwable) {
        String message = throwable.getMessage();
        if (message == null || message.isBlank()) {
            return throwable.getClass().getSimpleName();
        }
        return message;
    }

    @FunctionalInterface
    private interface ConsensusWrite {
        long execute();
    }
}
