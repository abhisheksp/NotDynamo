package io.notdynamo.controlplane.rebalance;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class RebalanceThrottlerTest {
    @Test
    void pausesMovesWhenP99BreachesThreshold() {
        RebalanceThrottler throttler = new RebalanceThrottler(20.0);

        assertTrue(throttler.allowMove(19.5));
        assertTrue(throttler.allowMove(20.0));
        assertFalse(throttler.allowMove(20.1));
    }
}
