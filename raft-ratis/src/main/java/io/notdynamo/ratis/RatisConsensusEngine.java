package io.notdynamo.ratis;

import io.notdynamo.storage.KeyValueStore;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
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
import org.apache.ratis.statemachine.TransactionContext;
import org.apache.ratis.statemachine.impl.BaseStateMachine;
import org.apache.ratis.thirdparty.com.google.protobuf.ByteString;
import org.apache.ratis.util.TimeDuration;

public final class RatisConsensusEngine implements ConsensusEngine {
    private final RaftServer server;
    private final RaftClient client;

    private RatisConsensusEngine(RaftServer server, RaftClient client) {
        this.server = Objects.requireNonNull(server, "server must not be null");
        this.client = Objects.requireNonNull(client, "client must not be null");
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

        try {
            RaftServer server = RaftServer.newBuilder()
                .setServerId(RaftPeerId.valueOf(config.localNodeId()))
                .setGroup(raftGroup)
                .setProperties(properties)
                .setStateMachine(stateMachine)
                .build();
            server.start();

            RaftClient client = RaftClient.newBuilder().setRaftGroup(raftGroup).setProperties(properties).build();
            return new RatisConsensusEngine(server, client);
        } catch (IOException e) {
            throw new IllegalStateException("failed to start ratis consensus engine for " + config.localNodeId(), e);
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
            RaftClientReply reply = client.io().send(Message.valueOf(ByteString.copyFrom(commandBytes)));
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
        } catch (IOException e) {
            throw new IllegalStateException("ratis write I/O failure", e);
        } catch (NumberFormatException e) {
            throw new IllegalStateException("invalid version returned from ratis state machine", e);
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
                CompletableFuture<Message> failed = new CompletableFuture<>();
                failed.completeExceptionally(e);
                return failed;
            }
        }
    }
}
