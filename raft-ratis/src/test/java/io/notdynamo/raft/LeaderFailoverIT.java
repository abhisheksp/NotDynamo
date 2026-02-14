package io.notdynamo.raft;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.nio.charset.StandardCharsets;
import java.util.Set;
import org.junit.jupiter.api.Test;

class LeaderFailoverIT {
    @Test
    void leaderTransferAllowsSubsequentWritesInNewTerm() {
        InMemoryMultiRaftGroup group = RaftModule.inMemoryGroup(
            new RaftGroupConfig("g1", Set.of("n1", "n2", "n3")),
            "n1"
        );

        QuorumWriteResult first = group.append("entry-1".getBytes(StandardCharsets.UTF_8));
        assertEquals(1L, first.term());
        assertEquals(1L, first.committedIndex());

        group.setPeerAvailability("n1", false);
        assertThrows(QuorumWriteException.class, () -> group.append("entry-2".getBytes(StandardCharsets.UTF_8)));

        group.transferLeadership("n2");
        QuorumWriteResult second = group.append("entry-2".getBytes(StandardCharsets.UTF_8));
        assertEquals(2L, second.term());
        assertEquals(2L, second.committedIndex());
        assertEquals("n2", group.leaderId());
    }
}
