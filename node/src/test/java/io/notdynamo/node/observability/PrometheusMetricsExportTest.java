package io.notdynamo.node.observability;

import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class PrometheusMetricsExportTest {
    @Test
    void exportsCoreMetricSeries() {
        NodeMetrics metrics = new NodeMetrics();
        metrics.recordRequest("get", 3.5);
        metrics.recordRequest("put", 6.2);
        metrics.recordReplicationLag(12, 350);
        metrics.incrementElection();

        String output = metrics.toPrometheus();

        assertTrue(output.contains("notdynamo_requests_total{operation=\"get\"}"));
        assertTrue(output.contains("notdynamo_requests_total{operation=\"put\"}"));
        assertTrue(output.contains("notdynamo_request_latency_ms_max{operation=\"get\"}"));
        assertTrue(output.contains("notdynamo_replication_lag_ms{shard=\"12\"}"));
        assertTrue(output.contains("notdynamo_elections_total"));
    }
}
