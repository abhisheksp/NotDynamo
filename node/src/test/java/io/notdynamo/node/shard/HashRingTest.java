package io.notdynamo.node.shard;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.HashSet;
import java.util.Set;
import org.junit.jupiter.api.Test;

class HashRingTest {
    @Test
    void serializationRoundTripPreservesDeterministicLookup() {
        ConsistentHashRing ring = ConsistentHashRing.create(shardRange(128), 256);
        String serialized = ring.serialize();
        ConsistentHashRing restored = ConsistentHashRing.deserialize(serialized);

        byte[] key = new byte[8];
        for (long i = 0; i < 1_000_000L; i++) {
            writeLongBigEndian(key, i);
            assertEquals(ring.shardForKey(key), restored.shardForKey(key));
        }

        assertEquals(serialized, restored.serialize());
        assertEquals(ring.tokenCount(), restored.tokenCount());
    }

    @Test
    void distributionStaysWithinReasonableSkew() {
        int sampleSize = sampleSize();
        int shardCount = 128;
        ConsistentHashRing ring = ConsistentHashRing.create(shardRange(shardCount), 256);

        long[] counts = new long[shardCount];
        byte[] key = new byte[8];

        for (long i = 0; i < sampleSize; i++) {
            writeLongBigEndian(key, i);
            int shardId = ring.shardForKey(key);
            counts[shardId] += 1;
        }

        double mean = (double) sampleSize / shardCount;
        double maxDeviation = 0.0;
        long minCount = Long.MAX_VALUE;
        long maxCount = Long.MIN_VALUE;
        for (long count : counts) {
            double deviation = Math.abs(count - mean) / mean;
            maxDeviation = Math.max(maxDeviation, deviation);
            minCount = Math.min(minCount, count);
            maxCount = Math.max(maxCount, count);
        }

        // 20% is a generous upper-bound for a practical vnode-based ring balance check.
        assertTrue(
            maxDeviation <= 0.20,
            "max deviation="
                + maxDeviation
                + " sampleSize="
                + sampleSize
                + " minCount="
                + minCount
                + " maxCount="
                + maxCount
        );
    }

    @Test
    void keyRemapRatioTracksMembershipChange() {
        int sampleSize = sampleSize();

        ConsistentHashRing baseline = ConsistentHashRing.create(shardRange(128), 256);
        ConsistentHashRing expanded = ConsistentHashRing.create(shardRange(144), 256);

        int moved = 0;
        byte[] key = new byte[8];

        for (long i = 0; i < sampleSize; i++) {
            writeLongBigEndian(key, i);
            if (baseline.shardForKey(key) != expanded.shardForKey(key)) {
                moved += 1;
            }
        }

        double remapRatio = moved / (double) sampleSize;
        double expected = 16.0 / 144.0;
        assertTrue(remapRatio >= 0.07, "remap ratio too low: " + remapRatio);
        assertTrue(remapRatio <= 0.15, "remap ratio too high: " + remapRatio);
        assertTrue(Math.abs(remapRatio - expected) <= 0.04, "remap ratio drifted from expectation: " + remapRatio);
    }

    private static Set<Integer> shardRange(int count) {
        Set<Integer> shards = new HashSet<>();
        for (int shard = 0; shard < count; shard++) {
            shards.add(shard);
        }
        return shards;
    }

    private static int sampleSize() {
        int configured = Integer.getInteger("notdynamo.ring.sampleSize", 2_000_000);
        return Math.max(configured, 100_000);
    }

    private static void writeLongBigEndian(byte[] target, long value) {
        for (int i = 7; i >= 0; i--) {
            target[i] = (byte) (value & 0xff);
            value >>>= 8;
        }
    }
}
