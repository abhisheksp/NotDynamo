package io.notdynamo.node.http;

import com.google.protobuf.ByteString;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import io.grpc.stub.StreamObserver;
import io.notdynamo.node.KvServiceHandler;
import io.notdynamo.proto.v1.DeleteRequest;
import io.notdynamo.proto.v1.DeleteResponse;
import io.notdynamo.proto.v1.GetRequest;
import io.notdynamo.proto.v1.GetResponse;
import io.notdynamo.proto.v1.PutRequest;
import io.notdynamo.proto.v1.PutResponse;
import io.notdynamo.proto.v1.StatusCode;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.net.InetSocketAddress;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Objects;
import java.util.concurrent.Executors;

public final class HttpBridgeServer implements AutoCloseable {
    private static final String KV_PREFIX = "/v1/kv/";

    private final String nodeId;
    private final HttpServer server;
    private final KvServiceHandler kvService;

    private HttpBridgeServer(String nodeId, HttpServer server, KvServiceHandler kvService) {
        this.nodeId = Objects.requireNonNull(nodeId, "nodeId must not be null");
        this.server = Objects.requireNonNull(server, "server must not be null");
        this.kvService = Objects.requireNonNull(kvService, "kvService must not be null");
    }

    public static HttpBridgeServer open(String nodeId, int port, KvServiceHandler kvService) {
        try {
            HttpServer httpServer = HttpServer.create(new InetSocketAddress(port), 0);
            HttpBridgeServer bridge = new HttpBridgeServer(nodeId, httpServer, kvService);
            bridge.registerContexts();
            return bridge;
        } catch (IOException e) {
            throw new UncheckedIOException("failed to create HTTP bridge server", e);
        }
    }

    public void start() {
        server.setExecutor(Executors.newFixedThreadPool(Math.max(4, Runtime.getRuntime().availableProcessors())));
        server.start();
    }

    public int port() {
        return server.getAddress().getPort();
    }

    @Override
    public void close() {
        server.stop(2);
    }

    private void registerContexts() {
        server.createContext("/healthz", this::handleHealth);
        server.createContext(KV_PREFIX, this::handleKv);
    }

    private void handleHealth(HttpExchange exchange) throws IOException {
        if (!"GET".equalsIgnoreCase(exchange.getRequestMethod())) {
            sendJson(exchange, 405, "{\"error\":\"method_not_allowed\"}");
            return;
        }

        String response = "{\"nodeId\":\"" + escapeJson(nodeId) + "\",\"ready\":true}";
        sendJson(exchange, 200, response);
    }

    private void handleKv(HttpExchange exchange) throws IOException {
        String keyPath = extractKeyPath(exchange);
        if (keyPath == null) {
            sendJson(exchange, 400, "{\"error\":\"invalid_key_path\"}");
            return;
        }

        byte[] keyBytes;
        try {
            keyBytes = decodeKey(keyPath);
        } catch (IllegalArgumentException e) {
            sendJson(exchange, 400, errorJson("STATUS_CODE_INVALID_ARGUMENT", e.getMessage()));
            return;
        }

        switch (exchange.getRequestMethod().toUpperCase()) {
            case "GET" -> handleGet(exchange, keyBytes);
            case "PUT" -> handlePut(exchange, keyBytes);
            case "DELETE" -> handleDelete(exchange, keyBytes);
            default -> sendJson(exchange, 405, "{\"error\":\"method_not_allowed\"}");
        }
    }

    private void handleGet(HttpExchange exchange, byte[] keyBytes) throws IOException {
        ObserverCapture<GetResponse> capture = new ObserverCapture<>();
        kvService.get(GetRequest.newBuilder().setKey(ByteString.copyFrom(keyBytes)).build(), capture);

        GetResponse response = capture.value();
        if (response.hasError()) {
            sendJson(exchange, statusToHttp(response.getError().getCode()), errorJson(response.getError().getCode().name(), response.getError().getMessage()));
            return;
        }
        if (!response.getFound()) {
            String body = "{\"found\":false,\"version\":" + response.getVersion() + "}";
            sendJson(exchange, 404, body);
            return;
        }

        byte[] value = response.getValue().toByteArray();
        exchange.getResponseHeaders().set("Content-Type", "application/octet-stream");
        exchange.getResponseHeaders().set("X-NotDynamo-Version", String.valueOf(response.getVersion()));
        exchange.sendResponseHeaders(200, value.length);
        exchange.getResponseBody().write(value);
        exchange.close();
    }

