package io.notdynamo.node.cluster;

import io.notdynamo.proto.v1.DeleteRequest;
import io.notdynamo.proto.v1.DeleteResponse;
import io.notdynamo.proto.v1.GetRequest;
import io.notdynamo.proto.v1.GetResponse;
import io.notdynamo.proto.v1.PutRequest;
import io.notdynamo.proto.v1.PutResponse;

public interface NodeRpcClient {
    GetResponse get(String nodeId, GetRequest request);

    PutResponse put(String nodeId, PutRequest request);

    DeleteResponse delete(String nodeId, DeleteRequest request);
}
