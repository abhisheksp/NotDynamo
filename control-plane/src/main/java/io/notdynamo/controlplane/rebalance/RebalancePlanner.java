package io.notdynamo.controlplane.rebalance;

import io.notdynamo.controlplane.ClusterPartitionMap;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.TreeSet;

public final class RebalancePlanner {
    public RebalancePlan plan(ClusterPartitionMap map, Set<String> liveNodes, int maxMoves) {
        Objects.requireNonNull(map, "map must not be null");
        Objects.requireNonNull(liveNodes, "liveNodes must not be null");

        if (liveNodes.isEmpty()) {
            throw new IllegalArgumentException("liveNodes must not be empty");
        }
        if (maxMoves < 0) {
            throw new IllegalArgumentException("maxMoves must be >= 0");
        }
        if (maxMoves == 0) {
            return RebalancePlan.empty();
        }

        Set<String> normalizedLiveNodes = new TreeSet<>();
        for (String nodeId : liveNodes) {
            if (nodeId == null || nodeId.isBlank()) {
                throw new IllegalArgumentException("liveNodes must not contain null/blank IDs");
            }
            normalizedLiveNodes.add(nodeId);
        }

        Map<Integer, String> workingAssignments = new HashMap<>(map.shardToNodeId());
        Map<String, Integer> counts = new HashMap<>();
        for (String nodeId : normalizedLiveNodes) {
            counts.put(nodeId, 0);
        }

        List<Integer> strandedShards = new ArrayList<>();
        for (int shard = 0; shard < map.shardCount(); shard++) {
            String owner = workingAssignments.get(shard);
            if (normalizedLiveNodes.contains(owner)) {
                counts.put(owner, counts.get(owner) + 1);
            } else {
                strandedShards.add(shard);
            }
        }
        strandedShards.sort(Integer::compareTo);

        List<ShardMove> moves = new ArrayList<>();
        Set<Integer> movedShards = new HashSet<>();

        for (int shard : strandedShards) {
            if (moves.size() >= maxMoves) {
                break;
            }

            String source = workingAssignments.get(shard);
            String target = leastLoadedNode(counts, normalizedLiveNodes);
            moves.add(new ShardMove(shard, source, target));
            movedShards.add(shard);
            workingAssignments.put(shard, target);
            counts.put(target, counts.get(target) + 1);
        }

        while (moves.size() < maxMoves) {
            String source = mostLoadedNode(counts, normalizedLiveNodes);
            String target = leastLoadedNode(counts, normalizedLiveNodes);

            int sourceCount = counts.get(source);
            int targetCount = counts.get(target);
            if (sourceCount - targetCount <= 1) {
                break;
            }

            Integer shardToMove = findShardOwnedBy(workingAssignments, source, movedShards);
            if (shardToMove == null) {
                break;
            }

            moves.add(new ShardMove(shardToMove, source, target));
            movedShards.add(shardToMove);
            workingAssignments.put(shardToMove, target);
            counts.put(source, sourceCount - 1);
            counts.put(target, targetCount + 1);
        }

        return new RebalancePlan(moves);
    }

    private static String mostLoadedNode(Map<String, Integer> counts, Set<String> nodes) {
        return nodes.stream()
            .max(
                Comparator.<String, Integer>comparing(counts::get)
                    .thenComparing(Comparator.naturalOrder())
            )
            .orElseThrow();
    }

    private static String leastLoadedNode(Map<String, Integer> counts, Set<String> nodes) {
        return nodes.stream()
            .min(
                Comparator.<String, Integer>comparing(counts::get)
                    .thenComparing(Comparator.naturalOrder())
            )
            .orElseThrow();
    }

    private static Integer findShardOwnedBy(Map<Integer, String> assignments, String nodeId, Set<Integer> excludedShards) {
        return assignments.entrySet().stream()
            .filter(entry -> entry.getValue().equals(nodeId))
            .filter(entry -> !excludedShards.contains(entry.getKey()))
            .map(Map.Entry::getKey)
            .min(Integer::compareTo)
            .orElse(null);
    }
}
