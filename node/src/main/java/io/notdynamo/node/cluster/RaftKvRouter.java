package io.notdynamo.node.cluster;

import com.google.protobuf.ByteString;
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
import io.notdynamo.proto.v1.RaftAppendEntriesRequest;
import io.notdynamo.proto.v1.RaftAppendEntriesResponse;
import io.notdynamo.proto.v1.RaftEntry;
import io.notdynamo.proto.v1.RaftOperationType;
import io.notdynamo.proto.v1.RaftVoteRequest;
import io.notdynamo.proto.v1.RaftVoteResponse;
import io.notdynamo.proto.v1.StatusCode;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

public final class RaftKvRouter {
    private static final String GROUP_PREFIX = "shard-";

    private final String localNodeId;
    private final KvServiceHandler localService;
    private final NodeRpcClient rpcClient;
    private final ReplicaPartitionMap replicaMap;
    private final ConsistentHashRing ring;
    private final ConcurrentHashMap<Integer, RaftGroupState> groupStates = new ConcurrentHashMap<>();

    public RaftKvRouter(
        String localNodeId,
        KvServiceHandler localService,
        NodeRpcClient rpcClient,
        ReplicaPartitionMap replicaMap
    ) {
        this.localNodeId = validateNodeId(localNodeId, "localNodeId");
        this.localService = Objects.requireNonNull(localService, "localService must not be null");
        this.rpcClient = Objects.requireNonNull(rpcClient, "rpcClient must not be null");
        this.replicaMap = Objects.requireNonNull(replicaMap, "replicaMap must not be null");
        this.ring = buildRing(replicaMap);
    }

    public GetResponse get(GetRequest request) {
        if (request.getKey().isEmpty()) {
            return GetResponse.newBuilder().setError(invalidArgument("key must not be empty")).build();
        }

        int shardId = shardForKey(request.getKey().toByteArray());
        RaftGroupState group = groupForShard(shardId);

        String readNode = group.containsPeer(localNodeId) ? localNodeId : group.leaderIdOrDefault();
        if (readNode == null || readNode.isBlank()) {
            return GetResponse.newBuilder().setError(unavailable("no leader for shard " + shardId)).build();
        }

        if (readNode.equals(localNodeId)) {
            return invokeLocalGet(request);
        }
        return rpcClient.get(readNode, request);
    }

    public PutResponse put(PutRequest request) {
        if (request.getKey().isEmpty()) {
            return PutResponse.newBuilder().setError(invalidArgument("key must not be empty")).build();
        }

        int shardId = shardForKey(request.getKey().toByteArray());
        RaftGroupState group = groupForShard(shardId);

        if (!group.containsPeer(localNodeId)) {
            String leader = group.leaderIdOrDefault();
            if (leader == null || leader.isBlank()) {
                return PutResponse.newBuilder().setError(unavailable("no leader available for shard " + shardId)).build();
            }
            return rpcClient.put(leader, request);
        }

        if (!group.isLocalLeader(localNodeId)) {
            String knownLeader = group.leaderIdOrDefault();
            if (knownLeader != null && !knownLeader.isBlank() && !knownLeader.equals(localNodeId)) {
                PutResponse forwarded = rpcClient.put(knownLeader, request);
                if (!shouldAttemptElection(forwarded)) {
                    return forwarded;
                }
                group.clearLeaderHintIfMatches(knownLeader);
            }

            if (!runElection(group)) {
                return PutResponse.newBuilder().setError(unavailable("failed to elect leader for shard " + shardId)).build();
            }
        }

        return appendAndCommitPut(group, request);
    }

