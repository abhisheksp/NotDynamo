package io.notdynamo.raft;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.nio.charset.StandardCharsets;
import java.util.Set;
import org.junit.jupiter.api.Test;

class QuorumWriteIT {
    @Test
    void commitsWriteWhenTwoOfThreeReplicasAcknowledge() {
        InMemoryMultiRaftGroup group = createGroup();

        group.setPeerAvailability("n3", false);
        QuorumWriteResult result = group.append("v1".getBytes(StandardCharsets.UTF_8));

        assertEquals(1L, result.term());
        assertEquals(1L, result.committedIndex());
        assertEquals(2, result.ackCount());
        assertEquals(2, result.quorumSize());
    }

    @Test
    void rejectsWriteWhenQuorumCannotBeReached() {
        InMemoryMultiRaftGroup group = createGroup();

        group.setPeerAvailability("n2", false);
        group.setPeerAvailability("n3", false);

        assertThrows(QuorumWriteException.class, () -> group.append("v1".getBytes(StandardCharsets.UTF_8)));
        assertEquals(0L, group.commitIndex());
    }

    private static InMemoryMultiRaftGroup createGroup() {
        return RaftModule.inMemoryGroup(new RaftGroupConfig("g1", Set.of("n1", "n2", "n3")), "n1");
    }
}
