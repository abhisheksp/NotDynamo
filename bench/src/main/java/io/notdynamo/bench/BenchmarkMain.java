package io.notdynamo.bench;

import io.notdynamo.storage.KeyValueStore;
import io.notdynamo.storage.RocksDbKeyValueStore;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;

public final class BenchmarkMain {
    private BenchmarkMain() {
    }

    public static void main(String[] args) throws Exception {
        Map<String, String> options = parseArgs(args);
        String scenario = options.getOrDefault("scenario", "single-node-sanity");

        if (!"single-node-sanity".equals(scenario)) {
            throw new IllegalArgumentException("unsupported scenario: " + scenario);
        }

        int operations = Integer.parseInt(options.getOrDefault("operations", "100000"));
        int keyspace = Integer.parseInt(options.getOrDefault("keyspace", "10000"));

        runSingleNodeSanity(operations, keyspace);
    }

    private static void runSingleNodeSanity(int operations, int keyspace) throws Exception {
        Path workDir = Files.createTempDirectory("notdynamo-bench-");
        Path dbPath = workDir.resolve("db");

        try (RocksDbKeyValueStore store = RocksDbKeyValueStore.open(dbPath)) {
            for (int i = 0; i < keyspace; i++) {
                byte[] key = key(i);
                byte[] value = value(i);
                store.put(key, value);
            }

            long[] latenciesNanos = new long[operations];
            long start = System.nanoTime();

            for (int i = 0; i < operations; i++) {
                byte[] key = key(i % keyspace);
                long before = System.nanoTime();
                KeyValueStore.GetResult result = store.get(key);
                long after = System.nanoTime();

                if (!result.found()) {
                    throw new IllegalStateException("missing key during benchmark");
                }
                latenciesNanos[i] = after - before;
            }

            long elapsedNanos = System.nanoTime() - start;
            Arrays.sort(latenciesNanos);

            double throughput = operations / (elapsedNanos / 1_000_000_000.0);
            double p50Ms = nanosToMillis(percentile(latenciesNanos, 50));
            double p95Ms = nanosToMillis(percentile(latenciesNanos, 95));
            double p99Ms = nanosToMillis(percentile(latenciesNanos, 99));

            System.out.println("scenario=single-node-sanity");
            System.out.println("operations=" + operations);
            System.out.println("keyspace=" + keyspace);
            System.out.printf("throughput_rps=%.2f%n", throughput);
            System.out.printf("latency_ms_p50=%.3f%n", p50Ms);
            System.out.printf("latency_ms_p95=%.3f%n", p95Ms);
            System.out.printf("latency_ms_p99=%.3f%n", p99Ms);
        } finally {
            deleteRecursively(workDir);
        }
    }

    private static long percentile(long[] sorted, int percentile) {
        if (sorted.length == 0) {
            return 0;
        }
        int index = (int) Math.ceil((percentile / 100.0) * sorted.length) - 1;
        index = Math.max(0, Math.min(index, sorted.length - 1));
        return sorted[index];
    }

    private static double nanosToMillis(long nanos) {
        return nanos / 1_000_000.0;
    }

    private static byte[] key(int i) {
        return ("key-" + i).getBytes(StandardCharsets.UTF_8);
    }

    private static byte[] value(int i) {
        return ("value-" + i).getBytes(StandardCharsets.UTF_8);
    }

    private static Map<String, String> parseArgs(String[] args) {
        Map<String, String> options = new HashMap<>();

        for (int i = 0; i < args.length; i++) {
            String arg = args[i];
            if (!arg.startsWith("--")) {
                continue;
            }

            String key = arg.substring(2);
            String value = "true";
            if (i + 1 < args.length && !args[i + 1].startsWith("--")) {
                value = args[++i];
            }
            options.put(key, value);
        }

        return options;
    }

    private static void deleteRecursively(Path root) throws IOException {
        if (!Files.exists(root)) {
            return;
        }

        try (var stream = Files.walk(root)) {
            stream.sorted((a, b) -> b.compareTo(a)).forEach(path -> {
                try {
                    Files.deleteIfExists(path);
                } catch (IOException e) {
                    throw new RuntimeException("failed to cleanup benchmark directory: " + path, e);
                }
            });
        }
    }
}
