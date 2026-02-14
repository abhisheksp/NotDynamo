package io.notdynamo.controlplane;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.TreeSet;
import java.util.concurrent.ConcurrentHashMap;

public final class NodeMembershipService {
    private final Duration heartbeatTimeout;
    private final Clock clock;
    private final ConcurrentHashMap<String, Instant> heartbeatByNode = new ConcurrentHashMap<>();

    public NodeMembershipService(Duration heartbeatTimeout, Clock clock) {
        this.heartbeatTimeout = Objects.requireNonNull(heartbeatTimeout, "heartbeatTimeout must not be null");
        this.clock = Objects.requireNonNull(clock, "clock must not be null");
        if (heartbeatTimeout.isNegative() || heartbeatTimeout.isZero()) {
            throw new IllegalArgumentException("heartbeatTimeout must be > 0");
        }
    }

    public void heartbeat(String nodeId) {
        heartbeatByNode.put(validateNodeId(nodeId), clock.instant());
    }

    public boolean isAlive(String nodeId) {
        Instant lastHeartbeat = heartbeatByNode.get(validateNodeId(nodeId));
        if (lastHeartbeat == null) {
            return false;
        }

        Duration age = Duration.between(lastHeartbeat, clock.instant());
        return !age.isNegative() && age.compareTo(heartbeatTimeout) <= 0;
    }

    public Set<String> liveNodes() {
        Set<String> live = new TreeSet<>();
        for (Map.Entry<String, Instant> entry : heartbeatByNode.entrySet()) {
            Duration age = Duration.between(entry.getValue(), clock.instant());
            if (!age.isNegative() && age.compareTo(heartbeatTimeout) <= 0) {
                live.add(entry.getKey());
            }
        }
        return live;
    }

    public Map<String, Instant> snapshotHeartbeats() {
        return Map.copyOf(heartbeatByNode);
    }

    private static String validateNodeId(String nodeId) {
        if (nodeId == null || nodeId.isBlank()) {
            throw new IllegalArgumentException("nodeId must not be blank");
        }
        return nodeId;
    }
}
