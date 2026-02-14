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
import io.notdynamo.node.cluster.EventualKvRouter;
import io.notdynamo.node.cluster.InMemoryNodeRpcClient;
import io.notdynamo.node.cluster.ReplicaLagTracker;
import io.notdynamo.node.shard.ConsistentHashRing;
import io.notdynamo.proto.v1.GetRequest;
import io.notdynamo.proto.v1.GetResponse;
import io.notdynamo.proto.v1.PutRequest;
import io.notdynamo.proto.v1.PutResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class EventualReadFreshnessIT {
    @TempDir
    Path tempDir;

    @Test
    void readsFromFreshFollowerWhenLagIsWithinBudget() {
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
            transport.register("node-a", nodeA.kvService());
            transport.register("node-b", nodeB.kvService());
            transport.register("node-c", nodeC.kvService());

            ReplicaLagTracker lagTracker = new ReplicaLagTracker();
            EventualKvRouter routerC = new EventualKvRouter(
                "node-c",
                nodeC.kvService(),
                transport,
                replicaMap,
                lagTracker,
                1000
            );

            byte[] key = findKeyForOwner(leaderMap, "node-a");
            byte[] value = "value-1".getBytes(StandardCharsets.UTF_8);
            PutRequest write = PutRequest.newBuilder()
                .setKey(ByteString.copyFrom(key))
                .setValue(ByteString.copyFrom(value))
                .build();

            // Write to leader first.
            PutResponse leaderWrite = routerC.put(write);
            assertFalse(leaderWrite.hasError());

            // Simulate replication applied to followers.
            assertFalse(transport.put("node-b", write).hasError());
            assertFalse(transport.put("node-c", write).hasError());

            int shardId = shardForKey(leaderMap, key);
            lagTracker.recordLagMillis(shardId, "node-b", 120);
            lagTracker.recordLagMillis(shardId, "node-c", 1300);

            long forwardedToBBefore = transport.getForwardedCallsTo("node-b");

            GetResponse response = routerC.get(GetRequest.newBuilder().setKey(ByteString.copyFrom(key)).build());
            assertFalse(response.hasError());
            assertTrue(response.getFound());
            assertArrayEquals(value, response.getValue().toByteArray());

            long forwardedToBAfter = transport.getForwardedCallsTo("node-b");
            assertEquals(forwardedToBBefore + 1, forwardedToBAfter);
            assertEquals(0L, routerC.leaderFallbackReads());
        }
    }

    @Test
    void fallsBackToLeaderWhenNoFollowerIsFresh() {
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
            transport.register("node-a", nodeA.kvService());
            transport.register("node-b", nodeB.kvService());
            transport.register("node-c", nodeC.kvService());

            ReplicaLagTracker lagTracker = new ReplicaLagTracker();
            EventualKvRouter routerC = new EventualKvRouter(
                "node-c",
                nodeC.kvService(),
                transport,
                replicaMap,
                lagTracker,
                1000
            );

            byte[] key = findKeyForOwner(leaderMap, "node-a");
            byte[] value = "value-2".getBytes(StandardCharsets.UTF_8);
            PutRequest write = PutRequest.newBuilder()
                .setKey(ByteString.copyFrom(key))
                .setValue(ByteString.copyFrom(value))
                .build();

            PutResponse leaderWrite = routerC.put(write);
            assertFalse(leaderWrite.hasError());

            int shardId = shardForKey(leaderMap, key);
            lagTracker.recordLagMillis(shardId, "node-b", 1500);
            lagTracker.recordLagMillis(shardId, "node-c", 2100);

            long leaderGetsBefore = transport.getForwardedCallsTo("node-a");

            GetResponse response = routerC.get(GetRequest.newBuilder().setKey(ByteString.copyFrom(key)).build());
            assertFalse(response.hasError());
            assertTrue(response.getFound());
            assertArrayEquals(value, response.getValue().toByteArray());

            long leaderGetsAfter = transport.getForwardedCallsTo("node-a");
            assertEquals(leaderGetsBefore + 1, leaderGetsAfter);
            assertEquals(1L, routerC.leaderFallbackReads());
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

    private static int shardForKey(ClusterPartitionMap map, byte[] key) {
        Set<Integer> shardIds = new HashSet<>();
        for (int shard = 0; shard < map.shardCount(); shard++) {
            shardIds.add(shard);
        }

        ConsistentHashRing ring = ConsistentHashRing.create(shardIds, map.virtualNodesPerShard());
        return ring.shardForKey(key);
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
