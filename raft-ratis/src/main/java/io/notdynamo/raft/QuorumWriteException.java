package io.notdynamo.raft;

public final class QuorumWriteException extends RuntimeException {
    public QuorumWriteException(String message) {
        super(message);
    }
}
