package io.notdynamo.controlplane;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.TreeMap;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

public final class ControlPlaneMain {
    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private static final long FIVE_MINUTES_MS = Duration.ofMinutes(5).toMillis();

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
        WriteLoadTracker writeLoadTracker = new WriteLoadTracker();
        HotShardLeaderRebalancer rebalancer = new HotShardLeaderRebalancer(settings, partitionMapManager, writeLoadTracker);

        HttpServer server = HttpServer.create(new InetSocketAddress(settings.port), 0);
        server.setExecutor(Executors.newFixedThreadPool(Math.max(2, Runtime.getRuntime().availableProcessors() / 2)));
        server.createContext("/healthz", exchange -> handleHealth(exchange, partitionMapManager));
        server.createContext("/v1/partition-map", exchange -> handlePartitionMap(exchange, partitionMapManager));
        server.createContext(
            "/v1/write-load-report",
            exchange -> handleWriteLoadReport(exchange, partitionMapManager, writeLoadTracker)
        );

        ScheduledExecutorService rebalanceExecutor = Executors.newSingleThreadScheduledExecutor();
        rebalanceExecutor.scheduleWithFixedDelay(
            rebalancer::runPass,
            settings.rebalanceIntervalMillis,
            settings.rebalanceIntervalMillis,
            TimeUnit.MILLISECONDS
        );

        CountDownLatch shutdownLatch = new CountDownLatch(1);
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            server.stop(2);
            rebalanceExecutor.shutdown();
            try {
                if (!rebalanceExecutor.awaitTermination(5, TimeUnit.SECONDS)) {
                    rebalanceExecutor.shutdownNow();
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                rebalanceExecutor.shutdownNow();
            }
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

    private static void handleWriteLoadReport(
        HttpExchange exchange,
        ShardPartitionMapManager partitionMapManager,
        WriteLoadTracker writeLoadTracker
    ) throws IOException {
        if (!"POST".equalsIgnoreCase(exchange.getRequestMethod())) {
            sendJson(exchange, 405, "{\"error\":\"method_not_allowed\"}");
            return;
        }

        String body = new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8);
        WriteLoadReportRequest request;
        try {
            request = OBJECT_MAPPER.readValue(body, WriteLoadReportRequest.class);
        } catch (JsonProcessingException e) {
            sendJson(exchange, 400, "{\"error\":\"invalid_json\"}");
            return;
        }

        if (request == null || request.nodeId == null || request.nodeId.isBlank()) {
            sendJson(exchange, 400, "{\"error\":\"nodeId_required\"}");
            return;
        }

        long epoch = request.partitionMapEpoch == null ? -1L : request.partitionMapEpoch;
        double nodeCpuPercent = request.nodeCpuPercent == null ? -1.0 : request.nodeCpuPercent;
        writeLoadTracker.ingest(request.nodeId.trim(), epoch, nodeCpuPercent, request.shards);

        long currentEpoch = partitionMapManager.current().version().epoch();
        sendJson(exchange, 202, "{\"accepted\":true,\"partitionMapEpoch\":" + currentEpoch + "}");
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
        System.out.println("rebalance_interval_ms=" + settings.rebalanceIntervalMillis);
        System.out.println("rebalance_max_moves_per_pass=" + settings.rebalanceMaxMovesPerPass);
        System.out.println("rebalance_max_churn_percent_5m=" + settings.rebalanceMaxChurnPercent5m);
        System.out.println("rebalance_timeout_weight=" + settings.timeoutRateWeight);
    }

    private static final class HotShardLeaderRebalancer {
        private final RuntimeSettings settings;
        private final ShardPartitionMapManager partitionMapManager;
        private final WriteLoadTracker writeLoadTracker;
        private final ArrayDeque<Long> leaderMoveTimestampsMs = new ArrayDeque<>();

        private HotShardLeaderRebalancer(
            RuntimeSettings settings,
            ShardPartitionMapManager partitionMapManager,
            WriteLoadTracker writeLoadTracker
        ) {
            this.settings = Objects.requireNonNull(settings, "settings must not be null");
            this.partitionMapManager = Objects.requireNonNull(partitionMapManager, "partitionMapManager must not be null");
            this.writeLoadTracker = Objects.requireNonNull(writeLoadTracker, "writeLoadTracker must not be null");
        }

