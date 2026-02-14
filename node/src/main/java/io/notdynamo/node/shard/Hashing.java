package io.notdynamo.node.shard;

import java.nio.ByteBuffer;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

final class Hashing {
    private static final ThreadLocal<MessageDigest> SHA_256 = ThreadLocal.withInitial(() -> {
        try {
            return MessageDigest.getInstance("SHA-256");
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 digest is unavailable", e);
        }
    });

    private Hashing() {
    }

    static long hash64(byte[] bytes) {
        MessageDigest digest = SHA_256.get();
        digest.reset();
        byte[] hash = digest.digest(bytes);
        return ByteBuffer.wrap(hash, 0, Long.BYTES).getLong();
    }
}
