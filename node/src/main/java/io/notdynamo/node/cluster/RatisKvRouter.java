package io.notdynamo.node.cluster;

import io.notdynamo.controlplane.ReplicaPartitionMap;
import io.notdynamo.node.KvServiceHandler;
import io.notdynamo.node.shard.ConsistentHashRing;
import io.notdynamo.proto.v1.DeleteRequest;
import io.notdynamo.proto.v1.DeleteResponse;
import io.notdynamo.proto.v1.Error;
import io.notdynamo.proto.v1.GetRequest;
import io.notdynamo.proto.v1.GetResponse;
import io.notdynamo.proto.v1.PutRequest;
import io.notdynamo.proto.v1.PutResponse;
import io.notdynamo.proto.v1.StatusCode;
import io.notdynamo.ratis.ConsensusEngine;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.TreeMap;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.LongAccumulator;
import java.util.concurrent.atomic.LongAdder;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;

public final class RatisKvRouter {
    private static final int MAX_CONSENSUS_WRITE_ATTEMPTS = 2;
    private static final long CONSENSUS_RETRY_BACKOFF_MS = 15L;
    private static final long MAX_CONSENSUS_WRITE_DURATION_MS = 1200L;
    private static final long WRITE_TELEMETRY_EMIT_INTERVAL_NANOS = TimeUnit.SECONDS.toNanos(5);
    private static final long LEADER_SNAPSHOT_REFRESH_INTERVAL_NANOS = TimeUnit.MILLISECONDS.toNanos(200);
    private static final long OBSERVED_LEADER_CACHE_TTL_NANOS = TimeUnit.MILLISECONDS.toNanos(250);
    private static final long OBSERVED_LEADER_FAILURE_BACKOFF_NANOS = TimeUnit.SECONDS.toNanos(2);
    private static final boolean OBSERVED_LEADER_OVERRIDE_RETRY_ENABLED = false;
    private static final int DEFAULT_WRITE_GLOBAL_INFLIGHT_LIMIT = 0;
    private static final int DEFAULT_WRITE_SHARD_INFLIGHT_MIN = 8;
    private static final int DEFAULT_RATIS_MAX_INFLIGHT_PER_SHARD = 16;
    private static final long DEFAULT_WRITE_ADMISSION_WAIT_MILLIS = 0L;
    private static final String ADMISSION_BACKPRESSURE_ERROR_CODE =
        StatusCode.STATUS_CODE_UNAVAILABLE.name() + "/cause=BACKPRESSURE";
    private static final String CONSENSUS_INFLIGHT_LIMIT_ERROR_CODE =
        StatusCode.STATUS_CODE_UNAVAILABLE.name() + "/cause=CONSENSUS_INFLIGHT_LIMIT";

    private final String localNodeId;
    private final KvServiceHandler localService;
    private final NodeRpcClient rpcClient;
    private final AtomicReference<ReplicaPartitionMap> replicaMapRef;
    private final ConsensusEngine consensusEngine;
    private final ReadMode readMode;
    private final ReplicaLagTracker lagTracker;
    private final FreshReplicaPicker replicaPicker;
    private final long freshnessBudgetMillis;
    private final AtomicLong leaderFallbackReads = new AtomicLong();
    private final WriteStageTelemetry writeStageTelemetry = new WriteStageTelemetry();
    private final AtomicLong lastWriteTelemetryEmitNanos = new AtomicLong(System.nanoTime());
    private final ConcurrentHashMap<Integer, CachedLeader> observedLeaderByShard = new ConcurrentHashMap<>();
    private final AtomicLong observedLeaderOverrideWrites = new AtomicLong();
    private final AtomicLong observedLeaderLookupFailures = new AtomicLong();
    private final AtomicLong observedLeaderLookupSkippedNonReplica = new AtomicLong();
    private final AtomicLong observedLeaderOverrideRetryAttempts = new AtomicLong();
    private final AtomicLong observedLeaderOverrideRetrySuccess = new AtomicLong();
    private final AtomicLong writeBackpressureRejections = new AtomicLong();
    private final ConcurrentHashMap<Integer, LongAdder> writeBackpressureRejectionsByShard = new ConcurrentHashMap<>();
    private final AtomicLong writeAdmissionWaitExhaustedCount = new AtomicLong();
    private final AtomicLong consensusRejectDueToInflightLimit = new AtomicLong();
    private final ConcurrentHashMap<Integer, LongAdder> consensusRejectDueToInflightLimitByShard = new ConcurrentHashMap<>();
    private final AtomicLong forwardedWrites = new AtomicLong();
    private final AtomicLong totalWrites = new AtomicLong();
    private final AtomicLong leaderSnapshotRefreshFailures = new AtomicLong();
    private final AtomicLong lastLeaderSnapshotRefreshNanos = new AtomicLong(0L);
    private final AtomicLong observedLocalLeaderShardCount = new AtomicLong(0L);
    private final int writeGlobalInflightLimit;
    private final int writeShardInflightMin;
    private final int ratisMaxInflightPerShard;
    private final long writeAdmissionWaitMillis;
    private final Semaphore writeAdmissionSemaphore;
    private final ConcurrentHashMap<Integer, Semaphore> shardWriteAdmissionSemaphores = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<Integer, Semaphore> consensusInflightByShard = new ConcurrentHashMap<>();

    private volatile long ringEpoch = Long.MIN_VALUE;
    private volatile ConsistentHashRing ring;
    private volatile long mappedLeaderShardCountEpoch = Long.MIN_VALUE;
    private volatile int mappedLocalLeaderShardCount = 1;
    private volatile int writeShardAdmissionLimit = -1;

    public RatisKvRouter(
        String localNodeId,
        KvServiceHandler localService,
        NodeRpcClient rpcClient,
        ReplicaPartitionMap replicaMap,
        ConsensusEngine consensusEngine
    ) {
        this(localNodeId, localService, rpcClient, replicaMap, consensusEngine, ReadMode.LOCAL_REPLICA, new ReplicaLagTracker(), 1000L);
    }

    public RatisKvRouter(
        String localNodeId,
        KvServiceHandler localService,
        NodeRpcClient rpcClient,
        ReplicaPartitionMap replicaMap,
        ConsensusEngine consensusEngine,
        ReadMode readMode,
        ReplicaLagTracker lagTracker,
        long freshnessBudgetMillis
    ) {
        this(
            localNodeId,
            localService,
            rpcClient,
            replicaMap,
            consensusEngine,
            readMode,
            lagTracker,
            freshnessBudgetMillis,
            DEFAULT_WRITE_GLOBAL_INFLIGHT_LIMIT,
            DEFAULT_WRITE_SHARD_INFLIGHT_MIN,
            DEFAULT_WRITE_ADMISSION_WAIT_MILLIS,
            DEFAULT_RATIS_MAX_INFLIGHT_PER_SHARD
        );
    }

