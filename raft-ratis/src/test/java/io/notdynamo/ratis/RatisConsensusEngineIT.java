package io.notdynamo.ratis;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
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

class RatisConsensusEngineIT {
    @TempDir
    Path tempDir;

    @Test
    void replicatesPutAndDeleteAcrossThreeNodes() throws Exception {
        List<String> nodeIds = List.of("n1", "n2", "n3");
        Map<String, Integer> ports = allocatePorts(nodeIds);
        List<TestNode> nodes = openNodes(nodeIds, ports);

        try {
            byte[] key = "profile:1".getBytes(StandardCharsets.UTF_8);
            byte[] value = "value-v1".getBytes(StandardCharsets.UTF_8);

            long putVersion = eventuallyValue(
                Duration.ofSeconds(8),
                Duration.ofMillis(150),
                () -> node(nodes, "n2").engine.put(key, value)
            );
            assertEquals(1L, putVersion);
            waitForReplication(nodes, key, true, value, 1L, Duration.ofSeconds(8));

            long deleteVersion = eventuallyValue(
                Duration.ofSeconds(8),
                Duration.ofMillis(150),
                () -> node(nodes, "n3").engine.delete(key)
            );
            assertEquals(2L, deleteVersion);
            waitForReplication(nodes, key, false, new byte[0], 2L, Duration.ofSeconds(8));
        } finally {
            closeNodes(nodes);
        }
    }

    @Test
    void continuesToCommitAfterOneNodeStops() throws Exception {
        List<String> nodeIds = List.of("n1", "n2", "n3");
        Map<String, Integer> ports = allocatePorts(nodeIds);
        List<TestNode> nodes = openNodes(nodeIds, ports);

        try {
            byte[] key1 = "profile:2".getBytes(StandardCharsets.UTF_8);
            byte[] value1 = "before-stop".getBytes(StandardCharsets.UTF_8);
            long firstVersion = eventuallyValue(
                Duration.ofSeconds(8),
                Duration.ofMillis(150),
                () -> node(nodes, "n1").engine.put(key1, value1)
            );
            assertEquals(1L, firstVersion);

            TestNode removed = node(nodes, "n1");
            removed.close();
            nodes.remove(removed);

            byte[] key2 = "profile:3".getBytes(StandardCharsets.UTF_8);
            byte[] value2 = "after-stop".getBytes(StandardCharsets.UTF_8);
            long secondVersion = eventuallyValue(
                Duration.ofSeconds(10),
                Duration.ofMillis(200),
                () -> node(nodes, "n2").engine.put(key2, value2)
            );
            assertEquals(1L, secondVersion);

            waitForReplication(nodes, key2, true, value2, 1L, Duration.ofSeconds(8));
        } finally {
            closeNodes(nodes);
        }
    }

    private List<TestNode> openNodes(List<String> nodeIds, Map<String, Integer> ports) {
        List<TestNode> nodes = new ArrayList<>();
        for (String nodeId : nodeIds) {
            Path nodeDir = tempDir.resolve(nodeId);
            RocksDbKeyValueStore store = RocksDbKeyValueStore.open(nodeDir.resolve("store"));
            RatisConsensusEngineConfig config = new RatisConsensusEngineConfig(
                nodeId,
                nodeIds,
                peerNodeId -> "127.0.0.1:" + ports.get(peerNodeId),
                nodeDir.resolve("ratis"),
                "notdynamo-test-group",
                2000
            );

            RatisConsensusEngine engine = RatisConsensusEngine.open(config, store);
            nodes.add(new TestNode(nodeId, store, engine));
        }
        return nodes;
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

    private static void waitForReplication(
        List<TestNode> nodes,
        byte[] key,
        boolean expectedFound,
        byte[] expectedValue,
        long expectedVersion,
        Duration timeout
    ) throws Exception {
        eventually(
            timeout,
            Duration.ofMillis(120),
            () -> {
                for (TestNode node : nodes) {
                    KeyValueStore.GetResult result = node.store.get(key);
                    if (result.found() != expectedFound) {
                        return false;
                    }
                    if (result.version() != expectedVersion) {
                        return false;
                    }
                    if (expectedFound) {
                        if (!java.util.Arrays.equals(result.value(), expectedValue)) {
                            return false;
                        }
                    } else if (result.value().length != 0) {
                        return false;
                    }
                }
                return true;
            }
        );

        for (TestNode node : nodes) {
            KeyValueStore.GetResult result = node.store.get(key);
            assertEquals(expectedFound, result.found());
            assertEquals(expectedVersion, result.version());
            if (expectedFound) {
                assertArrayEquals(expectedValue, result.value());
            } else {
                assertFalse(result.found());
                assertTrue(result.value().length == 0);
            }
        }
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
        private final RatisConsensusEngine engine;

        private TestNode(String nodeId, RocksDbKeyValueStore store, RatisConsensusEngine engine) {
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
