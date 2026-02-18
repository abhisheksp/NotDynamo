package io.notdynamo.ratis;

import io.notdynamo.storage.KeyValueStore;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import org.apache.ratis.RaftConfigKeys;
import org.apache.ratis.client.RaftClient;
import org.apache.ratis.client.RaftClientConfigKeys;
import org.apache.ratis.conf.RaftProperties;
import org.apache.ratis.netty.NettyConfigKeys;
import org.apache.ratis.protocol.ClientId;
import org.apache.ratis.protocol.GroupManagementRequest;
import org.apache.ratis.protocol.Message;
import org.apache.ratis.protocol.RaftClientReply;
import org.apache.ratis.protocol.RaftGroup;
import org.apache.ratis.protocol.RaftGroupId;
import org.apache.ratis.protocol.RaftPeer;
import org.apache.ratis.protocol.RaftPeerId;
import org.apache.ratis.rpc.SupportedRpcType;
import org.apache.ratis.server.RaftServer;
import org.apache.ratis.server.RaftServerConfigKeys;
import org.apache.ratis.server.storage.RaftStorage;
import org.apache.ratis.statemachine.StateMachine;
import org.apache.ratis.statemachine.TransactionContext;
import org.apache.ratis.statemachine.impl.BaseStateMachine;
import org.apache.ratis.thirdparty.com.google.protobuf.ByteString;
import org.apache.ratis.util.TimeDuration;

public final class RatisMultiShardConsensusEngine implements ConsensusEngine {
    private final RaftServer server;
    private final Map<Integer, ShardRuntime> runtimeByShard;
    private final long requestTimeoutMillis;

    private RatisMultiShardConsensusEngine(
        RaftServer server,
        Map<Integer, ShardRuntime> runtimeByShard,
        long requestTimeoutMillis
    ) {
        this.server = Objects.requireNonNull(server, "server must not be null");
        this.runtimeByShard = Map.copyOf(runtimeByShard);
        if (this.runtimeByShard.isEmpty()) {
            throw new IllegalArgumentException("runtimeByShard must not be empty");
        }
        if (requestTimeoutMillis <= 0) {
            throw new IllegalArgumentException("requestTimeoutMillis must be > 0");
        }
        this.requestTimeoutMillis = requestTimeoutMillis;
    }

    public static RatisMultiShardConsensusEngine open(
        RatisMultiShardConsensusEngineConfig config,
        KeyValueStore keyValueStore
    ) {
        Objects.requireNonNull(config, "config must not be null");
        Objects.requireNonNull(keyValueStore, "keyValueStore must not be null");
        ensureStorageDir(config.storageDir());

        String localAddress = normalizeAddress(config.addressResolver().apply(config.localNodeId()), config.localNodeId());
        HostPort localHostPort = parseHostPort(localAddress, config.localNodeId());
        RaftProperties properties = raftProperties(config, localHostPort);

        Map<Integer, ShardRuntimePlan> plansByShard = buildPlans(config);
        List<ShardRuntimePlan> localPlans = new ArrayList<>();
        for (ShardRuntimePlan plan : plansByShard.values()) {
            if (plan.localMember()) {
                localPlans.add(plan);
            }
        }
        if (localPlans.isEmpty()) {
            throw new IllegalStateException("local node " + config.localNodeId() + " is not a member of any shard group");
        }

        Map<RaftGroupId, StateMachine> stateMachineByGroupId = new LinkedHashMap<>();
        StateMachine.Registry stateMachineRegistry = groupId ->
            stateMachineByGroupId.computeIfAbsent(groupId, ignored -> new KeyValueStateMachine(keyValueStore));

        RaftServer server = null;
        Map<Integer, ShardRuntime> runtimeByShard = new LinkedHashMap<>();
        try {
            ShardRuntimePlan initial = localPlans.get(0);
            server = startServer(config, initial.group(), properties, stateMachineRegistry, RaftStorage.StartupOption.RECOVER);
            addRemainingLocalGroups(server, config.localNodeId(), localPlans, initial.group().getGroupId());
            for (ShardRuntimePlan plan : plansByShard.values()) {
                RaftClient client = RaftClient.newBuilder()
                    .setRaftGroup(plan.group())
                    .setProperties(properties)
                    .build();
                runtimeByShard.put(plan.shardId(), new ShardRuntime(plan.shardId(), plan.groupName(), plan.group(), client));
            }
            return new RatisMultiShardConsensusEngine(server, runtimeByShard, config.requestTimeoutMillis());
        } catch (RuntimeException | IOException e) {
            closeClients(runtimeByShard.values());
            closeServerQuietly(server);
            throw new IllegalStateException("failed to start multi-shard ratis consensus engine", e);
        }
    }

