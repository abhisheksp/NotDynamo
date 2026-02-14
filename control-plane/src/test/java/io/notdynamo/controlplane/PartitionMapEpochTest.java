package io.notdynamo.controlplane;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class PartitionMapEpochTest {
    @Test
    void rejectsStaleAndSkippedEpochUpdates() {
        ClusterPartitionMap initial = ClusterPartitionMap.roundRobin(
            new PartitionMapVersion(0),
            16,
            64,
            List.of("node-a", "node-b")
        );
        PartitionMapManager manager = new PartitionMapManager(initial);

        ClusterPartitionMap stale = ClusterPartitionMap.roundRobin(
            new PartitionMapVersion(0),
            16,
            64,
            List.of("node-a", "node-b")
        );
        assertFalse(manager.tryApply(stale));

        Map<Integer, String> v1Assignments = rebalance(initial.shardToNodeId(), List.of("node-a", "node-b", "node-c"));
        ClusterPartitionMap v1 = manager.next(v1Assignments);
        assertTrue(manager.tryApply(v1));
        assertEquals(1L, manager.current().version().epoch());

        ClusterPartitionMap skipped = new ClusterPartitionMap(
            new PartitionMapVersion(3),
            16,
            64,
            rebalance(v1.shardToNodeId(), List.of("node-a", "node-c"))
        );
        assertFalse(manager.tryApply(skipped));

        assertEquals(1L, manager.current().version().epoch());
    }

    private static Map<Integer, String> rebalance(Map<Integer, String> existing, List<String> nodeIds) {
        Map<Integer, String> next = new HashMap<>();
        List<Integer> shards = new ArrayList<>(existing.keySet());
        shards.sort(Integer::compareTo);

        for (int i = 0; i < shards.size(); i++) {
            next.put(shards.get(i), nodeIds.get(i % nodeIds.size()));
        }
        return next;
    }
}
