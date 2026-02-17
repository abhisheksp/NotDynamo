package io.notdynamo.it;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.google.protobuf.ByteString;
import io.notdynamo.controlplane.ClusterPartitionMap;
import io.notdynamo.controlplane.PartitionMapVersion;
import io.notdynamo.controlplane.ReplicaPartitionMap;
import io.notdynamo.node.NodeConfig;
import io.notdynamo.node.NodeServer;
import io.notdynamo.node.cluster.InMemoryNodeRpcClient;
import io.notdynamo.node.cluster.RatisKvRouter;
import io.notdynamo.node.cluster.RatisKvServiceHandler;
import io.notdynamo.node.shard.ConsistentHashRing;
import io.notdynamo.proto.v1.GetRequest;
import io.notdynamo.proto.v1.GetResponse;
import io.notdynamo.proto.v1.PutRequest;
import io.notdynamo.proto.v1.PutResponse;
import io.notdynamo.ratis.RatisConsensusEngine;
import io.notdynamo.ratis.RatisConsensusEngineConfig;
import io.notdynamo.storage.KeyValueStore;
import java.io.IOException;
import java.net.ServerSocket;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class RatisRoutingIT {
    @TempDir
    Path tempDir;

    @Test
    void writeViaFollowerCommitsAndReplicaExcludedReadForwardsToLeader() throws Exception {
        int shardCount = 64;
        int virtualNodesPerShard = 256;
        List<String> nodeIds = List.of("node-a", "node-b", "node-c");
        ClusterPartitionMap leaderMap = ClusterPartitionMap.roundRobin(
            new PartitionMapVersion(0),
            shardCount,
            virtualNodesPerShard,
            nodeIds
        );
        ReplicaPartitionMap replicaMap = ReplicaPartitionMap.withUniformReplicas(leaderMap, nodeIds);

        byte[] key = findKeyForOwner(leaderMap, "node-a");
        int shardId = ringFor(leaderMap).shardForKey(key);
        ReplicaPartitionMap readForwardingMap = replicaMap.withUpdatedShardReplicas(
            shardId,
            List.of("node-a", "node-b"),
            new PartitionMapVersion(1)
        );

        Map<String, Integer> ratisPorts = allocatePorts(nodeIds);

        try (TestCluster cluster = TestCluster.open(tempDir, nodeIds, shardCount, virtualNodesPerShard, readForwardingMap, ratisPorts)) {
            byte[] value = "ratis-forward".getBytes(StandardCharsets.UTF_8);

            PutResponse put = eventuallyValue(
                Duration.ofSeconds(10),
                Duration.ofMillis(150),
                () -> cluster.router("node-b").put(
                    PutRequest.newBuilder().setKey(ByteString.copyFrom(key)).setValue(ByteString.copyFrom(value)).build()
                )
            );

            assertFalse(put.hasError(), () -> "ratis put failed: " + put.getError().getMessage());
            assertEquals(1L, put.getVersion());
            waitForReplication(cluster, key, value, 1L, Duration.ofSeconds(8));

            GetResponse read = cluster.router("node-c").get(GetRequest.newBuilder().setKey(ByteString.copyFrom(key)).build());
            assertFalse(read.hasError(), () -> "expected forwarded read to succeed: " + read.getError().getMessage());
            assertTrue(read.getFound());
            assertArrayEquals(value, read.getValue().toByteArray());

            assertTrue(cluster.transport().getForwardedCallsTo("node-a") >= 1, "expected read forwarding to shard leader");
            assertEquals(0L, cluster.transport().putForwardedCalls(), "put should use local ratis client instead of node-to-node put forwarding");
        }
    }

    @Test
    void concurrentWritesAcrossRoutersSucceedAfterWarmup() throws Exception {
        int shardCount = 64;
        int virtualNodesPerShard = 256;
        List<String> nodeIds = List.of("node-a", "node-b", "node-c");
        ClusterPartitionMap leaderMap = ClusterPartitionMap.roundRobin(
            new PartitionMapVersion(0),
            shardCount,
            virtualNodesPerShard,
            nodeIds
        );
        ReplicaPartitionMap replicaMap = ReplicaPartitionMap.withUniformReplicas(leaderMap, nodeIds);
        Map<String, Integer> ratisPorts = allocatePorts(nodeIds);

        try (TestCluster cluster = TestCluster.open(tempDir, nodeIds, shardCount, virtualNodesPerShard, replicaMap, ratisPorts)) {
            PutResponse warmup = eventuallyValue(
                Duration.ofSeconds(10),
                Duration.ofMillis(150),
                () -> cluster.router("node-a").put(
                    PutRequest.newBuilder()
                        .setKey(ByteString.copyFromUtf8("warmup-key"))
                        .setValue(ByteString.copyFromUtf8("warmup-value"))
                        .build()
                )
            );
            assertFalse(warmup.hasError(), () -> "warmup put failed: " + warmup.getError().getMessage());

            int threads = 8;
            int operationsPerThread = 100;
            ExecutorService pool = Executors.newFixedThreadPool(threads);
            CountDownLatch startLatch = new CountDownLatch(1);
            List<Future<Integer>> results = new ArrayList<>();

            try {
                for (int thread = 0; thread < threads; thread++) {
                    final int threadId = thread;
                    results.add(
                        pool.submit(() -> {
                            startLatch.await();
                            int failures = 0;
                            for (int op = 0; op < operationsPerThread; op++) {
                                String nodeId = nodeIds.get((threadId + op) % nodeIds.size());
                                PutResponse put = cluster.router(nodeId).put(
                                    PutRequest.newBuilder()
                                        .setKey(ByteString.copyFromUtf8("concurrent-" + threadId + "-" + op))
                                        .setValue(ByteString.copyFromUtf8("value-" + threadId + "-" + op))
                                        .build()
                                );
                                if (put.hasError()) {
                                    failures += 1;
                                }
                            }
                            return failures;
                        })
                    );
                }

                startLatch.countDown();

                int totalFailures = 0;
                for (Future<Integer> result : results) {
                    totalFailures += result.get();
                }
                assertEquals(0, totalFailures, "concurrent ratis writes should not return errors");
            } finally {
                pool.shutdownNow();
            }
        }
    }

    private static Map<String, Integer> allocatePorts(List<String> nodeIds) throws IOException {
        Map<String, Integer> ports = new HashMap<>();
        for (String nodeId : nodeIds) {
            ports.put(nodeId, freePort());
        }
        return ports;
    }

    private static int freePort() throws IOException {
        try (ServerSocket socket = new ServerSocket(0)) {
            socket.setReuseAddress(true);
            return socket.getLocalPort();
        }
    }

    private static void waitForReplication(
        TestCluster cluster,
        byte[] key,
        byte[] expectedValue,
        long expectedVersion,
        Duration timeout
    ) throws Exception {
        eventually(
            timeout,
            Duration.ofMillis(120),
            () -> {
                for (String nodeId : cluster.nodeIds()) {
                    KeyValueStore.GetResult result = cluster.store(nodeId).get(key);
                    if (!result.found()) {
                        return false;
                    }
                    if (result.version() != expectedVersion) {
                        return false;
                    }
                    if (!java.util.Arrays.equals(result.value(), expectedValue)) {
                        return false;
                    }
                }
                return true;
            }
        );
    }

    private static byte[] findKeyForOwner(ClusterPartitionMap map, String ownerNodeId) {
        ConsistentHashRing ring = ringFor(map);
        for (int i = 0; i < 500_000; i++) {
            byte[] candidate = ("key-" + i).getBytes(StandardCharsets.UTF_8);
            int shard = ring.shardForKey(candidate);
            if (ownerNodeId.equals(map.ownerForShard(shard).orElse(null))) {
                return candidate;
            }
        }
        throw new IllegalStateException("unable to find key for owner " + ownerNodeId);
    }

    private static ConsistentHashRing ringFor(ClusterPartitionMap map) {
        Set<Integer> shardIds = new HashSet<>();
        for (int shard = 0; shard < map.shardCount(); shard++) {
            shardIds.add(shard);
        }
        return ConsistentHashRing.create(shardIds, map.virtualNodesPerShard());
    }

    private static <T> T eventuallyValue(Duration timeout, Duration pause, Callable<T> supplier) throws Exception {
        Instant deadline = Instant.now().plus(timeout);
        Exception last = null;
        while (Instant.now().isBefore(deadline)) {
            try {
                return supplier.call();
            } catch (Exception e) {
                last = e;
                Thread.sleep(pause.toMillis());
            }
        }
        if (last != null) {
            throw last;
        }
        throw new IllegalStateException("eventuallyValue timed out");
    }

    private static void eventually(Duration timeout, Duration pause, Callable<Boolean> condition) throws Exception {
        Instant deadline = Instant.now().plus(timeout);
        while (Instant.now().isBefore(deadline)) {
            if (condition.call()) {
                return;
            }
            Thread.sleep(pause.toMillis());
        }
        throw new IllegalStateException("condition did not become true within timeout");
    }

    private static final class TestCluster implements AutoCloseable {
        private final List<String> nodeIds;
        private final InMemoryNodeRpcClient transport;
        private final Map<String, NodeServer> nodesById;
        private final Map<String, RatisConsensusEngine> enginesById;
        private final Map<String, RatisKvRouter> routersById;

        private TestCluster(
            List<String> nodeIds,
            InMemoryNodeRpcClient transport,
            Map<String, NodeServer> nodesById,
            Map<String, RatisConsensusEngine> enginesById,
            Map<String, RatisKvRouter> routersById
        ) {
            this.nodeIds = List.copyOf(nodeIds);
            this.transport = transport;
            this.nodesById = nodesById;
            this.enginesById = enginesById;
            this.routersById = routersById;
        }

        static TestCluster open(
            Path tempDir,
            List<String> nodeIds,
            int shardCount,
            int virtualNodesPerShard,
            ReplicaPartitionMap replicaMap,
            Map<String, Integer> ratisPorts
        ) {
            InMemoryNodeRpcClient transport = new InMemoryNodeRpcClient();
            Map<String, NodeServer> nodesById = new LinkedHashMap<>();
            Map<String, RatisConsensusEngine> enginesById = new LinkedHashMap<>();
            Map<String, RatisKvRouter> routersById = new LinkedHashMap<>();

            RuntimeException openFailure = null;
            try {
                for (String nodeId : nodeIds) {
                    NodeServer node = NodeServer.openSharded(
                        new NodeConfig(
                            nodeId,
                            "127.0.0.1",
                            9000 + Math.abs(nodeId.hashCode() % 1000),
                            10000 + Math.abs(nodeId.hashCode() % 1000),
                            tempDir.resolve(nodeId)
                        ),
                        shardCount,
                        virtualNodesPerShard
                    );
                    nodesById.put(nodeId, node);

                    RatisConsensusEngineConfig config = new RatisConsensusEngineConfig(
                        nodeId,
                        nodeIds,
                        peer -> "127.0.0.1:" + ratisPorts.get(peer),
                        tempDir.resolve(nodeId).resolve("ratis"),
                        "notdynamo-routing-it",
                        2000
                    );
                    RatisConsensusEngine engine = RatisConsensusEngine.open(config, node.keyValueStore());
                    enginesById.put(nodeId, engine);

                    RatisKvRouter router = new RatisKvRouter(nodeId, node.kvService(), transport, replicaMap, engine);
                    routersById.put(nodeId, router);
                    transport.register(nodeId, new RatisKvServiceHandler(router));
                }

                return new TestCluster(nodeIds, transport, nodesById, enginesById, routersById);
            } catch (RuntimeException e) {
                openFailure = e;
                throw e;
            } finally {
                if (openFailure != null) {
                    closeQuietly(nodeIds, enginesById, nodesById);
                }
            }
        }

        List<String> nodeIds() {
            return nodeIds;
        }

        InMemoryNodeRpcClient transport() {
            return transport;
        }

        RatisKvRouter router(String nodeId) {
            return routersById.get(nodeId);
        }

        KeyValueStore store(String nodeId) {
            return nodesById.get(nodeId).keyValueStore();
        }

        @Override
        public void close() {
            closeQuietly(nodeIds, enginesById, nodesById);
        }

        private static void closeQuietly(
            List<String> nodeIds,
            Map<String, RatisConsensusEngine> enginesById,
            Map<String, NodeServer> nodesById
        ) {
            RuntimeException first = null;
            List<String> reverse = new ArrayList<>(nodeIds);
            java.util.Collections.reverse(reverse);

            for (String nodeId : reverse) {
                RatisConsensusEngine engine = enginesById.get(nodeId);
                if (engine != null) {
                    try {
                        engine.close();
                    } catch (RuntimeException e) {
                        if (first == null) {
                            first = e;
                        } else {
                            first.addSuppressed(e);
                        }
                    }
                }
            }

            for (String nodeId : reverse) {
                NodeServer node = nodesById.get(nodeId);
                if (node != null) {
                    try {
                        node.close();
                    } catch (RuntimeException e) {
                        if (first == null) {
                            first = e;
                        } else {
                            first.addSuppressed(e);
                        }
                    }
                }
            }

            if (first != null) {
                throw first;
            }
        }
    }
}
