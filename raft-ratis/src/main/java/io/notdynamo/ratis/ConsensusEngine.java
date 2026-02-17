package io.notdynamo.ratis;

public interface ConsensusEngine extends AutoCloseable {
    long put(byte[] key, byte[] value);

    long delete(byte[] key);

    @Override
    default void close() {
        // no-op
    }
}
