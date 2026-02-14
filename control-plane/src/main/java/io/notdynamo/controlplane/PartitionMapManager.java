package io.notdynamo.controlplane;

import java.util.Map;
import java.util.Objects;
import java.util.concurrent.atomic.AtomicReference;

public final class PartitionMapManager {
    private final AtomicReference<ClusterPartitionMap> current;

    public PartitionMapManager(ClusterPartitionMap initialMap) {
        this.current = new AtomicReference<>(Objects.requireNonNull(initialMap, "initialMap must not be null"));
    }

    public ClusterPartitionMap current() {
        return current.get();
    }

    public boolean tryApply(ClusterPartitionMap candidate) {
        Objects.requireNonNull(candidate, "candidate must not be null");

        while (true) {
            ClusterPartitionMap existing = current.get();
            long expectedNextEpoch = existing.version().epoch() + 1;

            if (candidate.version().epoch() != expectedNextEpoch) {
                return false;
            }
            if (!sameLayout(existing, candidate)) {
                return false;
            }

            if (current.compareAndSet(existing, candidate)) {
                return true;
            }
        }
    }

    public ClusterPartitionMap next(Map<Integer, String> nextAssignments) {
        ClusterPartitionMap existing = current.get();
        return new ClusterPartitionMap(
            existing.version().next(),
            existing.shardCount(),
            existing.virtualNodesPerShard(),
            nextAssignments
        );
    }

    private static boolean sameLayout(ClusterPartitionMap left, ClusterPartitionMap right) {
        return left.shardCount() == right.shardCount()
            && left.virtualNodesPerShard() == right.virtualNodesPerShard();
    }
}
