package io.notdynamo.it;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.google.protobuf.ByteString;
import io.notdynamo.controlplane.ClusterPartitionMap;
import io.notdynamo.controlplane.PartitionMapVersion;
import io.notdynamo.controlplane.ReplicaPartitionMap;
import io.notdynamo.node.NodeConfig;
import io.notdynamo.node.NodeServer;
import io.notdynamo.node.cluster.InMemoryNodeRpcClient;
import io.notdynamo.node.cluster.RaftConsensusServiceHandler;
import io.notdynamo.node.cluster.RaftKvRouter;
import io.notdynamo.node.cluster.RaftKvServiceHandler;
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

class RaftRoutingIT {
    @TempDir
    Path tempDir;

    @Test
    void followerWriteForwardsToLeaderAndReplicatesToOtherReplicas() {
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

            RaftKvRouter routerA = new RaftKvRouter("node-a", nodeA.kvService(), transport, replicaMap);
            RaftKvRouter routerB = new RaftKvRouter("node-b", nodeB.kvService(), transport, replicaMap);
            RaftKvRouter routerC = new RaftKvRouter("node-c", nodeC.kvService(), transport, replicaMap);

            transport.register("node-a", new RaftKvServiceHandler(routerA));
            transport.register("node-b", new RaftKvServiceHandler(routerB));
            transport.register("node-c", new RaftKvServiceHandler(routerC));
            transport.registerRaftConsensus("node-a", new RaftConsensusServiceHandler(routerA));
            transport.registerRaftConsensus("node-b", new RaftConsensusServiceHandler(routerB));
            transport.registerRaftConsensus("node-c", new RaftConsensusServiceHandler(routerC));

            byte[] key = findKeyForOwner(leaderMap, "node-a");
            byte[] value = "raft-forward".getBytes(StandardCharsets.UTF_8);

            PutResponse put = routerB.put(
                PutRequest.newBuilder().setKey(ByteString.copyFrom(key)).setValue(ByteString.copyFrom(value)).build()
            );
            assertFalse(put.hasError(), () -> "raft put failed: " + put.getError().getMessage());
            assertTrue(transport.putForwardedCallsTo("node-a") >= 1, "expected forwarded put to known leader");

            GetResponse readFromC = routerC.get(GetRequest.newBuilder().setKey(ByteString.copyFrom(key)).build());
            assertFalse(readFromC.hasError());
            assertTrue(readFromC.getFound());
            assertArrayEquals(value, readFromC.getValue().toByteArray());
        }
    }

    @Test
    void electsNewLeaderWhenKnownLeaderIsUnavailableAndStillCommitsWithQuorum() {
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

            RaftKvRouter routerA = new RaftKvRouter("node-a", nodeA.kvService(), transport, replicaMap);
            RaftKvRouter routerB = new RaftKvRouter("node-b", nodeB.kvService(), transport, replicaMap);
            RaftKvRouter routerC = new RaftKvRouter("node-c", nodeC.kvService(), transport, replicaMap);

            // Simulate leader outage by leaving node-a unregistered in transport.
            transport.register("node-b", new RaftKvServiceHandler(routerB));
            transport.register("node-c", new RaftKvServiceHandler(routerC));
            transport.registerRaftConsensus("node-b", new RaftConsensusServiceHandler(routerB));
            transport.registerRaftConsensus("node-c", new RaftConsensusServiceHandler(routerC));

            byte[] key = findKeyForOwner(leaderMap, "node-a");
            byte[] value = "raft-re-elected".getBytes(StandardCharsets.UTF_8);

            PutResponse put = routerB.put(
                PutRequest.newBuilder().setKey(ByteString.copyFrom(key)).setValue(ByteString.copyFrom(value)).build()
            );
            assertFalse(put.hasError(), () -> "raft put should succeed after election: " + put.getError().getMessage());
            assertTrue(transport.putForwardedCallsTo("node-a") >= 1, "expected initial forward attempt to old leader");

            GetResponse readFromC = routerC.get(GetRequest.newBuilder().setKey(ByteString.copyFrom(key)).build());
            assertFalse(readFromC.hasError());
            assertTrue(readFromC.getFound());
            assertArrayEquals(value, readFromC.getValue().toByteArray());
        }
    }

    @Test
    void writeFailsWhenQuorumCannotBeReachedAndEntryIsNotAppliedLocally() {
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
            RaftKvRouter routerB = new RaftKvRouter("node-b", nodeB.kvService(), transport, replicaMap);

            // Only node-b is reachable. node-a and node-c are unavailable.
            transport.register("node-b", new RaftKvServiceHandler(routerB));
            transport.registerRaftConsensus("node-b", new RaftConsensusServiceHandler(routerB));

            byte[] key = findKeyForOwner(leaderMap, "node-a");
            byte[] value = "raft-no-quorum".getBytes(StandardCharsets.UTF_8);

            PutResponse put = routerB.put(
                PutRequest.newBuilder().setKey(ByteString.copyFrom(key)).setValue(ByteString.copyFrom(value)).build()
            );
            assertTrue(put.hasError());
            assertEquals(StatusCode.STATUS_CODE_UNAVAILABLE, put.getError().getCode());

            GetResponse localRead = routerB.get(GetRequest.newBuilder().setKey(ByteString.copyFrom(key)).build());
            assertFalse(localRead.hasError());
            assertFalse(localRead.getFound());
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
}
