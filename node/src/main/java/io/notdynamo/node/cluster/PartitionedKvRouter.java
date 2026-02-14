package io.notdynamo.node.cluster;

import io.notdynamo.controlplane.ClusterPartitionMap;
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

public final class PartitionedKvRouter {
    private final String localNodeId;
    private final KvServiceHandler localService;
    private final NodeRpcClient rpcClient;
    private final PartitionMapCache partitionMapCache;

    private volatile long ringEpoch = Long.MIN_VALUE;
    private volatile ConsistentHashRing ring;

    public PartitionedKvRouter(
        String localNodeId,
        KvServiceHandler localService,
        NodeRpcClient rpcClient,
        PartitionMapCache partitionMapCache
    ) {
        this.localNodeId = validateNodeId(localNodeId);
        this.localService = Objects.requireNonNull(localService, "localService must not be null");
        this.rpcClient = Objects.requireNonNull(rpcClient, "rpcClient must not be null");
        this.partitionMapCache = Objects.requireNonNull(partitionMapCache, "partitionMapCache must not be null");
    }

    public GetResponse get(GetRequest request) {
        if (request.getKey().isEmpty()) {
            return GetResponse.newBuilder().setError(invalidArgument("key must not be empty")).build();
        }

        ClusterPartitionMap map = partitionMapCache.current();
        String ownerNodeId = ownerNodeIdForKey(request.getKey().toByteArray(), map);
        if (ownerNodeId == null) {
            return GetResponse.newBuilder().setError(unavailable("no owner found for key")).build();
        }

        if (localNodeId.equals(ownerNodeId)) {
            return invokeLocalGet(request);
        }
        return rpcClient.get(ownerNodeId, request);
    }

    public PutResponse put(PutRequest request) {
        if (request.getKey().isEmpty()) {
            return PutResponse.newBuilder().setError(invalidArgument("key must not be empty")).build();
        }

        ClusterPartitionMap map = partitionMapCache.current();
        String ownerNodeId = ownerNodeIdForKey(request.getKey().toByteArray(), map);
        if (ownerNodeId == null) {
            return PutResponse.newBuilder().setError(unavailable("no owner found for key")).build();
        }

        if (localNodeId.equals(ownerNodeId)) {
            return invokeLocalPut(request);
        }
        return rpcClient.put(ownerNodeId, request);
    }

    public DeleteResponse delete(DeleteRequest request) {
        if (request.getKey().isEmpty()) {
            return DeleteResponse.newBuilder().setError(invalidArgument("key must not be empty")).build();
        }

        ClusterPartitionMap map = partitionMapCache.current();
        String ownerNodeId = ownerNodeIdForKey(request.getKey().toByteArray(), map);
        if (ownerNodeId == null) {
            return DeleteResponse.newBuilder().setError(unavailable("no owner found for key")).build();
        }

        if (localNodeId.equals(ownerNodeId)) {
            return invokeLocalDelete(request);
        }
        return rpcClient.delete(ownerNodeId, request);
    }

    private String ownerNodeIdForKey(byte[] key, ClusterPartitionMap map) {
        ConsistentHashRing ringForMap = ringFor(map);
        int shardId = ringForMap.shardForKey(key);
        return map.ownerForShard(shardId).orElse(null);
    }

    private ConsistentHashRing ringFor(ClusterPartitionMap map) {
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

    private static String validateNodeId(String nodeId) {
        if (nodeId == null || nodeId.isBlank()) {
            throw new IllegalArgumentException("localNodeId must not be blank");
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
}
