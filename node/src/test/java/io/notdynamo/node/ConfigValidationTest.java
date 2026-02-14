package io.notdynamo.node;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.nio.file.Path;
import org.junit.jupiter.api.Test;

class ConfigValidationTest {
    @Test
    void acceptsValidConfig() {
        assertDoesNotThrow(() ->
            new NodeConfig("node-a", "127.0.0.1", 9090, 8080, Path.of("/tmp/notdynamo"))
        );
    }

    @Test
    void rejectsDuplicatePorts() {
        assertThrows(
            IllegalArgumentException.class,
            () -> new NodeConfig("node-a", "127.0.0.1", 9090, 9090, Path.of("/tmp/notdynamo"))
        );
    }

    @Test
    void rejectsOutOfRangePort() {
        assertThrows(
            IllegalArgumentException.class,
            () -> new NodeConfig("node-a", "127.0.0.1", 0, 8080, Path.of("/tmp/notdynamo"))
        );
    }
}
