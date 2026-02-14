package io.notdynamo.raft;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.charset.StandardCharsets;
import java.util.Set;
import org.junit.jupiter.api.Test;

class SnapshotCompactionIT {
    @Test
    void compactionTruncatesEntriesUpToSnapshotIndex() {
        InMemoryMultiRaftGroup group = RaftModule.inMemoryGroup(
            new RaftGroupConfig("g1", Set.of("n1", "n2", "n3")),
            "n1"
        );

        for (int i = 1; i <= 5; i++) {
            group.append(("entry-" + i).getBytes(StandardCharsets.UTF_8));
        }

        assertEquals(5L, group.commitIndex());
        group.compactUpTo(3L);

        for (InMemoryRaftReplica replica : group.replicas().values()) {
            assertEquals(3L, replica.snapshotIndex());
            assertTrue(replica.logView().stream().allMatch(entry -> entry.index() > 3L));
            assertEquals(5L, replica.lastLogIndex());
        }
    }
}
