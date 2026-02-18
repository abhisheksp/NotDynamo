package io.notdynamo.it;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import io.notdynamo.controlplane.ClusterPartitionMap;
import io.notdynamo.controlplane.PartitionMapVersion;
import io.notdynamo.controlplane.ReplicaPartitionMap;
import io.notdynamo.controlplane.rebalance.RebalanceThrottler;
import io.notdynamo.controlplane.rebalance.ReplicaRebalanceCoordinator;
import io.notdynamo.controlplane.rebalance.ShardMove;
import io.notdynamo.node.NodeConfig;
import io.notdynamo.node.NodeServer;
import io.notdynamo.node.shard.ConsistentHashRing;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class ReplicaMoveDataContinuityIT {
    @TempDir
    Path tempDir;

    @Test
    void learnerMoveCopyCatchupAndCutoverRetainData() {
        int shardCount = 32;
        int virtualNodesPerShard = 128;
        ClusterPartitionMap leaderMap = ClusterPartitionMap.roundRobin(
            new PartitionMapVersion(0),
            shardCount,
            virtualNodesPerShard,
            List.of("node-a", "node-b", "node-c")
        );
        ReplicaPartitionMap replicaMap = ReplicaPartitionMap.withUniformReplicas(
            leaderMap,
            List.of("node-a", "node-b", "node-c")
        );

        int shardId = shardWhereLeaderIs(leaderMap, "node-a");
        byte[] key = findKeyForShard(leaderMap, shardId);
        byte[] value = "rebalance-data".getBytes(StandardCharsets.UTF_8);

        try (
            NodeServer nodeA = NodeServer.openSharded(configFor("node-a"), shardCount, virtualNodesPerShard);
            NodeServer nodeB = NodeServer.openSharded(configFor("node-b"), shardCount, virtualNodesPerShard);
            NodeServer nodeD = NodeServer.openSharded(configFor("node-d"), shardCount, virtualNodesPerShard)
        ) {
            assertTrue(nodeA.keyValueStore().put(key, value) > 0);
            assertTrue(nodeB.keyValueStore().put(key, value) > 0);

            ReplicaRebalanceCoordinator coordinator = new ReplicaRebalanceCoordinator(replicaMap, 1000, 1);
            RebalanceThrottler throttler = new RebalanceThrottler(25.0);
            ShardMove move = new ShardMove(shardId, "node-b", "node-d");

            coordinator.startMove(move, 10.0, throttler);
            coordinator.markSnapshotTransferred(move);

            // Simulate snapshot copy/catchup from source learner to target learner.
            var sourceRecord = nodeB.keyValueStore().get(key);
            assertTrue(sourceRecord.found());
            assertTrue(nodeD.keyValueStore().put(key, sourceRecord.value()) > 0);

            coordinator.recordLearnerLagMillis(move, 0);
            coordinator.markCatchupComplete(move);
            assertTrue(coordinator.readyToPromote(move));
            coordinator.finalizeMove(move);

            List<String> replicas = coordinator.currentMap().replicasForShard(shardId);
            assertTrue(replicas.contains("node-d"));
            assertTrue(!replicas.contains("node-b"));

            var targetRecord = nodeD.keyValueStore().get(key);
            assertTrue(targetRecord.found());
            assertArrayEquals(value, targetRecord.value());
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

    private static int shardWhereLeaderIs(ClusterPartitionMap map, String leaderNodeId) {
        for (int shard = 0; shard < map.shardCount(); shard++) {
            if (leaderNodeId.equals(map.ownerForShard(shard).orElse(null))) {
                return shard;
            }
        }
        throw new IllegalStateException("no shard found for leader " + leaderNodeId);
    }

    private static byte[] findKeyForShard(ClusterPartitionMap map, int targetShard) {
        Set<Integer> shardIds = new HashSet<>();
        for (int shard = 0; shard < map.shardCount(); shard++) {
            shardIds.add(shard);
        }
        ConsistentHashRing ring = ConsistentHashRing.create(shardIds, map.virtualNodesPerShard());
        for (int i = 0; i < 2_000_000; i++) {
            byte[] candidate = ("rebalance-key-" + i).getBytes(StandardCharsets.UTF_8);
            if (ring.shardForKey(candidate) == targetShard) {
                return candidate;
            }
        }
        throw new IllegalStateException("unable to find key for shard " + targetShard);
    }
}
