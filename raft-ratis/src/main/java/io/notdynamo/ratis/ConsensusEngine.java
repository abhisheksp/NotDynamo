package io.notdynamo.ratis;

public interface ConsensusEngine extends AutoCloseable {
    long put(byte[] key, byte[] value);

    default long put(int shardId, byte[] key, byte[] value) {
        if (shardId < 0) {
            throw new IllegalArgumentException("shardId must be >= 0");
        }
        return put(key, value);
    }

    long delete(byte[] key);

    default long delete(int shardId, byte[] key) {
        if (shardId < 0) {
            throw new IllegalArgumentException("shardId must be >= 0");
        }
        return delete(key);
    }

    @Override
    default void close() {
        // no-op
    }
}
