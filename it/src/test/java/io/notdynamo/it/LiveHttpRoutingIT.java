package io.notdynamo.it;

import static org.junit.jupiter.api.Assertions.assertEquals;

import io.grpc.Server;
import io.grpc.ServerBuilder;
import io.notdynamo.controlplane.ClusterPartitionMap;
import io.notdynamo.controlplane.PartitionMapVersion;
import io.notdynamo.node.NodeConfig;
import io.notdynamo.node.NodeServer;
import io.notdynamo.node.cluster.GrpcNodeRpcClient;
import io.notdynamo.node.cluster.PartitionMapCache;
import io.notdynamo.node.cluster.PartitionedKvRouter;
import io.notdynamo.node.cluster.PartitionedKvServiceHandler;
import io.notdynamo.node.http.HttpBridgeServer;
import io.notdynamo.node.shard.ConsistentHashRing;
import java.io.IOException;
import java.net.ServerSocket;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class LiveHttpRoutingIT {
    @TempDir
    Path tempDir;

    @Test
    void httpRequestsRouteAcrossNodesAndPreserveSemantics() throws Exception {
        int shardCount = 64;
        int virtualNodesPerShard = 256;
        List<String> nodeIds = List.of("node-a", "node-b", "node-c");

        ClusterPartitionMap map = ClusterPartitionMap.roundRobin(
            new PartitionMapVersion(0),
            shardCount,
            virtualNodesPerShard,
            nodeIds
        );

        Map<String, Integer> grpcPorts = new HashMap<>();
        Map<String, Integer> httpPorts = new HashMap<>();
        for (String nodeId : nodeIds) {
            grpcPorts.put(nodeId, freePort());
            httpPorts.put(nodeId, freePort());
        }

        try (
            NodeServer nodeA = NodeServer.openSharded(configFor("node-a"), shardCount, virtualNodesPerShard);
            NodeServer nodeB = NodeServer.openSharded(configFor("node-b"), shardCount, virtualNodesPerShard);
            NodeServer nodeC = NodeServer.openSharded(configFor("node-c"), shardCount, virtualNodesPerShard)
        ) {
            var resolver = (java.util.function.Function<String, String>) nodeId -> "127.0.0.1:" + grpcPorts.get(nodeId);

            try (
                GrpcNodeRpcClient rpcA = new GrpcNodeRpcClient(resolver, 1000);
                GrpcNodeRpcClient rpcB = new GrpcNodeRpcClient(resolver, 1000);
                GrpcNodeRpcClient rpcC = new GrpcNodeRpcClient(resolver, 1000)
            ) {
                var serviceA = new PartitionedKvServiceHandler(new PartitionedKvRouter("node-a", nodeA.kvService(), rpcA, new PartitionMapCache(map)));
                var serviceB = new PartitionedKvServiceHandler(new PartitionedKvRouter("node-b", nodeB.kvService(), rpcB, new PartitionMapCache(map)));
                var serviceC = new PartitionedKvServiceHandler(new PartitionedKvRouter("node-c", nodeC.kvService(), rpcC, new PartitionMapCache(map)));

                Server grpcA = ServerBuilder.forPort(grpcPorts.get("node-a")).addService(serviceA).build().start();
                Server grpcB = ServerBuilder.forPort(grpcPorts.get("node-b")).addService(serviceB).build().start();
                Server grpcC = ServerBuilder.forPort(grpcPorts.get("node-c")).addService(serviceC).build().start();

                HttpBridgeServer httpA = HttpBridgeServer.open("node-a", httpPorts.get("node-a"), serviceA);
                HttpBridgeServer httpB = HttpBridgeServer.open("node-b", httpPorts.get("node-b"), serviceB);
                HttpBridgeServer httpC = HttpBridgeServer.open("node-c", httpPorts.get("node-c"), serviceC);
                httpA.start();
                httpB.start();
                httpC.start();

                try {
                    byte[] keyBytes = findKeyForOwner(map, "node-b");
                    String key = new String(keyBytes, StandardCharsets.UTF_8);
                    String value = "http-distributed-value";

                    HttpClient client = HttpClient.newHttpClient();
                    String putUrl = "http://127.0.0.1:" + httpPorts.get("node-a") + "/v1/kv/" + key;
                    String getUrl = "http://127.0.0.1:" + httpPorts.get("node-c") + "/v1/kv/" + key;

                    HttpResponse<byte[]> put = client.send(
                        HttpRequest.newBuilder()
                            .uri(URI.create(putUrl))
                            .PUT(HttpRequest.BodyPublishers.ofByteArray(value.getBytes(StandardCharsets.UTF_8)))
                            .build(),
                        HttpResponse.BodyHandlers.ofByteArray()
                    );
                    assertEquals(200, put.statusCode());

                    HttpResponse<byte[]> get = client.send(
                        HttpRequest.newBuilder().uri(URI.create(getUrl)).GET().build(),
                        HttpResponse.BodyHandlers.ofByteArray()
                    );
                    assertEquals(200, get.statusCode());
                    assertEquals(value, new String(get.body(), StandardCharsets.UTF_8));

                    HttpResponse<byte[]> delete = client.send(
                        HttpRequest.newBuilder().uri(URI.create(getUrl)).DELETE().build(),
                        HttpResponse.BodyHandlers.ofByteArray()
                    );
                    assertEquals(200, delete.statusCode());

                    HttpResponse<byte[]> postDelete = client.send(
                        HttpRequest.newBuilder().uri(URI.create(putUrl)).GET().build(),
                        HttpResponse.BodyHandlers.ofByteArray()
                    );
                    assertEquals(404, postDelete.statusCode());
                } finally {
                    httpA.close();
                    httpB.close();
                    httpC.close();
                    shutdownServer(grpcA);
                    shutdownServer(grpcB);
                    shutdownServer(grpcC);
                }
            }
        }
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

    private static int freePort() throws IOException {
        try (ServerSocket socket = new ServerSocket(0)) {
            socket.setReuseAddress(true);
            return socket.getLocalPort();
        }
    }

    private static void shutdownServer(Server server) throws InterruptedException {
        server.shutdownNow();
        server.awaitTermination(5, TimeUnit.SECONDS);
    }
}
