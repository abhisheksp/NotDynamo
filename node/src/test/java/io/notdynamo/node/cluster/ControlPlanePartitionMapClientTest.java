package io.notdynamo.node.cluster;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.sun.net.httpserver.HttpServer;
import io.notdynamo.controlplane.PartitionMapVersion;
import io.notdynamo.controlplane.ShardPartitionMap;
import io.notdynamo.controlplane.ShardPartitionMapJsonCodec;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import org.junit.jupiter.api.Test;

class ControlPlanePartitionMapClientTest {
    @Test
    void fetchesShardMetadataV2FromControlPlaneEndpoint() throws Exception {
        ShardPartitionMap map = ShardPartitionMap.roundRobin(
            new PartitionMapVersion(5),
            8,
            128,
            List.of("node-a", "node-b", "node-c"),
            3
        );
        String payload = ShardPartitionMapJsonCodec.toJson(map);

        try (TestHttpServer server = TestHttpServer.responding(200, payload)) {
            ControlPlanePartitionMapClient client = new ControlPlanePartitionMapClient(Duration.ofSeconds(1));
            ShardPartitionMap fetched = client.fetch(server.url("/v1/partition-map"));
            assertEquals(5L, fetched.version().epoch());
            assertEquals("shard-0", fetched.descriptorForShard(0).groupId());
            assertTrue(fetched.descriptorForShard(0).replicaNodeIds().contains(fetched.descriptorForShard(0).leaderNodeId()));
        }
    }

    @Test
    void throwsOnNonSuccessHttpStatus() throws Exception {
        try (TestHttpServer server = TestHttpServer.responding(503, "{\"error\":\"unavailable\"}")) {
            ControlPlanePartitionMapClient client = new ControlPlanePartitionMapClient(Duration.ofSeconds(1));
            assertThrows(IllegalStateException.class, () -> client.fetch(server.url("/v1/partition-map")));
        }
    }

    private static final class TestHttpServer implements AutoCloseable {
        private final HttpServer server;
        private final int port;

        private TestHttpServer(HttpServer server, int port) {
            this.server = server;
            this.port = port;
        }

        static TestHttpServer responding(int status, String body) throws IOException {
            HttpServer server = HttpServer.create(new InetSocketAddress(0), 0);
            byte[] payload = body.getBytes(StandardCharsets.UTF_8);
            server.createContext("/v1/partition-map", exchange -> {
                exchange.getResponseHeaders().set("Content-Type", "application/json");
                exchange.sendResponseHeaders(status, payload.length);
                exchange.getResponseBody().write(payload);
                exchange.close();
            });
            server.start();
            return new TestHttpServer(server, server.getAddress().getPort());
        }

        String url(String path) {
            return "http://127.0.0.1:" + port + path;
        }

        @Override
        public void close() {
            server.stop(0);
        }
    }
}
