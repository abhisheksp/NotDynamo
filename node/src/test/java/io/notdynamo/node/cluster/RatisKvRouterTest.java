package io.notdynamo.node.cluster;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.google.protobuf.ByteString;
import io.notdynamo.controlplane.ClusterPartitionMap;
import io.notdynamo.controlplane.PartitionMapVersion;
import io.notdynamo.controlplane.ReplicaPartitionMap;
import io.notdynamo.node.NodeConfig;
import io.notdynamo.node.NodeServer;
import io.notdynamo.proto.v1.PutRequest;
import io.notdynamo.proto.v1.PutResponse;
import io.notdynamo.proto.v1.StatusCode;
import io.notdynamo.ratis.ConsensusEngine;
import java.nio.file.Path;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class RatisKvRouterTest {
    @TempDir
    Path tempDir;

    @Test
    void putRetriesTransientConsensusFailures() {
        try (NodeServer node = NodeServer.openSharded(configFor("node-a"), 16, 64)) {
            FlakyConsensusEngine consensus = new FlakyConsensusEngine(2, 0, 11L, 0L);
            RatisKvRouter router = new RatisKvRouter(
                "node-a",
                node.kvService(),
                new InMemoryNodeRpcClient(),
                singleNodeReplicaMap("node-a"),
                consensus
            );

            PutResponse response = router.put(putRequest("k1", "v1"));
            assertFalse(response.hasError(), () -> "expected eventual success: " + response.getError().getMessage());
            assertEquals(11L, response.getVersion());
            assertEquals(3, consensus.putAttempts());
        }
    }

    @Test
    void putReturnsUnavailableAfterRetryBudgetExhausted() {
        try (NodeServer node = NodeServer.openSharded(configFor("node-a"), 16, 64)) {
            FlakyConsensusEngine consensus = FlakyConsensusEngine.alwaysFailPut("leader not ready");
            RatisKvRouter router = new RatisKvRouter(
                "node-a",
                node.kvService(),
                new InMemoryNodeRpcClient(),
                singleNodeReplicaMap("node-a"),
                consensus
            );

            PutResponse response = router.put(putRequest("k2", "v2"));
            assertTrue(response.hasError());
            assertEquals(StatusCode.STATUS_CODE_UNAVAILABLE, response.getError().getCode());
            assertTrue(consensus.putAttempts() >= 2, "expected retries before failing");
        }
    }

    private PutRequest putRequest(String key, String value) {
        return PutRequest.newBuilder()
            .setKey(ByteString.copyFromUtf8(key))
            .setValue(ByteString.copyFromUtf8(value))
            .build();
    }

    private NodeConfig configFor(String nodeId) {
        return new NodeConfig(
            nodeId,
            "127.0.0.1",
            9000 + Math.abs(nodeId.hashCode() % 1000),
            10000 + Math.abs(nodeId.hashCode() % 1000),
            tempDir.resolve(nodeId)
        );
    }

    private static ReplicaPartitionMap singleNodeReplicaMap(String nodeId) {
        ClusterPartitionMap map = ClusterPartitionMap.roundRobin(
            new PartitionMapVersion(0),
            16,
            64,
            List.of(nodeId)
        );
        return ReplicaPartitionMap.withUniformReplicas(map, List.of(nodeId));
    }

    private static final class FlakyConsensusEngine implements ConsensusEngine {
        private final int putFailuresBeforeSuccess;
        private final int deleteFailuresBeforeSuccess;
        private final long putSuccessVersion;
        private final long deleteSuccessVersion;
        private final String alwaysPutFailureMessage;
        private final AtomicInteger putCalls = new AtomicInteger();
        private final AtomicInteger deleteCalls = new AtomicInteger();

        private FlakyConsensusEngine(
            int putFailuresBeforeSuccess,
            int deleteFailuresBeforeSuccess,
            long putSuccessVersion,
            long deleteSuccessVersion
        ) {
            this(putFailuresBeforeSuccess, deleteFailuresBeforeSuccess, putSuccessVersion, deleteSuccessVersion, null);
        }

        private FlakyConsensusEngine(
            int putFailuresBeforeSuccess,
            int deleteFailuresBeforeSuccess,
            long putSuccessVersion,
            long deleteSuccessVersion,
            String alwaysPutFailureMessage
        ) {
            this.putFailuresBeforeSuccess = putFailuresBeforeSuccess;
            this.deleteFailuresBeforeSuccess = deleteFailuresBeforeSuccess;
            this.putSuccessVersion = putSuccessVersion;
            this.deleteSuccessVersion = deleteSuccessVersion;
            this.alwaysPutFailureMessage = alwaysPutFailureMessage;
        }

        static FlakyConsensusEngine alwaysFailPut(String message) {
            return new FlakyConsensusEngine(0, 0, 0L, 0L, message);
        }

        @Override
        public long put(byte[] key, byte[] value) {
            int call = putCalls.incrementAndGet();
            if (alwaysPutFailureMessage != null) {
                throw new IllegalStateException(alwaysPutFailureMessage);
            }
            if (call <= putFailuresBeforeSuccess) {
                throw new IllegalStateException("temporary ratis write failure");
            }
            return putSuccessVersion;
        }

        @Override
        public long delete(byte[] key) {
            int call = deleteCalls.incrementAndGet();
            if (call <= deleteFailuresBeforeSuccess) {
                throw new IllegalStateException("temporary ratis delete failure");
            }
            return deleteSuccessVersion;
        }

        int putAttempts() {
            return putCalls.get();
        }
    }
}
