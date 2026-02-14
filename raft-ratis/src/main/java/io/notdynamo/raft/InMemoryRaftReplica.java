package io.notdynamo.raft;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Objects;

public final class InMemoryRaftReplica {
    private final String peerId;
    private final List<RaftLogEntry> log = new ArrayList<>();

    private boolean available = true;
    private long snapshotIndex;

    public InMemoryRaftReplica(String peerId) {
        if (peerId == null || peerId.isBlank()) {
            throw new IllegalArgumentException("peerId must not be blank");
        }
        this.peerId = peerId;
    }

    public synchronized String peerId() {
        return peerId;
    }

    public synchronized boolean available() {
        return available;
    }

    public synchronized void setAvailable(boolean available) {
        this.available = available;
    }

    public synchronized boolean append(RaftLogEntry entry) {
        Objects.requireNonNull(entry, "entry must not be null");
        if (!available) {
            return false;
        }

        long expectedNextIndex = lastLogIndex() + 1;
        if (entry.index() != expectedNextIndex) {
            return false;
        }

        log.add(entry);
        return true;
    }

    public synchronized long lastLogIndex() {
        if (log.isEmpty()) {
            return snapshotIndex;
        }
        return log.get(log.size() - 1).index();
    }

    public synchronized long snapshotIndex() {
        return snapshotIndex;
    }

    public synchronized void compactUpTo(long indexInclusive) {
        if (indexInclusive <= snapshotIndex) {
            return;
        }

        log.removeIf(entry -> entry.index() <= indexInclusive);
        snapshotIndex = indexInclusive;
    }

    public synchronized void truncateTo(long indexInclusive) {
        log.removeIf(entry -> entry.index() > indexInclusive);
    }

    public synchronized List<RaftLogEntry> logView() {
        return Collections.unmodifiableList(new ArrayList<>(log));
    }
}
