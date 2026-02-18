package io.notdynamo.controlplane;

public enum ShardRebalanceState {
    STABLE,
    TRANSFERRING,
    CATCHING_UP,
    CUTOVER_PENDING
}
