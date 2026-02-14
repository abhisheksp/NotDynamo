package io.notdynamo.controlplane;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import org.junit.jupiter.api.Test;

class ReplicaPartitionMapTest {
    @Test
    void uniformReplicaPlacementContainsShardLeaderAndFollowers() {
        ClusterPartitionMap leaderMap = ClusterPartitionMap.roundRobin(
            new PartitionMapVersion(0),
            8,
            64,
            List.of("node-a", "node-b")
        );

        ReplicaPartitionMap replicaMap = ReplicaPartitionMap.withUniformReplicas(
            leaderMap,
            List.of("node-a", "node-b", "node-c")
        );

        for (int shard = 0; shard < leaderMap.shardCount(); shard++) {
            String leader = replicaMap.leaderForShard(shard);
            List<String> replicas = replicaMap.replicasForShard(shard);

            assertEquals(leader, replicas.get(0));
            assertTrue(replicas.contains("node-c"));
            assertEquals(3, replicas.size());
        }
    }
}
