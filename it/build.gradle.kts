plugins {
    id("java-library")
}

dependencies {
    testImplementation(project(":node"))
    testImplementation(project(":storage-rocksdb"))
}
