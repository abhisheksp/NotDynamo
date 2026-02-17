plugins {
    id("java-library")
}

dependencies {
    testImplementation(project(":node"))
    testImplementation(project(":proto"))
    testImplementation(project(":storage-rocksdb"))
    testImplementation(project(":control-plane"))
    testImplementation(project(":raft-ratis"))
    testImplementation("org.yaml:snakeyaml:2.2")
}
