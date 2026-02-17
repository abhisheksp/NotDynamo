package io.notdynamo.node.cluster;

import io.notdynamo.proto.v1.DeleteRequest;
import io.notdynamo.proto.v1.DeleteResponse;
import io.notdynamo.proto.v1.GetRequest;
import io.notdynamo.proto.v1.GetResponse;
import io.notdynamo.proto.v1.PutRequest;
import io.notdynamo.proto.v1.PutResponse;
import io.notdynamo.proto.v1.RaftAppendEntriesRequest;
import io.notdynamo.proto.v1.RaftAppendEntriesResponse;
import io.notdynamo.proto.v1.RaftVoteRequest;
import io.notdynamo.proto.v1.RaftVoteResponse;

public interface NodeRpcClient extends AutoCloseable {
    GetResponse get(String nodeId, GetRequest request);

    PutResponse put(String nodeId, PutRequest request);

    DeleteResponse delete(String nodeId, DeleteRequest request);

    PutResponse applyReplicaPut(String nodeId, PutRequest request);

    DeleteResponse applyReplicaDelete(String nodeId, DeleteRequest request);

    RaftVoteResponse requestVote(String nodeId, RaftVoteRequest request);

    RaftAppendEntriesResponse appendEntries(String nodeId, RaftAppendEntriesRequest request);

    @Override
    default void close() {
        // no-op by default
    }
}
