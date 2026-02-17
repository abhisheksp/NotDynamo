package io.notdynamo.node;

import io.grpc.Server;
import io.grpc.netty.shaded.io.grpc.netty.NettyServerBuilder;
import io.notdynamo.controlplane.ClusterPartitionMap;
import io.notdynamo.controlplane.PartitionMapVersion;
import io.notdynamo.controlplane.ReplicaPartitionMap;
import io.notdynamo.node.cluster.GrpcNodeRpcClient;
import io.notdynamo.node.cluster.InMemoryNodeRpcClient;
import io.notdynamo.node.cluster.NodeRpcClient;
import io.notdynamo.node.cluster.PartitionMapCache;
import io.notdynamo.node.cluster.PartitionedKvRouter;
import io.notdynamo.node.cluster.PartitionedKvServiceHandler;
import io.notdynamo.node.cluster.RatisKvRouter;
import io.notdynamo.node.cluster.RatisKvServiceHandler;
import io.notdynamo.node.cluster.ReplicaApplyServiceHandler;
import io.notdynamo.node.cluster.ReplicaQuorumKvRouter;
import io.notdynamo.node.cluster.ReplicaQuorumKvServiceHandler;
import io.notdynamo.node.http.HttpBridgeServer;
import io.notdynamo.proto.v1.KvServiceGrpc;
import io.notdynamo.ratis.ConsensusEngine;
import io.notdynamo.ratis.RatisConsensusEngine;
import io.notdynamo.ratis.RatisConsensusEngineConfig;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.function.Supplier;

public final class NodeMain {
    private NodeMain() {
    }

    public static void main(String[] args) throws Exception {
        RuntimeSettings settings = RuntimeSettings.fromEnvironment(System.getenv());
        NodeConfig config = new NodeConfig(settings.nodeId, settings.host, settings.grpcPort, settings.httpPort, settings.dataDir);

        Files.createDirectories(config.dataDir());

        NodeRpcClient rpcClient = null;
        ConsensusEngine consensusEngine = null;
        try (NodeServer nodeServer = NodeServer.openSharded(config, settings.shardCount, settings.virtualNodesPerShard)) {
            KvServiceGrpc.KvServiceImplBase kvApi = nodeServer.kvService();
            Supplier<String> partitionMapEpochSupplier = () -> "0";

            if (settings.runtimeMode == RuntimeMode.PARTITIONED) {
                ClusterPartitionMap partitionMap = settings.partitionMap();
                PartitionMapCache partitionMapCache = new PartitionMapCache(partitionMap);
                rpcClient = createRpcClient(settings);
                switch (settings.writePolicy) {
                    case LEADER_QUORUM -> {
                        ReplicaPartitionMap replicaMap = settings.replicaMap(partitionMap);
                        ReplicaQuorumKvRouter router = new ReplicaQuorumKvRouter(
                            config.nodeId(),
                            nodeServer.kvService(),
                            rpcClient,
                            replicaMap,
                            settings.writeQuorumAcks
                        );
                        kvApi = new ReplicaQuorumKvServiceHandler(router);
                    }
                    case RAFT -> {
                        ReplicaPartitionMap replicaMap = settings.replicaMap(partitionMap);
                        RatisConsensusEngineConfig consensusConfig = new RatisConsensusEngineConfig(
                            config.nodeId(),
                            settings.clusterNodeIds,
                            settings::ratisTargetForNode,
                            config.dataDir().resolve("ratis"),
                            settings.ratisGroupName,
                            settings.ratisRequestTimeoutMillis
                        );
                        consensusEngine = RatisConsensusEngine.open(consensusConfig, nodeServer.keyValueStore());
                        RatisKvRouter router = new RatisKvRouter(
                            config.nodeId(),
                            nodeServer.kvService(),
                            rpcClient,
                            replicaMap,
                            consensusEngine
                        );
                        kvApi = new RatisKvServiceHandler(router);
                    }
                    case SINGLE_OWNER -> {
                        PartitionedKvRouter router = new PartitionedKvRouter(
                            config.nodeId(),
                            nodeServer.kvService(),
                            rpcClient,
                            partitionMapCache
                        );
                        kvApi = new PartitionedKvServiceHandler(router);
                    }
                }
                partitionMapEpochSupplier = () -> String.valueOf(partitionMapCache.current().version().epoch());
            }

            if (rpcClient instanceof InMemoryNodeRpcClient inMemoryRpcClient) {
                inMemoryRpcClient.register(config.nodeId(), kvApi);
                inMemoryRpcClient.registerReplicaApply(config.nodeId(), nodeServer.kvService());
            }

            NodeHealthServiceHandler healthService = new NodeHealthServiceHandler(config.nodeId(), () -> true, partitionMapEpochSupplier);
            ReplicaApplyServiceHandler replicaApplyService = new ReplicaApplyServiceHandler(nodeServer.kvService());

            Server grpcServer = NettyServerBuilder.forPort(config.grpcPort())
                .addService(kvApi)
                .addService(replicaApplyService)
                .addService(healthService)
                .build();

            HttpBridgeServer httpBridge = HttpBridgeServer.open(config.nodeId(), config.httpPort(), kvApi);
            NodeRpcClient rpcClientForShutdown = rpcClient;
            ConsensusEngine consensusEngineForShutdown = consensusEngine;
            CountDownLatch shutdownLatch = new CountDownLatch(1);

            Runtime.getRuntime().addShutdownHook(new Thread(() -> {
                try {
                    httpBridge.close();
                    grpcServer.shutdown();
                    grpcServer.awaitTermination(5, TimeUnit.SECONDS);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                } finally {
                    closeQuietly(rpcClientForShutdown);
                    closeQuietly(consensusEngineForShutdown);
                    shutdownLatch.countDown();
                }
            }));

            grpcServer.start();
            httpBridge.start();
            logStartup(config, settings);

            grpcServer.awaitTermination();
            shutdownLatch.countDown();
            shutdownLatch.await(1, TimeUnit.SECONDS);
        } finally {
            closeQuietly(rpcClient);
            closeQuietly(consensusEngine);
        }
    }

