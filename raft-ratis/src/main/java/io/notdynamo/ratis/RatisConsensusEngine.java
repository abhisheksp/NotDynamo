package io.notdynamo.ratis;

import io.notdynamo.storage.KeyValueStore;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
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
import org.apache.ratis.statemachine.TransactionContext;
import org.apache.ratis.statemachine.impl.BaseStateMachine;
import org.apache.ratis.thirdparty.com.google.protobuf.ByteString;
import org.apache.ratis.util.TimeDuration;

public final class RatisConsensusEngine implements ConsensusEngine {
    private final RaftServer server;
    private final RaftClient client;
    private final long requestTimeoutMillis;

    private RatisConsensusEngine(RaftServer server, RaftClient client, long requestTimeoutMillis) {
        this.server = Objects.requireNonNull(server, "server must not be null");
        this.client = Objects.requireNonNull(client, "client must not be null");
        if (requestTimeoutMillis <= 0) {
            throw new IllegalArgumentException("requestTimeoutMillis must be positive");
        }
        this.requestTimeoutMillis = requestTimeoutMillis;
    }

    public static RatisConsensusEngine open(RatisConsensusEngineConfig config, KeyValueStore keyValueStore) {
        Objects.requireNonNull(config, "config must not be null");
        Objects.requireNonNull(keyValueStore, "keyValueStore must not be null");

        try {
            Files.createDirectories(config.storageDir());
        } catch (IOException e) {
            throw new IllegalStateException("failed to create ratis storage dir " + config.storageDir(), e);
        }

        List<RaftPeer> peers = new ArrayList<>(config.peerNodeIds().size());
        for (String nodeId : config.peerNodeIds()) {
            peers.add(
                RaftPeer.newBuilder()
                    .setId(RaftPeerId.valueOf(nodeId))
                    .setAddress(normalizeAddress(config.addressResolver().apply(nodeId), nodeId))
                    .build()
            );
        }

        String localAddress = normalizeAddress(config.addressResolver().apply(config.localNodeId()), config.localNodeId());
        HostPort hostPort = parseHostPort(localAddress, config.localNodeId());

        RaftProperties properties = new RaftProperties();
        RaftConfigKeys.Rpc.setType(properties, SupportedRpcType.NETTY);
        NettyConfigKeys.Server.setPort(properties, hostPort.port());
        NettyConfigKeys.Server.setHost(properties, hostPort.host());
        RaftServerConfigKeys.setStorageDir(properties, List.of(config.storageDir().toFile()));
        RaftClientConfigKeys.Rpc.setRequestTimeout(
            properties,
            TimeDuration.valueOf(config.requestTimeoutMillis(), TimeUnit.MILLISECONDS)
        );

        RaftGroupId raftGroupId = RaftGroupId.valueOf(UUID.nameUUIDFromBytes(config.groupName().getBytes(StandardCharsets.UTF_8)));
        RaftGroup raftGroup = RaftGroup.valueOf(raftGroupId, peers);
        KeyValueStateMachine stateMachine = new KeyValueStateMachine(keyValueStore);

        RaftServer server;
        try {
            server = startServer(config, raftGroup, properties, stateMachine, RaftStorage.StartupOption.RECOVER);
        } catch (Exception recoverFailure) {
            if (!isRecoverableStorageFailure(recoverFailure)) {
                throw new IllegalStateException("failed to start ratis consensus engine for " + config.localNodeId(), recoverFailure);
            }
            System.err.println(
                "ratis.recover.failed=true node_id="
                    + config.localNodeId()
                    + " reason="
                    + rootMessage(recoverFailure)
                    + " action=wipe_and_format"
            );
            wipeStorageDir(config.storageDir());
            try {
                server = startServer(config, raftGroup, properties, stateMachine, RaftStorage.StartupOption.FORMAT);
            } catch (Exception formatFailure) {
                throw new IllegalStateException(
                    "failed to start ratis consensus engine for "
                        + config.localNodeId()
                        + " after fallback format",
                    formatFailure
                );
            }
        }

        try {
            RaftClient client = RaftClient.newBuilder()
                .setRaftGroup(raftGroup)
                .setProperties(properties)
                .build();
            return new RatisConsensusEngine(server, client, config.requestTimeoutMillis());
        } catch (RuntimeException e) {
            try {
                server.close();
            } catch (IOException closeFailure) {
                e.addSuppressed(closeFailure);
            }
            throw new IllegalStateException("failed to start ratis consensus engine for " + config.localNodeId(), e);
        }
    }

