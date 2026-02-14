package io.notdynamo.node.observability;

import java.util.Map;
import java.util.Objects;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.DoubleAccumulator;
import java.util.concurrent.atomic.LongAdder;

public final class NodeMetrics {
    private final ConcurrentHashMap<String, LongAdder> requestCount = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, DoubleAccumulator> maxLatencyByOperation = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<Integer, LongAdder> replicationLagByShard = new ConcurrentHashMap<>();
    private final LongAdder electionCount = new LongAdder();

    public void recordRequest(String operation, double latencyMillis) {
        validateOperation(operation);
        if (latencyMillis < 0) {
            throw new IllegalArgumentException("latencyMillis must be >= 0");
        }

        requestCount.computeIfAbsent(operation, ignored -> new LongAdder()).increment();
        maxLatencyByOperation.computeIfAbsent(operation, ignored -> new DoubleAccumulator(Double::max, 0.0)).accumulate(latencyMillis);
    }

    public void recordReplicationLag(int shardId, long lagMillis) {
        if (shardId < 0) {
            throw new IllegalArgumentException("shardId must be >= 0");
        }
        if (lagMillis < 0) {
            throw new IllegalArgumentException("lagMillis must be >= 0");
        }

        replicationLagByShard.computeIfAbsent(shardId, ignored -> new LongAdder());
        LongAdder lag = replicationLagByShard.get(shardId);
        lag.reset();
        lag.add(lagMillis);
    }

    public void incrementElection() {
        electionCount.increment();
    }

    public String toPrometheus() {
        StringBuilder out = new StringBuilder();

        for (Map.Entry<String, LongAdder> entry : requestCount.entrySet()) {
            out.append("notdynamo_requests_total{operation=\"")
                .append(entry.getKey())
                .append("\"} ")
                .append(entry.getValue().sum())
                .append('\n');
        }

        for (Map.Entry<String, DoubleAccumulator> entry : maxLatencyByOperation.entrySet()) {
            out.append("notdynamo_request_latency_ms_max{operation=\"")
                .append(entry.getKey())
                .append("\"} ")
                .append(entry.getValue().get())
                .append('\n');
        }

        for (Map.Entry<Integer, LongAdder> entry : replicationLagByShard.entrySet()) {
            out.append("notdynamo_replication_lag_ms{shard=\"")
                .append(entry.getKey())
                .append("\"} ")
                .append(entry.getValue().sum())
                .append('\n');
        }

        out.append("notdynamo_elections_total ").append(electionCount.sum()).append('\n');
        return out.toString();
    }

    private static void validateOperation(String operation) {
        Objects.requireNonNull(operation, "operation must not be null");
        if (operation.isBlank()) {
            throw new IllegalArgumentException("operation must not be blank");
        }
    }
}
