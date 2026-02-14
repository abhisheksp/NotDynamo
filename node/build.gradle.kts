plugins {
    id("java-library")
}

dependencies {
    implementation(project(":proto"))
    implementation(project(":storage-rocksdb"))
}