    public RatisKvRouter(
        String localNodeId,
        KvServiceHandler localService,
        NodeRpcClient rpcClient,
        ReplicaPartitionMap replicaMap,
        ConsensusEngine consensusEngine,
        ReadMode readMode,
        ReplicaLagTracker lagTracker,
        long freshnessBudgetMillis,
        int writeInflightLimit,
        long writeAdmissionWaitMillis
    ) {
        this(
            localNodeId,
            localService,
            rpcClient,
            replicaMap,
            consensusEngine,
            readMode,
            lagTracker,
            freshnessBudgetMillis,
            writeInflightLimit,
            DEFAULT_WRITE_SHARD_INFLIGHT_MIN,
            writeAdmissionWaitMillis,
            DEFAULT_RATIS_MAX_INFLIGHT_PER_SHARD
        );
    }

    public RatisKvRouter(
        String localNodeId,
        KvServiceHandler localService,
        NodeRpcClient rpcClient,
        ReplicaPartitionMap replicaMap,
        ConsensusEngine consensusEngine,
        ReadMode readMode,
        ReplicaLagTracker lagTracker,
        long freshnessBudgetMillis,
        int writeGlobalInflightLimit,
        int writeShardInflightMin,
        long writeAdmissionWaitMillis,
        int ratisMaxInflightPerShard
    ) {
        this.localNodeId = validateNodeId(localNodeId, "localNodeId");
        this.localService = Objects.requireNonNull(localService, "localService must not be null");
        this.rpcClient = Objects.requireNonNull(rpcClient, "rpcClient must not be null");
        this.replicaMapRef = new AtomicReference<>(Objects.requireNonNull(replicaMap, "replicaMap must not be null"));
        this.consensusEngine = Objects.requireNonNull(consensusEngine, "consensusEngine must not be null");
        this.readMode = Objects.requireNonNull(readMode, "readMode must not be null");
        this.lagTracker = Objects.requireNonNull(lagTracker, "lagTracker must not be null");
        this.replicaPicker = new FreshReplicaPicker();
        if (freshnessBudgetMillis < 0) {
            throw new IllegalArgumentException("freshnessBudgetMillis must be >= 0");
        }
        if (writeGlobalInflightLimit < 0) {
            throw new IllegalArgumentException("writeGlobalInflightLimit must be >= 0");
        }
        if (writeShardInflightMin <= 0) {
            throw new IllegalArgumentException("writeShardInflightMin must be > 0");
        }
        if (writeAdmissionWaitMillis < 0) {
            throw new IllegalArgumentException("writeAdmissionWaitMillis must be >= 0");
        }
        if (ratisMaxInflightPerShard <= 0) {
            throw new IllegalArgumentException("ratisMaxInflightPerShard must be > 0");
        }
        this.freshnessBudgetMillis = freshnessBudgetMillis;
        this.writeGlobalInflightLimit = writeGlobalInflightLimit;
        this.writeShardInflightMin = writeShardInflightMin;
        this.ratisMaxInflightPerShard = ratisMaxInflightPerShard;
        this.writeAdmissionWaitMillis = writeAdmissionWaitMillis;
        this.writeAdmissionSemaphore = writeGlobalInflightLimit > 0 ? new Semaphore(writeGlobalInflightLimit, true) : null;
    }

    public GetResponse get(GetRequest request) {
        if (request.getKey().isEmpty()) {
            return GetResponse.newBuilder().setError(invalidArgument("key must not be empty")).build();
        }

        ReplicaPartitionMap map = currentReplicaMap();
        int shardId = shardForKey(request.getKey().toByteArray(), map);
        List<String> replicas = map.replicasForShard(shardId);
        String leaderNodeId = map.leaderForShard(shardId);
        String readNodeId = readNodeIdFor(shardId, replicas, leaderNodeId);
        if (readNodeId == null || readNodeId.isBlank()) {
            return GetResponse.newBuilder().setError(unavailable("no read node available for shard " + shardId)).build();
        }

        if (localNodeId.equals(readNodeId)) {
            return invokeLocalGet(request);
        }
        return rpcClient.get(readNodeId, request);
    }

    public PutResponse put(PutRequest request) {
        if (request.getKey().isEmpty()) {
            return PutResponse.newBuilder().setError(invalidArgument("key must not be empty")).build();
        }

        long writeStartNanos = System.nanoTime();
        totalWrites.incrementAndGet();
        refreshObservedLeaderSnapshotIfDue();

        ReplicaPartitionMap map = currentReplicaMap();
        int shardId = shardForKey(request.getKey().toByteArray(), map);
        List<String> replicas = map.replicasForShard(shardId);
        WriteLeaderSelection writeLeader = writeLeaderForShard(map, shardId, replicas);
        String leaderNodeId = writeLeader.targetLeaderNodeId();
        if (leaderNodeId == null || leaderNodeId.isBlank()) {
            PutResponse response = PutResponse.newBuilder().setError(unavailable("no leader for shard " + shardId)).build();
            writeStageTelemetry.recordPutTotal(
                shardId,
                false,
                isTimeoutError(response.getError()),
                System.nanoTime() - writeStartNanos,
                errorCodeName(response.getError())
            );
            emitWriteTelemetryIfDue();
            return response;
        }
        if (!localNodeId.equals(leaderNodeId)) {
            forwardedWrites.incrementAndGet();
            long forwardStartNanos = System.nanoTime();
            PutResponse response = rpcClient.put(leaderNodeId, request);
            if (OBSERVED_LEADER_OVERRIDE_RETRY_ENABLED && shouldRetryOnMappedLeader(writeLeader, response)) {
                observedLeaderOverrideRetryAttempts.incrementAndGet();
                PutResponse retryResponse = rpcClient.put(writeLeader.mappedLeaderNodeId(), request);
                if (!retryResponse.hasError()) {
                    observedLeaderOverrideRetrySuccess.incrementAndGet();
                }
                response = retryResponse;
            }
            boolean success = !response.hasError();
            writeStageTelemetry.recordForwardToLeader(
                shardId,
                success,
                isTimeoutError(response.getError()),
                System.nanoTime() - forwardStartNanos,
                errorCodeName(response.getError())
            );
            writeStageTelemetry.recordPutTotal(
                shardId,
                success,
                isTimeoutError(response.getError()),
                System.nanoTime() - writeStartNanos,
                errorCodeName(response.getError())
            );
            emitWriteTelemetryIfDue();
            return response;
        }

        WriteAdmissionPermit permit = acquireWriteAdmission(shardId, map);
        if (!permit.acquired()) {
            return rejectPutWithBackpressure(shardId, writeStartNanos);
        }
        long consensusReplyStartNanos = 0L;
        try {
            if (!acquireConsensusInflight(shardId)) {
                return rejectPutDueToConsensusInflightLimit(shardId, writeStartNanos);
            }
            writeStageTelemetry.recordConsensusSubmit(shardId, 0L);
            consensusReplyStartNanos = System.nanoTime();
            long version = writeWithRetry(
                () -> consensusEngine.put(shardId, request.getKey().toByteArray(), request.getValue().toByteArray())
            );
            lagTracker.recordLagMillis(shardId, localNodeId, 0L);
            writeStageTelemetry.recordConsensusReply(
                shardId,
                true,
                false,
                System.nanoTime() - consensusReplyStartNanos,
                ""
            );
            PutResponse response = PutResponse.newBuilder().setVersion(version).build();
            writeStageTelemetry.recordPutTotal(
                shardId,
                true,
                false,
                System.nanoTime() - writeStartNanos,
                ""
            );
            emitWriteTelemetryIfDue();
            return response;
        } catch (IllegalArgumentException e) {
            PutResponse response = PutResponse.newBuilder().setError(invalidArgument(e.getMessage())).build();
            writeStageTelemetry.recordConsensusReply(
                shardId,
                false,
                isTimeoutError(response.getError()),
                System.nanoTime() - consensusReplyStartNanos,
                errorCodeName(response.getError())
            );
            writeStageTelemetry.recordPutTotal(
                shardId,
                false,
                isTimeoutError(response.getError()),
                System.nanoTime() - writeStartNanos,
                errorCodeName(response.getError())
            );
            emitWriteTelemetryIfDue();
            return response;
        } catch (RuntimeException e) {
            boolean timeout = isTimeoutFailure(e);
            String consensusState = consensusStateForShard(shardId);
            Error error = timeout
                ? timeout("ratis put fast-fail: " + safeMessage(e) + " " + consensusState)
                : unavailable("ratis put failed: " + safeMessage(e) + " " + consensusState);
            PutResponse response = PutResponse.newBuilder().setError(error).build();
            writeStageTelemetry.recordConsensusReply(
                shardId,
                false,
                timeout,
                System.nanoTime() - consensusReplyStartNanos,
                errorCodeName(error)
            );
            writeStageTelemetry.recordPutTotal(
                shardId,
                false,
                timeout,
                System.nanoTime() - writeStartNanos,
                errorCodeName(error)
            );
            emitWriteTelemetryIfDue();
            return response;
        } finally {
            releaseConsensusInflight(shardId);
            permit.release();
        }
    }

