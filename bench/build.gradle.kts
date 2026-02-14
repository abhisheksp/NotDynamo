plugins {
    id("application")
}

dependencies {
    implementation(project(":storage-rocksdb"))
}

application {
    mainClass = "io.notdynamo.bench.BenchmarkMain"
}
