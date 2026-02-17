package io.notdynamo.node.cluster;

import io.grpc.stub.StreamObserver;
import io.notdynamo.proto.v1.DeleteRequest;
import io.notdynamo.proto.v1.DeleteResponse;
import io.notdynamo.proto.v1.GetRequest;
import io.notdynamo.proto.v1.GetResponse;
import io.notdynamo.proto.v1.KvServiceGrpc;
import io.notdynamo.proto.v1.PutRequest;
import io.notdynamo.proto.v1.PutResponse;
import java.util.Objects;

public final class RaftKvServiceHandler extends KvServiceGrpc.KvServiceImplBase {
    private final RaftKvRouter router;

    public RaftKvServiceHandler(RaftKvRouter router) {
        this.router = Objects.requireNonNull(router, "router must not be null");
    }

    @Override
    public void get(GetRequest request, StreamObserver<GetResponse> responseObserver) {
        respondAndComplete(responseObserver, router.get(request));
    }

    @Override
    public void put(PutRequest request, StreamObserver<PutResponse> responseObserver) {
        respondAndComplete(responseObserver, router.put(request));
    }

    @Override
    public void delete(DeleteRequest request, StreamObserver<DeleteResponse> responseObserver) {
        respondAndComplete(responseObserver, router.delete(request));
    }

    private static <T> void respondAndComplete(StreamObserver<T> observer, T response) {
        observer.onNext(response);
        observer.onCompleted();
    }
}