    public DeleteResponse delete(DeleteRequest request) {
        if (request.getKey().isEmpty()) {
            return DeleteResponse.newBuilder().setError(invalidArgument("key must not be empty")).build();
        }

        int shardId = shardForKey(request.getKey().toByteArray());
        RaftGroupState group = groupForShard(shardId);

        if (!group.containsPeer(localNodeId)) {
            String leader = group.leaderIdOrDefault();
            if (leader == null || leader.isBlank()) {
                return DeleteResponse.newBuilder().setError(unavailable("no leader available for shard " + shardId)).build();
            }
            return rpcClient.delete(leader, request);
        }

        if (!group.isLocalLeader(localNodeId)) {
            String knownLeader = group.leaderIdOrDefault();
            if (knownLeader != null && !knownLeader.isBlank() && !knownLeader.equals(localNodeId)) {
                DeleteResponse forwarded = rpcClient.delete(knownLeader, request);
                if (!shouldAttemptElection(forwarded)) {
                    return forwarded;
                }
                group.clearLeaderHintIfMatches(knownLeader);
            }

            if (!runElection(group)) {
                return DeleteResponse.newBuilder().setError(unavailable("failed to elect leader for shard " + shardId)).build();
            }
        }

        return appendAndCommitDelete(group, request);
    }

    public RaftVoteResponse requestVote(RaftVoteRequest request) {
        Integer shardId = shardIdFromGroupId(request.getGroupId());
        if (shardId == null) {
            return RaftVoteResponse.newBuilder().setTerm(request.getTerm()).setVoteGranted(false).setLeaderId("").build();
        }

        RaftGroupState group = groupForShard(shardId);
        return group.onRequestVote(request);
    }

    public RaftAppendEntriesResponse appendEntries(RaftAppendEntriesRequest request) {
        Integer shardId = shardIdFromGroupId(request.getGroupId());
        if (shardId == null) {
            return RaftAppendEntriesResponse.newBuilder()
                .setTerm(request.getTerm())
                .setSuccess(false)
                .setMatchIndex(0L)
                .setLeaderId("")
                .build();
        }

        RaftGroupState group = groupForShard(shardId);
        RaftAppendEntriesResponse response = group.onAppendEntries(request);
        applyCommittedEntries(group);
        return response;
    }

    private PutResponse appendAndCommitPut(RaftGroupState group, PutRequest request) {
        RaftEntry entry = group.appendLocalUncommitted(
            RaftOperationType.RAFT_OPERATION_TYPE_PUT,
            request.getKey().toByteArray(),
            request.getValue().toByteArray()
        );

        long quorum = group.quorumSize();
        long acks = 1;

        RaftAppendEntriesRequest appendRequest = group.appendRequestFor(entry, group.commitIndex());
        for (String follower : group.followers()) {
            RaftAppendEntriesResponse response = rpcClient.appendEntries(follower, appendRequest);
            if (response.getTerm() > group.currentTerm()) {
                group.stepDown(response.getTerm(), response.getLeaderId());
                return PutResponse.newBuilder().setError(unavailable("leader stepped down due to higher term")).build();
            }
            if (response.getSuccess()) {
                acks += 1;
            }
        }

        if (acks < quorum) {
            return PutResponse.newBuilder()
                .setError(unavailable("insufficient quorum acks: received=" + acks + " required=" + quorum))
                .build();
        }

        group.commitTo(entry.getIndex());
        AppliedResult applied = applyCommittedEntries(group);
        if (!applied.success) {
            return PutResponse.newBuilder().setError(internal("failed to apply committed entry")).build();
        }

        RaftAppendEntriesRequest heartbeat = group.heartbeatRequest();
        for (String follower : group.followers()) {
            rpcClient.appendEntries(follower, heartbeat);
        }

        Long version = applied.appliedVersions.get(entry.getIndex());
        if (version == null) {
            return PutResponse.newBuilder().setError(internal("committed put version not available")).build();
        }
        return PutResponse.newBuilder().setVersion(version).build();
    }

