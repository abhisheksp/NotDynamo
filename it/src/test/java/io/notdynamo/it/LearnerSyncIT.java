package io.notdynamo.it;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import io.notdynamo.controlplane.ClusterPartitionMap;
import io.notdynamo.controlplane.PartitionMapVersion;
import io.notdynamo.controlplane.ReplicaPartitionMap;
import io.notdynamo.controlplane.rebalance.RebalanceThrottler;
import io.notdynamo.controlplane.rebalance.ReplicaRebalanceCoordinator;
import io.notdynamo.controlplane.rebalance.ShardMove;
import java.util.List;
import org.junit.jupiter.api.Test;

class LearnerSyncIT {
    @Test
    void learnerMovePromotesAfterLagConverges() {
        ClusterPartitionMap leaderMap = ClusterPartitionMap.roundRobin(
            new PartitionMapVersion(0),
            12,
            64,
            List.of("node-a", "node-b", "node-c")
        );
        ReplicaPartitionMap replicaMap = ReplicaPartitionMap.withUniformReplicas(
            leaderMap,
            List.of("node-a", "node-b", "node-c")
        );

        ReplicaRebalanceCoordinator coordinator = new ReplicaRebalanceCoordinator(replicaMap, 1000, 2);
        RebalanceThrottler throttler = new RebalanceThrottler(25.0);

        int shardId = shardWhereLeaderIs(leaderMap, "node-a");
        ShardMove move = new ShardMove(shardId, "node-b", "node-d");

        coordinator.startMove(move, 12.0, throttler);
        coordinator.markSnapshotTransferred(move);
        coordinator.recordLearnerLagMillis(move, 700);
        assertTrue(coordinator.readyToPromote(move));

        coordinator.finalizeMove(move);
        assertEquals(0, coordinator.activeMoveCount());

        List<String> replicas = coordinator.currentMap().replicasForShard(shardId);
        assertTrue(replicas.contains("node-d"));
        assertTrue(!replicas.contains("node-b"));
    }

    private static int shardWhereLeaderIs(ClusterPartitionMap map, String leaderNodeId) {
        for (int shard = 0; shard < map.shardCount(); shard++) {
            if (leaderNodeId.equals(map.ownerForShard(shard).orElse(null))) {
                return shard;
            }
        }
        throw new IllegalStateException("no shard found for leader " + leaderNodeId);
    }
}
