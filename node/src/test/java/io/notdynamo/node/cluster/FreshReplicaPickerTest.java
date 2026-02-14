package io.notdynamo.node.cluster;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import java.util.List;
import org.junit.jupiter.api.Test;

class FreshReplicaPickerTest {
    @Test
    void selectsFreshestFollowerWithinBudget() {
        ReplicaLagTracker lagTracker = new ReplicaLagTracker();
        lagTracker.recordLagMillis(0, "node-b", 150);
        lagTracker.recordLagMillis(0, "node-c", 800);

        FreshReplicaPicker picker = new FreshReplicaPicker();
        String selected = picker.pickFreshFollower(
            0,
            "node-a",
            List.of("node-a", "node-b", "node-c"),
            lagTracker,
            1000
        );

        assertEquals("node-b", selected);
    }

    @Test
    void returnsNullWhenNoFollowerIsFresh() {
        ReplicaLagTracker lagTracker = new ReplicaLagTracker();
        lagTracker.recordLagMillis(0, "node-b", 1500);
        lagTracker.recordLagMillis(0, "node-c", 1200);

        FreshReplicaPicker picker = new FreshReplicaPicker();
        String selected = picker.pickFreshFollower(
            0,
            "node-a",
            List.of("node-a", "node-b", "node-c"),
            lagTracker,
            1000
        );

        assertNull(selected);
    }
}
