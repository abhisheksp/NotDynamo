package io.notdynamo.controlplane.observability;

import java.util.ArrayList;
import java.util.List;

public final class AlertRuleEvaluator {
    private final double readP99ThresholdMillis;
    private final double lagP99ThresholdMillis;
    private final double electionRateThreshold;

    public AlertRuleEvaluator(double readP99ThresholdMillis, double lagP99ThresholdMillis, double electionRateThreshold) {
        if (readP99ThresholdMillis <= 0 || lagP99ThresholdMillis <= 0 || electionRateThreshold <= 0) {
            throw new IllegalArgumentException("all thresholds must be > 0");
        }

        this.readP99ThresholdMillis = readP99ThresholdMillis;
        this.lagP99ThresholdMillis = lagP99ThresholdMillis;
        this.electionRateThreshold = electionRateThreshold;
    }

    public List<String> evaluate(SloSnapshot snapshot) {
        List<String> alerts = new ArrayList<>();
        if (snapshot.readP99Millis() > readP99ThresholdMillis) {
            alerts.add("READ_P99_BREACH");
        }
        if (snapshot.replicationLagP99Millis() > lagP99ThresholdMillis) {
            alerts.add("REPLICATION_LAG_BREACH");
        }
        if (snapshot.electionRatePerMinute() > electionRateThreshold) {
            alerts.add("ELECTION_CHURN_BREACH");
        }
        if (!snapshot.azHealthy()) {
            alerts.add("AZ_UNHEALTHY");
        }
        return alerts;
    }
}
