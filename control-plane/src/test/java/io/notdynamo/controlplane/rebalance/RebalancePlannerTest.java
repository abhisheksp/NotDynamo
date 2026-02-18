package io.notdynamo.controlplane.rebalance;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import io.notdynamo.controlplane.ClusterPartitionMap;
import io.notdynamo.controlplane.PartitionMapVersion;
import java.util.HashSet;
import java.util.HashMap;
import java.util.List;
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
        assertNoDuplicateShardMoves(plan);
    }

    @Test
    void plannerMovesAllStrandedShardsWhenNodeIsRemoved() {
        int shardCount = 18;
        ClusterPartitionMap base = ClusterPartitionMap.roundRobin(
            new PartitionMapVersion(0),
            shardCount,
            64,
            List.of("node-a", "node-b", "node-c")
        );

        RebalancePlanner planner = new RebalancePlanner();
        RebalancePlan plan = planner.plan(base, Set.of("node-a", "node-b"), 64);
        ClusterPartitionMap applied = plan.apply(base, new PartitionMapVersion(1));

        int strandedBefore = shardCountFor(base, "node-c");
        assertEquals(strandedBefore, plan.moves().size(), "all stranded shards should be remapped on node removal");
        assertEquals(0, shardCountFor(applied, "node-c"));
        assertTrue(maxSkew(applied, Set.of("node-a", "node-b")) <= 1);
        assertNoDuplicateShardMoves(plan);
    }

    @Test
    void plannerAssignsShardsToNewNodeOnScaleOut() {
        int shardCount = 12;
        ClusterPartitionMap base = ClusterPartitionMap.roundRobin(
            new PartitionMapVersion(0),
            shardCount,
            64,
            List.of("node-a", "node-b")
        );

        RebalancePlanner planner = new RebalancePlanner();
        RebalancePlan plan = planner.plan(base, Set.of("node-a", "node-b", "node-c"), shardCount);
        ClusterPartitionMap applied = plan.apply(base, new PartitionMapVersion(1));

        assertTrue(shardCountFor(applied, "node-c") > 0, "new node should receive shard ownership");
        assertTrue(maxSkew(applied, Set.of("node-a", "node-b", "node-c")) <= 1);
        assertNoDuplicateShardMoves(plan);
    }

    @Test
    void plannerRespectsMoveBudgetAndLiveNodeTargets() {
        ClusterPartitionMap skewed = new ClusterPartitionMap(
            new PartitionMapVersion(0),
            20,
            64,
            assignmentsAllToNodeA(20)
        );

        RebalancePlanner planner = new RebalancePlanner();
        RebalancePlan plan = planner.plan(skewed, Set.of("node-a", "node-b", "node-c", "node-d"), 5);

        assertTrue(plan.moves().size() <= 5);
        assertNoDuplicateShardMoves(plan);
        for (ShardMove move : plan.moves()) {
            assertFalse(move.targetNodeId().isBlank());
            assertTrue(Set.of("node-a", "node-b", "node-c", "node-d").contains(move.targetNodeId()));
        }
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

    private static int maxSkew(ClusterPartitionMap map, Set<String> nodes) {
        int min = Integer.MAX_VALUE;
        int max = Integer.MIN_VALUE;
        for (String node : nodes) {
            int count = shardCountFor(map, node);
            min = Math.min(min, count);
            max = Math.max(max, count);
        }
        return max - min;
    }

    private static void assertNoDuplicateShardMoves(RebalancePlan plan) {
        Set<Integer> movedShards = new HashSet<>();
        for (ShardMove move : plan.moves()) {
            assertTrue(movedShards.add(move.shardId()), "duplicate move for shard " + move.shardId());
        }
    }
}