    public DeleteResponse delete(DeleteRequest request) {
        if (request.getKey().isEmpty()) {
            return DeleteResponse.newBuilder().setError(invalidArgument("key must not be empty")).build();
        }

        long writeStartNanos = System.nanoTime();
        totalWrites.incrementAndGet();
        refreshObservedLeaderSnapshotIfDue();

        ReplicaPartitionMap map = currentReplicaMap();
        int shardId = shardForKey(request.getKey().toByteArray(), map);
        List<String> replicas = map.replicasForShard(shardId);
        WriteLeaderSelection writeLeader = writeLeaderForShard(map, shardId, replicas);
        String leaderNodeId = writeLeader.targetLeaderNodeId();
        if (leaderNodeId == null || leaderNodeId.isBlank()) {
            DeleteResponse response = DeleteResponse.newBuilder().setError(unavailable("no leader for shard " + shardId)).build();
            writeStageTelemetry.recordDeleteTotal(
                shardId,
                false,
                isTimeoutError(response.getError()),
                System.nanoTime() - writeStartNanos,
                errorCodeName(response.getError())
            );
            emitWriteTelemetryIfDue();
            return response;
        }
        if (!localNodeId.equals(leaderNodeId)) {
            forwardedWrites.incrementAndGet();
            long forwardStartNanos = System.nanoTime();
            DeleteResponse response = rpcClient.delete(leaderNodeId, request);
            if (OBSERVED_LEADER_OVERRIDE_RETRY_ENABLED && shouldRetryOnMappedLeader(writeLeader, response)) {
                observedLeaderOverrideRetryAttempts.incrementAndGet();
                DeleteResponse retryResponse = rpcClient.delete(writeLeader.mappedLeaderNodeId(), request);
                if (!retryResponse.hasError()) {
                    observedLeaderOverrideRetrySuccess.incrementAndGet();
                }
                response = retryResponse;
            }
            boolean success = !response.hasError();
            writeStageTelemetry.recordForwardToLeader(
                shardId,
                success,
                isTimeoutError(response.getError()),
                System.nanoTime() - forwardStartNanos,
                errorCodeName(response.getError())
            );
            writeStageTelemetry.recordDeleteTotal(
                shardId,
                success,
                isTimeoutError(response.getError()),
                System.nanoTime() - writeStartNanos,
                errorCodeName(response.getError())
            );
            emitWriteTelemetryIfDue();
            return response;
        }

        WriteAdmissionPermit permit = acquireWriteAdmission(shardId, map);
        if (!permit.acquired()) {
            return rejectDeleteWithBackpressure(shardId, writeStartNanos);
        }
        long consensusReplyStartNanos = 0L;
        try {
            if (!acquireConsensusInflight(shardId)) {
                return rejectDeleteDueToConsensusInflightLimit(shardId, writeStartNanos);
            }
            writeStageTelemetry.recordConsensusSubmit(shardId, 0L);
            consensusReplyStartNanos = System.nanoTime();
            long version = writeWithRetry(() -> consensusEngine.delete(shardId, request.getKey().toByteArray()));
            lagTracker.recordLagMillis(shardId, localNodeId, 0L);
            writeStageTelemetry.recordConsensusReply(
                shardId,
                true,
                false,
                System.nanoTime() - consensusReplyStartNanos,
                ""
            );
            DeleteResponse response = DeleteResponse.newBuilder().setVersion(version).build();
            writeStageTelemetry.recordDeleteTotal(
                shardId,
                true,
                false,
                System.nanoTime() - writeStartNanos,
                ""
            );
            emitWriteTelemetryIfDue();
            return response;
        } catch (IllegalArgumentException e) {
            DeleteResponse response = DeleteResponse.newBuilder().setError(invalidArgument(e.getMessage())).build();
            writeStageTelemetry.recordConsensusReply(
                shardId,
                false,
                isTimeoutError(response.getError()),
                System.nanoTime() - consensusReplyStartNanos,
                errorCodeName(response.getError())
            );
            writeStageTelemetry.recordDeleteTotal(
                shardId,
                false,
                isTimeoutError(response.getError()),
                System.nanoTime() - writeStartNanos,
                errorCodeName(response.getError())
            );
            emitWriteTelemetryIfDue();
            return response;
        } catch (RuntimeException e) {
            boolean timeout = isTimeoutFailure(e);
            String consensusState = consensusStateForShard(shardId);
            Error error = timeout
                ? timeout("ratis delete fast-fail: " + safeMessage(e) + " " + consensusState)
                : unavailable("ratis delete failed: " + safeMessage(e) + " " + consensusState);
            DeleteResponse response = DeleteResponse.newBuilder().setError(error).build();
            writeStageTelemetry.recordConsensusReply(
                shardId,
                false,
                timeout,
                System.nanoTime() - consensusReplyStartNanos,
                errorCodeName(error)
            );
            writeStageTelemetry.recordDeleteTotal(
                shardId,
                false,
                timeout,
                System.nanoTime() - writeStartNanos,
                errorCodeName(error)
            );
            emitWriteTelemetryIfDue();
            return response;
        } finally {
            releaseConsensusInflight(shardId);
            permit.release();
        }
    }

    public long leaderFallbackReads() {
        return leaderFallbackReads.get();
    }

    public long partitionMapEpoch() {
        return currentReplicaMap().version().epoch();
    }

