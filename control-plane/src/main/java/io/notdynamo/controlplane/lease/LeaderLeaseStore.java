package io.notdynamo.controlplane.lease;

import java.util.Optional;

public interface LeaderLeaseStore {
    Optional<LeaseRecord> current();

    boolean compareAndSet(Optional<Long> expectedVersion, LeaseRecord nextRecord);
}
