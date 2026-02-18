package io.notdynamo.node.cluster;

import io.notdynamo.controlplane.ShardPartitionMap;
import io.notdynamo.controlplane.ShardPartitionMapJsonCodec;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

public final class ControlPlanePartitionMapClient {
    private final HttpClient httpClient;
    private final Duration requestTimeout;

    public ControlPlanePartitionMapClient(Duration requestTimeout) {
        if (requestTimeout == null || requestTimeout.isNegative() || requestTimeout.isZero()) {
            throw new IllegalArgumentException("requestTimeout must be > 0");
        }
        this.requestTimeout = requestTimeout;
        this.httpClient = HttpClient.newBuilder().connectTimeout(requestTimeout).build();
    }

    public ShardPartitionMap fetch(String endpoint) {
        if (endpoint == null || endpoint.isBlank()) {
            throw new IllegalArgumentException("endpoint must not be blank");
        }
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(endpoint))
            .timeout(requestTimeout)
            .GET()
            .build();
        try {
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() != 200) {
                throw new IllegalStateException(
                    "control-plane partition map fetch failed: status="
                        + response.statusCode()
                        + " endpoint="
                        + endpoint
                );
            }
            return ShardPartitionMapJsonCodec.fromJson(response.body());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("interrupted while fetching control-plane partition map", e);
        } catch (IOException e) {
            throw new IllegalStateException("I/O error while fetching control-plane partition map", e);
        }
    }
}
