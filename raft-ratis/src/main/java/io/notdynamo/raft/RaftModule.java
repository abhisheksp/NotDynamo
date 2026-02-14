package io.notdynamo.raft;

public final class RaftModule {
    private RaftModule() {
    }

    public static InMemoryMultiRaftGroup inMemoryGroup(RaftGroupConfig config, String initialLeaderId) {
        return new InMemoryMultiRaftGroup(config, initialLeaderId);
    }
}
