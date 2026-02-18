package io.notdynamo.controlplane;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class ShardPartitionMapManagerTest {
    @Test
    void appliesSequentialEpochAndTracksLeaderHistory() {
        ShardPartitionMap v0 = ShardPartitionMap.roundRobin(
            new PartitionMapVersion(0),
            4,
            64,
            List.of("node-a", "node-b", "node-c"),
            3
        );
        ShardPartitionMapManager manager = new ShardPartitionMapManager(v0);

        Map<Integer, String> nextLeaders = new LinkedHashMap<>();
        for (int shardId = 0; shardId < v0.shardCount(); shardId++) {
            nextLeaders.put(shardId, shardId % 2 == 0 ? "node-b" : "node-c");
        }

        ShardPartitionMap v1 = manager.next(nextLeaders);
        assertEquals(1L, v1.version().epoch());
        assertTrue(manager.tryApply(v1));
        assertEquals(1L, manager.current().version().epoch());

        for (int shardId = 0; shardId < v1.shardCount(); shardId++) {
            ShardDescriptor descriptor = manager.current().descriptorForShard(shardId);
            assertTrue(descriptor.ownershipHistory().size() >= 1);
            assertEquals(descriptor.leaderNodeId(), descriptor.ownershipHistory().get(descriptor.ownershipHistory().size() - 1));
        }

        assertFalse(manager.tryApply(v0.withVersion(new PartitionMapVersion(0))));
    }
}
