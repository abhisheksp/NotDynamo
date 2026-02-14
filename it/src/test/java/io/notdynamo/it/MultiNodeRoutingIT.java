package io.notdynamo.it;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.google.protobuf.ByteString;
import io.notdynamo.controlplane.ClusterPartitionMap;
import io.notdynamo.controlplane.PartitionMapVersion;
import io.notdynamo.node.NodeConfig;
import io.notdynamo.node.NodeServer;
import io.notdynamo.node.cluster.InMemoryNodeRpcClient;
import io.notdynamo.node.cluster.PartitionMapCache;
import io.notdynamo.node.cluster.PartitionedKvRouter;
import io.notdynamo.node.shard.ConsistentHashRing;
import io.notdynamo.proto.v1.DeleteRequest;
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

class MultiNodeRoutingIT {
    @TempDir
    Path tempDir;

    @Test
    void routesRequestsToShardOwnerAcrossNodes() {
        int shardCount = 64;
        int virtualNodesPerShard = 256;
        List<String> nodeIds = List.of("node-a", "node-b", "node-c");

        ClusterPartitionMap partitionMap = ClusterPartitionMap.roundRobin(
            new PartitionMapVersion(0),
            shardCount,
            virtualNodesPerShard,
            nodeIds
        );

        try (
            NodeServer nodeA = NodeServer.openSharded(configFor("node-a"), shardCount, virtualNodesPerShard);
            NodeServer nodeB = NodeServer.openSharded(configFor("node-b"), shardCount, virtualNodesPerShard);
            NodeServer nodeC = NodeServer.openSharded(configFor("node-c"), shardCount, virtualNodesPerShard)
        ) {
            InMemoryNodeRpcClient transport = new InMemoryNodeRpcClient();
            transport.register("node-a", nodeA.kvService());
            transport.register("node-b", nodeB.kvService());
            transport.register("node-c", nodeC.kvService());

            PartitionedKvRouter routerA = new PartitionedKvRouter(
                "node-a",
                nodeA.kvService(),
                transport,
                new PartitionMapCache(partitionMap)
            );
            PartitionedKvRouter routerB = new PartitionedKvRouter(
                "node-b",
                nodeB.kvService(),
                transport,
                new PartitionMapCache(partitionMap)
            );
            PartitionedKvRouter routerC = new PartitionedKvRouter(
                "node-c",
                nodeC.kvService(),
                transport,
                new PartitionMapCache(partitionMap)
            );

            byte[] key = findKeyForOwner(partitionMap, "node-b");
            byte[] value = "profile-v1".getBytes(StandardCharsets.UTF_8);

            PutResponse putResponse = routerA.put(
                PutRequest.newBuilder().setKey(ByteString.copyFrom(key)).setValue(ByteString.copyFrom(value)).build()
            );
            assertFalse(putResponse.hasError());
            assertEquals(1L, putResponse.getVersion());

            GetResponse readFromOwner = routerB.get(GetRequest.newBuilder().setKey(ByteString.copyFrom(key)).build());
            assertFalse(readFromOwner.hasError());
            assertTrue(readFromOwner.getFound());
            assertArrayEquals(value, readFromOwner.getValue().toByteArray());

            GetResponse readFromOtherNode = routerC.get(GetRequest.newBuilder().setKey(ByteString.copyFrom(key)).build());
            assertFalse(readFromOtherNode.hasError());
            assertTrue(readFromOtherNode.getFound());
            assertArrayEquals(value, readFromOtherNode.getValue().toByteArray());

            assertTrue(transport.putForwardedCalls() >= 1, "expected forwarded put calls");
            assertTrue(transport.getForwardedCalls() >= 1, "expected forwarded get calls");

            var deleteResponse = routerA.delete(DeleteRequest.newBuilder().setKey(ByteString.copyFrom(key)).build());
            assertFalse(deleteResponse.hasError());
            assertEquals(2L, deleteResponse.getVersion());

            GetResponse postDelete = routerC.get(GetRequest.newBuilder().setKey(ByteString.copyFrom(key)).build());
            assertFalse(postDelete.hasError());
            assertFalse(postDelete.getFound());
            assertEquals(2L, postDelete.getVersion());

            assertTrue(transport.deleteForwardedCalls() >= 1, "expected forwarded delete calls");
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
