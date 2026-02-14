package io.notdynamo.raft;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.nio.charset.StandardCharsets;
import java.util.Set;
import org.junit.jupiter.api.Test;

class PartitionSafetyIT {
    @Test
    void minorityPartitionCannotCommitWrites() {
        InMemoryMultiRaftGroup group = RaftModule.inMemoryGroup(
            new RaftGroupConfig("g1", Set.of("n1", "n2", "n3")),
            "n1"
        );

        group.setPeerAvailability("n2", false);
        group.setPeerAvailability("n3", false);

        assertThrows(QuorumWriteException.class, () -> group.append("unsafe".getBytes(StandardCharsets.UTF_8)));
        assertEquals(0L, group.commitIndex());
    }

    @Test
    void majorityPartitionCommitsWrites() {
        InMemoryMultiRaftGroup group = RaftModule.inMemoryGroup(
            new RaftGroupConfig("g1", Set.of("n1", "n2", "n3")),
            "n1"
        );

        group.setPeerAvailability("n3", false);

        QuorumWriteResult result = group.append("safe".getBytes(StandardCharsets.UTF_8));
        assertEquals(1L, result.committedIndex());
        assertEquals(2, result.ackCount());
    }
}
