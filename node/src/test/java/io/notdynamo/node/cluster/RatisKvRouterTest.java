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
import java.util.Map;
import java.util.Set;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class RatisKvRouterTest {
    @TempDir
    Path tempDir;

    @Test
    void putRetriesTransientConsensusFailures() {
        try (NodeServer node = NodeServer.openSharded(configFor("node-a"), 16, 64)) {
            FlakyConsensusEngine consensus = new FlakyConsensusEngine(1, 0, 11L, 0L);
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
            assertEquals(2, consensus.putAttempts());
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
    void putFastFailsWithBackpressureWhenInflightLimitReached() throws Exception {
        ExecutorService executor = Executors.newSingleThreadExecutor();
        try (NodeServer node = NodeServer.openSharded(configFor("node-a"), 16, 64)) {
            BlockingConsensusEngine consensus = new BlockingConsensusEngine(17L);
            RatisKvRouter router = new RatisKvRouter(
                "node-a",
                node.kvService(),
                new InMemoryNodeRpcClient(),
                singleNodeReplicaMap("node-a"),
                consensus,
                RatisKvRouter.ReadMode.LOCAL_REPLICA,
                new ReplicaLagTracker(),
                1000L,
                1,
                0L
            );

            Future<PutResponse> firstWrite = executor.submit(() -> router.put(putRequest("k3", "v3")));
            assertTrue(consensus.awaitFirstWriteStarted(2, TimeUnit.SECONDS), "first write should enter consensus path");

            PutResponse backpressured = router.put(putRequest("k4", "v4"));
            assertTrue(backpressured.hasError());
            assertEquals(StatusCode.STATUS_CODE_UNAVAILABLE, backpressured.getError().getCode());
            assertTrue(backpressured.getError().getMessage().contains("write backpressure"));

            consensus.release();
            PutResponse firstWriteResponse = firstWrite.get(2, TimeUnit.SECONDS);
            assertFalse(firstWriteResponse.hasError(), () -> "first write should succeed: " + firstWriteResponse.getError());
        } finally {
            executor.shutdownNow();
        }
    }

    @Test
    void perShardAdmissionAllowsColdShardWhileHotShardIsSaturated() throws Exception {
        ExecutorService executor = Executors.newFixedThreadPool(2);
        int shardCount = 16;
        int virtualNodesPerShard = 64;
        try (NodeServer node = NodeServer.openSharded(configFor("node-a"), shardCount, virtualNodesPerShard)) {
            ClusterPartitionMap leaderMap = ClusterPartitionMap.roundRobin(
                new PartitionMapVersion(0),
                shardCount,
                virtualNodesPerShard,
                List.of("node-a")
            );
            ReplicaPartitionMap replicaMap = ReplicaPartitionMap.withUniformReplicas(leaderMap, List.of("node-a"));
            byte[] hotKey = findKeyForShard(leaderMap, 0);
            int hotShard = shardForKey(leaderMap, hotKey);
            byte[] coldKey = findKeyForShardDifferentFrom(leaderMap, hotShard);

            PerShardBlockingConsensusEngine consensus = new PerShardBlockingConsensusEngine(hotShard, 31L, 37L);
            RatisKvRouter router = new RatisKvRouter(
                "node-a",
                node.kvService(),
                new InMemoryNodeRpcClient(),
                replicaMap,
                consensus,
                RatisKvRouter.ReadMode.LOCAL_REPLICA,
                new ReplicaLagTracker(),
                1000L,
                4,
                1,
                0L,
                16
            );

            Future<PutResponse> hotWrite = executor.submit(() -> put(router, hotKey, "hot-1"));
            assertTrue(consensus.awaitHotWriteStarted(2, TimeUnit.SECONDS), "hot write should enter consensus");

            PutResponse hotRejected = put(router, hotKey, "hot-2");
            assertTrue(hotRejected.hasError());
            assertEquals(StatusCode.STATUS_CODE_UNAVAILABLE, hotRejected.getError().getCode());
            assertTrue(hotRejected.getError().getMessage().contains("write backpressure"));

            PutResponse coldResponse = put(router, coldKey, "cold-1");
            assertFalse(coldResponse.hasError(), () -> "cold shard should still proceed: " + coldResponse.getError());
            assertEquals(37L, coldResponse.getVersion());

            consensus.releaseHotWrite();
            PutResponse firstHot = hotWrite.get(2, TimeUnit.SECONDS);
            assertFalse(firstHot.hasError(), () -> "first hot write should succeed: " + firstHot.getError());
            assertEquals(31L, firstHot.getVersion());
        } finally {
            executor.shutdownNow();
        }
    }

    @Test
    void leaderSnapshotOverrideRoutesForwardToObservedLeader() {
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
        int shardId = shardForKey(leaderMap, key);

        try (
            NodeServer nodeA = NodeServer.openSharded(configFor("node-a"), shardCount, virtualNodesPerShard);
            NodeServer nodeB = NodeServer.openSharded(configFor("node-b"), shardCount, virtualNodesPerShard);
            NodeServer nodeC = NodeServer.openSharded(configFor("node-c"), shardCount, virtualNodesPerShard)
        ) {
            InMemoryNodeRpcClient transport = new InMemoryNodeRpcClient();
            transport.register("node-a", nodeA.kvService());
            transport.register("node-b", nodeB.kvService());
            transport.register("node-c", nodeC.kvService());

            SnapshotOnlyConsensusEngine consensus = new SnapshotOnlyConsensusEngine(shardId, "node-b");
            RatisKvRouter routerC = new RatisKvRouter(
                "node-c",
                nodeC.kvService(),
                transport,
                replicaMap,
                consensus,
                RatisKvRouter.ReadMode.EVENTUAL,
                new ReplicaLagTracker(),
                1000L
            );

            long forwardedToABefore = transport.putForwardedCallsTo("node-a");
            long forwardedToBBefore = transport.putForwardedCallsTo("node-b");
            PutResponse response = put(routerC, key, "observed-leader-target");
            assertFalse(response.hasError(), () -> "write should succeed via observed leader: " + response.getError());
            assertEquals(forwardedToABefore, transport.putForwardedCallsTo("node-a"));
            assertEquals(forwardedToBBefore + 1, transport.putForwardedCallsTo("node-b"));
            assertTrue(consensus.snapshotCalls() > 0, "router should consult leader snapshot");
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

    private static PutResponse put(RatisKvRouter router, byte[] key, String value) {
        return router.put(
            PutRequest.newBuilder()
                .setKey(ByteString.copyFrom(key))
                .setValue(ByteString.copyFromUtf8(value))
                .build()
        );
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

    private static byte[] findKeyForShard(ClusterPartitionMap map, int targetShardId) {
        Set<Integer> shardIds = new HashSet<>();
        for (int shard = 0; shard < map.shardCount(); shard++) {
            shardIds.add(shard);
        }
        ConsistentHashRing ring = ConsistentHashRing.create(shardIds, map.virtualNodesPerShard());
        for (int i = 0; i < 500_000; i++) {
            byte[] candidate = ("shard-key-" + i).getBytes(StandardCharsets.UTF_8);
            if (ring.shardForKey(candidate) == targetShardId) {
                return candidate;
            }
        }
        throw new IllegalStateException("unable to find key for shard " + targetShardId);
    }

    private static byte[] findKeyForShardDifferentFrom(ClusterPartitionMap map, int excludedShardId) {
        Set<Integer> shardIds = new HashSet<>();
        for (int shard = 0; shard < map.shardCount(); shard++) {
            shardIds.add(shard);
        }
        ConsistentHashRing ring = ConsistentHashRing.create(shardIds, map.virtualNodesPerShard());
        for (int i = 0; i < 500_000; i++) {
            byte[] candidate = ("cold-key-" + i).getBytes(StandardCharsets.UTF_8);
            int shard = ring.shardForKey(candidate);
            if (shard != excludedShardId) {
                return candidate;
            }
        }
        throw new IllegalStateException("unable to find key outside shard " + excludedShardId);
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

    private static final class BlockingConsensusEngine implements ConsensusEngine {
        private final long version;
        private final CountDownLatch putStarted = new CountDownLatch(1);
        private final CountDownLatch release = new CountDownLatch(1);

        private BlockingConsensusEngine(long version) {
            this.version = version;
        }

        @Override
        public long put(byte[] key, byte[] value) {
            putStarted.countDown();
            try {
                release.await(3, TimeUnit.SECONDS);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new IllegalStateException("interrupted while blocking put", e);
            }
            return version;
        }

        @Override
        public long delete(byte[] key) {
            return version;
        }

        private boolean awaitFirstWriteStarted(long timeout, TimeUnit unit) throws InterruptedException {
            return putStarted.await(timeout, unit);
        }

        private void release() {
            release.countDown();
        }
    }

    private static final class PerShardBlockingConsensusEngine implements ConsensusEngine {
        private final int hotShardId;
        private final long hotVersion;
        private final long coldVersion;
        private final CountDownLatch hotWriteStarted = new CountDownLatch(1);
        private final CountDownLatch hotWriteRelease = new CountDownLatch(1);

        private PerShardBlockingConsensusEngine(int hotShardId, long hotVersion, long coldVersion) {
            this.hotShardId = hotShardId;
            this.hotVersion = hotVersion;
            this.coldVersion = coldVersion;
        }

        @Override
        public long put(byte[] key, byte[] value) {
            return coldVersion;
        }

        @Override
        public long put(int shardId, byte[] key, byte[] value) {
            if (shardId == hotShardId) {
                hotWriteStarted.countDown();
                try {
                    hotWriteRelease.await(3, TimeUnit.SECONDS);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    throw new IllegalStateException("interrupted while waiting hot shard release", e);
                }
                return hotVersion;
            }
            return coldVersion;
        }

        @Override
        public long delete(byte[] key) {
            return coldVersion;
        }

        private boolean awaitHotWriteStarted(long timeout, TimeUnit unit) throws InterruptedException {
            return hotWriteStarted.await(timeout, unit);
        }

        private void releaseHotWrite() {
            hotWriteRelease.countDown();
        }
    }

    private static final class SnapshotOnlyConsensusEngine implements ConsensusEngine {
        private final int shardId;
        private final String observedLeaderNodeId;
        private final AtomicInteger snapshotCalls = new AtomicInteger();

        private SnapshotOnlyConsensusEngine(int shardId, String observedLeaderNodeId) {
            this.shardId = shardId;
            this.observedLeaderNodeId = observedLeaderNodeId;
        }

        @Override
        public long put(byte[] key, byte[] value) {
            return 1L;
        }

        @Override
        public long delete(byte[] key) {
            return 1L;
        }

        @Override
        public String leaderIdForShard(int shardId) {
            return shardId == this.shardId ? observedLeaderNodeId : "";
        }

        @Override
        public Map<Integer, String> leaderIdSnapshot() {
            snapshotCalls.incrementAndGet();
            return Map.of(shardId, observedLeaderNodeId);
        }

        private int snapshotCalls() {
            return snapshotCalls.get();
        }
    }
}