        private void runPass() {
            try {
                ShardPartitionMap currentMap = partitionMapManager.current();
                WriteLoadTracker.Snapshot snapshot = writeLoadTracker.snapshot();
                if (snapshot.nodeCount() == 0) {
                    return;
                }

                pruneChurnWindow(System.currentTimeMillis());
                int churnCap = Math.max(1, (int) Math.floor(currentMap.shardCount() * (settings.rebalanceMaxChurnPercent5m / 100.0)));
                int churnRemaining = Math.max(0, churnCap - leaderMoveTimestampsMs.size());
                if (churnRemaining <= 0) {
                    return;
                }

                int moveBudget = Math.min(settings.rebalanceMaxMovesPerPass, churnRemaining);
                if (moveBudget <= 0) {
                    return;
                }

                List<LeaderMove> moves = planMoves(currentMap, snapshot, moveBudget);
                if (moves.isEmpty()) {
                    return;
                }

                Map<Integer, String> nextLeaders = new LinkedHashMap<>(currentMap.shardCount());
                for (int shardId = 0; shardId < currentMap.shardCount(); shardId++) {
                    nextLeaders.put(shardId, currentMap.descriptorForShard(shardId).leaderNodeId());
                }
                for (LeaderMove move : moves) {
                    nextLeaders.put(move.shardId(), move.targetNodeId());
                }

                ShardPartitionMap candidate = partitionMapManager.next(nextLeaders);
                if (!partitionMapManager.tryApply(candidate)) {
                    return;
                }
                long nowMs = System.currentTimeMillis();
                for (int i = 0; i < moves.size(); i++) {
                    leaderMoveTimestampsMs.addLast(nowMs);
                }

                System.out.println(
                    "notdynamo.control_plane.rebalance.applied=true epoch="
                        + candidate.version().epoch()
                        + " moves="
                        + moves.size()
                        + " details="
                        + moves
                );
            } catch (RuntimeException e) {
                System.err.println("notdynamo.control_plane.rebalance.error=" + e.getMessage());
            }
        }

        private List<LeaderMove> planMoves(ShardPartitionMap map, WriteLoadTracker.Snapshot snapshot, int moveBudget) {
            Map<String, Double> nodeLoad = new HashMap<>();
            for (String nodeId : settings.clusterNodeIds) {
                nodeLoad.put(nodeId, 0.0);
            }

            Map<Integer, Double> shardScore = new HashMap<>();
            Map<String, List<Integer>> shardsByLeader = new HashMap<>();
            for (int shardId = 0; shardId < map.shardCount(); shardId++) {
                ShardDescriptor descriptor = map.descriptorForShard(shardId);
                String leader = descriptor.leaderNodeId();
                double writeRate = snapshot.writeRateFor(leader, shardId);
                double timeoutRate = snapshot.timeoutRateFor(leader, shardId);
                double score = Math.max(0.0, writeRate) + (Math.max(0.0, timeoutRate) * settings.timeoutRateWeight);
                shardScore.put(shardId, score);
                nodeLoad.merge(leader, score, Double::sum);
                shardsByLeader.computeIfAbsent(leader, ignored -> new ArrayList<>()).add(shardId);
            }

            for (List<Integer> shardIds : shardsByLeader.values()) {
                shardIds.sort((left, right) -> Double.compare(shardScore.getOrDefault(right, 0.0), shardScore.getOrDefault(left, 0.0)));
            }

            List<LeaderMove> planned = new ArrayList<>();
            LinkedHashSet<Integer> movedShards = new LinkedHashSet<>();
            for (int i = 0; i < moveBudget; i++) {
                String source = nodeLoad.entrySet().stream()
                    .max(Map.Entry.comparingByValue())
                    .map(Map.Entry::getKey)
                    .orElse(null);
                String target = nodeLoad.entrySet().stream()
                    .min(Map.Entry.comparingByValue())
                    .map(Map.Entry::getKey)
                    .orElse(null);
                if (source == null || target == null || source.equals(target)) {
                    break;
                }

                double sourceLoad = nodeLoad.getOrDefault(source, 0.0);
                double targetLoad = nodeLoad.getOrDefault(target, 0.0);
                if (sourceLoad <= targetLoad) {
                    break;
                }

                LeaderMove move = selectMove(map, source, target, movedShards, shardScore);
                if (move == null) {
                    break;
                }

                planned.add(move);
                movedShards.add(move.shardId());
                double score = shardScore.getOrDefault(move.shardId(), 0.0);
                nodeLoad.put(source, Math.max(0.0, sourceLoad - score));
                nodeLoad.put(target, Math.max(0.0, targetLoad + score));
            }

            return planned;
        }

