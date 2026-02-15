package io.notdynamo.node;

import io.grpc.stub.StreamObserver;
import io.notdynamo.proto.v1.HealthRequest;
import io.notdynamo.proto.v1.HealthResponse;
import io.notdynamo.proto.v1.NodeHealthServiceGrpc;
import java.util.Objects;
import java.util.function.Supplier;

public final class NodeHealthServiceHandler extends NodeHealthServiceGrpc.NodeHealthServiceImplBase {
    private final String nodeId;
    private final Supplier<Boolean> readinessSupplier;
    private final Supplier<String> partitionMapEpochSupplier;

    public NodeHealthServiceHandler(String nodeId, Supplier<Boolean> readinessSupplier, Supplier<String> partitionMapEpochSupplier) {
        this.nodeId = Objects.requireNonNull(nodeId, "nodeId must not be null");
        this.readinessSupplier = Objects.requireNonNull(readinessSupplier, "readinessSupplier must not be null");
        this.partitionMapEpochSupplier = Objects.requireNonNull(
            partitionMapEpochSupplier,
            "partitionMapEpochSupplier must not be null"
        );
    }

    @Override
    public void health(HealthRequest request, StreamObserver<HealthResponse> responseObserver) {
        boolean ready = readinessSupplier.get();
        String partitionMapEpoch = partitionMapEpochSupplier.get();

        HealthResponse response = HealthResponse.newBuilder()
            .setNodeId(nodeId)
            .setReady(ready)
            .setPartitionMapEpoch(partitionMapEpoch)
            .build();

        responseObserver.onNext(response);
        responseObserver.onCompleted();
    }
}
