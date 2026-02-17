package io.notdynamo.controlplane;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.net.ServerSocket;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;

class ControlPlaneMainIT {
    @Test
    void servesHealthAndPartitionMapEndpoints() throws Exception {
        int port = freePort();
        Process process = startControlPlaneProcess(port);

        try {
            waitUntilHealthy(port, Duration.ofSeconds(20));

            HttpClient client = HttpClient.newHttpClient();
            HttpResponse<String> health = client.send(
                HttpRequest.newBuilder().uri(URI.create("http://127.0.0.1:" + port + "/healthz")).GET().build(),
                HttpResponse.BodyHandlers.ofString()
            );
            assertEquals(200, health.statusCode());
            assertTrue(health.body().contains("\"ready\":true"));

            HttpResponse<String> partitionMap = client.send(
                HttpRequest.newBuilder().uri(URI.create("http://127.0.0.1:" + port + "/v1/partition-map")).GET().build(),
                HttpResponse.BodyHandlers.ofString()
            );
            assertEquals(200, partitionMap.statusCode());
            assertTrue(partitionMap.body().contains("\"shardCount\":16"));
            assertTrue(partitionMap.body().contains("\"virtualNodesPerShard\":32"));
        } finally {
            process.destroy();
            if (!process.waitFor(5, TimeUnit.SECONDS)) {
                process.destroyForcibly();
                process.waitFor(5, TimeUnit.SECONDS);
            }
        }
    }

    private static Process startControlPlaneProcess(int port) throws IOException {
        String javaBin = javaBin();
        String classpath = System.getProperty("java.class.path");

        ProcessBuilder builder = new ProcessBuilder(
            javaBin,
            "-cp",
            classpath,
            "io.notdynamo.controlplane.ControlPlaneMain"
        );

        Map<String, String> env = builder.environment();
        env.put("NOTDYNAMO_CONTROL_PLANE_PORT", String.valueOf(port));
        env.put("NOTDYNAMO_SHARD_COUNT", "16");
        env.put("NOTDYNAMO_VIRTUAL_NODES_PER_SHARD", "32");
        env.put("NOTDYNAMO_CLUSTER_NODE_IDS", "node-a,node-b,node-c");

        return builder.redirectErrorStream(true).start();
    }

    private static void waitUntilHealthy(int port, Duration timeout) throws Exception {
        HttpClient client = HttpClient.newHttpClient();
        long deadlineNanos = System.nanoTime() + timeout.toNanos();
        while (System.nanoTime() < deadlineNanos) {
            try {
                HttpResponse<String> response = client.send(
                    HttpRequest.newBuilder().uri(URI.create("http://127.0.0.1:" + port + "/healthz")).GET().build(),
                    HttpResponse.BodyHandlers.ofString()
                );
                if (response.statusCode() == 200) {
                    return;
                }
            } catch (IOException ignored) {
                // process may still be starting
            }
            Thread.sleep(200);
        }
        throw new IllegalStateException("control-plane health endpoint did not become ready");
    }

    private static int freePort() throws IOException {
        try (ServerSocket socket = new ServerSocket(0)) {
            socket.setReuseAddress(true);
            return socket.getLocalPort();
        }
    }

    private static String javaBin() {
        return System.getProperty("java.home") + "/bin/java";
    }
}
