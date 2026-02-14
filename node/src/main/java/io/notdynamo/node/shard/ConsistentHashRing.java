package io.notdynamo.node.shard;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.Collections;
import java.util.Comparator;
import java.util.Map;
import java.util.NavigableMap;
import java.util.Objects;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;

public final class ConsistentHashRing {
    private static final Comparator<Long> UNSIGNED_LONG_ORDER = Long::compareUnsigned;

    private final NavigableMap<Long, Integer> tokenToShard;
    private final Set<Integer> shardIds;
    private final int virtualNodesPerShard;

    private ConsistentHashRing(NavigableMap<Long, Integer> tokenToShard, int virtualNodesPerShard) {
        if (tokenToShard.isEmpty()) {
            throw new IllegalArgumentException("tokenToShard must not be empty");
        }
        if (virtualNodesPerShard <= 0) {
            throw new IllegalArgumentException("virtualNodesPerShard must be > 0");
        }

        TreeMap<Long, Integer> ordered = new TreeMap<>(UNSIGNED_LONG_ORDER);
        ordered.putAll(tokenToShard);
        this.tokenToShard = Collections.unmodifiableNavigableMap(ordered);
        this.shardIds = Collections.unmodifiableSet(new TreeSet<>(tokenToShard.values()));
        this.virtualNodesPerShard = virtualNodesPerShard;
    }

    public static ConsistentHashRing create(Set<Integer> shardIds, int virtualNodesPerShard) {
        Objects.requireNonNull(shardIds, "shardIds must not be null");
        if (shardIds.isEmpty()) {
            throw new IllegalArgumentException("shardIds must not be empty");
        }
        if (virtualNodesPerShard <= 0) {
            throw new IllegalArgumentException("virtualNodesPerShard must be > 0");
        }

        NavigableMap<Long, Integer> tokenMap = new TreeMap<>(UNSIGNED_LONG_ORDER);
        Set<Integer> sortedShards = new TreeSet<>(shardIds);

        for (int shardId : sortedShards) {
            for (int vnode = 0; vnode < virtualNodesPerShard; vnode++) {
                long token = vnodeToken(shardId, vnode);
                while (tokenMap.containsKey(token)) {
                    token += 1L;
                }
                tokenMap.put(token, shardId);
            }
        }

        return new ConsistentHashRing(tokenMap, virtualNodesPerShard);
    }

    public static ConsistentHashRing deserialize(String serialized) {
        Objects.requireNonNull(serialized, "serialized must not be null");

        String[] lines = serialized.split("\\R");
        if (lines.length < 2 || !lines[0].startsWith("vnodes=")) {
            throw new IllegalArgumentException("invalid ring serialization header");
        }

        int virtualNodesPerShard;
        try {
            virtualNodesPerShard = Integer.parseInt(lines[0].substring("vnodes=".length()));
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("invalid virtual node count", e);
        }

        NavigableMap<Long, Integer> tokenMap = new TreeMap<>(UNSIGNED_LONG_ORDER);
        for (int i = 1; i < lines.length; i++) {
            String line = lines[i].trim();
            if (line.isEmpty()) {
                continue;
            }

            String[] parts = line.split(",", 2);
            if (parts.length != 2) {
                throw new IllegalArgumentException("invalid token line: " + line);
            }

            long token;
            int shard;
            try {
                token = Long.parseUnsignedLong(parts[0]);
                shard = Integer.parseInt(parts[1]);
            } catch (NumberFormatException e) {
                throw new IllegalArgumentException("invalid token line: " + line, e);
            }
            tokenMap.put(token, shard);
        }

        return new ConsistentHashRing(tokenMap, virtualNodesPerShard);
    }

    public int shardForKey(byte[] key) {
        validateKey(key);
        long keyHash = Hashing.hash64(key);
        Map.Entry<Long, Integer> entry = tokenToShard.ceilingEntry(keyHash);
        if (entry == null) {
            entry = tokenToShard.firstEntry();
        }
        return entry.getValue();
    }

    public String serialize() {
        StringBuilder out = new StringBuilder();
        out.append("vnodes=").append(virtualNodesPerShard).append('\n');
        for (Map.Entry<Long, Integer> entry : tokenToShard.entrySet()) {
            out.append(Long.toUnsignedString(entry.getKey())).append(',').append(entry.getValue()).append('\n');
        }
        return out.toString();
    }

    public int virtualNodesPerShard() {
        return virtualNodesPerShard;
    }

    public int tokenCount() {
        return tokenToShard.size();
    }

    public Set<Integer> shardIds() {
        return shardIds;
    }

    private static long vnodeToken(int shardId, int vnode) {
        byte[] input = ByteBuffer.allocate(Integer.BYTES * 2)
            .order(ByteOrder.BIG_ENDIAN)
            .putInt(shardId)
            .putInt(vnode)
            .array();
        return Hashing.hash64(input);
    }

    private static void validateKey(byte[] key) {
        Objects.requireNonNull(key, "key must not be null");
        if (key.length == 0) {
            throw new IllegalArgumentException("key must not be empty");
        }
    }
}
