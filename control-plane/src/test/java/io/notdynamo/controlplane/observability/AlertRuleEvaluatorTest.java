package io.notdynamo.controlplane.observability;

import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import org.junit.jupiter.api.Test;

class AlertRuleEvaluatorTest {
    @Test
    void returnsExpectedAlertsForBreachedSloSignals() {
        AlertRuleEvaluator evaluator = new AlertRuleEvaluator(20.0, 1000.0, 5.0);

        List<String> alerts = evaluator.evaluate(new SloSnapshot(25.0, 1500.0, 7.0, false));

        assertTrue(alerts.contains("READ_P99_BREACH"));
        assertTrue(alerts.contains("REPLICATION_LAG_BREACH"));
        assertTrue(alerts.contains("ELECTION_CHURN_BREACH"));
        assertTrue(alerts.contains("AZ_UNHEALTHY"));
    }
}
