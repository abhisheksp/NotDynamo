package io.notdynamo.raft;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

public final class InMemoryMultiRaftGroup {
    private final RaftGroupConfig config;
    private final Map<String, InMemoryRaftReplica> replicas;

    private String leaderId;
    private long currentTerm;
    private long commitIndex;

    public InMemoryMultiRaftGroup(RaftGroupConfig config, String initialLeaderId) {
        this.config = Objects.requireNonNull(config, "config must not be null");
        if (!config.peerIds().contains(initialLeaderId)) {
            throw new IllegalArgumentException("initial leader must be a member of the peer set");
        }

        Map<String, InMemoryRaftReplica> replicaMap = new LinkedHashMap<>();
        for (String peerId : config.peerIds()) {
            replicaMap.put(peerId, new InMemoryRaftReplica(peerId));
        }

        this.replicas = Collections.unmodifiableMap(replicaMap);
        this.leaderId = initialLeaderId;
        this.currentTerm = 1L;
    }

    public synchronized QuorumWriteResult append(byte[] payload) {
        InMemoryRaftReplica leader = replicas.get(leaderId);
        if (leader == null) {
            throw new QuorumWriteException("leader is not part of group: " + leaderId);
        }
        if (!leader.available()) {
            throw new QuorumWriteException("leader is unavailable: " + leaderId);
        }

        long nextIndex = commitIndex + 1;
        RaftLogEntry entry = new RaftLogEntry(currentTerm, nextIndex, payload);

        int acks = 0;
        List<InMemoryRaftReplica> ackedReplicas = new ArrayList<>();
        for (InMemoryRaftReplica replica : replicas.values()) {
            if (replica.append(entry)) {
                acks += 1;
                ackedReplicas.add(replica);
            }
        }

        if (acks < config.quorumSize()) {
            rollbackEntry(nextIndex, ackedReplicas);
            throw new QuorumWriteException(
                "insufficient quorum acks: ackCount=" + acks + " quorum=" + config.quorumSize()
            );
        }

        commitIndex = nextIndex;
        return new QuorumWriteResult(currentTerm, commitIndex, acks, config.quorumSize());
    }

    public synchronized void transferLeadership(String nextLeaderId) {
        if (!replicas.containsKey(nextLeaderId)) {
            throw new IllegalArgumentException("nextLeaderId is not part of group: " + nextLeaderId);
        }
        this.leaderId = nextLeaderId;
        this.currentTerm += 1;
    }

    public synchronized void setPeerAvailability(String peerId, boolean available) {
        InMemoryRaftReplica replica = replicas.get(peerId);
        if (replica == null) {
            throw new IllegalArgumentException("peerId is not part of group: " + peerId);
        }
        replica.setAvailable(available);
    }

    public synchronized void compactUpTo(long indexInclusive) {
        for (InMemoryRaftReplica replica : replicas.values()) {
            replica.compactUpTo(indexInclusive);
        }
    }

    public synchronized String leaderId() {
        return leaderId;
    }

    public synchronized long currentTerm() {
        return currentTerm;
    }

    public synchronized long commitIndex() {
        return commitIndex;
    }

    public synchronized Map<String, InMemoryRaftReplica> replicas() {
        return replicas;
    }

    private static void rollbackEntry(long index, List<InMemoryRaftReplica> ackedReplicas) {
        for (InMemoryRaftReplica replica : ackedReplicas) {
            replica.truncateTo(index - 1);
        }
    }
}
