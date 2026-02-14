package io.notdynamo.controlplane;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import org.junit.jupiter.api.Test;

class MembershipTest {
    @Test
    void nodeLivenessTracksHeartbeatTimeout() {
        MutableClock clock = new MutableClock(Instant.parse("2026-01-01T00:00:00Z"));
        NodeMembershipService membership = new NodeMembershipService(Duration.ofSeconds(5), clock);

        membership.heartbeat("node-a");
        membership.heartbeat("node-b");

        assertTrue(membership.isAlive("node-a"));
        assertTrue(membership.isAlive("node-b"));

        clock.advance(Duration.ofSeconds(3));
        membership.heartbeat("node-a");

        clock.advance(Duration.ofSeconds(3));
        assertTrue(membership.isAlive("node-a"));
        assertFalse(membership.isAlive("node-b"));
        assertTrue(membership.liveNodes().contains("node-a"));
        assertFalse(membership.liveNodes().contains("node-b"));
    }

    private static final class MutableClock extends Clock {
        private Instant instant;

        private MutableClock(Instant initial) {
            this.instant = initial;
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