    private void handlePut(HttpExchange exchange, byte[] keyBytes) throws IOException {
        byte[] value = exchange.getRequestBody().readAllBytes();

        ObserverCapture<PutResponse> capture = new ObserverCapture<>();
        kvService.put(
            PutRequest.newBuilder().setKey(ByteString.copyFrom(keyBytes)).setValue(ByteString.copyFrom(value)).build(),
            capture
        );

        PutResponse response = capture.value();
        if (response.hasError()) {
            sendJson(exchange, statusToHttp(response.getError().getCode()), errorJson(response.getError().getCode().name(), response.getError().getMessage()));
            return;
        }

        sendJson(exchange, 200, "{\"version\":" + response.getVersion() + "}");
    }

    private void handleDelete(HttpExchange exchange, byte[] keyBytes) throws IOException {
        ObserverCapture<DeleteResponse> capture = new ObserverCapture<>();
        kvService.delete(DeleteRequest.newBuilder().setKey(ByteString.copyFrom(keyBytes)).build(), capture);

        DeleteResponse response = capture.value();
        if (response.hasError()) {
            sendJson(exchange, statusToHttp(response.getError().getCode()), errorJson(response.getError().getCode().name(), response.getError().getMessage()));
            return;
        }

        sendJson(exchange, 200, "{\"version\":" + response.getVersion() + "}");
    }

    private static String extractKeyPath(HttpExchange exchange) {
        String path = exchange.getRequestURI().getPath();
        if (!path.startsWith(KV_PREFIX)) {
            return null;
        }

        String encoded = path.substring(KV_PREFIX.length());
        if (encoded.isBlank() || encoded.contains("/")) {
            return null;
        }
        return URLDecoder.decode(encoded, StandardCharsets.UTF_8);
    }

    private static byte[] decodeKey(String keyPath) {
        if (keyPath.startsWith("b64:")) {
            String encoded = keyPath.substring("b64:".length());
            if (encoded.isBlank()) {
                throw new IllegalArgumentException("b64 key payload must not be empty");
            }
            return Base64.getUrlDecoder().decode(encoded);
        }
        return keyPath.getBytes(StandardCharsets.UTF_8);
    }

    private static int statusToHttp(StatusCode statusCode) {
        return switch (statusCode) {
            case STATUS_CODE_INVALID_ARGUMENT -> 400;
            case STATUS_CODE_NOT_FOUND -> 404;
            case STATUS_CODE_UNAVAILABLE -> 503;
            case STATUS_CODE_TIMEOUT -> 504;
            default -> 500;
        };
    }

    private static String errorJson(String code, String message) {
        return "{\"error\":{\"code\":\"" + escapeJson(code) + "\",\"message\":\"" + escapeJson(message) + "\"}}";
    }

    private static void sendJson(HttpExchange exchange, int status, String payload) throws IOException {
        byte[] body = payload.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "application/json; charset=utf-8");
        exchange.sendResponseHeaders(status, body.length);
        exchange.getResponseBody().write(body);
        exchange.close();
    }

    private static String escapeJson(String value) {
        return value.replace("\\", "\\\\").replace("\"", "\\\"");
    }

    private static final class ObserverCapture<T> implements StreamObserver<T> {
        private T value;
        private Throwable error;

        @Override
        public void onNext(T value) {
            this.value = value;
        }

        @Override
        public void onError(Throwable throwable) {
            this.error = throwable;
        }

        @Override
        public void onCompleted() {
            // no-op
        }

        private T value() {
            if (error != null) {
                throw new IllegalStateException("handler invocation failed", error);
            }
            if (value == null) {
                throw new IllegalStateException("handler returned no response");
            }
            return value;
        }
    }
}
