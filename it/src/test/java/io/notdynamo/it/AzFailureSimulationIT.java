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

class AzFailureSimulationIT {
    @TempDir
    Path tempDir;

    @Test
    void clusterContinuesServingHealthyShardsWhenOneAzFails() {
        int shardCount = 64;
        int virtualNodesPerShard = 256;
        List<String> nodes = List.of("node-a", "node-b", "node-c");

        ClusterPartitionMap map = ClusterPartitionMap.roundRobin(
            new PartitionMapVersion(0),
            shardCount,
            virtualNodesPerShard,
            nodes
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

            PartitionedKvRouter routerA = new PartitionedKvRouter("node-a", nodeA.kvService(), transport, new PartitionMapCache(map));
            PartitionedKvRouter routerB = new PartitionedKvRouter("node-b", nodeB.kvService(), transport, new PartitionMapCache(map));

            byte[] keyOnA = findKeyForOwner(map, "node-a");
            byte[] keyOnB = findKeyForOwner(map, "node-b");
            byte[] keyOnC = findKeyForOwner(map, "node-c");

            byte[] valueA = "value-a".getBytes(StandardCharsets.UTF_8);
            byte[] valueB = "value-b".getBytes(StandardCharsets.UTF_8);

            assertFalse(routerA.put(putRequest(keyOnA, valueA)).hasError());
            assertFalse(routerA.put(putRequest(keyOnB, valueB)).hasError());

            // Simulate an AZ outage by taking node-c out of transport.
            transport.unregister("node-c");

            GetResponse readA = routerB.get(GetRequest.newBuilder().setKey(ByteString.copyFrom(keyOnA)).build());
            assertFalse(readA.hasError());
            assertTrue(readA.getFound());
            assertArrayEquals(valueA, readA.getValue().toByteArray());

            GetResponse readB = routerA.get(GetRequest.newBuilder().setKey(ByteString.copyFrom(keyOnB)).build());
            assertFalse(readB.hasError());
            assertTrue(readB.getFound());
            assertArrayEquals(valueB, readB.getValue().toByteArray());

            GetResponse readFailedShard = routerA.get(GetRequest.newBuilder().setKey(ByteString.copyFrom(keyOnC)).build());
            assertTrue(readFailedShard.hasError());
            assertEquals(StatusCode.STATUS_CODE_UNAVAILABLE, readFailedShard.getError().getCode());
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

    private static PutRequest putRequest(byte[] key, byte[] value) {
        return PutRequest.newBuilder().setKey(ByteString.copyFrom(key)).setValue(ByteString.copyFrom(value)).build();
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
