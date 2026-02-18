package io.notdynamo.controlplane;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;

public final class ControlPlaneMain {
    private ControlPlaneMain() {
    }

    public static void main(String[] args) throws Exception {
        RuntimeSettings settings = RuntimeSettings.fromEnvironment(System.getenv());
        ShardPartitionMap initialMap = ShardPartitionMap.roundRobin(
            new PartitionMapVersion(0),
            settings.shardCount,
            settings.virtualNodesPerShard,
            settings.clusterNodeIds,
            settings.replicationFactor
        );
        ShardPartitionMapManager partitionMapManager = new ShardPartitionMapManager(initialMap);

        HttpServer server = HttpServer.create(new InetSocketAddress(settings.port), 0);
        server.setExecutor(Executors.newFixedThreadPool(Math.max(2, Runtime.getRuntime().availableProcessors() / 2)));
        server.createContext("/healthz", exchange -> handleHealth(exchange, partitionMapManager));
        server.createContext("/v1/partition-map", exchange -> handlePartitionMap(exchange, partitionMapManager));

        CountDownLatch shutdownLatch = new CountDownLatch(1);
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            server.stop(2);
            shutdownLatch.countDown();
        }));

        server.start();

        logStartup(settings, partitionMapManager.current());
        shutdownLatch.await();
    }

    private static void handleHealth(HttpExchange exchange, ShardPartitionMapManager partitionMapManager) throws IOException {
        if (!"GET".equalsIgnoreCase(exchange.getRequestMethod())) {
            sendJson(exchange, 405, "{\"error\":\"method_not_allowed\"}");
            return;
        }

        long epoch = partitionMapManager.current().version().epoch();
        sendJson(exchange, 200, "{\"ready\":true,\"partitionMapEpoch\":" + epoch + "}");
    }

    private static void handlePartitionMap(HttpExchange exchange, ShardPartitionMapManager partitionMapManager) throws IOException {
        if (!"GET".equalsIgnoreCase(exchange.getRequestMethod())) {
            sendJson(exchange, 405, "{\"error\":\"method_not_allowed\"}");
            return;
        }

        ShardPartitionMap map = partitionMapManager.current();
        sendJson(exchange, 200, ShardPartitionMapJsonCodec.toJson(map));
    }

    private static void sendJson(HttpExchange exchange, int status, String payload) throws IOException {
        byte[] body = payload.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "application/json; charset=utf-8");
        exchange.sendResponseHeaders(status, body.length);
        exchange.getResponseBody().write(body);
        exchange.close();
    }

    private static void logStartup(RuntimeSettings settings, ShardPartitionMap map) {
        System.out.println("notdynamo.control_plane.started=true");
        System.out.println("port=" + settings.port);
        System.out.println("shard_count=" + settings.shardCount);
        System.out.println("virtual_nodes_per_shard=" + settings.virtualNodesPerShard);
        System.out.println("replication_factor=" + settings.replicationFactor);
        System.out.println("cluster_nodes=" + String.join(",", settings.clusterNodeIds));
        System.out.println("partition_map_epoch=" + map.version().epoch());
    }

    private static final class RuntimeSettings {
        private static final String PORT_ENV = "NOTDYNAMO_CONTROL_PLANE_PORT";
        private static final String SHARD_COUNT_ENV = "NOTDYNAMO_SHARD_COUNT";
        private static final String VNODES_ENV = "NOTDYNAMO_VIRTUAL_NODES_PER_SHARD";
        private static final String REPLICATION_FACTOR_ENV = "NOTDYNAMO_REPLICATION_FACTOR";
        private static final String CLUSTER_NODE_IDS_ENV = "NOTDYNAMO_CLUSTER_NODE_IDS";
        private static final String CLUSTER_SIZE_ENV = "NOTDYNAMO_CLUSTER_SIZE";
        private static final String STATEFULSET_NAME_ENV = "NOTDYNAMO_STATEFULSET_NAME";

        private final int port;
        private final int shardCount;
        private final int virtualNodesPerShard;
        private final int replicationFactor;
        private final List<String> clusterNodeIds;

        private RuntimeSettings(
            int port,
            int shardCount,
            int virtualNodesPerShard,
            int replicationFactor,
            List<String> clusterNodeIds
        ) {
            this.port = port;
            this.shardCount = shardCount;
            this.virtualNodesPerShard = virtualNodesPerShard;
            this.replicationFactor = replicationFactor;
            this.clusterNodeIds = clusterNodeIds;
        }

        private static RuntimeSettings fromEnvironment(Map<String, String> env) {
            int port = parseInt(env.get(PORT_ENV), 9090, PORT_ENV);
            int shardCount = parseInt(env.get(SHARD_COUNT_ENV), 128, SHARD_COUNT_ENV);
            int virtualNodesPerShard = parseInt(env.get(VNODES_ENV), 256, VNODES_ENV);
            int replicationFactor = parseInt(env.get(REPLICATION_FACTOR_ENV), 3, REPLICATION_FACTOR_ENV);

            if (port <= 0 || port > 65535) {
                throw new IllegalArgumentException("NOTDYNAMO_CONTROL_PLANE_PORT must be in [1,65535]");
            }
            if (shardCount <= 0) {
                throw new IllegalArgumentException("NOTDYNAMO_SHARD_COUNT must be > 0");
            }
            if (virtualNodesPerShard <= 0) {
                throw new IllegalArgumentException("NOTDYNAMO_VIRTUAL_NODES_PER_SHARD must be > 0");
            }
            if (replicationFactor <= 0) {
                throw new IllegalArgumentException("NOTDYNAMO_REPLICATION_FACTOR must be > 0");
            }

            List<String> clusterNodeIds = parseClusterNodeIds(env.get(CLUSTER_NODE_IDS_ENV));
            if (clusterNodeIds.isEmpty()) {
                String statefulSetName = env.getOrDefault(STATEFULSET_NAME_ENV, "notdynamo-data");
                int clusterSize = parseInt(env.get(CLUSTER_SIZE_ENV), 3, CLUSTER_SIZE_ENV);
                if (clusterSize <= 0) {
                    throw new IllegalArgumentException("NOTDYNAMO_CLUSTER_SIZE must be > 0");
                }
                clusterNodeIds = new ArrayList<>(clusterSize);
                for (int i = 0; i < clusterSize; i++) {
                    clusterNodeIds.add(statefulSetName + "-" + i);
                }
            }

            clusterNodeIds = new ArrayList<>(new LinkedHashSet<>(clusterNodeIds));
            if (clusterNodeIds.isEmpty()) {
                throw new IllegalArgumentException("control-plane requires at least one node ID");
            }
            if (replicationFactor > clusterNodeIds.size()) {
                throw new IllegalArgumentException("NOTDYNAMO_REPLICATION_FACTOR must be <= cluster node count");
            }

            return new RuntimeSettings(port, shardCount, virtualNodesPerShard, replicationFactor, clusterNodeIds);
        }

        private static int parseInt(String value, int defaultValue, String envName) {
            if (value == null || value.isBlank()) {
                return defaultValue;
            }
            try {
                return Integer.parseInt(value);
            } catch (NumberFormatException e) {
                throw new IllegalArgumentException(envName + " must be an integer", e);
            }
        }

        private static List<String> parseClusterNodeIds(String value) {
            if (value == null || value.isBlank()) {
                return List.of();
            }

            String[] parts = value.split(",");
            List<String> nodeIds = new ArrayList<>(parts.length);
            for (String part : parts) {
                String trimmed = part.trim();
                if (!trimmed.isEmpty()) {
                    nodeIds.add(trimmed);
                }
            }
            return nodeIds;
        }
    }
}