    private static RaftServer startServer(
        RatisConsensusEngineConfig config,
        RaftGroup raftGroup,
        RaftProperties properties,
        KeyValueStateMachine stateMachine,
        RaftStorage.StartupOption startupOption
    ) throws IOException {
        RaftServer server = RaftServer.newBuilder()
            .setServerId(RaftPeerId.valueOf(config.localNodeId()))
            .setGroup(raftGroup)
            .setOption(startupOption)
            .setProperties(properties)
            .setStateMachine(stateMachine)
            .build();
        server.start();
        return server;
    }

    private static boolean isRecoverableStorageFailure(Throwable throwable) {
        Throwable cursor = throwable;
        while (cursor != null) {
            String message = cursor.getMessage();
            if (message != null) {
                String normalized = message.toLowerCase();
                if (
                    normalized.contains("not_formatted")
                        || normalized.contains("failed to parse 'term'")
                        || normalized.contains("failed to load")
                        || normalized.contains("existing directories found")
                ) {
                    return true;
                }
            }
            cursor = cursor.getCause();
        }
        return false;
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

    private static void wipeStorageDir(Path storageDir) {
        try {
            if (!Files.exists(storageDir)) {
                return;
            }
            try (var stream = Files.walk(storageDir)) {
                stream
                    .sorted(Comparator.reverseOrder())
                    .forEach(path -> {
                        try {
                            Files.deleteIfExists(path);
                        } catch (IOException e) {
                            throw new IllegalStateException("failed to delete path " + path, e);
                        }
                    });
            }
            Files.createDirectories(storageDir);
        } catch (IOException e) {
            throw new IllegalStateException("failed to wipe ratis storage dir " + storageDir, e);
        }
    }

    @Override
    public long put(byte[] key, byte[] value) {
        return submit(RatisCommandCodec.encodePut(key, value));
    }

    @Override
    public long delete(byte[] key) {
        return submit(RatisCommandCodec.encodeDelete(key));
    }

    @Override
    public void close() {
        RuntimeException first = null;
        try {
            client.close();
        } catch (IOException e) {
            first = new RuntimeException("failed to close ratis client", e);
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

    private long submit(byte[] commandBytes) {
        try {
            CompletableFuture<RaftClientReply> sendFuture = client.async().send(Message.valueOf(ByteString.copyFrom(commandBytes)));
            RaftClientReply reply = awaitReply(sendFuture);
            if (reply == null) {
                throw new IllegalStateException("ratis reply is null");
            }
            if (!reply.isSuccess()) {
                if (reply.getException() != null) {
                    throw new IllegalStateException("ratis write failed: " + reply.getException().getMessage(), reply.getException());
                }
                throw new IllegalStateException("ratis write failed without exception");
            }

            Message message = reply.getMessage();
            if (message == null || message.getContent() == null) {
                throw new IllegalStateException("ratis reply message missing");
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
                String detail = rootMessage(ioException);
                if (detail == null || detail.isBlank()) {
                    detail = ioException.getClass().getSimpleName();
                }
                throw new IllegalStateException("ratis write I/O failure: " + detail, ioException);
            }
            if (cause instanceof RuntimeException runtimeException) {
                throw runtimeException;
            }
            throw new IllegalStateException("ratis write failed", cause == null ? e : cause);
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

    private record HostPort(String host, int port) {}

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
