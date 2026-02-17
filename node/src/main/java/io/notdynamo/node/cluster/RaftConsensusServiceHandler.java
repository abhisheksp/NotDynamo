package io.notdynamo.node.cluster;

import io.grpc.stub.StreamObserver;
import io.notdynamo.proto.v1.RaftAppendEntriesRequest;
import io.notdynamo.proto.v1.RaftAppendEntriesResponse;
import io.notdynamo.proto.v1.RaftConsensusServiceGrpc;
import io.notdynamo.proto.v1.RaftVoteRequest;
import io.notdynamo.proto.v1.RaftVoteResponse;
import java.util.Objects;

public final class RaftConsensusServiceHandler extends RaftConsensusServiceGrpc.RaftConsensusServiceImplBase {
    private final RaftKvRouter router;

    public RaftConsensusServiceHandler(RaftKvRouter router) {
        this.router = Objects.requireNonNull(router, "router must not be null");
    }

    @Override
    public void requestVote(RaftVoteRequest request, StreamObserver<RaftVoteResponse> responseObserver) {
        respondAndComplete(responseObserver, router.requestVote(request));
    }

    @Override
    public void appendEntries(RaftAppendEntriesRequest request, StreamObserver<RaftAppendEntriesResponse> responseObserver) {
        respondAndComplete(responseObserver, router.appendEntries(request));
    }

    private static <T> void respondAndComplete(StreamObserver<T> observer, T response) {
        observer.onNext(response);
        observer.onCompleted();
    }
}
