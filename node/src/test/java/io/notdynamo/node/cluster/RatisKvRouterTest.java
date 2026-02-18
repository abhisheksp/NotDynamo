package io.notdynamo.node.cluster;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.google.protobuf.ByteString;
import io.notdynamo.controlplane.ClusterPartitionMap;
import io.notdynamo.controlplane.PartitionMapVersion;
import io.notdynamo.controlplane.ReplicaPartitionMap;
import io.notdynamo.node.NodeConfig;
import io.notdynamo.node.NodeServer;
import io.notdynamo.node.shard.ConsistentHashRing;
import io.notdynamo.proto.v1.GetRequest;
import io.notdynamo.proto.v1.GetResponse;
import io.notdynamo.proto.v1.PutRequest;
import io.notdynamo.proto.v1.PutResponse;
import io.notdynamo.proto.v1.StatusCode;
import io.notdynamo.ratis.ConsensusEngine;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class RatisKvRouterTest {
    @TempDir
    Path tempDir;

    @Test
    void putRetriesTransientConsensusFailures() {
        try (NodeServer node = NodeServer.openSharded(configFor("node-a"), 16, 64)) {
            FlakyConsensusEngine consensus = new FlakyConsensusEngine(2, 0, 11L, 0L);
            RatisKvRouter router = new RatisKvRouter(
                "node-a",
                node.kvService(),
                new InMemoryNodeRpcClient(),
                singleNodeReplicaMap("node-a"),
                consensus
            );

            PutResponse response = router.put(putRequest("k1", "v1"));
            assertFalse(response.hasError(), () -> "expected eventual success: " + response.getError().getMessage());
            assertEquals(11L, response.getVersion());
            assertEquals(3, consensus.putAttempts());
        }
    }

    @Test
    void putReturnsUnavailableAfterRetryBudgetExhausted() {
        try (NodeServer node = NodeServer.openSharded(configFor("node-a"), 16, 64)) {
            FlakyConsensusEngine consensus = FlakyConsensusEngine.alwaysFailPut("leader not ready");
            RatisKvRouter router = new RatisKvRouter(
                "node-a",
                node.kvService(),
                new InMemoryNodeRpcClient(),
                singleNodeReplicaMap("node-a"),
                consensus
            );

            PutResponse response = router.put(putRequest("k2", "v2"));
            assertTrue(response.hasError());
            assertEquals(StatusCode.STATUS_CODE_UNAVAILABLE, response.getError().getCode());
            assertTrue(consensus.putAttempts() >= 2, "expected retries before failing");
        }
    }

    @Test
    void eventualReadUsesFreshFollowerWithinBudget() {
        int shardCount = 16;
        int virtualNodesPerShard = 64;
        List<String> nodes = List.of("node-a", "node-b", "node-c");
        ClusterPartitionMap leaderMap = ClusterPartitionMap.roundRobin(
            new PartitionMapVersion(0),
            shardCount,
            virtualNodesPerShard,
            nodes
        );
        ReplicaPartitionMap replicaMap = ReplicaPartitionMap.withUniformReplicas(leaderMap, nodes);
        byte[] key = findKeyForOwner(leaderMap, "node-a");
        byte[] value = "fresh-follower".getBytes(StandardCharsets.UTF_8);

        try (
            NodeServer nodeA = NodeServer.openSharded(configFor("node-a"), shardCount, virtualNodesPerShard);
            NodeServer nodeB = NodeServer.openSharded(configFor("node-b"), shardCount, virtualNodesPerShard);
            NodeServer nodeC = NodeServer.openSharded(configFor("node-c"), shardCount, virtualNodesPerShard)
        ) {
            InMemoryNodeRpcClient transport = new InMemoryNodeRpcClient();
            transport.register("node-a", nodeA.kvService());
            transport.register("node-b", nodeB.kvService());
            transport.register("node-c", nodeC.kvService());

            PutRequest preload = PutRequest.newBuilder().setKey(ByteString.copyFrom(key)).setValue(ByteString.copyFrom(value)).build();
            assertFalse(transport.put("node-a", preload).hasError());
            assertFalse(transport.put("node-b", preload).hasError());

            int shardId = shardForKey(leaderMap, key);
            ReplicaLagTracker lagTracker = new ReplicaLagTracker();
            lagTracker.recordLagMillis(shardId, "node-b", 120L);
            lagTracker.recordLagMillis(shardId, "node-c", 1500L);

            RatisKvRouter routerC = new RatisKvRouter(
                "node-c",
                nodeC.kvService(),
                transport,
                replicaMap,
                new FlakyConsensusEngine(0, 0, 1L, 1L),
                RatisKvRouter.ReadMode.EVENTUAL,
                lagTracker,
                1000L
            );

            long forwardedToBBefore = transport.getForwardedCallsTo("node-b");
            GetResponse read = routerC.get(GetRequest.newBuilder().setKey(ByteString.copyFrom(key)).build());
            assertFalse(read.hasError());
            assertTrue(read.getFound());
            assertEquals(forwardedToBBefore + 1, transport.getForwardedCallsTo("node-b"));
            assertEquals(0L, routerC.leaderFallbackReads());
        }
    }

    @Test
    void eventualReadFallsBackToLeaderWhenNoFollowerIsFresh() {
        int shardCount = 16;
        int virtualNodesPerShard = 64;
        List<String> nodes = List.of("node-a", "node-b", "node-c");
        ClusterPartitionMap leaderMap = ClusterPartitionMap.roundRobin(
            new PartitionMapVersion(0),
            shardCount,
            virtualNodesPerShard,
            nodes
        );
        ReplicaPartitionMap replicaMap = ReplicaPartitionMap.withUniformReplicas(leaderMap, nodes);
        byte[] key = findKeyForOwner(leaderMap, "node-a");
        byte[] value = "leader-fallback".getBytes(StandardCharsets.UTF_8);

        try (
            NodeServer nodeA = NodeServer.openSharded(configFor("node-a"), shardCount, virtualNodesPerShard);
            NodeServer nodeB = NodeServer.openSharded(configFor("node-b"), shardCount, virtualNodesPerShard);
            NodeServer nodeC = NodeServer.openSharded(configFor("node-c"), shardCount, virtualNodesPerShard)
        ) {
            InMemoryNodeRpcClient transport = new InMemoryNodeRpcClient();
            transport.register("node-a", nodeA.kvService());
            transport.register("node-b", nodeB.kvService());
            transport.register("node-c", nodeC.kvService());

            PutRequest preload = PutRequest.newBuilder().setKey(ByteString.copyFrom(key)).setValue(ByteString.copyFrom(value)).build();
            assertFalse(transport.put("node-a", preload).hasError());

            int shardId = shardForKey(leaderMap, key);
            ReplicaLagTracker lagTracker = new ReplicaLagTracker();
            lagTracker.recordLagMillis(shardId, "node-b", 1800L);
            lagTracker.recordLagMillis(shardId, "node-c", 2500L);

            RatisKvRouter routerC = new RatisKvRouter(
                "node-c",
                nodeC.kvService(),
                transport,
                replicaMap,
                new FlakyConsensusEngine(0, 0, 1L, 1L),
                RatisKvRouter.ReadMode.EVENTUAL,
                lagTracker,
                1000L
            );

            long leaderGetsBefore = transport.getForwardedCallsTo("node-a");
            GetResponse read = routerC.get(GetRequest.newBuilder().setKey(ByteString.copyFrom(key)).build());
            assertFalse(read.hasError());
            assertTrue(read.getFound());
            assertEquals(leaderGetsBefore + 1, transport.getForwardedCallsTo("node-a"));
            assertEquals(1L, routerC.leaderFallbackReads());
        }
    }

    private PutRequest putRequest(String key, String value) {
        return PutRequest.newBuilder()
            .setKey(ByteString.copyFromUtf8(key))
            .setValue(ByteString.copyFromUtf8(value))
            .build();
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

    private static ReplicaPartitionMap singleNodeReplicaMap(String nodeId) {
        ClusterPartitionMap map = ClusterPartitionMap.roundRobin(
            new PartitionMapVersion(0),
            16,
            64,
            List.of(nodeId)
        );
        return ReplicaPartitionMap.withUniformReplicas(map, List.of(nodeId));
    }

    private static int shardForKey(ClusterPartitionMap map, byte[] key) {
        Set<Integer> shardIds = new HashSet<>();
        for (int shard = 0; shard < map.shardCount(); shard++) {
            shardIds.add(shard);
        }
        ConsistentHashRing ring = ConsistentHashRing.create(shardIds, map.virtualNodesPerShard());
        return ring.shardForKey(key);
    }

    private static byte[] findKeyForOwner(ClusterPartitionMap map, String ownerNodeId) {
        Set<Integer> shardIds = new HashSet<>();
        for (int shard = 0; shard < map.shardCount(); shard++) {
            shardIds.add(shard);
        }
        ConsistentHashRing ring = ConsistentHashRing.create(shardIds, map.virtualNodesPerShard());
        for (int i = 0; i < 500_000; i++) {
            byte[] candidate = ("key-" + i).getBytes(StandardCharsets.UTF_8);
            int shard = ring.shardForKey(candidate);
            if (ownerNodeId.equals(map.ownerForShard(shard).orElse(null))) {
                return candidate;
            }
        }
        throw new IllegalStateException("unable to find key for owner " + ownerNodeId);
    }

    private static final class FlakyConsensusEngine implements ConsensusEngine {
        private final int putFailuresBeforeSuccess;
        private final int deleteFailuresBeforeSuccess;
        private final long putSuccessVersion;
        private final long deleteSuccessVersion;
        private final String alwaysPutFailureMessage;
        private final AtomicInteger putCalls = new AtomicInteger();
        private final AtomicInteger deleteCalls = new AtomicInteger();

        private FlakyConsensusEngine(
            int putFailuresBeforeSuccess,
            int deleteFailuresBeforeSuccess,
            long putSuccessVersion,
            long deleteSuccessVersion
        ) {
            this(putFailuresBeforeSuccess, deleteFailuresBeforeSuccess, putSuccessVersion, deleteSuccessVersion, null);
        }

        private FlakyConsensusEngine(
            int putFailuresBeforeSuccess,
            int deleteFailuresBeforeSuccess,
            long putSuccessVersion,
            long deleteSuccessVersion,
            String alwaysPutFailureMessage
        ) {
            this.putFailuresBeforeSuccess = putFailuresBeforeSuccess;
            this.deleteFailuresBeforeSuccess = deleteFailuresBeforeSuccess;
            this.putSuccessVersion = putSuccessVersion;
            this.deleteSuccessVersion = deleteSuccessVersion;
            this.alwaysPutFailureMessage = alwaysPutFailureMessage;
        }

        static FlakyConsensusEngine alwaysFailPut(String message) {
            return new FlakyConsensusEngine(0, 0, 0L, 0L, message);
        }

        @Override
        public long put(byte[] key, byte[] value) {
            int call = putCalls.incrementAndGet();
            if (alwaysPutFailureMessage != null) {
                throw new IllegalStateException(alwaysPutFailureMessage);
            }
            if (call <= putFailuresBeforeSuccess) {
                throw new IllegalStateException("temporary ratis write failure");
            }
            return putSuccessVersion;
        }

        @Override
        public long delete(byte[] key) {
            int call = deleteCalls.incrementAndGet();
            if (call <= deleteFailuresBeforeSuccess) {
                throw new IllegalStateException("temporary ratis delete failure");
            }
            return deleteSuccessVersion;
        }

        int putAttempts() {
            return putCalls.get();
        }
    }
}
