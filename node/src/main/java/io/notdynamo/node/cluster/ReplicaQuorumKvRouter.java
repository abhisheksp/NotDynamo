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
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;

public final class ReplicaQuorumKvRouter {
    private final String localNodeId;
    private final KvServiceHandler localService;
    private final NodeRpcClient rpcClient;
    private final ReplicaPartitionMap replicaMap;
    private final int writeQuorumAcks;

    private volatile long ringEpoch = Long.MIN_VALUE;
    private volatile ConsistentHashRing ring;

    public ReplicaQuorumKvRouter(
        String localNodeId,
        KvServiceHandler localService,
        NodeRpcClient rpcClient,
        ReplicaPartitionMap replicaMap,
        int writeQuorumAcks
    ) {
        this.localNodeId = validateNodeId(localNodeId, "localNodeId");
        this.localService = Objects.requireNonNull(localService, "localService must not be null");
        this.rpcClient = Objects.requireNonNull(rpcClient, "rpcClient must not be null");
        this.replicaMap = Objects.requireNonNull(replicaMap, "replicaMap must not be null");
        if (writeQuorumAcks <= 0) {
            throw new IllegalArgumentException("writeQuorumAcks must be > 0");
        }
        this.writeQuorumAcks = writeQuorumAcks;
    }

    public GetResponse get(GetRequest request) {
        if (request.getKey().isEmpty()) {
            return GetResponse.newBuilder().setError(invalidArgument("key must not be empty")).build();
        }

        int shardId = shardForKey(request.getKey().toByteArray());
        List<String> replicas = replicaMap.replicasForShard(shardId);
        String readNodeId = replicas.contains(localNodeId) ? localNodeId : replicas.get(0);

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
        if (!localNodeId.equals(leaderNodeId)) {
            return rpcClient.put(leaderNodeId, request);
        }

        List<String> replicas = replicaMap.replicasForShard(shardId);
        int requiredFollowerAcks = Math.max(0, writeQuorumAcks - 1);
        List<String> followers = followersFor(replicas, leaderNodeId);
        Set<String> ackedFollowers = new HashSet<>();
        int followerAcks = replicatePutUntilQuorum(followers, request, requiredFollowerAcks, ackedFollowers);
        if (followerAcks < requiredFollowerAcks) {
            return PutResponse.newBuilder()
                .setError(
                    unavailable(
                        "insufficient follower acks for quorum: required=" + requiredFollowerAcks + " received=" + followerAcks
                    )
                )
                .build();
        }

        PutResponse local = invokeLocalPut(request);
        if (local.hasError()) {
            return local;
        }

        replicatePutBestEffort(followers, request, ackedFollowers);
        return local;
    }

    public DeleteResponse delete(DeleteRequest request) {
        if (request.getKey().isEmpty()) {
            return DeleteResponse.newBuilder().setError(invalidArgument("key must not be empty")).build();
        }

        int shardId = shardForKey(request.getKey().toByteArray());
        String leaderNodeId = replicaMap.leaderForShard(shardId);
        if (!localNodeId.equals(leaderNodeId)) {
            return rpcClient.delete(leaderNodeId, request);
        }

        List<String> replicas = replicaMap.replicasForShard(shardId);
        int requiredFollowerAcks = Math.max(0, writeQuorumAcks - 1);
        List<String> followers = followersFor(replicas, leaderNodeId);
        Set<String> ackedFollowers = new HashSet<>();
        int followerAcks = replicateDeleteUntilQuorum(followers, request, requiredFollowerAcks, ackedFollowers);
        if (followerAcks < requiredFollowerAcks) {
            return DeleteResponse.newBuilder()
                .setError(
                    unavailable(
                        "insufficient follower acks for quorum: required=" + requiredFollowerAcks + " received=" + followerAcks
                    )
                )
                .build();
        }

        DeleteResponse local = invokeLocalDelete(request);
        if (local.hasError()) {
            return local;
        }

        replicateDeleteBestEffort(followers, request, ackedFollowers);
        return local;
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

    private int replicatePutUntilQuorum(
        List<String> followerNodeIds,
        PutRequest request,
        int requiredFollowerAcks,
        Set<String> ackedFollowers
    ) {
        int followerAcks = 0;
        for (String replicaNodeId : followerNodeIds) {
            PutResponse response = rpcClient.applyReplicaPut(replicaNodeId, request);
            if (!response.hasError()) {
                followerAcks += 1;
                ackedFollowers.add(replicaNodeId);
                if (followerAcks >= requiredFollowerAcks) {
                    return followerAcks;
                }
            }
        }
        return followerAcks;
    }

    private int replicateDeleteUntilQuorum(
        List<String> followerNodeIds,
        DeleteRequest request,
        int requiredFollowerAcks,
        Set<String> ackedFollowers
    ) {
        int followerAcks = 0;
        for (String replicaNodeId : followerNodeIds) {
            DeleteResponse response = rpcClient.applyReplicaDelete(replicaNodeId, request);
            if (!response.hasError()) {
                followerAcks += 1;
                ackedFollowers.add(replicaNodeId);
                if (followerAcks >= requiredFollowerAcks) {
                    return followerAcks;
                }
            }
        }
        return followerAcks;
    }

    private void replicatePutBestEffort(List<String> followerNodeIds, PutRequest request, Set<String> ackedFollowers) {
        for (String replicaNodeId : followerNodeIds) {
            if (ackedFollowers.contains(replicaNodeId)) {
                continue;
            }
            rpcClient.applyReplicaPut(replicaNodeId, request);
        }
    }

    private void replicateDeleteBestEffort(List<String> followerNodeIds, DeleteRequest request, Set<String> ackedFollowers) {
        for (String replicaNodeId : followerNodeIds) {
            if (ackedFollowers.contains(replicaNodeId)) {
                continue;
            }
            rpcClient.applyReplicaDelete(replicaNodeId, request);
        }
    }

    private static List<String> followersFor(List<String> replicas, String leaderNodeId) {
        List<String> followers = new ArrayList<>(Math.max(0, replicas.size() - 1));
        for (String replica : replicas) {
            if (!replica.equals(leaderNodeId)) {
                followers.add(replica);
            }
        }
        return followers;
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
}
