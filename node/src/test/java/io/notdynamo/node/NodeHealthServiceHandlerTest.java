package io.notdynamo.node;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import io.grpc.stub.StreamObserver;
import io.notdynamo.proto.v1.HealthRequest;
import io.notdynamo.proto.v1.HealthResponse;
import org.junit.jupiter.api.Test;

class NodeHealthServiceHandlerTest {
    @Test
    void returnsConfiguredNodeHealthStatus() {
        NodeHealthServiceHandler handler = new NodeHealthServiceHandler("node-a", () -> true, () -> "17");
        ObserverCapture<HealthResponse> capture = new ObserverCapture<>();

        handler.health(HealthRequest.getDefaultInstance(), capture);

        HealthResponse response = capture.value();
        assertEquals("node-a", response.getNodeId());
        assertTrue(response.getReady());
        assertEquals("17", response.getPartitionMapEpoch());
    }

    private static final class ObserverCapture<T> implements StreamObserver<T> {
        private T value;

        @Override
        public void onNext(T value) {
            this.value = value;
        }

        @Override
        public void onError(Throwable throwable) {
            throw new AssertionError("unexpected observer error", throwable);
        }

        @Override
        public void onCompleted() {
            // no-op
        }

        private T value() {
            return value;
        }
    }
}
