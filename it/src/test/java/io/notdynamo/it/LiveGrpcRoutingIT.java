package io.notdynamo.it;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.google.protobuf.ByteString;
import io.grpc.ManagedChannel;
import io.grpc.ManagedChannelBuilder;
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
import io.notdynamo.node.shard.ConsistentHashRing;
import io.notdynamo.proto.v1.DeleteRequest;
import io.notdynamo.proto.v1.GetRequest;
import io.notdynamo.proto.v1.GetResponse;
import io.notdynamo.proto.v1.KvServiceGrpc;
import io.notdynamo.proto.v1.PutRequest;
import io.notdynamo.proto.v1.PutResponse;
import java.io.IOException;
import java.net.ServerSocket;
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

class LiveGrpcRoutingIT {
    @TempDir
    Path tempDir;

    @Test
    void routesRequestsAcrossLiveGrpcServers() throws Exception {
        int shardCount = 64;
        int virtualNodesPerShard = 256;
        List<String> nodeIds = List.of("node-a", "node-b", "node-c");

        ClusterPartitionMap map = ClusterPartitionMap.roundRobin(
            new PartitionMapVersion(0),
            shardCount,
            virtualNodesPerShard,
            nodeIds
        );

        Map<String, Integer> ports = new HashMap<>();
        for (String nodeId : nodeIds) {
            ports.put(nodeId, freePort());
        }

        try (
            NodeServer nodeA = NodeServer.openSharded(configFor("node-a"), shardCount, virtualNodesPerShard);
            NodeServer nodeB = NodeServer.openSharded(configFor("node-b"), shardCount, virtualNodesPerShard);
            NodeServer nodeC = NodeServer.openSharded(configFor("node-c"), shardCount, virtualNodesPerShard)
        ) {
            var resolver = (java.util.function.Function<String, String>) nodeId -> "127.0.0.1:" + ports.get(nodeId);

            try (
                GrpcNodeRpcClient rpcA = new GrpcNodeRpcClient(resolver, 1000);
                GrpcNodeRpcClient rpcB = new GrpcNodeRpcClient(resolver, 1000);
                GrpcNodeRpcClient rpcC = new GrpcNodeRpcClient(resolver, 1000)
            ) {
                Server serverA = ServerBuilder.forPort(ports.get("node-a"))
                    .addService(new PartitionedKvServiceHandler(new PartitionedKvRouter("node-a", nodeA.kvService(), rpcA, new PartitionMapCache(map))))
                    .build()
                    .start();
                Server serverB = ServerBuilder.forPort(ports.get("node-b"))
                    .addService(new PartitionedKvServiceHandler(new PartitionedKvRouter("node-b", nodeB.kvService(), rpcB, new PartitionMapCache(map))))
                    .build()
                    .start();
                Server serverC = ServerBuilder.forPort(ports.get("node-c"))
                    .addService(new PartitionedKvServiceHandler(new PartitionedKvRouter("node-c", nodeC.kvService(), rpcC, new PartitionMapCache(map))))
                    .build()
                    .start();

                ManagedChannel channelA = ManagedChannelBuilder.forAddress("127.0.0.1", ports.get("node-a")).usePlaintext().build();
                ManagedChannel channelC = ManagedChannelBuilder.forAddress("127.0.0.1", ports.get("node-c")).usePlaintext().build();

                try {
                    KvServiceGrpc.KvServiceBlockingStub clientA = KvServiceGrpc.newBlockingStub(channelA);
                    KvServiceGrpc.KvServiceBlockingStub clientC = KvServiceGrpc.newBlockingStub(channelC);

                    byte[] key = findKeyForOwner(map, "node-b");
                    byte[] value = "profile-v2".getBytes(StandardCharsets.UTF_8);

                    PutResponse put = clientA.put(
                        PutRequest.newBuilder().setKey(ByteString.copyFrom(key)).setValue(ByteString.copyFrom(value)).build()
                    );
                    assertFalse(put.hasError());

                    GetResponse get = clientC.get(GetRequest.newBuilder().setKey(ByteString.copyFrom(key)).build());
                    assertFalse(get.hasError());
                    assertTrue(get.getFound());
                    assertArrayEquals(value, get.getValue().toByteArray());

                    var delete = clientA.delete(DeleteRequest.newBuilder().setKey(ByteString.copyFrom(key)).build());
                    assertFalse(delete.hasError());

                    GetResponse postDelete = clientC.get(GetRequest.newBuilder().setKey(ByteString.copyFrom(key)).build());
                    assertFalse(postDelete.hasError());
                    assertFalse(postDelete.getFound());
                } finally {
                    shutdownChannel(channelA);
                    shutdownChannel(channelC);
                    shutdownServer(serverA);
                    shutdownServer(serverB);
                    shutdownServer(serverC);
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

    private static void shutdownChannel(ManagedChannel channel) throws InterruptedException {
        channel.shutdownNow();
        channel.awaitTermination(5, TimeUnit.SECONDS);
    }
}
