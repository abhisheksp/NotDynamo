package io.notdynamo.storage;

public interface KeyValueStore extends AutoCloseable {
    GetResult get(byte[] key);

    long put(byte[] key, byte[] value);

    long delete(byte[] key);

    @Override
    void close();

    record GetResult(boolean found, byte[] value, long version) {
        public GetResult {
            if (value == null) {
                value = new byte[0];
            }
        }
    }
}
