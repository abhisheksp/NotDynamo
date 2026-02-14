package io.notdynamo.controlplane.lease;

import java.time.Clock;
import java.util.Objects;
import java.util.Optional;

public final class LeaseLeaderElector {
    private final String nodeId;
    private final long leaseDurationMillis;
    private final LeaderLeaseStore leaseStore;
    private final Clock clock;

    public LeaseLeaderElector(String nodeId, long leaseDurationMillis, LeaderLeaseStore leaseStore, Clock clock) {
        if (nodeId == null || nodeId.isBlank()) {
            throw new IllegalArgumentException("nodeId must not be blank");
        }
        if (leaseDurationMillis <= 0) {
            throw new IllegalArgumentException("leaseDurationMillis must be > 0");
        }

        this.nodeId = nodeId;
        this.leaseDurationMillis = leaseDurationMillis;
        this.leaseStore = Objects.requireNonNull(leaseStore, "leaseStore must not be null");
        this.clock = Objects.requireNonNull(clock, "clock must not be null");
    }

    public boolean tryAcquireOrRenew() {
        long now = clock.millis();
        Optional<LeaseRecord> existingOpt = leaseStore.current();

        if (existingOpt.isEmpty()) {
            LeaseRecord next = new LeaseRecord(nodeId, now, leaseDurationMillis, 0L);
            return leaseStore.compareAndSet(Optional.empty(), next);
        }

        LeaseRecord existing = existingOpt.get();
        boolean canTakeOver = existing.isExpiredAt(now) || existing.holderIdentity().equals(nodeId);
        if (!canTakeOver) {
            return false;
        }

        LeaseRecord next = new LeaseRecord(nodeId, now, leaseDurationMillis, existing.version() + 1);
        return leaseStore.compareAndSet(Optional.of(existing.version()), next);
    }

    public Optional<String> currentLeader() {
        return leaseStore.current().map(LeaseRecord::holderIdentity);
    }
}
