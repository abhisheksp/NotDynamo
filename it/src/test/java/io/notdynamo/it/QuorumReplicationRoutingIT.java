package io.notdynamo.it;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.google.protobuf.ByteString;
import io.grpc.stub.StreamObserver;
import io.notdynamo.controlplane.ClusterPartitionMap;
import io.notdynamo.controlplane.PartitionMapVersion;
import io.notdynamo.controlplane.ReplicaPartitionMap;
import io.notdynamo.node.NodeConfig;
import io.notdynamo.node.NodeServer;
import io.notdynamo.node.cluster.InMemoryNodeRpcClient;
import io.notdynamo.node.cluster.ReplicaQuorumKvRouter;
import io.notdynamo.node.cluster.ReplicaQuorumKvServiceHandler;
import io.notdynamo.node.shard.ConsistentHashRing;
import io.notdynamo.proto.v1.GetRequest;
import io.notdynamo.proto.v1.GetResponse;
import io.notdynamo.proto.v1.PutRequest;
import io.notdynamo.proto.v1.PutResponse;
import io.notdynamo.proto.v1.StatusCode;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class QuorumReplicationRoutingIT {
    @TempDir
    Path tempDir;

    @Test
    void leaderWriteReplicatesToFollowersAndReadsSucceedAcrossReplicas() {
        int shardCount = 64;
        int virtualNodesPerShard = 256;
        List<String> nodes = List.of("node-a", "node-b", "node-c");

        ClusterPartitionMap leaderMap = ClusterPartitionMap.roundRobin(
            new PartitionMapVersion(0),
            shardCount,
            virtualNodesPerShard,
            nodes
        );
        ReplicaPartitionMap replicaMap = ReplicaPartitionMap.withUniformReplicas(leaderMap, nodes);

        try (
            NodeServer nodeA = NodeServer.openSharded(configFor("node-a"), shardCount, virtualNodesPerShard);
            NodeServer nodeB = NodeServer.openSharded(configFor("node-b"), shardCount, virtualNodesPerShard);
            NodeServer nodeC = NodeServer.openSharded(configFor("node-c"), shardCount, virtualNodesPerShard)
        ) {
            InMemoryNodeRpcClient transport = new InMemoryNodeRpcClient();

            ReplicaQuorumKvRouter routerA = new ReplicaQuorumKvRouter("node-a", nodeA.kvService(), transport, replicaMap, 2);
            ReplicaQuorumKvRouter routerB = new ReplicaQuorumKvRouter("node-b", nodeB.kvService(), transport, replicaMap, 2);
            ReplicaQuorumKvRouter routerC = new ReplicaQuorumKvRouter("node-c", nodeC.kvService(), transport, replicaMap, 2);

            transport.register("node-a", new ReplicaQuorumKvServiceHandler(routerA));
            transport.register("node-b", new ReplicaQuorumKvServiceHandler(routerB));
            transport.register("node-c", new ReplicaQuorumKvServiceHandler(routerC));
            transport.registerReplicaApply("node-a", nodeA.kvService());
            transport.registerReplicaApply("node-b", nodeB.kvService());
            transport.registerReplicaApply("node-c", nodeC.kvService());

            byte[] key = findKeyForOwner(leaderMap, "node-a");
            byte[] value = "quorum-value".getBytes(StandardCharsets.UTF_8);

            PutResponse put = routerA.put(
                PutRequest.newBuilder().setKey(ByteString.copyFrom(key)).setValue(ByteString.copyFrom(value)).build()
            );
            assertFalse(put.hasError());

            GetResponse readFromB = routerB.get(GetRequest.newBuilder().setKey(ByteString.copyFrom(key)).build());
            assertFalse(readFromB.hasError());
            assertTrue(readFromB.getFound());
            assertArrayEquals(value, readFromB.getValue().toByteArray());

            GetResponse readFromC = routerC.get(GetRequest.newBuilder().setKey(ByteString.copyFrom(key)).build());
            assertFalse(readFromC.hasError());
            assertTrue(readFromC.getFound());
            assertArrayEquals(value, readFromC.getValue().toByteArray());
        }
    }

    @Test
    void writeFailsWhenFollowerQuorumCannotBeReachedAndLeaderDoesNotApply() {
        int shardCount = 64;
        int virtualNodesPerShard = 256;
        List<String> nodes = List.of("node-a", "node-b", "node-c");

        ClusterPartitionMap leaderMap = ClusterPartitionMap.roundRobin(
            new PartitionMapVersion(0),
            shardCount,
            virtualNodesPerShard,
            nodes
        );
        ReplicaPartitionMap replicaMap = ReplicaPartitionMap.withUniformReplicas(leaderMap, nodes);

        try (
            NodeServer nodeA = NodeServer.openSharded(configFor("node-a"), shardCount, virtualNodesPerShard);
            NodeServer nodeB = NodeServer.openSharded(configFor("node-b"), shardCount, virtualNodesPerShard);
            NodeServer nodeC = NodeServer.openSharded(configFor("node-c"), shardCount, virtualNodesPerShard)
        ) {
            InMemoryNodeRpcClient transport = new InMemoryNodeRpcClient();
            ReplicaQuorumKvRouter routerA = new ReplicaQuorumKvRouter("node-a", nodeA.kvService(), transport, replicaMap, 2);

            transport.register("node-a", new ReplicaQuorumKvServiceHandler(routerA));
            transport.registerReplicaApply("node-a", nodeA.kvService());
            // Followers are intentionally not registered.

            byte[] key = findKeyForOwner(leaderMap, "node-a");
            byte[] value = "should-not-commit".getBytes(StandardCharsets.UTF_8);

            PutResponse put = routerA.put(
                PutRequest.newBuilder().setKey(ByteString.copyFrom(key)).setValue(ByteString.copyFrom(value)).build()
            );
            assertTrue(put.hasError());
            assertEquals(StatusCode.STATUS_CODE_UNAVAILABLE, put.getError().getCode());

            GetResponse localRead = callLocalGet(nodeA, key);
            assertFalse(localRead.hasError());
            assertFalse(localRead.getFound());
        }
    }

    @Test
    void nonLeaderForwardsWriteToLeaderForQuorumCommit() {
        int shardCount = 64;
        int virtualNodesPerShard = 256;
        List<String> nodes = List.of("node-a", "node-b", "node-c");

        ClusterPartitionMap leaderMap = ClusterPartitionMap.roundRobin(
            new PartitionMapVersion(0),
            shardCount,
            virtualNodesPerShard,
            nodes
        );
        ReplicaPartitionMap replicaMap = ReplicaPartitionMap.withUniformReplicas(leaderMap, nodes);

        try (
            NodeServer nodeA = NodeServer.openSharded(configFor("node-a"), shardCount, virtualNodesPerShard);
            NodeServer nodeB = NodeServer.openSharded(configFor("node-b"), shardCount, virtualNodesPerShard);
            NodeServer nodeC = NodeServer.openSharded(configFor("node-c"), shardCount, virtualNodesPerShard)
        ) {
            InMemoryNodeRpcClient transport = new InMemoryNodeRpcClient();

            ReplicaQuorumKvRouter routerA = new ReplicaQuorumKvRouter("node-a", nodeA.kvService(), transport, replicaMap, 2);
            ReplicaQuorumKvRouter routerB = new ReplicaQuorumKvRouter("node-b", nodeB.kvService(), transport, replicaMap, 2);
            ReplicaQuorumKvRouter routerC = new ReplicaQuorumKvRouter("node-c", nodeC.kvService(), transport, replicaMap, 2);

            transport.register("node-a", new ReplicaQuorumKvServiceHandler(routerA));
            transport.register("node-b", new ReplicaQuorumKvServiceHandler(routerB));
            transport.register("node-c", new ReplicaQuorumKvServiceHandler(routerC));
            transport.registerReplicaApply("node-a", nodeA.kvService());
            transport.registerReplicaApply("node-b", nodeB.kvService());
            transport.registerReplicaApply("node-c", nodeC.kvService());

            byte[] key = findKeyForOwner(leaderMap, "node-b");
            byte[] value = "forwarded-value".getBytes(StandardCharsets.UTF_8);

            PutResponse put = routerA.put(
                PutRequest.newBuilder().setKey(ByteString.copyFrom(key)).setValue(ByteString.copyFrom(value)).build()
            );
            assertFalse(put.hasError());

            GetResponse readFromC = routerC.get(GetRequest.newBuilder().setKey(ByteString.copyFrom(key)).build());
            assertFalse(readFromC.hasError());
            assertTrue(readFromC.getFound());
            assertArrayEquals(value, readFromC.getValue().toByteArray());
        }
    }

    private NodeConfig configFor(String nodeId) {
        return new NodeConfig(
            nodeId,
            "127.0.0.1",
            9000 + Math.abs(nodeId.hashCode() % 1000),
            10000 + Math.abs(nodeId.hashCode() % 1000),
            tempDir.resolve(nodeId)
        );
    }

    private static GetResponse callLocalGet(NodeServer nodeServer, byte[] key) {
        ObserverCapture<GetResponse> observer = new ObserverCapture<>();
        nodeServer.kvService().get(GetRequest.newBuilder().setKey(ByteString.copyFrom(key)).build(), observer);
        if (observer.error() != null || observer.value() == null || !observer.completed()) {
            throw new IllegalStateException("local get failed");
        }
        return observer.value();
    }

    private static byte[] findKeyForOwner(ClusterPartitionMap map, String ownerNodeId) {
        Set<Integer> shardIds = new HashSet<>();
        for (int shard = 0; shard < map.shardCount(); shard++) {
            shardIds.add(shard);
        }

        ConsistentHashRing ring = ConsistentHashRing.create(shardIds, map.virtualNodesPerShard());
        for (int i = 0; i < 500_000; i++) {
            byte[] candidate = ("key-" + i).getBytes(StandardCharsets.UTF_8);
            int shard = ring.shardForKey(candidate);
            if (ownerNodeId.equals(map.ownerForShard(shard).orElse(null))) {
                return candidate;
            }
        }

        throw new IllegalStateException("unable to find key for owner " + ownerNodeId);
    }

    private static final class ObserverCapture<T> implements StreamObserver<T> {
        private T value;
        private Throwable error;
        private boolean completed;

        @Override
        public void onNext(T value) {
            this.value = value;
        }

        @Override
        public void onError(Throwable throwable) {
            this.error = throwable;
        }

        @Override
        public void onCompleted() {
            this.completed = true;
        }

        private T value() {
            return value;
        }

        private Throwable error() {
            return error;
        }

        private boolean completed() {
            return completed;
        }
    }
}
