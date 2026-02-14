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
import java.util.HashSet;
import java.util.Objects;
import java.util.Set;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;

public final class EventualKvRouter {
    private final String localNodeId;
    private final KvServiceHandler localService;
    private final NodeRpcClient rpcClient;
    private final ReplicaLagTracker lagTracker;
    private final FreshReplicaPicker replicaPicker;
    private final long freshnessBudgetMillis;
    private final AtomicReference<ReplicaPartitionMap> replicaMapRef;
    private final AtomicLong leaderFallbackReads = new AtomicLong();

    private volatile long ringEpoch = Long.MIN_VALUE;
    private volatile ConsistentHashRing ring;

    public EventualKvRouter(
        String localNodeId,
        KvServiceHandler localService,
        NodeRpcClient rpcClient,
        ReplicaPartitionMap initialReplicaMap,
        ReplicaLagTracker lagTracker,
        long freshnessBudgetMillis
    ) {
        this.localNodeId = validateNodeId(localNodeId, "localNodeId");
        this.localService = Objects.requireNonNull(localService, "localService must not be null");
        this.rpcClient = Objects.requireNonNull(rpcClient, "rpcClient must not be null");
        this.lagTracker = Objects.requireNonNull(lagTracker, "lagTracker must not be null");
        this.replicaPicker = new FreshReplicaPicker();
        this.replicaMapRef = new AtomicReference<>(
            Objects.requireNonNull(initialReplicaMap, "initialReplicaMap must not be null")
        );
        if (freshnessBudgetMillis < 0) {
            throw new IllegalArgumentException("freshnessBudgetMillis must be >= 0");
        }
        this.freshnessBudgetMillis = freshnessBudgetMillis;
    }

    public void updateReplicaMap(ReplicaPartitionMap candidate) {
        Objects.requireNonNull(candidate, "candidate must not be null");
        while (true) {
            ReplicaPartitionMap existing = replicaMapRef.get();
            if (candidate.version().epoch() <= existing.version().epoch()) {
                return;
            }
            if (candidate.shardCount() != existing.shardCount()) {
                throw new IllegalArgumentException("shardCount cannot change in-place");
            }
            if (candidate.virtualNodesPerShard() != existing.virtualNodesPerShard()) {
                throw new IllegalArgumentException("virtualNodesPerShard cannot change in-place");
            }
            if (replicaMapRef.compareAndSet(existing, candidate)) {
                return;
            }
        }
    }

    public GetResponse get(GetRequest request) {
        if (request.getKey().isEmpty()) {
            return GetResponse.newBuilder().setError(invalidArgument("key must not be empty")).build();
        }

        ReplicaPartitionMap map = replicaMapRef.get();
        int shardId = ringFor(map).shardForKey(request.getKey().toByteArray());
        String leaderNodeId = map.leaderForShard(shardId);
        String readNodeId = replicaPicker.pickFreshFollower(
            shardId,
            leaderNodeId,
            map.replicasForShard(shardId),
            lagTracker,
            freshnessBudgetMillis
        );

        if (readNodeId == null) {
            readNodeId = leaderNodeId;
            leaderFallbackReads.incrementAndGet();
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

        ReplicaPartitionMap map = replicaMapRef.get();
        int shardId = ringFor(map).shardForKey(request.getKey().toByteArray());
        String leaderNodeId = map.leaderForShard(shardId);

        if (localNodeId.equals(leaderNodeId)) {
            return invokeLocalPut(request);
        }
        return rpcClient.put(leaderNodeId, request);
    }

    public DeleteResponse delete(DeleteRequest request) {
        if (request.getKey().isEmpty()) {
            return DeleteResponse.newBuilder().setError(invalidArgument("key must not be empty")).build();
        }

        ReplicaPartitionMap map = replicaMapRef.get();
        int shardId = ringFor(map).shardForKey(request.getKey().toByteArray());
        String leaderNodeId = map.leaderForShard(shardId);

        if (localNodeId.equals(leaderNodeId)) {
            return invokeLocalDelete(request);
        }
        return rpcClient.delete(leaderNodeId, request);
    }

    public long leaderFallbackReads() {
        return leaderFallbackReads.get();
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

    private PutResponse invokeLocalPut(PutRequest request) {
        SyncResponseObserver<PutResponse> observer = new SyncResponseObserver<>();
        localService.put(request, observer);
        if (observer.error() != null || observer.value() == null || !observer.completed()) {
            return PutResponse.newBuilder().setError(internal("local put invocation failed")).build();
        }
        return observer.value();
    }

    private DeleteResponse invokeLocalDelete(DeleteRequest request) {
        SyncResponseObserver<DeleteResponse> observer = new SyncResponseObserver<>();
        localService.delete(request, observer);
        if (observer.error() != null || observer.value() == null || !observer.completed()) {
            return DeleteResponse.newBuilder().setError(internal("local delete invocation failed")).build();
        }
        return observer.value();
    }

    private static String validateNodeId(String nodeId, String fieldName) {
        if (nodeId == null || nodeId.isBlank()) {
            throw new IllegalArgumentException(fieldName + " must not be blank");
        }
        return nodeId;
    }

    private static Error invalidArgument(String message) {
        return Error.newBuilder().setCode(StatusCode.STATUS_CODE_INVALID_ARGUMENT).setMessage(message).build();
    }

    private static Error internal(String message) {
        return Error.newBuilder().setCode(StatusCode.STATUS_CODE_INTERNAL).setMessage(message).build();
    }
}