    public boolean tryUpdateReplicaMap(ReplicaPartitionMap candidate) {
        Objects.requireNonNull(candidate, "candidate must not be null");
        while (true) {
            ReplicaPartitionMap existing = replicaMapRef.get();
            if (candidate.version().epoch() <= existing.version().epoch()) {
                return false;
            }
            if (!isReplicaMapLayoutCompatible(existing, candidate)) {
                return false;
            }
            if (replicaMapRef.compareAndSet(existing, candidate)) {
                observedLeaderByShard.clear();
                shardWriteAdmissionSemaphores.clear();
                mappedLeaderShardCountEpoch = Long.MIN_VALUE;
                return true;
            }
        }
    }

    public Map<Integer, ShardWriteLoadSnapshot> shardWriteLoadSnapshot() {
        return writeStageTelemetry.putLoadByShardSnapshot();
    }

    private String readNodeIdFor(int shardId, List<String> replicas, String leaderNodeId) {
        if (leaderNodeId == null || leaderNodeId.isBlank()) {
            return "";
        }
        return switch (readMode) {
            case LEADER -> leaderNodeId;
            case LOCAL_REPLICA -> replicas.contains(localNodeId) ? localNodeId : leaderNodeId;
            case EVENTUAL -> {
                String freshReplica = replicaPicker.pickFreshFollower(
                    shardId,
                    leaderNodeId,
                    replicas,
                    lagTracker,
                    freshnessBudgetMillis
                );
                if (freshReplica != null && !freshReplica.isBlank()) {
                    yield freshReplica;
                }
                leaderFallbackReads.incrementAndGet();
                yield leaderNodeId;
            }
        };
    }

    private int shardForKey(byte[] key, ReplicaPartitionMap map) {
        return ringFor(map).shardForKey(key);
    }

    private ReplicaPartitionMap currentReplicaMap() {
        return replicaMapRef.get();
    }

    private static boolean isReplicaMapLayoutCompatible(ReplicaPartitionMap current, ReplicaPartitionMap candidate) {
        return current.shardCount() == candidate.shardCount()
            && current.virtualNodesPerShard() == candidate.virtualNodesPerShard();
    }

    private ConsistentHashRing ringFor(ReplicaPartitionMap map) {
        long epoch = map.version().epoch();
        ConsistentHashRing cachedRing = ring;
        if (cachedRing != null && ringEpoch == epoch) {
            return cachedRing;
        }

        synchronized (this) {
            if (ring != null && ringEpoch == epoch) {
                return ring;
            }

            Set<Integer> shardIds = new HashSet<>();
            for (int shard = 0; shard < map.shardCount(); shard++) {
                shardIds.add(shard);
            }

            ring = ConsistentHashRing.create(shardIds, map.virtualNodesPerShard());
            ringEpoch = epoch;
            return ring;
        }
    }

    private GetResponse invokeLocalGet(GetRequest request) {
        SyncResponseObserver<GetResponse> observer = new SyncResponseObserver<>();
        localService.get(request, observer);
        if (observer.error() != null || observer.value() == null || !observer.completed()) {
            return GetResponse.newBuilder().setError(internal("local get invocation failed")).build();
        }
        return observer.value();
    }

    private long writeWithRetry(ConsensusWrite write) {
        long deadlineNanos = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(MAX_CONSENSUS_WRITE_DURATION_MS);
        RuntimeException lastFailure = null;
        for (int attempt = 1; attempt <= MAX_CONSENSUS_WRITE_ATTEMPTS; attempt++) {
            try {
                return write.execute();
            } catch (RuntimeException e) {
                lastFailure = e;
                if (attempt == MAX_CONSENSUS_WRITE_ATTEMPTS) {
                    break;
                }
                if (System.nanoTime() >= deadlineNanos) {
                    break;
                }
                sleepBeforeRetry(attempt, deadlineNanos);
            }
        }
        throw lastFailure == null ? new IllegalStateException("consensus write failed without exception") : lastFailure;
    }

    private static void sleepBeforeRetry(int attempt, long deadlineNanos) {
        long delayMillis = CONSENSUS_RETRY_BACKOFF_MS * attempt;
        long remainingMillis = TimeUnit.NANOSECONDS.toMillis(deadlineNanos - System.nanoTime());
        if (remainingMillis <= 0) {
            return;
        }
        try {
            Thread.sleep(Math.min(delayMillis, remainingMillis));
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("interrupted while retrying consensus write", e);
        }
    }

    private WriteAdmissionPermit acquireWriteAdmission(int shardId, ReplicaPartitionMap map) {
        Semaphore global = writeAdmissionSemaphore;
        if (global == null) {
            return WriteAdmissionPermit.disabled();
        }

        if (!tryAcquirePermit(global)) {
            writeAdmissionWaitExhaustedCount.incrementAndGet();
            return WriteAdmissionPermit.rejected();
        }

        Semaphore shardSemaphore = shardAdmissionSemaphoreFor(shardId, map);
        if (shardSemaphore != null && !tryAcquirePermit(shardSemaphore)) {
            writeAdmissionWaitExhaustedCount.incrementAndGet();
            global.release();
            return WriteAdmissionPermit.rejected();
        }

        return WriteAdmissionPermit.acquired(global, shardSemaphore);
    }

