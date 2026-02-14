package io.notdynamo.raft;

import java.util.Arrays;
import java.util.Objects;

public record RaftLogEntry(long term, long index, byte[] payload) {
    public RaftLogEntry {
        if (term <= 0) {
            throw new IllegalArgumentException("term must be > 0");
        }
        if (index <= 0) {
            throw new IllegalArgumentException("index must be > 0");
        }
        Objects.requireNonNull(payload, "payload must not be null");
        payload = Arrays.copyOf(payload, payload.length);
    }
}
