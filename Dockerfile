FROM eclipse-temurin:17-jdk AS build

WORKDIR /workspace
COPY . .
RUN ./gradlew :node:installDist :control-plane:installDist --no-daemon

FROM eclipse-temurin:17-jre

WORKDIR /opt/notdynamo
COPY --from=build /workspace/node/build/install/node/ /opt/notdynamo/
COPY --from=build /workspace/control-plane/build/install/control-plane/ /opt/notdynamo-control-plane/

ENV NOTDYNAMO_NODE_ID=node-local
ENV NOTDYNAMO_HOST=0.0.0.0
ENV NOTDYNAMO_GRPC_PORT=9090
ENV NOTDYNAMO_HTTP_PORT=8080
ENV NOTDYNAMO_SHARD_COUNT=64
ENV NOTDYNAMO_VIRTUAL_NODES_PER_SHARD=256
ENV NOTDYNAMO_DATA_DIR=/var/lib/notdynamo

EXPOSE 9090 8080
ENTRYPOINT ["/opt/notdynamo/bin/node"]
