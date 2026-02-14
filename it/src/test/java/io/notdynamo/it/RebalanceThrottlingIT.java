package io.notdynamo.it;

import static org.junit.jupiter.api.Assertions.assertThrows;

import io.notdynamo.controlplane.ClusterPartitionMap;
import io.notdynamo.controlplane.PartitionMapVersion;
import io.notdynamo.controlplane.ReplicaPartitionMap;
import io.notdynamo.controlplane.rebalance.RebalanceThrottler;
import io.notdynamo.controlplane.rebalance.ReplicaRebalanceCoordinator;
import io.notdynamo.controlplane.rebalance.ShardMove;
import java.util.List;
import org.junit.jupiter.api.Test;

class RebalanceThrottlingIT {
    @Test
    void moveStartIsPausedWhenReadP99BreachesThreshold() {
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

        ReplicaRebalanceCoordinator coordinator = new ReplicaRebalanceCoordinator(replicaMap, 1000, 1);
        RebalanceThrottler throttler = new RebalanceThrottler(20.0);

        int shardId = shardWhereLeaderIs(leaderMap, "node-a");
        ShardMove move = new ShardMove(shardId, "node-b", "node-d");

        assertThrows(
            IllegalStateException.class,
            () -> coordinator.startMove(move, 21.0, throttler)
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
}