    private static NodeRpcClient createRpcClient(RuntimeSettings settings) {
        return switch (settings.rpcMode) {
            case IN_MEMORY -> new InMemoryNodeRpcClient();
            case GRPC -> new GrpcNodeRpcClient(settings::rpcTargetForNode, settings.rpcTimeoutMillis);
        };
    }

    private static void closeQuietly(NodeRpcClient rpcClient) {
        if (rpcClient == null) {
            return;
        }
        try {
            rpcClient.close();
        } catch (RuntimeException e) {
            System.err.println("failed to close rpc client: " + e.getMessage());
        }
    }

    private static void closeQuietly(ConsensusEngine consensusEngine) {
        if (consensusEngine == null) {
            return;
        }
        try {
            consensusEngine.close();
        } catch (RuntimeException e) {
            System.err.println("failed to close consensus engine: " + e.getMessage());
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
        System.out.println("runtime_mode=" + settings.runtimeMode);
        System.out.println("write_policy=" + settings.writePolicy);
        System.out.println("write_quorum_acks=" + settings.writeQuorumAcks);
        System.out.println("rpc_mode=" + settings.rpcMode);
        System.out.println("ratis_group_name=" + settings.ratisGroupName);
        System.out.println("ratis_port=" + settings.ratisPort);
        System.out.println("ratis_request_timeout_ms=" + settings.ratisRequestTimeoutMillis);
        System.out.println("cluster_nodes=" + String.join(",", settings.clusterNodeIds));
    }

    private enum RuntimeMode {
        LOCAL_SHARDED,
        PARTITIONED;

        private static RuntimeMode parse(String value) {
            if (value == null || value.isBlank()) {
                return LOCAL_SHARDED;
            }
            return switch (value.trim().toLowerCase(Locale.ROOT)) {
                case "local", "local-sharded", "local_sharded" -> LOCAL_SHARDED;
                case "partitioned", "cluster" -> PARTITIONED;
                default -> throw new IllegalArgumentException("unsupported NOTDYNAMO_RUNTIME_MODE: " + value);
            };
        }
    }

    private enum RpcMode {
        GRPC,
        IN_MEMORY;

        private static RpcMode parse(String value) {
            if (value == null || value.isBlank()) {
                return GRPC;
            }
            return switch (value.trim().toLowerCase(Locale.ROOT)) {
                case "grpc" -> GRPC;
                case "in-memory", "in_memory", "memory" -> IN_MEMORY;
                default -> throw new IllegalArgumentException("unsupported NOTDYNAMO_RPC_MODE: " + value);
            };
        }
    }

    private enum WritePolicy {
        SINGLE_OWNER,
        LEADER_QUORUM,
        RAFT;

        private static WritePolicy parse(String value) {
            if (value == null || value.isBlank()) {
                return SINGLE_OWNER;
            }
            return switch (value.trim().toLowerCase(Locale.ROOT)) {
                case "single-owner", "single_owner", "single" -> SINGLE_OWNER;
                case "leader-quorum", "leader_quorum", "quorum" -> LEADER_QUORUM;
                case "raft", "ratis" -> RAFT;
                default -> throw new IllegalArgumentException("unsupported NOTDYNAMO_WRITE_POLICY: " + value);
            };
        }
    }

    private static final class RuntimeSettings {
        private static final String NODE_ID_ENV = "NOTDYNAMO_NODE_ID";
        private static final String HOST_ENV = "NOTDYNAMO_HOST";
        private static final String GRPC_PORT_ENV = "NOTDYNAMO_GRPC_PORT";
        private static final String HTTP_PORT_ENV = "NOTDYNAMO_HTTP_PORT";
        private static final String DATA_DIR_ENV = "NOTDYNAMO_DATA_DIR";
        private static final String SHARD_COUNT_ENV = "NOTDYNAMO_SHARD_COUNT";
        private static final String VNODES_ENV = "NOTDYNAMO_VIRTUAL_NODES_PER_SHARD";
        private static final String RUNTIME_MODE_ENV = "NOTDYNAMO_RUNTIME_MODE";
        private static final String RPC_MODE_ENV = "NOTDYNAMO_RPC_MODE";
        private static final String CLUSTER_SIZE_ENV = "NOTDYNAMO_CLUSTER_SIZE";
        private static final String CLUSTER_NODE_IDS_ENV = "NOTDYNAMO_CLUSTER_NODE_IDS";
        private static final String STATEFULSET_NAME_ENV = "NOTDYNAMO_STATEFULSET_NAME";
        private static final String HEADLESS_SERVICE_ENV = "NOTDYNAMO_HEADLESS_SERVICE";
        private static final String NAMESPACE_ENV = "NOTDYNAMO_NAMESPACE";
        private static final String RPC_ADDRESS_TEMPLATE_ENV = "NOTDYNAMO_RPC_ADDRESS_TEMPLATE";
        private static final String RPC_TIMEOUT_MS_ENV = "NOTDYNAMO_RPC_TIMEOUT_MS";
        private static final String RATIS_PORT_ENV = "NOTDYNAMO_RATIS_PORT";
        private static final String RATIS_GROUP_NAME_ENV = "NOTDYNAMO_RATIS_GROUP_NAME";
        private static final String RATIS_ADDRESS_TEMPLATE_ENV = "NOTDYNAMO_RATIS_ADDRESS_TEMPLATE";
        private static final String RATIS_REQUEST_TIMEOUT_MS_ENV = "NOTDYNAMO_RATIS_REQUEST_TIMEOUT_MS";
        private static final String WRITE_POLICY_ENV = "NOTDYNAMO_WRITE_POLICY";
        private static final String WRITE_QUORUM_ACKS_ENV = "NOTDYNAMO_WRITE_QUORUM_ACKS";

        private final String nodeId;
        private final String host;
        private final int grpcPort;
        private final int httpPort;
        private final Path dataDir;
        private final int shardCount;
        private final int virtualNodesPerShard;
        private final RuntimeMode runtimeMode;
        private final RpcMode rpcMode;
        private final List<String> clusterNodeIds;
        private final String rpcAddressTemplate;
        private final long rpcTimeoutMillis;
        private final int ratisPort;
        private final String ratisGroupName;
        private final String ratisAddressTemplate;
        private final long ratisRequestTimeoutMillis;
        private final WritePolicy writePolicy;
        private final int writeQuorumAcks;

        private RuntimeSettings(
            String nodeId,
            String host,
            int grpcPort,
            int httpPort,
            Path dataDir,
            int shardCount,
            int virtualNodesPerShard,
            RuntimeMode runtimeMode,
            RpcMode rpcMode,
            List<String> clusterNodeIds,
            String rpcAddressTemplate,
            long rpcTimeoutMillis,
            int ratisPort,
            String ratisGroupName,
            String ratisAddressTemplate,
            long ratisRequestTimeoutMillis,
            WritePolicy writePolicy,
            int writeQuorumAcks
        ) {
            this.nodeId = nodeId;
            this.host = host;
            this.grpcPort = grpcPort;
            this.httpPort = httpPort;
            this.dataDir = dataDir;
            this.shardCount = shardCount;
            this.virtualNodesPerShard = virtualNodesPerShard;
            this.runtimeMode = runtimeMode;
            this.rpcMode = rpcMode;
            this.clusterNodeIds = clusterNodeIds;
            this.rpcAddressTemplate = rpcAddressTemplate;
            this.rpcTimeoutMillis = rpcTimeoutMillis;
            this.ratisPort = ratisPort;
            this.ratisGroupName = ratisGroupName;
            this.ratisAddressTemplate = ratisAddressTemplate;
            this.ratisRequestTimeoutMillis = ratisRequestTimeoutMillis;
            this.writePolicy = writePolicy;
            this.writeQuorumAcks = writeQuorumAcks;
        }

        private static RuntimeSettings fromEnvironment(Map<String, String> env) {
            String nodeId = env.getOrDefault(NODE_ID_ENV, "node-local");
            String host = env.getOrDefault(HOST_ENV, "0.0.0.0");
            int grpcPort = parseInt(env.get(GRPC_PORT_ENV), 9090, GRPC_PORT_ENV);
            int httpPort = parseInt(env.get(HTTP_PORT_ENV), 8080, HTTP_PORT_ENV);
            Path dataDir = Path.of(env.getOrDefault(DATA_DIR_ENV, "data/node-local"));
            int shardCount = parseInt(env.get(SHARD_COUNT_ENV), 64, SHARD_COUNT_ENV);
            int virtualNodesPerShard = parseInt(env.get(VNODES_ENV), 256, VNODES_ENV);
            long rpcTimeoutMillis = parseLong(env.get(RPC_TIMEOUT_MS_ENV), 750L, RPC_TIMEOUT_MS_ENV);
            int ratisPort = parseInt(env.get(RATIS_PORT_ENV), 10090, RATIS_PORT_ENV);
            long ratisRequestTimeoutMillis = parseLong(
                env.get(RATIS_REQUEST_TIMEOUT_MS_ENV),
                2000L,
                RATIS_REQUEST_TIMEOUT_MS_ENV
            );
            String ratisGroupName = env.getOrDefault(RATIS_GROUP_NAME_ENV, "notdynamo-main");

            if (shardCount <= 0) {
                throw new IllegalArgumentException("NOTDYNAMO_SHARD_COUNT must be > 0");
            }
            if (virtualNodesPerShard <= 0) {
                throw new IllegalArgumentException("NOTDYNAMO_VIRTUAL_NODES_PER_SHARD must be > 0");
            }
            if (rpcTimeoutMillis <= 0) {
                throw new IllegalArgumentException("NOTDYNAMO_RPC_TIMEOUT_MS must be > 0");
            }
            if (ratisPort <= 0 || ratisPort > 65535) {
                throw new IllegalArgumentException("NOTDYNAMO_RATIS_PORT must be in range 1..65535");
            }
            if (ratisRequestTimeoutMillis <= 0) {
                throw new IllegalArgumentException("NOTDYNAMO_RATIS_REQUEST_TIMEOUT_MS must be > 0");
            }
            if (ratisGroupName.isBlank()) {
                throw new IllegalArgumentException("NOTDYNAMO_RATIS_GROUP_NAME must not be blank");
            }

            List<String> clusterNodeIds = parseClusterNodeIds(env.get(CLUSTER_NODE_IDS_ENV));
            if (clusterNodeIds.isEmpty()) {
                String statefulSetName = env.getOrDefault(STATEFULSET_NAME_ENV, "notdynamo-data");
                int clusterSize = parseInt(env.get(CLUSTER_SIZE_ENV), 1, CLUSTER_SIZE_ENV);
                if (clusterSize <= 0) {
                    throw new IllegalArgumentException("NOTDYNAMO_CLUSTER_SIZE must be > 0");
                }
                clusterNodeIds = new ArrayList<>(clusterSize);
                for (int i = 0; i < clusterSize; i++) {
                    clusterNodeIds.add(statefulSetName + "-" + i);
                }
            }

            if (!clusterNodeIds.contains(nodeId)) {
                clusterNodeIds.add(nodeId);
            }
            clusterNodeIds = new ArrayList<>(new LinkedHashSet<>(clusterNodeIds));

            String headlessService = env.getOrDefault(HEADLESS_SERVICE_ENV, "notdynamo-data-headless");
            String namespace = env.getOrDefault(NAMESPACE_ENV, "notdynamo");
            String defaultTemplate = "%s." + headlessService + "." + namespace + ".svc.cluster.local";
            String rpcAddressTemplate = env.getOrDefault(RPC_ADDRESS_TEMPLATE_ENV, defaultTemplate);
            String ratisAddressTemplate = env.getOrDefault(RATIS_ADDRESS_TEMPLATE_ENV, defaultTemplate);

            String runtimeModeValue = env.get(RUNTIME_MODE_ENV);
            RuntimeMode runtimeMode = RuntimeMode.parse(
                runtimeModeValue == null || runtimeModeValue.isBlank()
                    ? (clusterNodeIds.size() > 1 ? "partitioned" : "local-sharded")
                    : runtimeModeValue
            );
            RpcMode rpcMode = RpcMode.parse(env.get(RPC_MODE_ENV));
            WritePolicy writePolicy = WritePolicy.parse(env.get(WRITE_POLICY_ENV));
            int writeQuorumAcks = parseInt(env.get(WRITE_QUORUM_ACKS_ENV), 2, WRITE_QUORUM_ACKS_ENV);
            if (writeQuorumAcks <= 0) {
                throw new IllegalArgumentException("NOTDYNAMO_WRITE_QUORUM_ACKS must be > 0");
            }
            if (writePolicy == WritePolicy.LEADER_QUORUM && clusterNodeIds.size() < writeQuorumAcks) {
                throw new IllegalArgumentException(
                    "cluster node count must be >= write quorum acks for leader-quorum policy"
                );
            }
            if (writePolicy == WritePolicy.RAFT && clusterNodeIds.size() < 3) {
                throw new IllegalArgumentException("raft policy requires at least 3 nodes");
            }

            return new RuntimeSettings(
                nodeId,
                host,
                grpcPort,
                httpPort,
                dataDir,
                shardCount,
                virtualNodesPerShard,
                runtimeMode,
                rpcMode,
                clusterNodeIds,
                rpcAddressTemplate,
                rpcTimeoutMillis,
                ratisPort,
                ratisGroupName,
                ratisAddressTemplate,
                ratisRequestTimeoutMillis,
                writePolicy,
                writeQuorumAcks
            );
        }

        private ClusterPartitionMap partitionMap() {
            return ClusterPartitionMap.roundRobin(
                new PartitionMapVersion(0),
                shardCount,
                virtualNodesPerShard,
                clusterNodeIds
            );
        }

        private ReplicaPartitionMap replicaMap(ClusterPartitionMap partitionMap) {
            return ReplicaPartitionMap.withUniformReplicas(partitionMap, clusterNodeIds);
        }

        private String rpcTargetForNode(String nodeId) {
            if (nodeId == null || nodeId.isBlank()) {
                throw new IllegalArgumentException("nodeId must not be blank");
            }

            String target;
            if (rpcAddressTemplate.contains("%s") && rpcAddressTemplate.contains("%d")) {
                target = String.format(rpcAddressTemplate, nodeId, grpcPort);
            } else if (rpcAddressTemplate.contains("%s")) {
                target = String.format(rpcAddressTemplate, nodeId);
            } else {
                target = rpcAddressTemplate;
            }

            if (!target.contains(":")) {
                target = target + ":" + grpcPort;
            }
            return target;
        }

        private String ratisTargetForNode(String nodeId) {
            if (nodeId == null || nodeId.isBlank()) {
                throw new IllegalArgumentException("nodeId must not be blank");
            }

            String target;
            if (ratisAddressTemplate.contains("%s") && ratisAddressTemplate.contains("%d")) {
                target = String.format(ratisAddressTemplate, nodeId, ratisPort);
            } else if (ratisAddressTemplate.contains("%s")) {
                target = String.format(ratisAddressTemplate, nodeId);
            } else {
                target = ratisAddressTemplate;
            }

            if (!target.contains(":")) {
                target = target + ":" + ratisPort;
            }
            return target;
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

        private static long parseLong(String value, long defaultValue, String envName) {
            if (value == null || value.isBlank()) {
                return defaultValue;
            }
            try {
                return Long.parseLong(value);
            } catch (NumberFormatException e) {
                throw new IllegalArgumentException(envName + " must be a long", e);
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
