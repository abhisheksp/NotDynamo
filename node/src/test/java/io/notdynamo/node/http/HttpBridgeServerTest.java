package io.notdynamo.node.http;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import io.notdynamo.node.KvServiceHandler;
import io.notdynamo.storage.RocksDbKeyValueStore;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class HttpBridgeServerTest {
    @TempDir
    Path tempDir;

    @Test
    void putGetDeleteRoundTripOverHttp() throws Exception {
        String key = "demo-key";
        byte[] value = "hello-http-bridge".getBytes(StandardCharsets.UTF_8);

        try (RocksDbKeyValueStore store = RocksDbKeyValueStore.open(tempDir.resolve("db"))) {
            KvServiceHandler kvService = new KvServiceHandler(store);
            try (HttpBridgeServer bridge = HttpBridgeServer.open("node-test", 0, kvService)) {
                bridge.start();
                String baseUrl = "http://127.0.0.1:" + bridge.port();
                HttpClient client = HttpClient.newHttpClient();

                HttpResponse<String> putResponse = client.send(
                    request(baseUrl, "PUT", "/v1/kv/" + urlEncode(key), value),
                    HttpResponse.BodyHandlers.ofString()
                );
                assertEquals(200, putResponse.statusCode());
                assertTrue(putResponse.body().contains("\"version\":1"));

                HttpResponse<byte[]> getResponse = client.send(
                    request(baseUrl, "GET", "/v1/kv/" + urlEncode(key), null),
                    HttpResponse.BodyHandlers.ofByteArray()
                );
                assertEquals(200, getResponse.statusCode());
                assertEquals("1", getResponse.headers().firstValue("X-NotDynamo-Version").orElseThrow());
                assertEquals("hello-http-bridge", new String(getResponse.body(), StandardCharsets.UTF_8));

                HttpResponse<String> deleteResponse = client.send(
                    request(baseUrl, "DELETE", "/v1/kv/" + urlEncode(key), null),
                    HttpResponse.BodyHandlers.ofString()
                );
                assertEquals(200, deleteResponse.statusCode());
                assertTrue(deleteResponse.body().contains("\"version\":2"));

                HttpResponse<String> postDelete = client.send(
                    request(baseUrl, "GET", "/v1/kv/" + urlEncode(key), null),
                    HttpResponse.BodyHandlers.ofString()
                );
                assertEquals(404, postDelete.statusCode());
                assertTrue(postDelete.body().contains("\"found\":false"));
            }
        }
    }

    @Test
    void exposesHealthEndpoint() throws Exception {
        try (RocksDbKeyValueStore store = RocksDbKeyValueStore.open(tempDir.resolve("db-health"))) {
            KvServiceHandler kvService = new KvServiceHandler(store);
            try (HttpBridgeServer bridge = HttpBridgeServer.open("node-health", 0, kvService)) {
                bridge.start();
                HttpClient client = HttpClient.newHttpClient();

                HttpResponse<String> response = client.send(
                    request("http://127.0.0.1:" + bridge.port(), "GET", "/healthz", null),
                    HttpResponse.BodyHandlers.ofString()
                );

                assertEquals(200, response.statusCode());
                assertTrue(response.body().contains("\"nodeId\":\"node-health\""));
                assertTrue(response.body().contains("\"ready\":true"));
            }
        }
    }

    private static HttpRequest request(String baseUrl, String method, String path, byte[] body) {
        HttpRequest.Builder builder = HttpRequest.newBuilder(URI.create(baseUrl + path));
        if (body == null) {
            builder.method(method, HttpRequest.BodyPublishers.noBody());
        } else {
            builder.method(method, HttpRequest.BodyPublishers.ofByteArray(body));
        }
        return builder.build();
    }

    private static String urlEncode(String value) {
        return URLEncoder.encode(value, StandardCharsets.UTF_8);
    }
}
