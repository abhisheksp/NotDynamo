package io.notdynamo.controlplane.lease;

import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;

public final class InMemoryLeaderLeaseStore implements LeaderLeaseStore {
    private final AtomicReference<LeaseRecord> current = new AtomicReference<>();

    @Override
    public Optional<LeaseRecord> current() {
        return Optional.ofNullable(current.get());
    }

    @Override
    public boolean compareAndSet(Optional<Long> expectedVersion, LeaseRecord nextRecord) {
        LeaseRecord existing = current.get();
        if (expectedVersion.isEmpty()) {
            if (existing != null) {
                return false;
            }
            return current.compareAndSet(null, nextRecord);
        }

        if (existing == null) {
            return false;
        }
        if (existing.version() != expectedVersion.get()) {
            return false;
        }

        return current.compareAndSet(existing, nextRecord);
    }
}
