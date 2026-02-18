package io.notdynamo.controlplane;

import java.util.Map;
import java.util.Objects;
import java.util.concurrent.atomic.AtomicReference;

public final class ShardPartitionMapManager {
    private final AtomicReference<ShardPartitionMap> current;

    public ShardPartitionMapManager(ShardPartitionMap initial) {
        this.current = new AtomicReference<>(Objects.requireNonNull(initial, "initial must not be null"));
    }

    public ShardPartitionMap current() {
        return current.get();
    }

    public boolean tryApply(ShardPartitionMap candidate) {
        Objects.requireNonNull(candidate, "candidate must not be null");

        while (true) {
            ShardPartitionMap existing = current.get();
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

    public ShardPartitionMap next(Map<Integer, String> nextLeaders) {
        ShardPartitionMap existing = current.get();
        return existing.withLeaderAssignments(nextLeaders, existing.version().next());
    }

    private static boolean sameLayout(ShardPartitionMap left, ShardPartitionMap right) {
        return left.shardCount() == right.shardCount()
            && left.virtualNodesPerShard() == right.virtualNodesPerShard();
    }
}
