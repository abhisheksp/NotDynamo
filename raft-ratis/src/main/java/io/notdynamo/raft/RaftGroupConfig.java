package io.notdynamo.raft;

import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.Objects;
import java.util.Set;

public final class RaftGroupConfig {
    private final String groupId;
    private final Set<String> peerIds;

    public RaftGroupConfig(String groupId, Set<String> peerIds) {
        this.groupId = validateId(groupId, "groupId");
        Objects.requireNonNull(peerIds, "peerIds must not be null");
        if (peerIds.size() < 3) {
            throw new IllegalArgumentException("peerIds must contain at least 3 peers");
        }

        Set<String> normalized = new LinkedHashSet<>();
        for (String peerId : peerIds) {
            normalized.add(validateId(peerId, "peerId"));
        }
        if (normalized.size() < 3) {
            throw new IllegalArgumentException("peerIds must contain at least 3 unique peers");
        }

        this.peerIds = Collections.unmodifiableSet(normalized);
    }

    public String groupId() {
        return groupId;
    }

    public Set<String> peerIds() {
        return peerIds;
    }

    public int quorumSize() {
        return (peerIds.size() / 2) + 1;
    }

    private static String validateId(String value, String label) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(label + " must not be blank");
        }
        return value;
    }
}