        private LeaderMove selectMove(
            ShardPartitionMap map,
            String source,
            String target,
            LinkedHashSet<Integer> movedShards,
            Map<Integer, Double> shardScore
        ) {
            List<String> targetsByLoad = settings.clusterNodeIds.stream()
                .sorted(Comparator.comparingDouble(node -> shardTargetLoad(node, map, shardScore)))
                .toList();

            for (String candidateTarget : targetsByLoad) {
                if (candidateTarget.equals(source)) {
                    continue;
                }
                for (int shardId = 0; shardId < map.shardCount(); shardId++) {
                    if (movedShards.contains(shardId)) {
                        continue;
                    }
                    ShardDescriptor descriptor = map.descriptorForShard(shardId);
                    if (!source.equals(descriptor.leaderNodeId())) {
                        continue;
                    }
                    if (!descriptor.replicaNodeIds().contains(candidateTarget)) {
                        continue;
                    }
                    return new LeaderMove(shardId, source, candidateTarget);
                }
            }

            if (!source.equals(target)) {
                for (int shardId = 0; shardId < map.shardCount(); shardId++) {
                    if (movedShards.contains(shardId)) {
                        continue;
                    }
                    ShardDescriptor descriptor = map.descriptorForShard(shardId);
                    if (source.equals(descriptor.leaderNodeId()) && descriptor.replicaNodeIds().contains(target)) {
                        return new LeaderMove(shardId, source, target);
                    }
                }
            }
            return null;
        }

        private double shardTargetLoad(String nodeId, ShardPartitionMap map, Map<Integer, Double> shardScore) {
            double total = 0.0;
            for (int shardId = 0; shardId < map.shardCount(); shardId++) {
                ShardDescriptor descriptor = map.descriptorForShard(shardId);
                if (nodeId.equals(descriptor.leaderNodeId())) {
                    total += shardScore.getOrDefault(shardId, 0.0);
                }
            }
            return total;
        }

        private void pruneChurnWindow(long nowMs) {
            while (!leaderMoveTimestampsMs.isEmpty()) {
                long oldest = leaderMoveTimestampsMs.peekFirst();
                if (nowMs - oldest <= FIVE_MINUTES_MS) {
                    break;
                }
                leaderMoveTimestampsMs.removeFirst();
            }
        }
    }

    private static final class WriteLoadTracker {
        private final ConcurrentHashMap<String, NodeWriteState> byNode = new ConcurrentHashMap<>();

        private void ingest(String nodeId, long mapEpoch, double nodeCpuPercent, Map<String, ShardLoadPayload> shardPayloads) {
            long nowMs = System.currentTimeMillis();
            Map<Integer, ShardCounters> counters = decodeShardCounters(shardPayloads);

            byNode.compute(nodeId, (ignored, existing) -> {
                if (existing == null) {
                    return new NodeWriteState(mapEpoch, nodeCpuPercent, nowMs, counters, Map.of());
                }

                double elapsedSeconds = Math.max(0.001, (double) (nowMs - existing.timestampMs) / 1000.0);
                Map<Integer, ShardRates> rates = new HashMap<>();
                for (Map.Entry<Integer, ShardCounters> entry : counters.entrySet()) {
                    int shardId = entry.getKey();
                    ShardCounters next = entry.getValue();
                    ShardCounters prev = existing.counters.getOrDefault(shardId, ShardCounters.ZERO);
                    long deltaPut = Math.max(0L, next.putTotalCount - prev.putTotalCount);
                    long deltaTimeout = Math.max(0L, next.putTimeoutCount - prev.putTimeoutCount);
                    rates.put(
                        shardId,
                        new ShardRates(
                            (double) deltaPut / elapsedSeconds,
                            (double) deltaTimeout / elapsedSeconds,
                            deltaTimeout
                        )
                    );
                }

                return new NodeWriteState(mapEpoch, nodeCpuPercent, nowMs, counters, rates);
            });
        }

        private Snapshot snapshot() {
            return new Snapshot(Map.copyOf(byNode));
        }

