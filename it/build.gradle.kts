plugins {
    id("java-library")
}

dependencies {
    testImplementation(project(":node"))
    testImplementation(project(":proto"))
    testImplementation(project(":storage-rocksdb"))
    testImplementation(project(":control-plane"))
}
