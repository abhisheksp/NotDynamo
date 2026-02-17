package io.notdynamo.ratis;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.Arrays;
import java.util.Objects;

final class RatisCommandCodec {
    private static final byte OP_PUT = 1;
    private static final byte OP_DELETE = 2;
    private static final int HEADER_BYTES = 1 + Integer.BYTES + Integer.BYTES;

    private RatisCommandCodec() {
    }

    static byte[] encodePut(byte[] key, byte[] value) {
        validateKey(key);
        Objects.requireNonNull(value, "value must not be null");

        ByteBuffer buffer = ByteBuffer.allocate(HEADER_BYTES + key.length + value.length).order(ByteOrder.BIG_ENDIAN);
        buffer.put(OP_PUT);
        buffer.putInt(key.length);
        buffer.putInt(value.length);
        buffer.put(key);
        buffer.put(value);
        return buffer.array();
    }

    static byte[] encodeDelete(byte[] key) {
        validateKey(key);

        ByteBuffer buffer = ByteBuffer.allocate(HEADER_BYTES + key.length).order(ByteOrder.BIG_ENDIAN);
        buffer.put(OP_DELETE);
        buffer.putInt(key.length);
        buffer.putInt(0);
        buffer.put(key);
        return buffer.array();
    }

    static DecodedCommand decode(byte[] bytes) {
        Objects.requireNonNull(bytes, "bytes must not be null");
        if (bytes.length < HEADER_BYTES) {
            throw new IllegalArgumentException("command payload too small");
        }

        ByteBuffer buffer = ByteBuffer.wrap(bytes).order(ByteOrder.BIG_ENDIAN);
        byte operation = buffer.get();
        int keyLength = buffer.getInt();
        int valueLength = buffer.getInt();
        if (keyLength <= 0) {
            throw new IllegalArgumentException("key length must be > 0");
        }
        if (valueLength < 0) {
            throw new IllegalArgumentException("value length must be >= 0");
        }
        if (buffer.remaining() != keyLength + valueLength) {
            throw new IllegalArgumentException("command payload length mismatch");
        }

        byte[] key = new byte[keyLength];
        buffer.get(key);
        byte[] value = new byte[valueLength];
        buffer.get(value);

        return switch (operation) {
            case OP_PUT -> new DecodedCommand(Operation.PUT, key, value);
            case OP_DELETE -> new DecodedCommand(Operation.DELETE, key, value);
            default -> throw new IllegalArgumentException("unsupported operation code: " + operation);
        };
    }

    private static void validateKey(byte[] key) {
        Objects.requireNonNull(key, "key must not be null");
        if (key.length == 0) {
            throw new IllegalArgumentException("key must not be empty");
        }
    }

    enum Operation {
        PUT,
        DELETE
    }

    static final class DecodedCommand {
        private final Operation operation;
        private final byte[] key;
        private final byte[] value;

        private DecodedCommand(Operation operation, byte[] key, byte[] value) {
            this.operation = Objects.requireNonNull(operation, "operation must not be null");
            this.key = Arrays.copyOf(Objects.requireNonNull(key, "key must not be null"), key.length);
            this.value = Arrays.copyOf(Objects.requireNonNull(value, "value must not be null"), value.length);
        }

        Operation operation() {
            return operation;
        }

        byte[] key() {
            return Arrays.copyOf(key, key.length);
        }

        byte[] value() {
            return Arrays.copyOf(value, value.length);
        }
    }
}