        private static Map<Integer, ShardCounters> decodeShardCounters(Map<String, ShardLoadPayload> payloads) {
            if (payloads == null || payloads.isEmpty()) {
                return Map.of();
            }
            Map<Integer, ShardCounters> decoded = new HashMap<>();
            for (Map.Entry<String, ShardLoadPayload> entry : payloads.entrySet()) {
                int shardId;
                try {
                    shardId = Integer.parseInt(entry.getKey());
                } catch (NumberFormatException e) {
                    continue;
                }
                ShardLoadPayload payload = entry.getValue();
                if (payload == null) {
                    continue;
                }
                long putTotal = payload.putTotalCount == null ? 0L : Math.max(0L, payload.putTotalCount);
                long putTimeout = payload.putTimeoutCount == null ? 0L : Math.max(0L, payload.putTimeoutCount);
                decoded.put(shardId, new ShardCounters(putTotal, putTimeout));
            }
            return decoded;
        }

        private static final class Snapshot {
            private final Map<String, NodeWriteState> byNode;

            private Snapshot(Map<String, NodeWriteState> byNode) {
                this.byNode = byNode;
            }

            private int nodeCount() {
                return byNode.size();
            }

            private double writeRateFor(String nodeId, int shardId) {
                NodeWriteState state = byNode.get(nodeId);
                if (state == null) {
                    return 0.0;
                }
                ShardRates rates = state.rates.get(shardId);
                if (rates == null) {
                    return 0.0;
                }
                return rates.writeRate;
            }

            private double timeoutRateFor(String nodeId, int shardId) {
                NodeWriteState state = byNode.get(nodeId);
                if (state == null) {
                    return 0.0;
                }
                ShardRates rates = state.rates.get(shardId);
                if (rates == null) {
                    return 0.0;
                }
                return rates.timeoutRate;
            }
        }

        private static final class NodeWriteState {
            private final long mapEpoch;
            private final double nodeCpuPercent;
            private final long timestampMs;
            private final Map<Integer, ShardCounters> counters;
            private final Map<Integer, ShardRates> rates;

            private NodeWriteState(
                long mapEpoch,
                double nodeCpuPercent,
                long timestampMs,
                Map<Integer, ShardCounters> counters,
                Map<Integer, ShardRates> rates
            ) {
                this.mapEpoch = mapEpoch;
                this.nodeCpuPercent = nodeCpuPercent;
                this.timestampMs = timestampMs;
                this.counters = Map.copyOf(counters);
                this.rates = Map.copyOf(rates);
            }
        }

        private record ShardCounters(long putTotalCount, long putTimeoutCount) {
            private static final ShardCounters ZERO = new ShardCounters(0L, 0L);
        }

        private record ShardRates(double writeRate, double timeoutRate, long timeoutCountDelta) {}
    }

    private record LeaderMove(int shardId, String sourceNodeId, String targetNodeId) {}

    private static final class WriteLoadReportRequest {
        public String nodeId;
        public Long partitionMapEpoch;
        public Double nodeCpuPercent;
        public Map<String, ShardLoadPayload> shards;
    }

    private static final class ShardLoadPayload {
        public Long putTotalCount;
        public Long putTimeoutCount;
    }

    private static final class RuntimeSettings {
        private static final String PORT_ENV = "NOTDYNAMO_CONTROL_PLANE_PORT";
        private static final String SHARD_COUNT_ENV = "NOTDYNAMO_SHARD_COUNT";
        private static final String VNODES_ENV = "NOTDYNAMO_VIRTUAL_NODES_PER_SHARD";
        private static final String REPLICATION_FACTOR_ENV = "NOTDYNAMO_REPLICATION_FACTOR";
        private static final String CLUSTER_NODE_IDS_ENV = "NOTDYNAMO_CLUSTER_NODE_IDS";
        private static final String CLUSTER_SIZE_ENV = "NOTDYNAMO_CLUSTER_SIZE";
        private static final String STATEFULSET_NAME_ENV = "NOTDYNAMO_STATEFULSET_NAME";
        private static final String REBALANCE_INTERVAL_MS_ENV = "NOTDYNAMO_REBALANCE_INTERVAL_MS";
        private static final String REBALANCE_MAX_MOVES_PER_PASS_ENV = "NOTDYNAMO_REBALANCE_MAX_MOVES_PER_PASS";
        private static final String REBALANCE_MAX_CHURN_PERCENT_5M_ENV = "NOTDYNAMO_REBALANCE_MAX_CHURN_PERCENT_5M";
        private static final String REBALANCE_TIMEOUT_WEIGHT_ENV = "NOTDYNAMO_REBALANCE_TIMEOUT_WEIGHT";

