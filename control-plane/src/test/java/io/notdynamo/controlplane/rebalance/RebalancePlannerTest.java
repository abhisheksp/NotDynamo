package io.notdynamo.controlplane.rebalance;

import static org.junit.jupiter.api.Assertions.assertTrue;

import io.notdynamo.controlplane.ClusterPartitionMap;
import io.notdynamo.controlplane.PartitionMapVersion;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.Test;

class RebalancePlannerTest {
    @Test
    void plannerProducesMovesThatReduceSkew() {
        ClusterPartitionMap skewed = new ClusterPartitionMap(
            new PartitionMapVersion(0),
            12,
            64,
            assignmentsAllToNodeA(12)
        );

        RebalancePlanner planner = new RebalancePlanner();
        RebalancePlan plan = planner.plan(skewed, Set.of("node-a", "node-b", "node-c"), 4);

        assertTrue(plan.moves().size() <= 4);
        assertTrue(plan.moves().stream().allMatch(move -> move.sourceNodeId().equals("node-a")));
        assertTrue(plan.moves().stream().allMatch(move -> !move.targetNodeId().equals("node-a")));

        ClusterPartitionMap applied = plan.apply(skewed, new PartitionMapVersion(1));
        assertTrue(shardCountFor(skewed, "node-a") > shardCountFor(applied, "node-a"));
        assertTrue(shardCountFor(applied, "node-b") > 0 || shardCountFor(applied, "node-c") > 0);
    }

    private static Map<Integer, String> assignmentsAllToNodeA(int shardCount) {
        Map<Integer, String> map = new HashMap<>();
        for (int shard = 0; shard < shardCount; shard++) {
            map.put(shard, "node-a");
        }
        return map;
    }

    private static int shardCountFor(ClusterPartitionMap map, String nodeId) {
        int count = 0;
        for (String owner : map.shardToNodeId().values()) {
            if (nodeId.equals(owner)) {
                count += 1;
            }
        }
        return count;
    }
}