    private DeleteResponse appendAndCommitDelete(RaftGroupState group, DeleteRequest request) {
        RaftEntry entry = group.appendLocalUncommitted(
            RaftOperationType.RAFT_OPERATION_TYPE_DELETE,
            request.getKey().toByteArray(),
            new byte[0]
        );

        long quorum = group.quorumSize();
        long acks = 1;

        RaftAppendEntriesRequest appendRequest = group.appendRequestFor(entry, group.commitIndex());
        for (String follower : group.followers()) {
            RaftAppendEntriesResponse response = rpcClient.appendEntries(follower, appendRequest);
            if (response.getTerm() > group.currentTerm()) {
                group.stepDown(response.getTerm(), response.getLeaderId());
                return DeleteResponse.newBuilder().setError(unavailable("leader stepped down due to higher term")).build();
            }
            if (response.getSuccess()) {
                acks += 1;
            }
        }

        if (acks < quorum) {
            return DeleteResponse.newBuilder()
                .setError(unavailable("insufficient quorum acks: received=" + acks + " required=" + quorum))
                .build();
        }

        group.commitTo(entry.getIndex());
        AppliedResult applied = applyCommittedEntries(group);
        if (!applied.success) {
            return DeleteResponse.newBuilder().setError(internal("failed to apply committed entry")).build();
        }

        RaftAppendEntriesRequest heartbeat = group.heartbeatRequest();
        for (String follower : group.followers()) {
            rpcClient.appendEntries(follower, heartbeat);
        }

        Long version = applied.appliedVersions.get(entry.getIndex());
        if (version == null) {
            return DeleteResponse.newBuilder().setError(internal("committed delete version not available")).build();
        }
        return DeleteResponse.newBuilder().setVersion(version).build();
    }

    private AppliedResult applyCommittedEntries(RaftGroupState group) {
        Map<Long, Long> versionsByIndex = new HashMap<>();

        while (true) {
            RaftEntry entry = group.nextCommittableEntry();
            if (entry == null) {
                return new AppliedResult(true, versionsByIndex);
            }

            switch (entry.getOperationType()) {
                case RAFT_OPERATION_TYPE_PUT -> {
                    PutResponse put = invokeLocalPut(
                        PutRequest.newBuilder()
                            .setKey(entry.getKey())
                            .setValue(entry.getValue())
                            .build()
                    );
                    if (put.hasError()) {
                        return new AppliedResult(false, versionsByIndex);
                    }
                    versionsByIndex.put(entry.getIndex(), put.getVersion());
                }
                case RAFT_OPERATION_TYPE_DELETE -> {
                    DeleteResponse delete = invokeLocalDelete(
                        DeleteRequest.newBuilder()
                            .setKey(entry.getKey())
                            .build()
                    );
                    if (delete.hasError()) {
                        return new AppliedResult(false, versionsByIndex);
                    }
                    versionsByIndex.put(entry.getIndex(), delete.getVersion());
                }
                default -> {
                    return new AppliedResult(false, versionsByIndex);
                }
            }

            group.markApplied(entry.getIndex());
        }
    }

    private boolean runElection(RaftGroupState group) {
        RaftVoteRequest voteRequest = group.nextVoteRequest(localNodeId);
        long votes = 1;

        for (String peer : group.followersAndOtherPeers(localNodeId)) {
            RaftVoteResponse response = rpcClient.requestVote(peer, voteRequest);
            if (response.getTerm() > group.currentTerm()) {
                group.stepDown(response.getTerm(), response.getLeaderId());
                return false;
            }
            if (response.getVoteGranted()) {
                votes += 1;
            }
        }

        if (votes >= group.quorumSize()) {
            group.becomeLeader(localNodeId);
            return true;
        }

        group.becomeFollower();
        return false;
    }

    private int shardForKey(byte[] key) {
        return ring.shardForKey(key);
    }

    private RaftGroupState groupForShard(int shardId) {
        return groupStates.computeIfAbsent(
            shardId,
            id -> new RaftGroupState(id, replicaMap.replicasForShard(id), replicaMap.leaderForShard(id))
        );
    }

