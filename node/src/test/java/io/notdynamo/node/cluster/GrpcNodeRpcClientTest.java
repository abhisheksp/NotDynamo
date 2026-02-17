package io.notdynamo.node.cluster;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.google.protobuf.ByteString;
import io.grpc.Server;
import io.grpc.netty.shaded.io.grpc.netty.NettyServerBuilder;
import io.notdynamo.node.NodeConfig;
import io.notdynamo.node.NodeServer;
import io.notdynamo.proto.v1.DeleteRequest;
import io.notdynamo.proto.v1.GetRequest;
import io.notdynamo.proto.v1.GetResponse;
import io.notdynamo.proto.v1.PutRequest;
import io.notdynamo.proto.v1.PutResponse;
import io.notdynamo.proto.v1.StatusCode;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class GrpcNodeRpcClientTest {
    @TempDir
    Path tempDir;

    @Test
    void forwardsKvOperationsToRemoteNode() throws Exception {
        NodeConfig config = new NodeConfig("node-a", "127.0.0.1", 9090, 8080, tempDir.resolve("node-a"));

        try (NodeServer node = NodeServer.openSharded(config, 32, 64)) {
            Server grpcServer = NettyServerBuilder.forPort(0).addService(node.kvService()).build().start();
            int port = grpcServer.getPort();

            try (GrpcNodeRpcClient rpc = new GrpcNodeRpcClient(ignored -> "127.0.0.1:" + port, 1000)) {
                byte[] key = "user:1".getBytes(StandardCharsets.UTF_8);
                byte[] value = "v1".getBytes(StandardCharsets.UTF_8);

                PutResponse put = rpc.put(
                    "node-a",
                    PutRequest.newBuilder().setKey(ByteString.copyFrom(key)).setValue(ByteString.copyFrom(value)).build()
                );
                assertFalse(put.hasError());
                assertEquals(1L, put.getVersion());

                GetResponse get = rpc.get("node-a", GetRequest.newBuilder().setKey(ByteString.copyFrom(key)).build());
                assertFalse(get.hasError());
                assertTrue(get.getFound());
                assertArrayEquals(value, get.getValue().toByteArray());
                assertEquals(1L, get.getVersion());

                var delete = rpc.delete("node-a", DeleteRequest.newBuilder().setKey(ByteString.copyFrom(key)).build());
                assertFalse(delete.hasError());
                assertEquals(2L, delete.getVersion());
            } finally {
                grpcServer.shutdownNow();
                grpcServer.awaitTermination(5, TimeUnit.SECONDS);
            }
        }
    }

    @Test
    void returnsUnavailableWhenRemoteNodeCannotBeReached() {
        try (GrpcNodeRpcClient rpc = new GrpcNodeRpcClient(ignored -> "127.0.0.1:1", 150)) {
            PutResponse put = rpc.put(
                "missing-node",
                PutRequest.newBuilder()
                    .setKey(ByteString.copyFromUtf8("k"))
                    .setValue(ByteString.copyFromUtf8("v"))
                    .build()
            );

            assertTrue(put.hasError());
            assertEquals(StatusCode.STATUS_CODE_UNAVAILABLE, put.getError().getCode());
        }
    }
}
