package io.notdynamo.controlplane.rebalance;

import io.notdynamo.controlplane.ClusterPartitionMap;
import io.notdynamo.controlplane.PartitionMapVersion;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

public final class RebalancePlan {
    private final List<ShardMove> moves;

    public RebalancePlan(List<ShardMove> moves) {
        Objects.requireNonNull(moves, "moves must not be null");
        this.moves = Collections.unmodifiableList(new ArrayList<>(moves));
    }

    public static RebalancePlan empty() {
        return new RebalancePlan(List.of());
    }

    public List<ShardMove> moves() {
        return moves;
    }

    public boolean isEmpty() {
        return moves.isEmpty();
    }

    public ClusterPartitionMap apply(ClusterPartitionMap baseMap, PartitionMapVersion nextVersion) {
        Objects.requireNonNull(baseMap, "baseMap must not be null");
        Objects.requireNonNull(nextVersion, "nextVersion must not be null");

        Map<Integer, String> assignments = new LinkedHashMap<>(baseMap.shardToNodeId());
        for (ShardMove move : moves) {
            String currentOwner = assignments.get(move.shardId());
            if (!move.sourceNodeId().equals(currentOwner)) {
                throw new IllegalStateException(
                    "shard " + move.shardId() + " owner mismatch during apply: expected "
                        + move.sourceNodeId() + " but found " + currentOwner
                );
            }
            assignments.put(move.shardId(), move.targetNodeId());
        }

        return new ClusterPartitionMap(nextVersion, baseMap.shardCount(), baseMap.virtualNodesPerShard(), assignments);
    }
}
