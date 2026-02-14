package io.notdynamo.node;

import com.google.protobuf.ByteString;
import io.grpc.stub.StreamObserver;
import io.notdynamo.proto.v1.DeleteRequest;
import io.notdynamo.proto.v1.DeleteResponse;
import io.notdynamo.proto.v1.Error;
import io.notdynamo.proto.v1.GetRequest;
import io.notdynamo.proto.v1.GetResponse;
import io.notdynamo.proto.v1.KvServiceGrpc;
import io.notdynamo.proto.v1.PutRequest;
import io.notdynamo.proto.v1.PutResponse;
import io.notdynamo.proto.v1.StatusCode;
import io.notdynamo.storage.KeyValueStore;
import io.notdynamo.storage.StorageException;
import java.util.Objects;

public final class KvServiceHandler extends KvServiceGrpc.KvServiceImplBase {
    private final KeyValueStore keyValueStore;

    public KvServiceHandler(KeyValueStore keyValueStore) {
        this.keyValueStore = Objects.requireNonNull(keyValueStore, "keyValueStore must not be null");
    }

    @Override
    public void get(GetRequest request, StreamObserver<GetResponse> responseObserver) {
        if (request.getKey().isEmpty()) {
            respondAndComplete(
                responseObserver,
                GetResponse.newBuilder().setError(error(StatusCode.STATUS_CODE_INVALID_ARGUMENT, "key must not be empty")).build()
            );
            return;
        }

        try {
            KeyValueStore.GetResult result = keyValueStore.get(request.getKey().toByteArray());
            GetResponse.Builder response = GetResponse.newBuilder()
                .setFound(result.found())
                .setVersion(result.version());

            if (result.found()) {
                response.setValue(ByteString.copyFrom(result.value()));
            }

            respondAndComplete(responseObserver, response.build());
        } catch (StorageException e) {
            respondAndComplete(
                responseObserver,
                GetResponse.newBuilder().setError(error(StatusCode.STATUS_CODE_INTERNAL, e.getMessage())).build()
            );
        }
    }

    @Override
    public void put(PutRequest request, StreamObserver<PutResponse> responseObserver) {
        if (request.getKey().isEmpty()) {
            respondAndComplete(
                responseObserver,
                PutResponse.newBuilder().setError(error(StatusCode.STATUS_CODE_INVALID_ARGUMENT, "key must not be empty")).build()
            );
            return;
        }

        try {
            long version = keyValueStore.put(request.getKey().toByteArray(), request.getValue().toByteArray());
            respondAndComplete(responseObserver, PutResponse.newBuilder().setVersion(version).build());
        } catch (StorageException e) {
            respondAndComplete(
                responseObserver,
                PutResponse.newBuilder().setError(error(StatusCode.STATUS_CODE_INTERNAL, e.getMessage())).build()
            );
        }
    }

    @Override
    public void delete(DeleteRequest request, StreamObserver<DeleteResponse> responseObserver) {
        if (request.getKey().isEmpty()) {
            respondAndComplete(
                responseObserver,
                DeleteResponse.newBuilder().setError(error(StatusCode.STATUS_CODE_INVALID_ARGUMENT, "key must not be empty")).build()
            );
            return;
        }

        try {
            long version = keyValueStore.delete(request.getKey().toByteArray());
            respondAndComplete(responseObserver, DeleteResponse.newBuilder().setVersion(version).build());
        } catch (StorageException e) {
            respondAndComplete(
                responseObserver,
                DeleteResponse.newBuilder().setError(error(StatusCode.STATUS_CODE_INTERNAL, e.getMessage())).build()
            );
        }
    }

    private static Error error(StatusCode code, String message) {
        return Error.newBuilder().setCode(code).setMessage(message).build();
    }

    private static <T> void respondAndComplete(StreamObserver<T> observer, T response) {
        observer.onNext(response);
        observer.onCompleted();
    }
}
