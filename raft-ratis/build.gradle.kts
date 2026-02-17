plugins {
    id("java-library")
}

val ratisVersion = "3.2.1"

dependencies {
    implementation(project(":storage-rocksdb"))
    implementation("org.apache.ratis:ratis-common:$ratisVersion")
    implementation("org.apache.ratis:ratis-server:$ratisVersion")
    implementation("org.apache.ratis:ratis-client:$ratisVersion")
    implementation("org.apache.ratis:ratis-netty:$ratisVersion")
    implementation("org.apache.ratis:ratis-metrics-default:$ratisVersion")
}
