package io.notdynamo.node;

import io.grpc.Server;
import io.grpc.netty.shaded.io.grpc.netty.NettyServerBuilder;
import io.notdynamo.controlplane.ClusterPartitionMap;
import io.notdynamo.controlplane.PartitionMapVersion;
import io.notdynamo.controlplane.ReplicaPartitionMap;
import io.notdynamo.controlplane.ShardPartitionMap;
import io.notdynamo.node.cluster.ControlPlanePartitionMapClient;
import io.notdynamo.node.cluster.GrpcNodeRpcClient;
import io.notdynamo.node.cluster.InMemoryNodeRpcClient;
import io.notdynamo.node.cluster.NodeRpcClient;
import io.notdynamo.node.cluster.PartitionMapCache;
import io.notdynamo.node.cluster.PartitionedKvRouter;
import io.notdynamo.node.cluster.PartitionedKvServiceHandler;
import io.notdynamo.node.cluster.RatisKvRouter;
import io.notdynamo.node.cluster.RatisKvServiceHandler;
import io.notdynamo.node.cluster.ReplicaLagTracker;
import io.notdynamo.node.cluster.ReplicaApplyServiceHandler;
import io.notdynamo.node.cluster.ReplicaQuorumKvRouter;
import io.notdynamo.node.cluster.ReplicaQuorumKvServiceHandler;
import io.notdynamo.node.http.HttpBridgeServer;
import io.notdynamo.proto.v1.KvServiceGrpc;
import io.notdynamo.ratis.ConsensusEngine;
import io.notdynamo.ratis.RatisMultiShardConsensusEngine;
import io.notdynamo.ratis.RatisMultiShardConsensusEngineConfig;
import io.notdynamo.ratis.ShardRaftGroupConfig;
import java.lang.management.ManagementFactory;
import com.sun.management.OperatingSystemMXBean;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
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
        ScheduledExecutorService backgroundTasks = null;
        try (NodeServer nodeServer = NodeServer.openSharded(config, settings.shardCount, settings.virtualNodesPerShard)) {
            KvServiceGrpc.KvServiceImplBase kvApi = nodeServer.kvService();
            Supplier<String> partitionMapEpochSupplier = () -> "0";
            PartitionMapCache partitionMapCache = null;
            RatisKvRouter ratisRouter = null;

            if (settings.runtimeMode == RuntimeMode.PARTITIONED) {
                ShardPartitionMap shardPartitionMap = settings.shardPartitionMap();
                ClusterPartitionMap partitionMap = shardPartitionMap.toClusterPartitionMap();
                ReplicaPartitionMap replicaMap = shardPartitionMap.toReplicaPartitionMap();
                partitionMapCache = new PartitionMapCache(partitionMap);
                rpcClient = createRpcClient(settings);
                switch (settings.writePolicy) {
                    case LEADER_QUORUM -> {
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
                        RatisMultiShardConsensusEngineConfig consensusConfig = settings.multiShardConsensusConfig(shardPartitionMap);
                        consensusEngine = RatisMultiShardConsensusEngine.open(consensusConfig, nodeServer.keyValueStore());
                        ReplicaLagTracker lagTracker = new ReplicaLagTracker();
                        ratisRouter = new RatisKvRouter(
                            config.nodeId(),
                            nodeServer.kvService(),
                            rpcClient,
                            replicaMap,
                            consensusEngine,
                            settings.ratisReadMode(),
                            lagTracker,
                            settings.eventualFreshnessMillis,
                            settings.writeGlobalInflightLimit,
                            settings.writeShardInflightMin,
                            settings.writeAdmissionWaitMillis,
                            settings.ratisMaxInflightPerShard
                        );
                        kvApi = new RatisKvServiceHandler(ratisRouter);
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
                if (ratisRouter != null) {
                    RatisKvRouter routerRef = ratisRouter;
                    partitionMapEpochSupplier = () -> String.valueOf(routerRef.partitionMapEpoch());
                } else {
                    PartitionMapCache cache = partitionMapCache;
                    partitionMapEpochSupplier = () -> String.valueOf(cache.current().version().epoch());
                }
            }

            if (rpcClient instanceof InMemoryNodeRpcClient inMemoryRpcClient) {
                inMemoryRpcClient.register(config.nodeId(), kvApi);
                inMemoryRpcClient.registerReplicaApply(config.nodeId(), nodeServer.kvService());
            }

            if (
                settings.runtimeMode == RuntimeMode.PARTITIONED
                    && settings.partitionMapSource == PartitionMapSource.CONTROL_PLANE
                    && (partitionMapCache != null || ratisRouter != null)
            ) {
                PartitionMapCache cacheRef = partitionMapCache;
                RatisKvRouter ratisRef = ratisRouter;
                ControlPlanePartitionMapClient controlPlaneClient = new ControlPlanePartitionMapClient(
                    Duration.ofMillis(settings.controlPlanePartitionMapTimeoutMillis)
                );
                backgroundTasks = Executors.newScheduledThreadPool(ratisRef == null ? 1 : 2);
                backgroundTasks.scheduleWithFixedDelay(
                    () -> refreshPartitionMapFromControlPlane(settings, controlPlaneClient, cacheRef, ratisRef),
                    1L,
                    settings.controlPlanePartitionMapRefreshIntervalMillis,
                    TimeUnit.MILLISECONDS
                );
                if (ratisRef != null) {
                    HttpClient writeLoadHttpClient = HttpClient.newBuilder()
                        .connectTimeout(Duration.ofMillis(settings.controlPlanePartitionMapTimeoutMillis))
                        .build();
                    backgroundTasks.scheduleWithFixedDelay(
                        () -> publishWriteLoadReport(settings, config.nodeId(), ratisRef, writeLoadHttpClient),
                        settings.controlPlaneWriteLoadReportIntervalMillis,
                        settings.controlPlaneWriteLoadReportIntervalMillis,
                        TimeUnit.MILLISECONDS
                    );
                }
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
            ScheduledExecutorService backgroundTasksForShutdown = backgroundTasks;
            CountDownLatch shutdownLatch = new CountDownLatch(1);

            Runtime.getRuntime().addShutdownHook(new Thread(() -> {
                try {
                    httpBridge.close();
                    grpcServer.shutdown();
                    grpcServer.awaitTermination(5, TimeUnit.SECONDS);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                } finally {
                    closeQuietly(backgroundTasksForShutdown);
                    closeQuietly(rpcClientForShutdown);
                    closeQuietly(consensusEngineForShutdown);
                    shutdownLatch.countDown();
                }
            }));

            grpcServer.start();
            httpBridge.start(settings.httpWorkerThreads);
            logStartup(config, settings);

            grpcServer.awaitTermination();
            shutdownLatch.countDown();
            shutdownLatch.await(1, TimeUnit.SECONDS);
        } finally {
            closeQuietly(backgroundTasks);
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

    private static void closeQuietly(ScheduledExecutorService executor) {
        if (executor == null) {
            return;
        }
        executor.shutdown();
        try {
            if (!executor.awaitTermination(5, TimeUnit.SECONDS)) {
                executor.shutdownNow();
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            executor.shutdownNow();
        }
    }

    private static void refreshPartitionMapFromControlPlane(
        RuntimeSettings settings,
        ControlPlanePartitionMapClient client,
        PartitionMapCache partitionMapCache,
        RatisKvRouter ratisRouter
    ) {
        try {
            ShardPartitionMap map = client.fetch(settings.controlPlanePartitionMapEndpoint);
            if (map.shardCount() != settings.shardCount || map.virtualNodesPerShard() != settings.virtualNodesPerShard) {
                System.err.println(
                    "control-plane partition map refresh rejected: layout mismatch shardCount="
                        + map.shardCount()
                        + " virtualNodesPerShard="
                        + map.virtualNodesPerShard()
                );
                return;
            }
            if (partitionMapCache != null) {
                partitionMapCache.tryApply(map.toClusterPartitionMap());
            }
            if (ratisRouter != null) {
                ratisRouter.tryUpdateReplicaMap(map.toReplicaPartitionMap());
            }
        } catch (RuntimeException e) {
            System.err.println("control-plane partition map refresh failed: " + e.getMessage());
        }
    }

    private static void publishWriteLoadReport(
        RuntimeSettings settings,
        String nodeId,
        RatisKvRouter router,
        HttpClient httpClient
    ) {
        try {
            Map<Integer, RatisKvRouter.ShardWriteLoadSnapshot> shardLoads = router.shardWriteLoadSnapshot();
            if (shardLoads.isEmpty()) {
                return;
            }
            double cpuPercent = currentProcessCpuPercent();
            String payload = writeLoadReportPayload(nodeId, router.partitionMapEpoch(), cpuPercent, shardLoads);
            HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(settings.controlPlaneWriteLoadReportEndpoint()))
                .timeout(Duration.ofMillis(settings.controlPlanePartitionMapTimeoutMillis))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(payload, StandardCharsets.UTF_8))
                .build();
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            int status = response.statusCode();
            if (status < 200 || status >= 300) {
                System.err.println(
                    "control-plane write-load report failed: status=" + status + " body=" + response.body()
                );
            }
        } catch (Exception e) {
            System.err.println("control-plane write-load report error: " + e.getMessage());
        }
    }

    private static String writeLoadReportPayload(
        String nodeId,
        long partitionMapEpoch,
        double cpuPercent,
        Map<Integer, RatisKvRouter.ShardWriteLoadSnapshot> shardLoads
    ) {
        StringBuilder out = new StringBuilder();
        out.append('{');
        out.append("\"nodeId\":\"").append(escapeJson(nodeId)).append("\",");
        out.append("\"partitionMapEpoch\":").append(partitionMapEpoch).append(',');
        out.append("\"nodeCpuPercent\":").append(formatDouble(cpuPercent)).append(',');
        out.append("\"shards\":{");
        boolean first = true;
        for (Map.Entry<Integer, RatisKvRouter.ShardWriteLoadSnapshot> entry : shardLoads.entrySet()) {
            RatisKvRouter.ShardWriteLoadSnapshot load = entry.getValue();
            if (load == null) {
                continue;
            }
            if (!first) {
                out.append(',');
            }
            out.append('"').append(entry.getKey()).append('"').append(':');
            out.append('{');
            out.append("\"putTotalCount\":").append(load.putTotalCount()).append(',');
            out.append("\"putTimeoutCount\":").append(load.putTimeoutCount());
            out.append('}');
            first = false;
        }
        out.append("}}");
        return out.toString();
    }

    private static double currentProcessCpuPercent() {
        try {
            OperatingSystemMXBean osBean = ManagementFactory.getPlatformMXBean(OperatingSystemMXBean.class);
            if (osBean == null) {
                return -1.0;
            }
            double load = osBean.getProcessCpuLoad();
            if (Double.isNaN(load) || load < 0.0) {
                return -1.0;
            }
            return load * 100.0;
        } catch (RuntimeException e) {
            return -1.0;
        }
    }

    private static String escapeJson(String value) {
        if (value == null) {
            return "";
        }
        return value.replace("\\", "\\\\").replace("\"", "\\\"");
    }

    private static String formatDouble(double value) {
        if (Double.isNaN(value) || Double.isInfinite(value)) {
            return "-1.0";
        }
        return String.format(Locale.ROOT, "%.3f", value);
    }

    private static void logStartup(NodeConfig config, RuntimeSettings settings) {
        System.out.println("notdynamo.node.started=true");
        System.out.println("node_id=" + config.nodeId());
        System.out.println("grpc_port=" + config.grpcPort());
        System.out.println("http_port=" + config.httpPort());
        System.out.println("http_worker_threads=" + settings.httpWorkerThreads);
        System.out.println("data_dir=" + config.dataDir());
        System.out.println("shard_count=" + settings.shardCount);
        System.out.println("virtual_nodes_per_shard=" + settings.virtualNodesPerShard);
        System.out.println("runtime_mode=" + settings.runtimeMode);
        System.out.println("write_policy=" + settings.writePolicy);
        System.out.println("write_quorum_acks=" + settings.writeQuorumAcks);
        System.out.println("write_global_inflight_limit=" + settings.writeGlobalInflightLimit);
        System.out.println("write_shard_inflight_min=" + settings.writeShardInflightMin);
        System.out.println("write_admission_wait_ms=" + settings.writeAdmissionWaitMillis);
        System.out.println("ratis_max_inflight_per_shard=" + settings.ratisMaxInflightPerShard);
        System.out.println("rpc_mode=" + settings.rpcMode);
        System.out.println("ratis_group_name=" + settings.ratisGroupName);
        System.out.println("ratis_port=" + settings.ratisPort);
        System.out.println("ratis_request_timeout_ms=" + settings.ratisRequestTimeoutMillis);
        System.out.println("read_consistency=" + settings.readConsistency);
        System.out.println("eventual_freshness_ms=" + settings.eventualFreshnessMillis);
        System.out.println("partition_map_source=" + settings.partitionMapSource);
        System.out.println("partition_map_endpoint=" + settings.controlPlanePartitionMapEndpoint);
        System.out.println("partition_map_refresh_interval_ms=" + settings.controlPlanePartitionMapRefreshIntervalMillis);
        System.out.println("write_load_report_interval_ms=" + settings.controlPlaneWriteLoadReportIntervalMillis);
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

    private enum ReadConsistency {
        EVENTUAL,
        LEADER;

        private static ReadConsistency parse(String value) {
            if (value == null || value.isBlank()) {
                return EVENTUAL;
            }
            return switch (value.trim().toLowerCase(Locale.ROOT)) {
                case "eventual", "replica", "replica-read", "replica_read" -> EVENTUAL;
                case "leader", "strong", "leader-read", "leader_read" -> LEADER;
                default -> throw new IllegalArgumentException("unsupported NOTDYNAMO_READ_CONSISTENCY: " + value);
            };
        }
    }

    private enum PartitionMapSource {
        STATIC,
        CONTROL_PLANE;

        private static PartitionMapSource parse(String value) {
            if (value == null || value.isBlank()) {
                return STATIC;
            }
            return switch (value.trim().toLowerCase(Locale.ROOT)) {
                case "static", "embedded" -> STATIC;
                case "control-plane", "control_plane", "controlplane" -> CONTROL_PLANE;
                default -> throw new IllegalArgumentException("unsupported NOTDYNAMO_PARTITION_MAP_SOURCE: " + value);
            };
        }
    }

    private static final class RuntimeSettings {
        private static final String NODE_ID_ENV = "NOTDYNAMO_NODE_ID";
        private static final String HOST_ENV = "NOTDYNAMO_HOST";
        private static final String GRPC_PORT_ENV = "NOTDYNAMO_GRPC_PORT";
        private static final String HTTP_PORT_ENV = "NOTDYNAMO_HTTP_PORT";
        private static final String HTTP_WORKER_THREADS_ENV = "NOTDYNAMO_HTTP_WORKER_THREADS";
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
        private static final String WRITE_GLOBAL_INFLIGHT_LIMIT_ENV = "NOTDYNAMO_WRITE_GLOBAL_INFLIGHT_LIMIT";
        private static final String WRITE_INFLIGHT_LIMIT_ENV = "NOTDYNAMO_WRITE_INFLIGHT_LIMIT";
        private static final String WRITE_SHARD_INFLIGHT_MIN_ENV = "NOTDYNAMO_WRITE_SHARD_INFLIGHT_MIN";
        private static final String WRITE_ADMISSION_WAIT_MS_ENV = "NOTDYNAMO_WRITE_ADMISSION_WAIT_MS";
        private static final String RATIS_MAX_INFLIGHT_PER_SHARD_ENV = "NOTDYNAMO_RATIS_MAX_INFLIGHT_PER_SHARD";
        private static final String READ_CONSISTENCY_ENV = "NOTDYNAMO_READ_CONSISTENCY";
        private static final String EVENTUAL_FRESHNESS_MS_ENV = "NOTDYNAMO_EVENTUAL_FRESHNESS_MILLIS";
        private static final String REPLICATION_FACTOR_ENV = "NOTDYNAMO_REPLICATION_FACTOR";
        private static final String PARTITION_MAP_SOURCE_ENV = "NOTDYNAMO_PARTITION_MAP_SOURCE";
        private static final String CONTROL_PLANE_PARTITION_MAP_ENDPOINT_ENV = "NOTDYNAMO_CONTROL_PLANE_PARTITION_MAP_ENDPOINT";
        private static final String CONTROL_PLANE_PARTITION_MAP_TIMEOUT_MS_ENV = "NOTDYNAMO_CONTROL_PLANE_PARTITION_MAP_TIMEOUT_MS";
        private static final String CONTROL_PLANE_PARTITION_MAP_REFRESH_INTERVAL_MS_ENV =
            "NOTDYNAMO_CONTROL_PLANE_PARTITION_MAP_REFRESH_INTERVAL_MS";
        private static final String CONTROL_PLANE_WRITE_LOAD_REPORT_INTERVAL_MS_ENV =
            "NOTDYNAMO_CONTROL_PLANE_WRITE_LOAD_REPORT_INTERVAL_MS";

        private final String nodeId;
        private final String host;
        private final int grpcPort;
        private final int httpPort;
        private final int httpWorkerThreads;
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
        private final int writeGlobalInflightLimit;
        private final int writeShardInflightMin;
        private final long writeAdmissionWaitMillis;
        private final int ratisMaxInflightPerShard;
        private final ReadConsistency readConsistency;
        private final long eventualFreshnessMillis;
        private final int replicationFactor;
        private final PartitionMapSource partitionMapSource;
        private final String controlPlanePartitionMapEndpoint;
        private final long controlPlanePartitionMapTimeoutMillis;
        private final long controlPlanePartitionMapRefreshIntervalMillis;
        private final long controlPlaneWriteLoadReportIntervalMillis;

        private RuntimeSettings(
            String nodeId,
            String host,
            int grpcPort,
            int httpPort,
            int httpWorkerThreads,
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
            int writeQuorumAcks,
            int writeGlobalInflightLimit,
            int writeShardInflightMin,
            long writeAdmissionWaitMillis,
            int ratisMaxInflightPerShard,
            ReadConsistency readConsistency,
            long eventualFreshnessMillis,
            int replicationFactor,
            PartitionMapSource partitionMapSource,
            String controlPlanePartitionMapEndpoint,
            long controlPlanePartitionMapTimeoutMillis,
            long controlPlanePartitionMapRefreshIntervalMillis,
            long controlPlaneWriteLoadReportIntervalMillis
        ) {
            this.nodeId = nodeId;
            this.host = host;
            this.grpcPort = grpcPort;
            this.httpPort = httpPort;
            this.httpWorkerThreads = httpWorkerThreads;
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
            this.writeGlobalInflightLimit = writeGlobalInflightLimit;
            this.writeShardInflightMin = writeShardInflightMin;
            this.writeAdmissionWaitMillis = writeAdmissionWaitMillis;
            this.ratisMaxInflightPerShard = ratisMaxInflightPerShard;
            this.readConsistency = readConsistency;
            this.eventualFreshnessMillis = eventualFreshnessMillis;
            this.replicationFactor = replicationFactor;
            this.partitionMapSource = partitionMapSource;
            this.controlPlanePartitionMapEndpoint = controlPlanePartitionMapEndpoint;
            this.controlPlanePartitionMapTimeoutMillis = controlPlanePartitionMapTimeoutMillis;
            this.controlPlanePartitionMapRefreshIntervalMillis = controlPlanePartitionMapRefreshIntervalMillis;
            this.controlPlaneWriteLoadReportIntervalMillis = controlPlaneWriteLoadReportIntervalMillis;
        }

        private static RuntimeSettings fromEnvironment(Map<String, String> env) {
            String nodeId = env.getOrDefault(NODE_ID_ENV, "node-local");
            String host = env.getOrDefault(HOST_ENV, "0.0.0.0");
            int grpcPort = parseInt(env.get(GRPC_PORT_ENV), 9090, GRPC_PORT_ENV);
            int httpPort = parseInt(env.get(HTTP_PORT_ENV), 8080, HTTP_PORT_ENV);
            int httpWorkerThreads = parseInt(
                env.get(HTTP_WORKER_THREADS_ENV),
                Math.max(32, Runtime.getRuntime().availableProcessors() * 16),
                HTTP_WORKER_THREADS_ENV
            );
            Path dataDir = Path.of(env.getOrDefault(DATA_DIR_ENV, "data/node-local"));
            int shardCount = parseInt(env.get(SHARD_COUNT_ENV), 64, SHARD_COUNT_ENV);
            int virtualNodesPerShard = parseInt(env.get(VNODES_ENV), 256, VNODES_ENV);
            long rpcTimeoutMillis = parseLong(env.get(RPC_TIMEOUT_MS_ENV), 5000L, RPC_TIMEOUT_MS_ENV);
            int ratisPort = parseInt(env.get(RATIS_PORT_ENV), 10090, RATIS_PORT_ENV);
            long ratisRequestTimeoutMillis = parseLong(
                env.get(RATIS_REQUEST_TIMEOUT_MS_ENV),
                5000L,
                RATIS_REQUEST_TIMEOUT_MS_ENV
            );
            String ratisGroupName = env.getOrDefault(RATIS_GROUP_NAME_ENV, "notdynamo-main");
            int replicationFactor = parseInt(env.get(REPLICATION_FACTOR_ENV), 3, REPLICATION_FACTOR_ENV);
            PartitionMapSource partitionMapSource = PartitionMapSource.parse(env.get(PARTITION_MAP_SOURCE_ENV));
            String controlPlanePartitionMapEndpoint = env.getOrDefault(
                CONTROL_PLANE_PARTITION_MAP_ENDPOINT_ENV,
                "http://notdynamo-control-plane:9090/v1/partition-map"
            );
            long controlPlanePartitionMapTimeoutMillis = parseLong(
                env.get(CONTROL_PLANE_PARTITION_MAP_TIMEOUT_MS_ENV),
                1500L,
                CONTROL_PLANE_PARTITION_MAP_TIMEOUT_MS_ENV
            );
            long controlPlanePartitionMapRefreshIntervalMillis = parseLong(
                env.get(CONTROL_PLANE_PARTITION_MAP_REFRESH_INTERVAL_MS_ENV),
                2000L,
                CONTROL_PLANE_PARTITION_MAP_REFRESH_INTERVAL_MS_ENV
            );
            long controlPlaneWriteLoadReportIntervalMillis = parseLong(
                env.get(CONTROL_PLANE_WRITE_LOAD_REPORT_INTERVAL_MS_ENV),
                10000L,
                CONTROL_PLANE_WRITE_LOAD_REPORT_INTERVAL_MS_ENV
            );

            if (shardCount <= 0) {
                throw new IllegalArgumentException("NOTDYNAMO_SHARD_COUNT must be > 0");
            }
            if (virtualNodesPerShard <= 0) {
                throw new IllegalArgumentException("NOTDYNAMO_VIRTUAL_NODES_PER_SHARD must be > 0");
            }
            if (rpcTimeoutMillis <= 0) {
                throw new IllegalArgumentException("NOTDYNAMO_RPC_TIMEOUT_MS must be > 0");
            }
            if (httpWorkerThreads <= 0) {
                throw new IllegalArgumentException("NOTDYNAMO_HTTP_WORKER_THREADS must be > 0");
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
            if (replicationFactor <= 0) {
                throw new IllegalArgumentException("NOTDYNAMO_REPLICATION_FACTOR must be > 0");
            }
            if (controlPlanePartitionMapTimeoutMillis <= 0) {
                throw new IllegalArgumentException("NOTDYNAMO_CONTROL_PLANE_PARTITION_MAP_TIMEOUT_MS must be > 0");
            }
            if (controlPlanePartitionMapRefreshIntervalMillis <= 0) {
                throw new IllegalArgumentException(
                    "NOTDYNAMO_CONTROL_PLANE_PARTITION_MAP_REFRESH_INTERVAL_MS must be > 0"
                );
            }
            if (controlPlaneWriteLoadReportIntervalMillis <= 0) {
                throw new IllegalArgumentException(
                    "NOTDYNAMO_CONTROL_PLANE_WRITE_LOAD_REPORT_INTERVAL_MS must be > 0"
                );
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
            if (replicationFactor > clusterNodeIds.size()) {
                throw new IllegalArgumentException("NOTDYNAMO_REPLICATION_FACTOR must be <= cluster node count");
            }
            if (
                partitionMapSource == PartitionMapSource.CONTROL_PLANE
                    && (controlPlanePartitionMapEndpoint == null || controlPlanePartitionMapEndpoint.isBlank())
            ) {
                throw new IllegalArgumentException(
                    "NOTDYNAMO_CONTROL_PLANE_PARTITION_MAP_ENDPOINT must not be blank when source=control-plane"
                );
            }

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
            String writeGlobalInflightRaw = env.get(WRITE_GLOBAL_INFLIGHT_LIMIT_ENV);
            if (writeGlobalInflightRaw == null || writeGlobalInflightRaw.isBlank()) {
                writeGlobalInflightRaw = env.get(WRITE_INFLIGHT_LIMIT_ENV);
            }
            int writeGlobalInflightLimit = parseInt(writeGlobalInflightRaw, 256, WRITE_GLOBAL_INFLIGHT_LIMIT_ENV);
            int writeShardInflightMin = parseInt(
                env.get(WRITE_SHARD_INFLIGHT_MIN_ENV),
                8,
                WRITE_SHARD_INFLIGHT_MIN_ENV
            );
            long writeAdmissionWaitMillis = parseLong(
                env.get(WRITE_ADMISSION_WAIT_MS_ENV),
                2L,
                WRITE_ADMISSION_WAIT_MS_ENV
            );
            int ratisMaxInflightPerShard = parseInt(
                env.get(RATIS_MAX_INFLIGHT_PER_SHARD_ENV),
                16,
                RATIS_MAX_INFLIGHT_PER_SHARD_ENV
            );
            ReadConsistency readConsistency = ReadConsistency.parse(env.get(READ_CONSISTENCY_ENV));
            long eventualFreshnessMillis = parseLong(env.get(EVENTUAL_FRESHNESS_MS_ENV), 1000L, EVENTUAL_FRESHNESS_MS_ENV);
            if (writeQuorumAcks <= 0) {
                throw new IllegalArgumentException("NOTDYNAMO_WRITE_QUORUM_ACKS must be > 0");
            }
            if (writeGlobalInflightLimit < 0) {
                throw new IllegalArgumentException("NOTDYNAMO_WRITE_GLOBAL_INFLIGHT_LIMIT must be >= 0");
            }
            if (writeShardInflightMin <= 0) {
                throw new IllegalArgumentException("NOTDYNAMO_WRITE_SHARD_INFLIGHT_MIN must be > 0");
            }
            if (writeAdmissionWaitMillis < 0) {
                throw new IllegalArgumentException("NOTDYNAMO_WRITE_ADMISSION_WAIT_MS must be >= 0");
            }
            if (ratisMaxInflightPerShard <= 0) {
                throw new IllegalArgumentException("NOTDYNAMO_RATIS_MAX_INFLIGHT_PER_SHARD must be > 0");
            }
            if (eventualFreshnessMillis < 0) {
                throw new IllegalArgumentException("NOTDYNAMO_EVENTUAL_FRESHNESS_MILLIS must be >= 0");
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
                httpWorkerThreads,
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
                writeQuorumAcks,
                writeGlobalInflightLimit,
                writeShardInflightMin,
                writeAdmissionWaitMillis,
                ratisMaxInflightPerShard,
                readConsistency,
                eventualFreshnessMillis,
                replicationFactor,
                partitionMapSource,
                controlPlanePartitionMapEndpoint,
                controlPlanePartitionMapTimeoutMillis,
                controlPlanePartitionMapRefreshIntervalMillis,
                controlPlaneWriteLoadReportIntervalMillis
            );
        }

        private ShardPartitionMap shardPartitionMap() {
            if (runtimeMode != RuntimeMode.PARTITIONED || partitionMapSource == PartitionMapSource.STATIC) {
                return ShardPartitionMap.roundRobin(
                    new PartitionMapVersion(0),
                    shardCount,
                    virtualNodesPerShard,
                    clusterNodeIds,
                    replicationFactor
                );
            }

            ControlPlanePartitionMapClient client = new ControlPlanePartitionMapClient(
                Duration.ofMillis(controlPlanePartitionMapTimeoutMillis)
            );
            RuntimeException lastFailure = null;
            for (int attempt = 1; attempt <= 20; attempt++) {
                try {
                    ShardPartitionMap fetched = client.fetch(controlPlanePartitionMapEndpoint);
                    if (fetched.shardCount() != shardCount) {
                        throw new IllegalStateException(
                            "control-plane shardCount mismatch: expected=" + shardCount + " actual=" + fetched.shardCount()
                        );
                    }
                    if (fetched.virtualNodesPerShard() != virtualNodesPerShard) {
                        throw new IllegalStateException(
                            "control-plane virtualNodesPerShard mismatch: expected="
                                + virtualNodesPerShard
                                + " actual="
                                + fetched.virtualNodesPerShard()
                        );
                    }
                    return fetched;
                } catch (RuntimeException e) {
                    lastFailure = e;
                    if (attempt == 20) {
                        break;
                    }
                    try {
                        Thread.sleep(Math.min(200L * attempt, 1000L));
                    } catch (InterruptedException interruptedException) {
                        Thread.currentThread().interrupt();
                        throw new IllegalStateException(
                            "interrupted while retrying control-plane partition map fetch",
                            interruptedException
                        );
                    }
                }
            }

            throw new IllegalStateException(
                "failed to fetch partition map from control-plane endpoint " + controlPlanePartitionMapEndpoint,
                lastFailure
            );
        }

        private RatisMultiShardConsensusEngineConfig multiShardConsensusConfig(ShardPartitionMap shardPartitionMap) {
            List<ShardRaftGroupConfig> shardGroups = new ArrayList<>(shardPartitionMap.shardCount());
            for (int shardId = 0; shardId < shardPartitionMap.shardCount(); shardId++) {
                var descriptor = shardPartitionMap.descriptorForShard(shardId);
                shardGroups.add(new ShardRaftGroupConfig(shardId, descriptor.groupId(), descriptor.replicaNodeIds()));
            }
            return new RatisMultiShardConsensusEngineConfig(
                nodeId,
                shardGroups,
                this::ratisTargetForNode,
                dataDir.resolve("ratis"),
                ratisRequestTimeoutMillis
            );
        }

        private RatisKvRouter.ReadMode ratisReadMode() {
            return readConsistency == ReadConsistency.LEADER
                ? RatisKvRouter.ReadMode.LEADER
                : RatisKvRouter.ReadMode.EVENTUAL;
        }

        private String controlPlaneWriteLoadReportEndpoint() {
            String endpoint = controlPlanePartitionMapEndpoint;
            String suffix = "/v1/partition-map";
            if (endpoint.endsWith(suffix)) {
                return endpoint.substring(0, endpoint.length() - suffix.length()) + "/v1/write-load-report";
            }
            if (endpoint.endsWith("/")) {
                return endpoint + "v1/write-load-report";
            }
            return endpoint + "/v1/write-load-report";
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