    private boolean tryAcquirePermit(Semaphore semaphore) {
        try {
            if (writeAdmissionWaitMillis <= 0) {
                return semaphore.tryAcquire();
            }
            return semaphore.tryAcquire(writeAdmissionWaitMillis, TimeUnit.MILLISECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return false;
        }
    }

    private Semaphore shardAdmissionSemaphoreFor(int shardId, ReplicaPartitionMap map) {
        if (writeAdmissionSemaphore == null) {
            return null;
        }
        int limit = perShardAdmissionLimit(map);
        return shardWriteAdmissionSemaphores.compute(shardId, (ignored, existing) -> {
            if (existing == null || writeShardAdmissionLimit != limit) {
                return new Semaphore(limit, true);
            }
            return existing;
        });
    }

    private int perShardAdmissionLimit(ReplicaPartitionMap map) {
        int localLeaders = Math.max(1, currentLocalLeaderShardCount(map));
        int derived = writeGlobalInflightLimit / localLeaders;
        int limit = Math.max(writeShardInflightMin, derived);
        if (writeShardAdmissionLimit != limit) {
            writeShardAdmissionLimit = limit;
            shardWriteAdmissionSemaphores.clear();
        }
        return limit;
    }

    private int currentLocalLeaderShardCount(ReplicaPartitionMap map) {
        long observed = observedLocalLeaderShardCount.get();
        if (observed > 0) {
            return (int) observed;
        }
        return mappedLocalLeaderShardCount(map);
    }

    private int mappedLocalLeaderShardCount(ReplicaPartitionMap map) {
        long epoch = map.version().epoch();
        if (mappedLeaderShardCountEpoch == epoch) {
            return mappedLocalLeaderShardCount;
        }
        synchronized (this) {
            if (mappedLeaderShardCountEpoch == epoch) {
                return mappedLocalLeaderShardCount;
            }
            int count = 0;
            for (int shard = 0; shard < map.shardCount(); shard++) {
                if (localNodeId.equals(map.leaderForShard(shard))) {
                    count++;
                }
            }
            mappedLocalLeaderShardCount = Math.max(1, count);
            mappedLeaderShardCountEpoch = epoch;
            return mappedLocalLeaderShardCount;
        }
    }

    private boolean acquireConsensusInflight(int shardId) {
        Semaphore semaphore = consensusInflightByShard.computeIfAbsent(
            shardId,
            ignored -> new Semaphore(ratisMaxInflightPerShard, true)
        );
        if (tryAcquirePermit(semaphore)) {
            return true;
        }
        writeAdmissionWaitExhaustedCount.incrementAndGet();
        return false;
    }

    private void releaseConsensusInflight(int shardId) {
        Semaphore semaphore = consensusInflightByShard.get(shardId);
        if (semaphore == null) {
            return;
        }
        int maxPermits = ratisMaxInflightPerShard;
        if (semaphore.availablePermits() >= maxPermits) {
            return;
        }
        semaphore.release();
    }

    private PutResponse rejectPutWithBackpressure(int shardId, long writeStartNanos) {
        recordBackpressureRejection(shardId);
        PutResponse response = PutResponse.newBuilder().setError(backpressureError(shardId)).build();
        writeStageTelemetry.recordConsensusReply(shardId, false, false, 0L, ADMISSION_BACKPRESSURE_ERROR_CODE);
        writeStageTelemetry.recordPutTotal(
            shardId,
            false,
            false,
            System.nanoTime() - writeStartNanos,
            ADMISSION_BACKPRESSURE_ERROR_CODE
        );
        emitWriteTelemetryIfDue();
        return response;
    }

    private DeleteResponse rejectDeleteWithBackpressure(int shardId, long writeStartNanos) {
        recordBackpressureRejection(shardId);
        DeleteResponse response = DeleteResponse.newBuilder().setError(backpressureError(shardId)).build();
        writeStageTelemetry.recordConsensusReply(shardId, false, false, 0L, ADMISSION_BACKPRESSURE_ERROR_CODE);
        writeStageTelemetry.recordDeleteTotal(
            shardId,
            false,
            false,
            System.nanoTime() - writeStartNanos,
            ADMISSION_BACKPRESSURE_ERROR_CODE
        );
        emitWriteTelemetryIfDue();
        return response;
    }

    private PutResponse rejectPutDueToConsensusInflightLimit(int shardId, long writeStartNanos) {
        recordConsensusInflightRejection(shardId);
        PutResponse response = PutResponse.newBuilder().setError(consensusInflightLimitError(shardId)).build();
        writeStageTelemetry.recordConsensusReply(shardId, false, false, 0L, CONSENSUS_INFLIGHT_LIMIT_ERROR_CODE);
        writeStageTelemetry.recordPutTotal(
            shardId,
            false,
            false,
            System.nanoTime() - writeStartNanos,
            CONSENSUS_INFLIGHT_LIMIT_ERROR_CODE
        );
        emitWriteTelemetryIfDue();
        return response;
    }

    private DeleteResponse rejectDeleteDueToConsensusInflightLimit(int shardId, long writeStartNanos) {
        recordConsensusInflightRejection(shardId);
        DeleteResponse response = DeleteResponse.newBuilder().setError(consensusInflightLimitError(shardId)).build();
        writeStageTelemetry.recordConsensusReply(shardId, false, false, 0L, CONSENSUS_INFLIGHT_LIMIT_ERROR_CODE);
        writeStageTelemetry.recordDeleteTotal(
            shardId,
            false,
            false,
            System.nanoTime() - writeStartNanos,
            CONSENSUS_INFLIGHT_LIMIT_ERROR_CODE
        );
        emitWriteTelemetryIfDue();
        return response;
    }

    private void recordBackpressureRejection(int shardId) {
        writeBackpressureRejections.incrementAndGet();
        writeBackpressureRejectionsByShard.computeIfAbsent(shardId, ignored -> new LongAdder()).increment();
    }

    private void recordConsensusInflightRejection(int shardId) {
        consensusRejectDueToInflightLimit.incrementAndGet();
        consensusRejectDueToInflightLimitByShard.computeIfAbsent(shardId, ignored -> new LongAdder()).increment();
    }

    private Error backpressureError(int shardId) {
        long inflight = writeInflightCurrent();
        return unavailable(
            "write backpressure: shard="
                + shardId
                + " inflight="
                + inflight
                + " global_limit="
                + writeGlobalInflightLimit
                + " shard_limit="
                + writeShardAdmissionLimit
        );
    }

    private Error consensusInflightLimitError(int shardId) {
        return unavailable(
            "consensus inflight limit: shard="
                + shardId
                + " inflight="
                + consensusInflightCurrent(shardId)
                + " limit="
                + ratisMaxInflightPerShard
        );
    }

    private long writeInflightCurrent() {
        Semaphore semaphore = writeAdmissionSemaphore;
        if (semaphore == null) {
            return 0L;
        }
        int available = semaphore.availablePermits();
        long inflight = (long) writeGlobalInflightLimit - (long) available;
        return Math.max(0L, inflight);
    }

    private long consensusInflightCurrent(int shardId) {
        Semaphore semaphore = consensusInflightByShard.get(shardId);
        if (semaphore == null) {
            return 0L;
        }
        int available = semaphore.availablePermits();
        long inflight = (long) ratisMaxInflightPerShard - (long) available;
        return Math.max(0L, inflight);
    }

    private Map<Integer, Long> consensusInflightByShardSnapshot() {
        TreeMap<Integer, Long> snapshot = new TreeMap<>();
        for (Map.Entry<Integer, Semaphore> entry : consensusInflightByShard.entrySet()) {
            int available = entry.getValue().availablePermits();
            long inflight = Math.max(0L, (long) ratisMaxInflightPerShard - (long) available);
            if (inflight > 0) {
                snapshot.put(entry.getKey(), inflight);
            }
        }
        return snapshot;
    }

    private void emitWriteTelemetryIfDue() {
        long now = System.nanoTime();
        long last = lastWriteTelemetryEmitNanos.get();
        if (now - last < WRITE_TELEMETRY_EMIT_INTERVAL_NANOS) {
            return;
        }
        if (!lastWriteTelemetryEmitNanos.compareAndSet(last, now)) {
            return;
        }
        long total = totalWrites.get();
        long forwarded = forwardedWrites.get();
        double forwardHopRatio = total <= 0 ? 0.0 : (double) forwarded / (double) total;
        System.out.println(
            "notdynamo_write_stage_telemetry "
                + writeStageTelemetry.snapshotJson(
                    localNodeId,
                    observedLeaderOverrideWrites.get(),
                    observedLeaderLookupFailures.get(),
                    observedLeaderLookupSkippedNonReplica.get(),
                    observedLeaderOverrideRetryAttempts.get(),
                    observedLeaderOverrideRetrySuccess.get(),
                    writeBackpressureRejections.get(),
                    writeBackpressureRejectionsByShard,
                    writeAdmissionWaitExhaustedCount.get(),
                    writeGlobalInflightLimit,
                    writeShardInflightMin,
                    writeShardAdmissionLimit,
                    writeInflightCurrent(),
                    consensusRejectDueToInflightLimit.get(),
                    consensusRejectDueToInflightLimitByShard,
                    consensusInflightByShardSnapshot(),
                    total,
                    forwarded,
                    forwardHopRatio,
                    leaderSnapshotRefreshFailures.get()
                )
        );
    }

    private WriteLeaderSelection writeLeaderForShard(ReplicaPartitionMap map, int shardId, List<String> replicas) {
        String mappedLeader = map.leaderForShard(shardId);
        String observedLeader = observedLeaderForShard(shardId, replicas);
        if (observedLeader.isBlank()) {
            return new WriteLeaderSelection(mappedLeader, mappedLeader, false);
        }
        if (replicas != null && !replicas.isEmpty() && !replicas.contains(observedLeader)) {
            return new WriteLeaderSelection(mappedLeader, mappedLeader, false);
        }
        if (mappedLeader == null || mappedLeader.isBlank()) {
            return new WriteLeaderSelection(observedLeader, mappedLeader, false);
        }
        boolean override = false;
        if (!observedLeader.equals(mappedLeader)) {
            observedLeaderOverrideWrites.incrementAndGet();
            override = true;
        }
        return new WriteLeaderSelection(observedLeader, mappedLeader, override);
    }

    private String observedLeaderForShard(int shardId, List<String> replicas) {
        if (replicas == null || !replicas.contains(localNodeId)) {
            observedLeaderLookupSkippedNonReplica.incrementAndGet();
            return "";
        }
        long now = System.nanoTime();
        CachedLeader cached = observedLeaderByShard.get(shardId);
        if (cached != null && now - cached.observedAtNanos() <= cached.ttlNanos()) {
            return cached.leaderNodeId();
        }

        try {
            String leader = consensusEngine.leaderIdForShard(shardId);
            String normalized = leader == null ? "" : leader.trim();
            observedLeaderByShard.put(shardId, new CachedLeader(normalized, now, OBSERVED_LEADER_CACHE_TTL_NANOS));
            return normalized;
        } catch (RuntimeException e) {
            observedLeaderLookupFailures.incrementAndGet();
            observedLeaderByShard.put(shardId, new CachedLeader("", now, OBSERVED_LEADER_FAILURE_BACKOFF_NANOS));
            return cached == null ? "" : cached.leaderNodeId();
        }
    }

    private void refreshObservedLeaderSnapshotIfDue() {
        long now = System.nanoTime();
        long last = lastLeaderSnapshotRefreshNanos.get();
        if (now - last < LEADER_SNAPSHOT_REFRESH_INTERVAL_NANOS) {
            return;
        }
        if (!lastLeaderSnapshotRefreshNanos.compareAndSet(last, now)) {
            return;
        }

        try {
            Map<Integer, String> snapshot = consensusEngine.leaderIdSnapshot();
            if (snapshot == null || snapshot.isEmpty()) {
                return;
            }
            long localLeaderCount = 0L;
            for (Map.Entry<Integer, String> entry : snapshot.entrySet()) {
                int shardId = entry.getKey();
                String leaderNodeId = entry.getValue();
                String normalized = leaderNodeId == null ? "" : leaderNodeId.trim();
                observedLeaderByShard.put(shardId, new CachedLeader(normalized, now, OBSERVED_LEADER_CACHE_TTL_NANOS));
                if (localNodeId.equals(normalized)) {
                    localLeaderCount++;
                }
            }
            if (localLeaderCount > 0) {
                observedLocalLeaderShardCount.set(localLeaderCount);
            }
        } catch (RuntimeException e) {
            observedLeaderLookupFailures.incrementAndGet();
            leaderSnapshotRefreshFailures.incrementAndGet();
        }
    }

    private static boolean shouldRetryOnMappedLeader(WriteLeaderSelection writeLeader, PutResponse response) {
        if (response == null || !response.hasError()) {
            return false;
        }
        if (!writeLeader.usedObservedOverride()) {
            return false;
        }
        String mappedLeader = writeLeader.mappedLeaderNodeId();
        String targetLeader = writeLeader.targetLeaderNodeId();
        if (mappedLeader == null || mappedLeader.isBlank()) {
            return false;
        }
        if (mappedLeader.equals(targetLeader)) {
            return false;
        }
        StatusCode errorCode = response.getError().getCode();
        return errorCode == StatusCode.STATUS_CODE_INTERNAL || errorCode == StatusCode.STATUS_CODE_UNAVAILABLE;
    }

    private static boolean shouldRetryOnMappedLeader(WriteLeaderSelection writeLeader, DeleteResponse response) {
        if (response == null || !response.hasError()) {
            return false;
        }
        if (!writeLeader.usedObservedOverride()) {
            return false;
        }
        String mappedLeader = writeLeader.mappedLeaderNodeId();
        String targetLeader = writeLeader.targetLeaderNodeId();
        if (mappedLeader == null || mappedLeader.isBlank()) {
            return false;
        }
        if (mappedLeader.equals(targetLeader)) {
            return false;
        }
        StatusCode errorCode = response.getError().getCode();
        return errorCode == StatusCode.STATUS_CODE_INTERNAL || errorCode == StatusCode.STATUS_CODE_UNAVAILABLE;
    }

    private static boolean isTimeoutFailure(Throwable throwable) {
        Throwable current = throwable;
        while (current != null) {
            String message = current.getMessage();
            if (message != null) {
                String normalized = message.toLowerCase();
                if (normalized.contains("timed out") || normalized.contains("timeout") || normalized.contains("deadline")) {
                    return true;
                }
            }
            current = current.getCause();
        }
        return false;
    }

    private static boolean isTimeoutError(Error error) {
        return error != null && error.getCode() == StatusCode.STATUS_CODE_TIMEOUT;
    }

    private static String errorCodeName(Error error) {
        if (error == null) {
            return "";
        }
        String base = error.getCode().name();
        String grpcCode = grpcCodeFromMessage(error.getMessage());
        if (grpcCode.isBlank()) {
            return base;
        }
        return base + "/grpc=" + grpcCode;
    }

    private static String grpcCodeFromMessage(String message) {
        if (message == null || message.isBlank()) {
            return "";
        }
        if (!message.startsWith("grpc=")) {
            return "";
        }
        int space = message.indexOf(' ');
        String code = space > 5 ? message.substring(5, space) : message.substring(5);
        String normalized = code.trim().toUpperCase(Locale.ROOT);
        if (normalized.isEmpty()) {
            return "";
        }
        StringBuilder out = new StringBuilder(normalized.length());
        for (int i = 0; i < normalized.length(); i++) {
            char ch = normalized.charAt(i);
            if ((ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9') || ch == '_' || ch == '-') {
                out.append(ch);
            } else {
                out.append('_');
            }
        }
        return out.toString();
    }

    private static String validateNodeId(String nodeId, String label) {
        if (nodeId == null || nodeId.isBlank()) {
            throw new IllegalArgumentException(label + " must not be blank");
        }
        return nodeId;
    }

    private static Error invalidArgument(String message) {
        return Error.newBuilder().setCode(StatusCode.STATUS_CODE_INVALID_ARGUMENT).setMessage(message).build();
    }

    private static Error unavailable(String message) {
        return Error.newBuilder().setCode(StatusCode.STATUS_CODE_UNAVAILABLE).setMessage(message).build();
    }

    private static Error timeout(String message) {
        return Error.newBuilder().setCode(StatusCode.STATUS_CODE_TIMEOUT).setMessage(message).build();
    }

    private static Error internal(String message) {
        return Error.newBuilder().setCode(StatusCode.STATUS_CODE_INTERNAL).setMessage(message).build();
    }

    private static String safeMessage(Throwable throwable) {
        String message = throwable.getMessage();
        if (message == null || message.isBlank()) {
            return throwable.getClass().getSimpleName();
        }
        return message;
    }

    private String consensusStateForShard(int shardId) {
        try {
            String leader = consensusEngine.leaderIdForShard(shardId);
            long lastApplied = consensusEngine.lastAppliedIndexForShard(shardId);
            String normalizedLeader = (leader == null || leader.isBlank()) ? "<none>" : leader;
            return "[shard=" + shardId + " leader=" + normalizedLeader + " lastApplied=" + lastApplied + "]";
        } catch (RuntimeException e) {
            return "[shard=" + shardId + " leader=<unknown> lastApplied=<unknown> reason=" + safeMessage(e) + "]";
        }
    }

    @FunctionalInterface
    private interface ConsensusWrite {
        long execute();
    }

    private static final class WriteStageTelemetry {
        private final StageMetrics forwardToLeader = new StageMetrics();
        private final StageMetrics consensusSubmit = new StageMetrics();
        private final StageMetrics consensusReply = new StageMetrics();
        private final StageMetrics putTotal = new StageMetrics();
        private final StageMetrics deleteTotal = new StageMetrics();
        private final ConcurrentHashMap<Integer, LongAdder> forwardErrorByShard = new ConcurrentHashMap<>();
        private final ConcurrentHashMap<Integer, LongAdder> consensusReplyErrorByShard = new ConcurrentHashMap<>();
        private final ConcurrentHashMap<Integer, LongAdder> putTotalByShard = new ConcurrentHashMap<>();
        private final ConcurrentHashMap<Integer, LongAdder> putTimeoutByShard = new ConcurrentHashMap<>();
        private final ConcurrentHashMap<String, LongAdder> errorCodeByStage = new ConcurrentHashMap<>();

        void recordForwardToLeader(int shardId, boolean success, boolean timeout, long latencyNanos, String errorCode) {
            forwardToLeader.record(success, timeout, latencyNanos);
            if (!success) {
                forwardErrorByShard.computeIfAbsent(shardId, ignored -> new LongAdder()).increment();
                incrementErrorCode("forward", errorCode);
            }
        }

        void recordConsensusSubmit(int shardId, long latencyNanos) {
            consensusSubmit.record(true, false, latencyNanos);
        }

        void recordConsensusReply(int shardId, boolean success, boolean timeout, long latencyNanos, String errorCode) {
            consensusReply.record(success, timeout, latencyNanos);
            if (!success) {
                consensusReplyErrorByShard.computeIfAbsent(shardId, ignored -> new LongAdder()).increment();
                incrementErrorCode("consensus_reply", errorCode);
            }
        }

        void recordPutTotal(int shardId, boolean success, boolean timeout, long latencyNanos, String errorCode) {
            putTotal.record(success, timeout, latencyNanos);
            putTotalByShard.computeIfAbsent(shardId, ignored -> new LongAdder()).increment();
            if (timeout) {
                putTimeoutByShard.computeIfAbsent(shardId, ignored -> new LongAdder()).increment();
            }
            if (!success) {
                incrementErrorCode("put_total", errorCode);
            }
        }

        void recordDeleteTotal(int shardId, boolean success, boolean timeout, long latencyNanos, String errorCode) {
            deleteTotal.record(success, timeout, latencyNanos);
            if (!success) {
                incrementErrorCode("delete_total", errorCode);
            }
        }

        String snapshotJson(
            String nodeId,
            long observedLeaderOverrideCount,
            long observedLeaderLookupFailureCount,
            long observedLeaderLookupSkippedNonReplicaCount,
            long observedLeaderOverrideRetryAttemptCount,
            long observedLeaderOverrideRetrySuccessCount,
            long writeBackpressureRejectionCount,
            ConcurrentHashMap<Integer, LongAdder> writeBackpressureRejectionsByShard,
            long writeAdmissionWaitExhaustedCount,
            int writeGlobalInflightLimit,
            int writeShardInflightMin,
            int writeShardAdmissionLimit,
            long writeInflightCurrent,
            long consensusInflightRejectionCount,
            ConcurrentHashMap<Integer, LongAdder> consensusInflightRejectByShard,
            Map<Integer, Long> consensusInflightByShard,
            long totalWrites,
            long forwardedWrites,
            double forwardHopRatio,
            long leaderSnapshotRefreshFailureCount
        ) {
            StringBuilder out = new StringBuilder();
            out.append('{');
            out.append("\"node\":\"").append(escapeJson(nodeId)).append("\",");
            out.append("\"observed_leader_override_writes\":").append(observedLeaderOverrideCount).append(',');
            out.append("\"observed_leader_lookup_failures\":").append(observedLeaderLookupFailureCount).append(',');
            out.append("\"observed_leader_lookup_skipped_non_replica\":").append(observedLeaderLookupSkippedNonReplicaCount).append(',');
            out.append("\"observed_leader_override_retry_attempts\":").append(observedLeaderOverrideRetryAttemptCount).append(',');
            out.append("\"observed_leader_override_retry_success\":").append(observedLeaderOverrideRetrySuccessCount).append(',');
            out.append("\"observed_leader_snapshot_refresh_failures\":").append(leaderSnapshotRefreshFailureCount).append(',');
            out.append("\"write_backpressure_rejections\":").append(writeBackpressureRejectionCount).append(',');
            out.append("\"write_backpressure_rejections_by_shard\":").append(toJsonByShard(writeBackpressureRejectionsByShard)).append(',');
            out.append("\"write_admission_wait_exhausted_count\":").append(writeAdmissionWaitExhaustedCount).append(',');
            out.append("\"write_inflight_limit\":").append(writeGlobalInflightLimit).append(',');
            out.append("\"write_shard_inflight_min\":").append(writeShardInflightMin).append(',');
            out.append("\"write_shard_inflight_limit\":").append(writeShardAdmissionLimit).append(',');
            out.append("\"write_inflight_current\":").append(writeInflightCurrent).append(',');
            out.append("\"consensus_reject_due_to_inflight_limit\":").append(consensusInflightRejectionCount).append(',');
            out.append("\"consensus_reject_due_to_inflight_limit_by_shard\":")
                .append(toJsonByShard(consensusInflightRejectByShard))
                .append(',');
            out.append("\"consensus_inflight_by_shard\":").append(toJsonByShardLong(consensusInflightByShard)).append(',');
            out.append("\"write_total_requests\":").append(totalWrites).append(',');
            out.append("\"write_forwarded_requests\":").append(forwardedWrites).append(',');
            out.append("\"forward_hop_ratio\":").append(formatDouble(forwardHopRatio)).append(',');
            out.append("\"forward_to_leader\":").append(forwardToLeader.snapshotJson()).append(',');
            out.append("\"consensus_submit\":").append(consensusSubmit.snapshotJson()).append(',');
            out.append("\"consensus_reply\":").append(consensusReply.snapshotJson()).append(',');
            out.append("\"put_total\":").append(putTotal.snapshotJson()).append(',');
            out.append("\"delete_total\":").append(deleteTotal.snapshotJson()).append(',');
            out.append("\"forward_error_by_shard\":").append(toJsonByShard(forwardErrorByShard)).append(',');
            out.append("\"consensus_reply_error_by_shard\":").append(toJsonByShard(consensusReplyErrorByShard)).append(',');
            out.append("\"put_total_by_shard\":").append(toJsonByShard(putTotalByShard)).append(',');
            out.append("\"put_timeout_by_shard\":").append(toJsonByShard(putTimeoutByShard)).append(',');
            out.append("\"error_code_counts\":").append(toJsonByCode(errorCodeByStage));
            out.append('}');
            return out.toString();
        }

        Map<Integer, ShardWriteLoadSnapshot> putLoadByShardSnapshot() {
            TreeMap<Integer, ShardWriteLoadSnapshot> snapshot = new TreeMap<>();
            TreeMap<Integer, LongAdder> totals = new TreeMap<>(putTotalByShard);
            for (Map.Entry<Integer, LongAdder> entry : totals.entrySet()) {
                int shardId = entry.getKey();
                long putTotalCount = entry.getValue().sum();
                if (putTotalCount <= 0) {
                    continue;
                }
                long timeoutCount = 0L;
                LongAdder timeoutAdder = putTimeoutByShard.get(shardId);
                if (timeoutAdder != null) {
                    timeoutCount = timeoutAdder.sum();
                }
                snapshot.put(shardId, new ShardWriteLoadSnapshot(putTotalCount, Math.max(0L, timeoutCount)));
            }
            return snapshot;
        }

        private void incrementErrorCode(String stage, String errorCode) {
            String normalizedCode = (errorCode == null || errorCode.isBlank()) ? "UNKNOWN" : errorCode;
            String key = stage + ":" + normalizedCode;
            errorCodeByStage.computeIfAbsent(key, ignored -> new LongAdder()).increment();
        }

        private static String toJsonByShard(ConcurrentHashMap<Integer, LongAdder> values) {
            TreeMap<Integer, LongAdder> sorted = new TreeMap<>(values);
            StringBuilder out = new StringBuilder();
            out.append('{');
            boolean first = true;
            for (Map.Entry<Integer, LongAdder> entry : sorted.entrySet()) {
                long count = entry.getValue().sum();
                if (count <= 0) {
                    continue;
                }
                if (!first) {
                    out.append(',');
                }
                out.append('"').append(entry.getKey()).append('"').append(':').append(count);
                first = false;
            }
            out.append('}');
            return out.toString();
        }

        private static String toJsonByCode(ConcurrentHashMap<String, LongAdder> values) {
            TreeMap<String, LongAdder> sorted = new TreeMap<>(values);
            StringBuilder out = new StringBuilder();
            out.append('{');
            boolean first = true;
            for (Map.Entry<String, LongAdder> entry : sorted.entrySet()) {
                long count = entry.getValue().sum();
                if (count <= 0) {
                    continue;
                }
                if (!first) {
                    out.append(',');
                }
                out.append('"').append(escapeJson(entry.getKey())).append('"').append(':').append(count);
                first = false;
            }
            out.append('}');
            return out.toString();
        }

        private static String toJsonByShardLong(Map<Integer, Long> values) {
            if (values == null || values.isEmpty()) {
                return "{}";
            }
            TreeMap<Integer, Long> sorted = new TreeMap<>(values);
            StringBuilder out = new StringBuilder();
            out.append('{');
            boolean first = true;
            for (Map.Entry<Integer, Long> entry : sorted.entrySet()) {
                long count = entry.getValue() == null ? 0L : entry.getValue();
                if (count <= 0) {
                    continue;
                }
                if (!first) {
                    out.append(',');
                }
                out.append('"').append(entry.getKey()).append('"').append(':').append(count);
                first = false;
            }
            out.append('}');
            return out.toString();
        }

        private static String escapeJson(String value) {
            return value.replace("\\", "\\\\").replace("\"", "\\\"");
        }

        private static String formatDouble(double value) {
            return String.format(Locale.ROOT, "%.6f", value);
        }
    }

    private static final class StageMetrics {
        private final LongAdder successCount = new LongAdder();
        private final LongAdder errorCount = new LongAdder();
        private final LongAdder timeoutCount = new LongAdder();
        private final LongAdder latencyNanosSum = new LongAdder();
        private final LongAccumulator latencyNanosMax = new LongAccumulator(Long::max, 0L);

        void record(boolean success, boolean timeout, long latencyNanos) {
            if (latencyNanos < 0) {
                latencyNanos = 0;
            }
            if (success) {
                successCount.increment();
            } else {
                errorCount.increment();
                if (timeout) {
                    timeoutCount.increment();
                }
            }
            latencyNanosSum.add(latencyNanos);
            latencyNanosMax.accumulate(latencyNanos);
        }

        String snapshotJson() {
            long success = successCount.sum();
            long errors = errorCount.sum();
            long timeouts = timeoutCount.sum();
            long count = success + errors;
            double latencyAvgMs = count == 0 ? 0.0 : nanosToMillis((double) latencyNanosSum.sum() / (double) count);
            double latencyMaxMs = nanosToMillis((double) latencyNanosMax.get());
            return "{"
                + "\"success\":" + success + ","
                + "\"error\":" + errors + ","
                + "\"timeout\":" + timeouts + ","
                + "\"latency_ms_avg\":" + formatDouble(latencyAvgMs) + ","
                + "\"latency_ms_max\":" + formatDouble(latencyMaxMs)
                + "}";
        }

        private static double nanosToMillis(double nanos) {
            return nanos / 1_000_000.0;
        }

        private static String formatDouble(double value) {
            return String.format(java.util.Locale.ROOT, "%.3f", value);
        }
    }

    public enum ReadMode {
        LOCAL_REPLICA,
        EVENTUAL,
        LEADER
    }

    public record ShardWriteLoadSnapshot(long putTotalCount, long putTimeoutCount) {
        public ShardWriteLoadSnapshot {
            if (putTotalCount < 0) {
                throw new IllegalArgumentException("putTotalCount must be >= 0");
            }
            if (putTimeoutCount < 0) {
                throw new IllegalArgumentException("putTimeoutCount must be >= 0");
            }
        }
    }

    private record CachedLeader(String leaderNodeId, long observedAtNanos, long ttlNanos) {}

    private record WriteLeaderSelection(String targetLeaderNodeId, String mappedLeaderNodeId, boolean usedObservedOverride) {}

    private record WriteAdmissionPermit(boolean acquired, Semaphore globalSemaphore, Semaphore shardSemaphore) {
        private static WriteAdmissionPermit disabled() {
            return new WriteAdmissionPermit(true, null, null);
        }

        private static WriteAdmissionPermit rejected() {
            return new WriteAdmissionPermit(false, null, null);
        }

        private static WriteAdmissionPermit acquired(Semaphore globalSemaphore, Semaphore shardSemaphore) {
            return new WriteAdmissionPermit(true, globalSemaphore, shardSemaphore);
        }

        private void release() {
            if (!acquired) {
                return;
            }
            if (shardSemaphore != null) {
                shardSemaphore.release();
            }
            if (globalSemaphore != null) {
                globalSemaphore.release();
            }
        }
    }
}