        private final int port;
        private final int shardCount;
        private final int virtualNodesPerShard;
        private final int replicationFactor;
        private final List<String> clusterNodeIds;
        private final long rebalanceIntervalMillis;
        private final int rebalanceMaxMovesPerPass;
        private final double rebalanceMaxChurnPercent5m;
        private final double timeoutRateWeight;

        private RuntimeSettings(
            int port,
            int shardCount,
            int virtualNodesPerShard,
            int replicationFactor,
            List<String> clusterNodeIds,
            long rebalanceIntervalMillis,
            int rebalanceMaxMovesPerPass,
            double rebalanceMaxChurnPercent5m,
            double timeoutRateWeight
        ) {
            this.port = port;
            this.shardCount = shardCount;
            this.virtualNodesPerShard = virtualNodesPerShard;
            this.replicationFactor = replicationFactor;
            this.clusterNodeIds = clusterNodeIds;
            this.rebalanceIntervalMillis = rebalanceIntervalMillis;
            this.rebalanceMaxMovesPerPass = rebalanceMaxMovesPerPass;
            this.rebalanceMaxChurnPercent5m = rebalanceMaxChurnPercent5m;
            this.timeoutRateWeight = timeoutRateWeight;
        }

        private static RuntimeSettings fromEnvironment(Map<String, String> env) {
            int port = parseInt(env.get(PORT_ENV), 9090, PORT_ENV);
            int shardCount = parseInt(env.get(SHARD_COUNT_ENV), 128, SHARD_COUNT_ENV);
            int virtualNodesPerShard = parseInt(env.get(VNODES_ENV), 256, VNODES_ENV);
            int replicationFactor = parseInt(env.get(REPLICATION_FACTOR_ENV), 3, REPLICATION_FACTOR_ENV);
            long rebalanceIntervalMillis = parseLong(env.get(REBALANCE_INTERVAL_MS_ENV), 60000L, REBALANCE_INTERVAL_MS_ENV);
            int rebalanceMaxMovesPerPass = parseInt(
                env.get(REBALANCE_MAX_MOVES_PER_PASS_ENV),
                3,
                REBALANCE_MAX_MOVES_PER_PASS_ENV
            );
            double rebalanceMaxChurnPercent5m = parseDouble(
                env.get(REBALANCE_MAX_CHURN_PERCENT_5M_ENV),
                10.0,
                REBALANCE_MAX_CHURN_PERCENT_5M_ENV
            );
            double timeoutRateWeight = parseDouble(
                env.get(REBALANCE_TIMEOUT_WEIGHT_ENV),
                5.0,
                REBALANCE_TIMEOUT_WEIGHT_ENV
            );

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
            if (rebalanceIntervalMillis <= 0) {
                throw new IllegalArgumentException("NOTDYNAMO_REBALANCE_INTERVAL_MS must be > 0");
            }
            if (rebalanceMaxMovesPerPass <= 0) {
                throw new IllegalArgumentException("NOTDYNAMO_REBALANCE_MAX_MOVES_PER_PASS must be > 0");
            }
            if (rebalanceMaxChurnPercent5m <= 0.0 || rebalanceMaxChurnPercent5m > 100.0) {
                throw new IllegalArgumentException("NOTDYNAMO_REBALANCE_MAX_CHURN_PERCENT_5M must be in (0,100]");
            }
            if (timeoutRateWeight <= 0.0) {
                throw new IllegalArgumentException("NOTDYNAMO_REBALANCE_TIMEOUT_WEIGHT must be > 0");
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

            return new RuntimeSettings(
                port,
                shardCount,
                virtualNodesPerShard,
                replicationFactor,
                clusterNodeIds,
                rebalanceIntervalMillis,
                rebalanceMaxMovesPerPass,
                rebalanceMaxChurnPercent5m,
                timeoutRateWeight
            );
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

        private static double parseDouble(String value, double defaultValue, String envName) {
            if (value == null || value.isBlank()) {
                return defaultValue;
            }
            try {
                return Double.parseDouble(value);
            } catch (NumberFormatException e) {
                throw new IllegalArgumentException(envName + " must be a decimal", e);
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
