plugins {
    id("application")
    id("java-library")
}

dependencies {
    implementation("com.fasterxml.jackson.core:jackson-databind:2.18.2")
}

application {
    mainClass = "io.notdynamo.controlplane.ControlPlaneMain"
}
