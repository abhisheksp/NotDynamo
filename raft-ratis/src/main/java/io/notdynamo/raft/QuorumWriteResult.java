package io.notdynamo.raft;

public record QuorumWriteResult(long term, long committedIndex, int ackCount, int quorumSize) {
    public QuorumWriteResult {
        if (term <= 0) {
            throw new IllegalArgumentException("term must be > 0");
        }
        if (committedIndex <= 0) {
            throw new IllegalArgumentException("committedIndex must be > 0");
        }
        if (ackCount <= 0) {
            throw new IllegalArgumentException("ackCount must be > 0");
        }
        if (quorumSize <= 0) {
            throw new IllegalArgumentException("quorumSize must be > 0");
        }
    }
}
