package io.notdynamo.it;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import io.notdynamo.controlplane.ClusterPartitionMap;
import io.notdynamo.controlplane.PartitionMapManager;
import io.notdynamo.controlplane.PartitionMapVersion;
import io.notdynamo.controlplane.ShardPartitionMap;
import io.notdynamo.controlplane.ShardPartitionMapManager;
import io.notdynamo.node.cluster.PartitionMapCache;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class PartitionMapConvergenceIT {
    @Test
    void metadataV2EpochUpdatesConvergeAcrossNodes() {
        List<String> nodes = List.of("node-a", "node-b", "node-c");
        ShardPartitionMap v0 = ShardPartitionMap.roundRobin(new PartitionMapVersion(0), 16, 64, nodes, 3);
        ShardPartitionMapManager manager = new ShardPartitionMapManager(v0);

        Map<Integer, String> v1Leaders = rotatedAssignments(v0.toClusterPartitionMap().shardToNodeId(), nodes, 1);
        ShardPartitionMap v1 = manager.next(v1Leaders);
        assertTrue(manager.tryApply(v1));

        Map<Integer, String> v2Leaders = rotatedAssignments(v1.toClusterPartitionMap().shardToNodeId(), nodes, 2);
        ShardPartitionMap v2 = manager.next(v2Leaders);
        assertTrue(manager.tryApply(v2));

        PartitionMapCache cacheA = new PartitionMapCache(v0.toClusterPartitionMap());
        PartitionMapCache cacheB = new PartitionMapCache(v0.toClusterPartitionMap());

        assertTrue(cacheA.tryApply(v1.toClusterPartitionMap()));
        assertTrue(cacheA.tryApply(v2.toClusterPartitionMap()));
        assertTrue(cacheB.tryApply(v2.toClusterPartitionMap()));
        assertEquals(v2.version().epoch(), cacheA.current().version().epoch());
        assertEquals(v2.version().epoch(), cacheB.current().version().epoch());
    }

    @Test
    void rollingNodeUpdatesConvergeToLatestPartitionMap() {
        List<String> nodes = List.of("node-a", "node-b", "node-c");
        ClusterPartitionMap v0 = ClusterPartitionMap.roundRobin(new PartitionMapVersion(0), 32, 128, nodes);

        PartitionMapManager manager = new PartitionMapManager(v0);

        Map<Integer, String> v1Assignments = rotatedAssignments(v0.shardToNodeId(), nodes, 1);
        ClusterPartitionMap v1 = manager.next(v1Assignments);
        assertTrue(manager.tryApply(v1));

        Map<Integer, String> v2Assignments = rotatedAssignments(v1.shardToNodeId(), nodes, 2);
        ClusterPartitionMap v2 = manager.next(v2Assignments);
        assertTrue(manager.tryApply(v2));

        PartitionMapCache cacheA = new PartitionMapCache(v0);
        PartitionMapCache cacheB = new PartitionMapCache(v0);
        PartitionMapCache cacheC = new PartitionMapCache(v0);

        assertTrue(cacheA.tryApply(v1));
        assertFalse(cacheA.tryApply(v0));

        // B skips v1 and applies v2 directly.
        assertTrue(cacheB.tryApply(v2));

        assertTrue(cacheC.tryApply(v1));
        assertTrue(cacheC.tryApply(v2));

        // A eventually receives latest map and converges.
        assertTrue(cacheA.tryApply(v2));

        long expectedEpoch = v2.version().epoch();
        assertEquals(expectedEpoch, cacheA.current().version().epoch());
        assertEquals(expectedEpoch, cacheB.current().version().epoch());
        assertEquals(expectedEpoch, cacheC.current().version().epoch());

        assertEquals(cacheA.current().shardToNodeId(), cacheB.current().shardToNodeId());
        assertEquals(cacheB.current().shardToNodeId(), cacheC.current().shardToNodeId());
    }

    private static Map<Integer, String> rotatedAssignments(Map<Integer, String> existing, List<String> nodes, int offset) {
        List<Integer> shards = new ArrayList<>(existing.keySet());
        shards.sort(Integer::compareTo);

        Map<Integer, String> assignments = new HashMap<>();
        for (int i = 0; i < shards.size(); i++) {
            assignments.put(shards.get(i), nodes.get((i + offset) % nodes.size()));
        }
        return assignments;
    }
}
