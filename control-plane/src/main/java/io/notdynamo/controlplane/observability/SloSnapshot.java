package io.notdynamo.controlplane.observability;

public record SloSnapshot(double readP99Millis, double replicationLagP99Millis, double electionRatePerMinute, boolean azHealthy) {
    public SloSnapshot {
        if (readP99Millis < 0) {
            throw new IllegalArgumentException("readP99Millis must be >= 0");
        }
        if (replicationLagP99Millis < 0) {
            throw new IllegalArgumentException("replicationLagP99Millis must be >= 0");
        }
        if (electionRatePerMinute < 0) {
            throw new IllegalArgumentException("electionRatePerMinute must be >= 0");
        }
    }
}
