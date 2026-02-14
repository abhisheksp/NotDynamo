package io.notdynamo.it;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import io.notdynamo.storage.KeyValueStore;
import io.notdynamo.storage.RocksDbKeyValueStore;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.time.Duration;
import java.util.Base64;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class CrashRecoveryIT {
    private static final Duration ACK_TIMEOUT = Duration.ofSeconds(20);

    @TempDir
    Path tempDir;

    @Test
    void survivesForcedProcessTerminationAfterAcknowledgedWrites() throws Exception {
        Path dbPath = tempDir.resolve("db");
        byte[] key = "durability-key".getBytes(StandardCharsets.UTF_8);
        int loops = Integer.getInteger("notdynamo.crash.loops", 20);

        long lastVersion = 0;
        byte[] lastValue = null;

        for (int i = 1; i <= loops; i++) {
            lastValue = ("value-" + i).getBytes(StandardCharsets.UTF_8);
            Process process = startWriterProcess(dbPath, key, lastValue);
            long acknowledgedVersion = waitForAckVersion(process, ACK_TIMEOUT);
            assertTrue(acknowledgedVersion >= i, "acknowledged version must progress");
            lastVersion = acknowledgedVersion;

            process.destroyForcibly();
            boolean exited = process.waitFor(10, TimeUnit.SECONDS);
            assertTrue(exited, "writer process must terminate after forced kill");
        }

        try (RocksDbKeyValueStore store = RocksDbKeyValueStore.open(dbPath)) {
            KeyValueStore.GetResult result = store.get(key);
            assertTrue(result.found());
            assertEquals(lastVersion, result.version());
            assertArrayEquals(lastValue, result.value());
        }
    }

    private Process startWriterProcess(Path dbPath, byte[] key, byte[] value) throws IOException {
        String javaBin = Path.of(System.getProperty("java.home"), "bin", "java").toString();
        String classpath = System.getProperty("java.class.path");

        String keyEncoded = Base64.getEncoder().encodeToString(key);
        String valueEncoded = Base64.getEncoder().encodeToString(value);

        return new ProcessBuilder(
            javaBin,
            "-cp",
            classpath,
            "io.notdynamo.it.CrashWriteProcess",
            dbPath.toString(),
            keyEncoded,
            valueEncoded
        )
            .redirectErrorStream(true)
            .start();
    }

    private long waitForAckVersion(Process process, Duration timeout) throws Exception {
        long deadlineNanos = System.nanoTime() + timeout.toNanos();

        try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream(), StandardCharsets.UTF_8))) {
            while (System.nanoTime() < deadlineNanos) {
                if (reader.ready()) {
                    String line = reader.readLine();
                    if (line == null) {
                        break;
                    }

                    if (line.startsWith("ACK version=")) {
                        String value = line.substring("ACK version=".length()).trim();
                        return Long.parseLong(value);
                    }
                } else {
                    if (!process.isAlive()) {
                        break;
                    }
                    Thread.sleep(25);
                }
            }
        }

        assertTrue(process.isAlive(), "writer process exited before ack");
        throw new IllegalStateException("timed out waiting for ACK line from writer process");
    }
}