    @Override
    public long put(byte[] key, byte[] value) {
        return put(defaultShardId(), key, value);
    }

    @Override
    public long put(int shardId, byte[] key, byte[] value) {
        return submit(shardId, RatisCommandCodec.encodePut(key, value));
    }

    @Override
    public long delete(byte[] key) {
        return delete(defaultShardId(), key);
    }

    @Override
    public long delete(int shardId, byte[] key) {
        return submit(shardId, RatisCommandCodec.encodeDelete(key));
    }

    public String leaderIdForShard(int shardId) {
        ShardRuntime runtime = runtimeForShard(shardId);
        try {
            RaftServer.Division division = server.getDivision(runtime.group().getGroupId());
            if (division == null || division.getInfo().getLeaderId() == null) {
                return "";
            }
            return division.getInfo().getLeaderId().toString();
        } catch (IOException e) {
            throw new IllegalStateException("failed to query leader for shard " + shardId, e);
        }
    }

    public long lastAppliedIndexForShard(int shardId) {
        ShardRuntime runtime = runtimeForShard(shardId);
        try {
            RaftServer.Division division = server.getDivision(runtime.group().getGroupId());
            if (division == null) {
                return 0L;
            }
            return Math.max(0L, division.getInfo().getLastAppliedIndex());
        } catch (IOException e) {
            throw new IllegalStateException("failed to query lastAppliedIndex for shard " + shardId, e);
        }
    }

    public boolean transferLeadership(int shardId, String newLeaderNodeId, long timeoutMillis) {
        if (newLeaderNodeId == null || newLeaderNodeId.isBlank()) {
            throw new IllegalArgumentException("newLeaderNodeId must not be blank");
        }
        if (timeoutMillis <= 0) {
            throw new IllegalArgumentException("timeoutMillis must be > 0");
        }

        ShardRuntime runtime = runtimeForShard(shardId);
        try {
            RaftClientReply reply = runtime.client().admin().transferLeadership(RaftPeerId.valueOf(newLeaderNodeId), timeoutMillis);
            return reply != null && reply.isSuccess();
        } catch (IOException e) {
            throw new IllegalStateException("failed to transfer leadership for shard " + shardId, e);
        }
    }

    @Override
    public void close() {
        RuntimeException first = null;
        try {
            closeClients(runtimeByShard.values());
        } catch (RuntimeException e) {
            first = e;
        }
        try {
            server.close();
        } catch (IOException e) {
            if (first == null) {
                first = new RuntimeException("failed to close ratis server", e);
            } else {
                first.addSuppressed(e);
            }
        }
        if (first != null) {
            throw first;
        }
    }

    private long submit(int shardId, byte[] commandBytes) {
        ShardRuntime runtime = runtimeForShard(shardId);
        try {
            CompletableFuture<RaftClientReply> sendFuture = runtime.client().async().send(Message.valueOf(ByteString.copyFrom(commandBytes)));
            RaftClientReply reply = awaitReply(sendFuture);
            if (reply == null) {
                throw new IllegalStateException("ratis reply is null for shard " + shardId);
            }
            if (!reply.isSuccess()) {
                if (reply.getException() != null) {
                    throw new IllegalStateException(
                        "ratis write failed for shard " + shardId + ": " + reply.getException().getMessage(),
                        reply.getException()
                    );
                }
                throw new IllegalStateException("ratis write failed for shard " + shardId + " without exception");
            }

            Message message = reply.getMessage();
            if (message == null || message.getContent() == null) {
                throw new IllegalStateException("ratis reply message missing for shard " + shardId);
            }
            String versionText = new String(message.getContent().toByteArray(), StandardCharsets.UTF_8);
            return Long.parseLong(versionText);
        } catch (NumberFormatException e) {
            throw new IllegalStateException("invalid version returned from ratis state machine", e);
        }
    }

