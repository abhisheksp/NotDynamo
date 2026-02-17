plugins {
    id("application")
}

val grpcVersion = "1.71.0"

dependencies {
    implementation(project(":proto"))
    implementation(project(":storage-rocksdb"))
    implementation(project(":control-plane"))
    implementation(project(":raft-ratis"))
    implementation("io.grpc:grpc-netty-shaded:$grpcVersion")
}

application {
    mainClass = "io.notdynamo.node.NodeMain"
}
