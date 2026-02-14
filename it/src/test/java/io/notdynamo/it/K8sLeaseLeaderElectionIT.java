package io.notdynamo.it;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import io.notdynamo.controlplane.lease.InMemoryLeaderLeaseStore;
import io.notdynamo.controlplane.lease.LeaseLeaderElector;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import org.junit.jupiter.api.Test;

class K8sLeaseLeaderElectionIT {
    @Test
    void leaseLeadershipTransfersAfterExpiration() {
        MutableClock clock = new MutableClock(Instant.parse("2026-01-01T00:00:00Z"));
        InMemoryLeaderLeaseStore store = new InMemoryLeaderLeaseStore();

        LeaseLeaderElector nodeA = new LeaseLeaderElector("node-a", 5000L, store, clock);
        LeaseLeaderElector nodeB = new LeaseLeaderElector("node-b", 5000L, store, clock);

        assertTrue(nodeA.tryAcquireOrRenew());
        assertEquals("node-a", nodeA.currentLeader().orElseThrow());
        assertFalse(nodeB.tryAcquireOrRenew());

        clock.advance(Duration.ofSeconds(6));
        assertTrue(nodeB.tryAcquireOrRenew());
        assertEquals("node-b", nodeB.currentLeader().orElseThrow());
    }

    private static final class MutableClock extends Clock {
        private Instant instant;

        private MutableClock(Instant instant) {
            this.instant = instant;
        }

        @Override
        public ZoneId getZone() {
            return ZoneId.of("UTC");
        }

        @Override
        public Clock withZone(ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return instant;
        }

        void advance(Duration duration) {
            instant = instant.plus(duration);
        }
    }
}
