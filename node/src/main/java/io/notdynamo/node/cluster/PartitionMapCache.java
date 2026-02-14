package io.notdynamo.node.cluster;

import io.notdynamo.controlplane.ClusterPartitionMap;
import java.util.Objects;
import java.util.concurrent.atomic.AtomicReference;

public final class PartitionMapCache {
    private final AtomicReference<ClusterPartitionMap> current;

    public PartitionMapCache(ClusterPartitionMap initialMap) {
        this.current = new AtomicReference<>(Objects.requireNonNull(initialMap, "initialMap must not be null"));
    }

    public ClusterPartitionMap current() {
        return current.get();
    }

    public boolean tryApply(ClusterPartitionMap candidate) {
        Objects.requireNonNull(candidate, "candidate must not be null");

        while (true) {
            ClusterPartitionMap existing = current.get();
            if (candidate.version().epoch() <= existing.version().epoch()) {
                return false;
            }
            if (candidate.shardCount() != existing.shardCount()) {
                return false;
            }
            if (candidate.virtualNodesPerShard() != existing.virtualNodesPerShard()) {
                return false;
            }

            if (current.compareAndSet(existing, candidate)) {
                return true;
            }
        }
    }
}
