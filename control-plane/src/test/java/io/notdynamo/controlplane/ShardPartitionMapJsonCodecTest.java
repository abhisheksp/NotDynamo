package io.notdynamo.controlplane;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import org.junit.jupiter.api.Test;

class ShardPartitionMapJsonCodecTest {
    @Test
    void roundTripPreservesShardMetadata() {
        ShardPartitionMap source = ShardPartitionMap.roundRobin(
            new PartitionMapVersion(3),
            6,
            128,
            List.of("node-a", "node-b", "node-c"),
            3
        );

        String json = ShardPartitionMapJsonCodec.toJson(source);
        ShardPartitionMap restored = ShardPartitionMapJsonCodec.fromJson(json);

        assertEquals(3L, restored.version().epoch());
        assertEquals(6, restored.shardCount());
        assertEquals(128, restored.virtualNodesPerShard());
        for (int shardId = 0; shardId < restored.shardCount(); shardId++) {
            ShardDescriptor descriptor = restored.descriptorForShard(shardId);
            assertEquals("shard-" + shardId, descriptor.groupId());
            assertTrue(descriptor.replicaNodeIds().contains(descriptor.leaderNodeId()));
            assertEquals(3, descriptor.replicaNodeIds().size());
            assertEquals(descriptor.leaderNodeId(), descriptor.ownershipHistory().get(0));
            assertEquals(ShardRebalanceState.STABLE, descriptor.rebalanceState());
        }
    }

    @Test
    void supportsLegacyOwnersOnlyPayloads() {
        String json = """
            {
              "version": {"epoch": 7},
              "shardCount": 2,
              "virtualNodesPerShard": 64,
              "owners": {"0":"node-a","1":"node-b"}
            }
            """;

        ShardPartitionMap restored = ShardPartitionMapJsonCodec.fromJson(json);
        assertEquals(7L, restored.version().epoch());
        assertEquals("node-a", restored.descriptorForShard(0).leaderNodeId());
        assertEquals("node-b", restored.descriptorForShard(1).leaderNodeId());
        assertEquals(List.of("node-a"), restored.descriptorForShard(0).replicaNodeIds());
    }
}
