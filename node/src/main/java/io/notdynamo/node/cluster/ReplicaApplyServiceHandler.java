package io.notdynamo.node.cluster;

import io.grpc.stub.StreamObserver;
import io.notdynamo.node.KvServiceHandler;
import io.notdynamo.proto.v1.DeleteRequest;
import io.notdynamo.proto.v1.DeleteResponse;
import io.notdynamo.proto.v1.PutRequest;
import io.notdynamo.proto.v1.PutResponse;
import io.notdynamo.proto.v1.ReplicaApplyServiceGrpc;
import java.util.Objects;

public final class ReplicaApplyServiceHandler extends ReplicaApplyServiceGrpc.ReplicaApplyServiceImplBase {
    private final KvServiceHandler localKvService;

    public ReplicaApplyServiceHandler(KvServiceHandler localKvService) {
        this.localKvService = Objects.requireNonNull(localKvService, "localKvService must not be null");
    }

    @Override
    public void applyPut(PutRequest request, StreamObserver<PutResponse> responseObserver) {
        localKvService.put(request, responseObserver);
    }

    @Override
    public void applyDelete(DeleteRequest request, StreamObserver<DeleteResponse> responseObserver) {
        localKvService.delete(request, responseObserver);
    }
}
