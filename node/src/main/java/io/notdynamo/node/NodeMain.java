package io.notdynamo.node;

import io.grpc.Server;
import io.grpc.netty.shaded.io.grpc.netty.NettyServerBuilder;
import io.notdynamo.node.http.HttpBridgeServer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

public final class NodeMain {
    private NodeMain() {
    }

    public static void main(String[] args) throws Exception {
        RuntimeSettings settings = RuntimeSettings.fromEnvironment(System.getenv());
        NodeConfig config = new NodeConfig(settings.nodeId, settings.host, settings.grpcPort, settings.httpPort, settings.dataDir);

        Files.createDirectories(config.dataDir());

        try (NodeServer nodeServer = NodeServer.openSharded(config, settings.shardCount, settings.virtualNodesPerShard)) {
            NodeHealthServiceHandler healthService = new NodeHealthServiceHandler(config.nodeId(), () -> true, () -> "0");

            Server grpcServer = NettyServerBuilder.forPort(config.grpcPort())
                .addService(nodeServer.kvService())
                .addService(healthService)
                .build();

            HttpBridgeServer httpBridge = HttpBridgeServer.open(config.nodeId(), config.httpPort(), nodeServer.kvService());
            CountDownLatch shutdownLatch = new CountDownLatch(1);

            Runtime.getRuntime().addShutdownHook(new Thread(() -> {
                try {
                    httpBridge.close();
                    grpcServer.shutdown();
                    grpcServer.awaitTermination(5, TimeUnit.SECONDS);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                } finally {
                    shutdownLatch.countDown();
                }
            }));

            grpcServer.start();
            httpBridge.start();
            logStartup(config, settings);

            grpcServer.awaitTermination();
            shutdownLatch.countDown();
            shutdownLatch.await(1, TimeUnit.SECONDS);
        }
    }

    private static void logStartup(NodeConfig config, RuntimeSettings settings) {
        System.out.println("notdynamo.node.started=true");
        System.out.println("node_id=" + config.nodeId());
        System.out.println("grpc_port=" + config.grpcPort());
        System.out.println("http_port=" + config.httpPort());
        System.out.println("data_dir=" + config.dataDir());
        System.out.println("shard_count=" + settings.shardCount);
        System.out.println("virtual_nodes_per_shard=" + settings.virtualNodesPerShard);
    }

    private static final class RuntimeSettings {
        private static final String NODE_ID_ENV = "NOTDYNAMO_NODE_ID";
        private static final String HOST_ENV = "NOTDYNAMO_HOST";
        private static final String GRPC_PORT_ENV = "NOTDYNAMO_GRPC_PORT";
        private static final String HTTP_PORT_ENV = "NOTDYNAMO_HTTP_PORT";
        private static final String DATA_DIR_ENV = "NOTDYNAMO_DATA_DIR";
        private static final String SHARD_COUNT_ENV = "NOTDYNAMO_SHARD_COUNT";
        private static final String VNODES_ENV = "NOTDYNAMO_VIRTUAL_NODES_PER_SHARD";

        private final String nodeId;
        private final String host;
        private final int grpcPort;
        private final int httpPort;
        private final Path dataDir;
        private final int shardCount;
        private final int virtualNodesPerShard;

        private RuntimeSettings(
            String nodeId,
            String host,
            int grpcPort,
            int httpPort,
            Path dataDir,
            int shardCount,
            int virtualNodesPerShard
        ) {
            this.nodeId = nodeId;
            this.host = host;
            this.grpcPort = grpcPort;
            this.httpPort = httpPort;
            this.dataDir = dataDir;
            this.shardCount = shardCount;
            this.virtualNodesPerShard = virtualNodesPerShard;
        }

        private static RuntimeSettings fromEnvironment(Map<String, String> env) {
            String nodeId = env.getOrDefault(NODE_ID_ENV, "node-local");
            String host = env.getOrDefault(HOST_ENV, "0.0.0.0");
            int grpcPort = parseInt(env.get(GRPC_PORT_ENV), 9090, GRPC_PORT_ENV);
            int httpPort = parseInt(env.get(HTTP_PORT_ENV), 8080, HTTP_PORT_ENV);
            Path dataDir = Path.of(env.getOrDefault(DATA_DIR_ENV, "data/node-local"));
            int shardCount = parseInt(env.get(SHARD_COUNT_ENV), 64, SHARD_COUNT_ENV);
            int virtualNodesPerShard = parseInt(env.get(VNODES_ENV), 256, VNODES_ENV);

            if (shardCount <= 0) {
                throw new IllegalArgumentException("NOTDYNAMO_SHARD_COUNT must be > 0");
            }
            if (virtualNodesPerShard <= 0) {
                throw new IllegalArgumentException("NOTDYNAMO_VIRTUAL_NODES_PER_SHARD must be > 0");
            }

            return new RuntimeSettings(nodeId, host, grpcPort, httpPort, dataDir, shardCount, virtualNodesPerShard);
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
    }
}