    private RaftClientReply awaitReply(CompletableFuture<RaftClientReply> sendFuture) {
        try {
            return sendFuture.get(requestTimeoutMillis, TimeUnit.MILLISECONDS);
        } catch (TimeoutException e) {
            throw new IllegalStateException("ratis write timed out after " + requestTimeoutMillis + "ms", e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("interrupted while waiting for ratis write", e);
        } catch (ExecutionException e) {
            Throwable cause = e.getCause();
            if (cause instanceof IOException ioException) {
                throw new IllegalStateException("ratis write I/O failure: " + rootMessage(ioException), ioException);
            }
            if (cause instanceof RuntimeException runtimeException) {
                throw runtimeException;
            }
            throw new IllegalStateException("ratis write failed", cause == null ? e : cause);
        }
    }

    private int defaultShardId() {
        return runtimeByShard.keySet().stream().min(Integer::compareTo).orElseThrow();
    }

    private ShardRuntime runtimeForShard(int shardId) {
        ShardRuntime runtime = runtimeByShard.get(shardId);
        if (runtime == null) {
            throw new IllegalArgumentException("unknown shardId " + shardId);
        }
        return runtime;
    }

    private static Map<Integer, ShardRuntimePlan> buildPlans(RatisMultiShardConsensusEngineConfig config) {
        Map<Integer, ShardRuntimePlan> plansByShard = new LinkedHashMap<>();
        for (ShardRaftGroupConfig groupConfig : config.shardGroups()) {
            List<RaftPeer> peers = new ArrayList<>(groupConfig.peerNodeIds().size());
            for (String peerNodeId : groupConfig.peerNodeIds()) {
                peers.add(
                    RaftPeer.newBuilder()
                        .setId(RaftPeerId.valueOf(peerNodeId))
                        .setAddress(normalizeAddress(config.addressResolver().apply(peerNodeId), peerNodeId))
                        .build()
                );
            }
            RaftGroupId groupId = RaftGroupId.valueOf(
                UUID.nameUUIDFromBytes(groupConfig.groupName().getBytes(StandardCharsets.UTF_8))
            );
            RaftGroup group = RaftGroup.valueOf(groupId, peers);
            boolean localMember = groupConfig.peerNodeIds().contains(config.localNodeId());
            plansByShard.put(
                groupConfig.shardId(),
                new ShardRuntimePlan(groupConfig.shardId(), groupConfig.groupName(), group, localMember)
            );
        }
        return plansByShard;
    }

    private static void addRemainingLocalGroups(
        RaftServer server,
        String localNodeId,
        List<ShardRuntimePlan> localPlans,
        RaftGroupId initialGroupId
    ) throws IOException {
        long callId = 1L;
        RaftPeerId localPeerId = RaftPeerId.valueOf(localNodeId);
        ClientId clientId = ClientId.randomId();
        for (ShardRuntimePlan plan : localPlans) {
            if (plan.group().getGroupId().equals(initialGroupId)) {
                continue;
            }
            GroupManagementRequest request = GroupManagementRequest.newAdd(clientId, localPeerId, callId++, plan.group());
            RaftClientReply reply = server.groupManagement(request);
            if (reply == null || !reply.isSuccess()) {
                throw new IllegalStateException("failed to add shard group " + plan.groupName() + " via group management");
            }
        }
    }

    private static RaftServer startServer(
        RatisMultiShardConsensusEngineConfig config,
        RaftGroup initialGroup,
        RaftProperties properties,
        StateMachine.Registry stateMachineRegistry,
        RaftStorage.StartupOption startupOption
    ) throws IOException {
        RaftServer server = RaftServer.newBuilder()
            .setServerId(RaftPeerId.valueOf(config.localNodeId()))
            .setGroup(initialGroup)
            .setOption(startupOption)
            .setProperties(properties)
            .setStateMachineRegistry(stateMachineRegistry)
            .build();
        server.start();
        return server;
    }

    private static RaftProperties raftProperties(RatisMultiShardConsensusEngineConfig config, HostPort hostPort) {
        RaftProperties properties = new RaftProperties();
        RaftConfigKeys.Rpc.setType(properties, SupportedRpcType.NETTY);
        NettyConfigKeys.Server.setPort(properties, hostPort.port());
        NettyConfigKeys.Server.setHost(properties, hostPort.host());
        RaftServerConfigKeys.setStorageDir(properties, List.of(config.storageDir().toFile()));
        RaftClientConfigKeys.Rpc.setRequestTimeout(
            properties,
            TimeDuration.valueOf(config.requestTimeoutMillis(), TimeUnit.MILLISECONDS)
        );
        return properties;
    }

    private static void closeClients(Iterable<ShardRuntime> runtimes) {
        RuntimeException first = null;
        for (ShardRuntime runtime : runtimes) {
            try {
                runtime.client().close();
            } catch (IOException e) {
                if (first == null) {
                    first = new RuntimeException("failed to close raft client for shard " + runtime.shardId(), e);
                } else {
                    first.addSuppressed(e);
                }
            }
        }
        if (first != null) {
            throw first;
        }
    }

    private static void closeServerQuietly(RaftServer server) {
        if (server == null) {
            return;
        }
        try {
            server.close();
        } catch (IOException ignored) {
            // best effort shutdown on startup failure path
        }
    }

    private static void ensureStorageDir(Path storageDir) {
        try {
            Files.createDirectories(storageDir);
        } catch (IOException e) {
            throw new IllegalStateException("failed to create ratis storage dir " + storageDir, e);
        }
    }

    private static String normalizeAddress(String address, String nodeId) {
        if (address == null || address.isBlank()) {
            throw new IllegalArgumentException("resolved address is blank for nodeId=" + nodeId);
        }
        return address.trim();
    }

    private static HostPort parseHostPort(String address, String nodeId) {
        int colon = address.lastIndexOf(':');
        if (colon <= 0 || colon >= address.length() - 1) {
            throw new IllegalArgumentException("address must be host:port for nodeId=" + nodeId + ": " + address);
        }
        String host = address.substring(0, colon);
        int port;
        try {
            port = Integer.parseInt(address.substring(colon + 1));
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("invalid port in address for nodeId=" + nodeId + ": " + address, e);
        }
        if (port <= 0 || port > 65535) {
            throw new IllegalArgumentException("port out of range in address for nodeId=" + nodeId + ": " + address);
        }
        return new HostPort(host, port);
    }

    private static String rootMessage(Throwable throwable) {
        Throwable cursor = throwable;
        Throwable last = throwable;
        while (cursor != null) {
            last = cursor;
            cursor = cursor.getCause();
        }
        String message = last.getMessage();
        return message == null || message.isBlank() ? last.getClass().getSimpleName() : message;
    }

    private record HostPort(String host, int port) {}

    private record ShardRuntimePlan(int shardId, String groupName, RaftGroup group, boolean localMember) {}

    private record ShardRuntime(int shardId, String groupName, RaftGroup group, RaftClient client) {}

    private static final class KeyValueStateMachine extends BaseStateMachine {
        private final KeyValueStore keyValueStore;

        private KeyValueStateMachine(KeyValueStore keyValueStore) {
            this.keyValueStore = Objects.requireNonNull(keyValueStore, "keyValueStore must not be null");
        }

        @Override
        public CompletableFuture<Message> applyTransaction(TransactionContext transaction) {
            try {
                byte[] commandBytes = transaction.getLogEntry().getStateMachineLogEntry().getLogData().toByteArray();
                RatisCommandCodec.DecodedCommand command = RatisCommandCodec.decode(commandBytes);

                long version = switch (command.operation()) {
                    case PUT -> keyValueStore.put(command.key(), command.value());
                    case DELETE -> keyValueStore.delete(command.key());
                };

                return CompletableFuture.completedFuture(Message.valueOf(Long.toString(version)));
            } catch (RuntimeException e) {
                System.err.println("ratis.state_machine.apply.failed=true reason=" + rootMessage(e));
                CompletableFuture<Message> failed = new CompletableFuture<>();
                failed.completeExceptionally(e);
                return failed;
            }
        }
    }
}
