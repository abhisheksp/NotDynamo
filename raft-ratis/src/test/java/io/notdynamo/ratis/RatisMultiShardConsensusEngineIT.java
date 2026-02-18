package io.notdynamo.ratis;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import io.notdynamo.storage.KeyValueStore;
import io.notdynamo.storage.RocksDbKeyValueStore;
import java.io.IOException;
import java.net.ServerSocket;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Callable;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class RatisMultiShardConsensusEngineIT {
    @TempDir
    Path tempDir;

    @Test
    void maintainsIndependentShardGroupsWithDistinctLeadersAndLogs() throws Exception {
        List<String> nodeIds = List.of("n1", "n2", "n3");
        Map<String, Integer> ports = allocatePorts(nodeIds);
        List<TestNode> nodes = openNodes(nodeIds, ports);
        try {
            byte[] shard0Key = "s0:profile:1".getBytes(StandardCharsets.UTF_8);
            byte[] shard0Value = "s0-v1".getBytes(StandardCharsets.UTF_8);
            byte[] shard1Key = "s1:profile:1".getBytes(StandardCharsets.UTF_8);
            byte[] shard1Value = "s1-v1".getBytes(StandardCharsets.UTF_8);

            eventuallyValue(
                Duration.ofSeconds(10),
                Duration.ofMillis(150),
                () -> node(nodes, "n2").engine.put(0, shard0Key, shard0Value)
            );
            eventuallyValue(
                Duration.ofSeconds(10),
                Duration.ofMillis(150),
                () -> node(nodes, "n2").engine.put(1, shard1Key, shard1Value)
            );

            waitForReplication(nodes, shard0Key, shard0Value, Duration.ofSeconds(8));
            waitForReplication(nodes, shard1Key, shard1Value, Duration.ofSeconds(8));

            TestNode coordinator = node(nodes, "n1");
            eventually(
                Duration.ofSeconds(10),
                Duration.ofMillis(200),
                () -> coordinator.engine.transferLeadership(0, "n1", 5000)
            );
            eventually(
                Duration.ofSeconds(10),
                Duration.ofMillis(200),
                () -> coordinator.engine.transferLeadership(1, "n2", 5000)
            );

            eventually(
                Duration.ofSeconds(10),
                Duration.ofMillis(200),
                () -> {
                    String shard0Leader = coordinator.engine.leaderIdForShard(0);
                    String shard1Leader = coordinator.engine.leaderIdForShard(1);
                    return !shard0Leader.isBlank() && !shard1Leader.isBlank() && !shard0Leader.equals(shard1Leader);
                }
            );

            String shard0Leader = coordinator.engine.leaderIdForShard(0);
            String shard1Leader = coordinator.engine.leaderIdForShard(1);
            assertNotEquals(shard0Leader, shard1Leader, "shards should support independent leaders");

            long shard1IndexBefore = coordinator.engine.lastAppliedIndexForShard(1);
            eventuallyValue(
                Duration.ofSeconds(10),
                Duration.ofMillis(150),
                () -> coordinator.engine.put(0, "s0:profile:2".getBytes(StandardCharsets.UTF_8), "s0-v2".getBytes(StandardCharsets.UTF_8))
            );
            eventuallyValue(
                Duration.ofSeconds(10),
                Duration.ofMillis(150),
                () -> coordinator.engine.put(0, "s0:profile:3".getBytes(StandardCharsets.UTF_8), "s0-v3".getBytes(StandardCharsets.UTF_8))
            );

            eventually(
                Duration.ofSeconds(8),
                Duration.ofMillis(150),
                () -> coordinator.engine.lastAppliedIndexForShard(0) > shard1IndexBefore
            );
            assertEquals(
                shard1IndexBefore,
                coordinator.engine.lastAppliedIndexForShard(1),
                "shard-1 log should not advance when only shard-0 writes are committed"
            );
        } finally {
            closeNodes(nodes);
        }
    }

    private List<TestNode> openNodes(List<String> nodeIds, Map<String, Integer> ports) {
        List<TestNode> nodes = new ArrayList<>();
        for (String nodeId : nodeIds) {
            Path nodeDir = tempDir.resolve(nodeId);
            RocksDbKeyValueStore store = RocksDbKeyValueStore.open(nodeDir.resolve("store"));
            List<ShardRaftGroupConfig> groups = List.of(
                new ShardRaftGroupConfig(0, "shard-0", nodeIds),
                new ShardRaftGroupConfig(1, "shard-1", nodeIds)
            );
            RatisMultiShardConsensusEngineConfig config = new RatisMultiShardConsensusEngineConfig(
                nodeId,
                groups,
                peerNodeId -> "127.0.0.1:" + ports.get(peerNodeId),
                nodeDir.resolve("ratis"),
                2000
            );
            RatisMultiShardConsensusEngine engine = RatisMultiShardConsensusEngine.open(config, store);
            nodes.add(new TestNode(nodeId, store, engine));
        }
        return nodes;
    }

    private static void waitForReplication(List<TestNode> nodes, byte[] key, byte[] expectedValue, Duration timeout) throws Exception {
        eventually(
            timeout,
            Duration.ofMillis(120),
            () -> {
                for (TestNode node : nodes) {
                    KeyValueStore.GetResult result = node.store.get(key);
                    if (!result.found()) {
                        return false;
                    }
                    if (!java.util.Arrays.equals(expectedValue, result.value())) {
                        return false;
                    }
                }
                return true;
            }
        );

        for (TestNode node : nodes) {
            KeyValueStore.GetResult result = node.store.get(key);
            assertTrue(result.found());
            assertArrayEquals(expectedValue, result.value());
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

    private static TestNode node(List<TestNode> nodes, String nodeId) {
        return nodes.stream().filter(node -> node.nodeId.equals(nodeId)).findFirst().orElseThrow();
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

    private static void closeNodes(List<TestNode> nodes) {
        for (int i = nodes.size() - 1; i >= 0; i--) {
            nodes.get(i).close();
        }
        nodes.clear();
    }

    private static final class TestNode implements AutoCloseable {
        private final String nodeId;
        private final RocksDbKeyValueStore store;
        private final RatisMultiShardConsensusEngine engine;

        private TestNode(String nodeId, RocksDbKeyValueStore store, RatisMultiShardConsensusEngine engine) {
            this.nodeId = nodeId;
            this.store = store;
            this.engine = engine;
        }

        @Override
        public void close() {
            RuntimeException first = null;
            try {
                engine.close();
            } catch (RuntimeException e) {
                first = e;
            }
            try {
                store.close();
            } catch (RuntimeException e) {
                if (first == null) {
                    first = e;
                } else {
                    first.addSuppressed(e);
                }
            }
            if (first != null) {
                throw first;
            }
        }
    }
}