    private static ConsistentHashRing buildRing(ReplicaPartitionMap replicaMap) {
        Set<Integer> shardIds = new HashSet<>();
        for (int shard = 0; shard < replicaMap.shardCount(); shard++) {
            shardIds.add(shard);
        }
        return ConsistentHashRing.create(shardIds, replicaMap.virtualNodesPerShard());
    }

    private static Integer shardIdFromGroupId(String groupId) {
        if (groupId == null || !groupId.startsWith(GROUP_PREFIX)) {
            return null;
        }
        String suffix = groupId.substring(GROUP_PREFIX.length());
        try {
            return Integer.parseInt(suffix);
        } catch (NumberFormatException e) {
            return null;
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

    private PutResponse invokeLocalPut(PutRequest request) {
        SyncResponseObserver<PutResponse> observer = new SyncResponseObserver<>();
        localService.put(request, observer);
        if (observer.error() != null || observer.value() == null || !observer.completed()) {
            return PutResponse.newBuilder().setError(internal("local put invocation failed")).build();
        }
        return observer.value();
    }

    private DeleteResponse invokeLocalDelete(DeleteRequest request) {
        SyncResponseObserver<DeleteResponse> observer = new SyncResponseObserver<>();
        localService.delete(request, observer);
        if (observer.error() != null || observer.value() == null || !observer.completed()) {
            return DeleteResponse.newBuilder().setError(internal("local delete invocation failed")).build();
        }
        return observer.value();
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

    private static Error internal(String message) {
        return Error.newBuilder().setCode(StatusCode.STATUS_CODE_INTERNAL).setMessage(message).build();
    }

    private static boolean shouldAttemptElection(PutResponse response) {
        return response.hasError()
            && (response.getError().getCode() == StatusCode.STATUS_CODE_UNAVAILABLE
                || response.getError().getCode() == StatusCode.STATUS_CODE_TIMEOUT);
    }

    private static boolean shouldAttemptElection(DeleteResponse response) {
        return response.hasError()
            && (response.getError().getCode() == StatusCode.STATUS_CODE_UNAVAILABLE
                || response.getError().getCode() == StatusCode.STATUS_CODE_TIMEOUT);
    }

    private static final class AppliedResult {
        private final boolean success;
        private final Map<Long, Long> appliedVersions;

        private AppliedResult(boolean success, Map<Long, Long> appliedVersions) {
            this.success = success;
            this.appliedVersions = appliedVersions;
        }
    }

    private static final class RaftGroupState {
        private enum Role {
            FOLLOWER,
            CANDIDATE,
            LEADER
        }

        private final int shardId;
        private final List<String> peers;
        private final Map<Long, RaftEntry> logByIndex = new HashMap<>();

        private long currentTerm = 1L;
        private long commitIndex = 0L;
        private long lastApplied = 0L;
        private String votedFor = null;
        private String leaderId;
        private Role role = Role.FOLLOWER;

        private RaftGroupState(int shardId, List<String> peers, String initialLeaderId) {
            this.shardId = shardId;
            this.peers = List.copyOf(peers);
            this.leaderId = initialLeaderId;
        }

        private synchronized boolean containsPeer(String nodeId) {
            return peers.contains(nodeId);
        }

        private synchronized boolean isLocalLeader(String nodeId) {
            return role == Role.LEADER && nodeId.equals(leaderId);
        }

        private synchronized String leaderIdOrDefault() {
            if (leaderId != null && !leaderId.isBlank()) {
                return leaderId;
            }
            return peers.isEmpty() ? null : peers.get(0);
        }

        private synchronized long quorumSize() {
            return (peers.size() / 2L) + 1L;
        }

        private synchronized long currentTerm() {
            return currentTerm;
        }

        private synchronized long commitIndex() {
            return commitIndex;
        }

        private synchronized RaftVoteRequest nextVoteRequest(String candidateId) {
            role = Role.CANDIDATE;
            currentTerm += 1;
            votedFor = candidateId;
            leaderId = "";
            return RaftVoteRequest.newBuilder()
                .setGroupId(groupId())
                .setCandidateId(candidateId)
                .setTerm(currentTerm)
                .setLastLogIndex(lastLogIndex())
                .setLastLogTerm(lastLogTerm())
                .build();
        }

        private synchronized void becomeLeader(String nodeId) {
            role = Role.LEADER;
            leaderId = nodeId;
            votedFor = null;
        }

        private synchronized void becomeFollower() {
            role = Role.FOLLOWER;
        }

        private synchronized void stepDown(long newTerm, String newLeaderId) {
            if (newTerm > currentTerm) {
                currentTerm = newTerm;
                votedFor = null;
            }
            role = Role.FOLLOWER;
            leaderId = newLeaderId == null ? "" : newLeaderId;
        }

        private synchronized void clearLeaderHintIfMatches(String nodeId) {
            if (leaderId != null && leaderId.equals(nodeId)) {
                leaderId = "";
            }
        }

        private synchronized List<String> followers() {
            List<String> followers = new ArrayList<>();
            for (String peer : peers) {
                if (!peer.equals(leaderId)) {
                    followers.add(peer);
                }
            }
            return followers;
        }

        private synchronized List<String> followersAndOtherPeers(String selfNodeId) {
            List<String> nodes = new ArrayList<>();
            for (String peer : peers) {
                if (!peer.equals(selfNodeId)) {
                    nodes.add(peer);
                }
            }
            return nodes;
        }

        private synchronized RaftEntry appendLocalUncommitted(RaftOperationType operationType, byte[] key, byte[] value) {
            long nextIndex = lastLogIndex() + 1;
            RaftEntry entry = RaftEntry.newBuilder()
                .setTerm(currentTerm)
                .setIndex(nextIndex)
                .setOperationType(operationType)
                .setKey(ByteString.copyFrom(key))
                .setValue(ByteString.copyFrom(value))
                .build();
            logByIndex.put(nextIndex, entry);
            return entry;
        }

        private synchronized RaftAppendEntriesRequest appendRequestFor(RaftEntry entry, long leaderCommit) {
            long prevIndex = entry.getIndex() - 1;
            long prevTerm = prevIndex == 0 ? 0 : termAt(prevIndex);
            return RaftAppendEntriesRequest.newBuilder()
                .setGroupId(groupId())
                .setLeaderId(leaderId == null ? "" : leaderId)
                .setTerm(currentTerm)
                .setPrevLogIndex(prevIndex)
                .setPrevLogTerm(prevTerm)
                .addEntries(entry)
                .setLeaderCommit(leaderCommit)
                .build();
        }

        private synchronized RaftAppendEntriesRequest heartbeatRequest() {
            long lastIndex = lastLogIndex();
            long lastTerm = lastIndex == 0 ? 0 : termAt(lastIndex);
            return RaftAppendEntriesRequest.newBuilder()
                .setGroupId(groupId())
                .setLeaderId(leaderId == null ? "" : leaderId)
                .setTerm(currentTerm)
                .setPrevLogIndex(lastIndex)
                .setPrevLogTerm(lastTerm)
                .setLeaderCommit(commitIndex)
                .build();
        }

        private synchronized void commitTo(long newCommitIndex) {
            commitIndex = Math.max(commitIndex, newCommitIndex);
        }

        private synchronized RaftEntry nextCommittableEntry() {
            long next = lastApplied + 1;
            if (next > commitIndex) {
                return null;
            }
            return logByIndex.get(next);
        }

        private synchronized void markApplied(long index) {
            if (index > lastApplied) {
                lastApplied = index;
            }
        }

        private synchronized long lastLogIndex() {
            if (logByIndex.isEmpty()) {
                return 0L;
            }
            long max = 0;
            for (Long index : logByIndex.keySet()) {
                if (index > max) {
                    max = index;
                }
            }
            return max;
        }

        private synchronized long lastLogTerm() {
            long lastIndex = lastLogIndex();
            if (lastIndex == 0L) {
                return 0L;
            }
            return termAt(lastIndex);
        }

        private synchronized long termAt(long index) {
            RaftEntry entry = logByIndex.get(index);
            if (entry == null) {
                return 0L;
            }
            return entry.getTerm();
        }

        private synchronized RaftVoteResponse onRequestVote(RaftVoteRequest request) {
            if (request.getTerm() < currentTerm) {
                return RaftVoteResponse.newBuilder()
                    .setTerm(currentTerm)
                    .setVoteGranted(false)
                    .setLeaderId(leaderId == null ? "" : leaderId)
                    .build();
            }

            if (request.getTerm() > currentTerm) {
                currentTerm = request.getTerm();
                votedFor = null;
                role = Role.FOLLOWER;
                leaderId = "";
            }

            boolean logUpToDate = request.getLastLogTerm() > lastLogTerm()
                || (request.getLastLogTerm() == lastLogTerm() && request.getLastLogIndex() >= lastLogIndex());

            boolean canVote = (votedFor == null || votedFor.equals(request.getCandidateId())) && logUpToDate;
            if (canVote) {
                votedFor = request.getCandidateId();
                leaderId = "";
            }

            return RaftVoteResponse.newBuilder()
                .setTerm(currentTerm)
                .setVoteGranted(canVote)
                .setLeaderId(leaderId == null ? "" : leaderId)
                .build();
        }

        private synchronized RaftAppendEntriesResponse onAppendEntries(RaftAppendEntriesRequest request) {
            if (request.getTerm() < currentTerm) {
                return RaftAppendEntriesResponse.newBuilder()
                    .setTerm(currentTerm)
                    .setSuccess(false)
                    .setMatchIndex(lastLogIndex())
                    .setLeaderId(leaderId == null ? "" : leaderId)
                    .build();
            }

            if (request.getTerm() > currentTerm) {
                currentTerm = request.getTerm();
                votedFor = null;
            }

            role = Role.FOLLOWER;
            leaderId = request.getLeaderId();

            long prevIndex = request.getPrevLogIndex();
            long prevTerm = request.getPrevLogTerm();
            if (prevIndex > 0) {
                RaftEntry prevEntry = logByIndex.get(prevIndex);
                if (prevEntry == null || prevEntry.getTerm() != prevTerm) {
                    return RaftAppendEntriesResponse.newBuilder()
                        .setTerm(currentTerm)
                        .setSuccess(false)
                        .setMatchIndex(lastLogIndex())
                        .setLeaderId(leaderId == null ? "" : leaderId)
                        .build();
                }
            }

            for (RaftEntry incoming : request.getEntriesList()) {
                RaftEntry existing = logByIndex.get(incoming.getIndex());
                if (existing != null && existing.getTerm() != incoming.getTerm()) {
                    truncateFrom(incoming.getIndex());
                    existing = null;
                }
                if (existing == null) {
                    logByIndex.put(incoming.getIndex(), incoming);
                }
            }

            long lastIndex = lastLogIndex();
            if (request.getLeaderCommit() > commitIndex) {
                commitIndex = Math.min(request.getLeaderCommit(), lastIndex);
            }

            return RaftAppendEntriesResponse.newBuilder()
                .setTerm(currentTerm)
                .setSuccess(true)
                .setMatchIndex(lastIndex)
                .setLeaderId(leaderId == null ? "" : leaderId)
                .build();
        }

        private synchronized void truncateFrom(long startIndex) {
            List<Long> toRemove = new ArrayList<>();
            for (Long index : logByIndex.keySet()) {
                if (index >= startIndex) {
                    toRemove.add(index);
                }
            }
            for (Long index : toRemove) {
                logByIndex.remove(index);
            }
            if (commitIndex >= startIndex) {
                commitIndex = startIndex - 1;
            }
            if (lastApplied >= startIndex) {
                lastApplied = startIndex - 1;
            }
        }

        private String groupId() {
            return GROUP_PREFIX + shardId;
        }
    }
}
