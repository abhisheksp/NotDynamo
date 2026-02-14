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
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;

public final class BenchmarkMain {
    private BenchmarkMain() {
    }

    public static void main(String[] args) throws Exception {
        Map<String, String> options = parseArgs(args);
        String scenario = options.getOrDefault("scenario", "single-node-sanity");

        switch (scenario) {
            case "single-node-sanity" -> runSingleNodeSanity(
                Integer.parseInt(options.getOrDefault("operations", "100000")),
                Integer.parseInt(options.getOrDefault("keyspace", "10000"))
            );
            case "cluster-read", "target-1m" -> runConcurrentReadScenario(
                "cluster-read",
                Integer.parseInt(options.getOrDefault("operations", "1000000")),
                Integer.parseInt(options.getOrDefault("keyspace", "100000")),
                Integer.parseInt(options.getOrDefault("threads", defaultThreadCount())),
                Distribution.uniform()
            );
            case "hotkey-zipf" -> runConcurrentReadScenario(
                "hotkey-zipf",
                Integer.parseInt(options.getOrDefault("operations", "1000000")),
                Integer.parseInt(options.getOrDefault("keyspace", "100000")),
                Integer.parseInt(options.getOrDefault("threads", defaultThreadCount())),
                Distribution.zipf(
                    Integer.parseInt(options.getOrDefault("keyspace", "100000")),
                    Double.parseDouble(options.getOrDefault("zipfTheta", "0.9"))
                )
            );
            case "soak" -> runSoakScenario(
                Integer.parseInt(options.getOrDefault("durationSec", "60")),
                Integer.parseInt(options.getOrDefault("operationsPerCycle", "200000")),
                Integer.parseInt(options.getOrDefault("keyspace", "100000")),
                Integer.parseInt(options.getOrDefault("threads", defaultThreadCount()))
            );
            default -> throw new IllegalArgumentException("unsupported scenario: " + scenario);
        }
    }

    private static String defaultThreadCount() {
        return String.valueOf(Math.max(4, Runtime.getRuntime().availableProcessors() * 2));
    }

    private static void runSingleNodeSanity(int operations, int keyspace) throws Exception {
        runConcurrentReadScenario("single-node-sanity", operations, keyspace, 1, Distribution.sequential());
    }

    private static void runConcurrentReadScenario(
        String scenario,
        int operations,
        int keyspace,
        int threads,
        Distribution distribution
    ) throws Exception {
        if (operations <= 0 || keyspace <= 0 || threads <= 0) {
            throw new IllegalArgumentException("operations, keyspace, and threads must be > 0");
        }

        Path workDir = Files.createTempDirectory("notdynamo-bench-");
        Path dbPath = workDir.resolve("db");

        try (RocksDbKeyValueStore store = RocksDbKeyValueStore.open(dbPath)) {
            preload(store, keyspace);

            long[] latenciesNanos = new long[operations];
            CountDownLatch startLatch = new CountDownLatch(1);
            CountDownLatch doneLatch = new CountDownLatch(threads);
            ExecutorService executor = Executors.newFixedThreadPool(threads);

            int baseOpsPerThread = operations / threads;
            int remainder = operations % threads;
            AtomicLong globalIndex = new AtomicLong(0);

            for (int threadId = 0; threadId < threads; threadId++) {
                int threadOps = baseOpsPerThread + (threadId < remainder ? 1 : 0);
                executor.submit(() -> {
                    try {
                        startLatch.await();
                        ThreadLocalRandom random = ThreadLocalRandom.current();

                        for (int i = 0; i < threadOps; i++) {
                            long writeIndex = globalIndex.getAndIncrement();
                            int keyIndex = distribution.nextKeyIndex(random, keyspace, writeIndex);
                            byte[] key = key(keyIndex);

                            long before = System.nanoTime();
                            KeyValueStore.GetResult result = store.get(key);
                            long after = System.nanoTime();

                            if (!result.found()) {
                                throw new IllegalStateException("missing key during benchmark");
                            }

                            latenciesNanos[(int) writeIndex] = after - before;
                        }
                    } catch (Exception e) {
                        throw new RuntimeException(e);
                    } finally {
                        doneLatch.countDown();
                    }
                });
            }

            long startNanos = System.nanoTime();
            startLatch.countDown();
            boolean finished = doneLatch.await(10, TimeUnit.MINUTES);
            long elapsedNanos = System.nanoTime() - startNanos;

            executor.shutdownNow();
            if (!finished) {
                throw new IllegalStateException("benchmark threads did not finish within timeout");
            }

            Arrays.sort(latenciesNanos);
            emitResult(scenario, operations, keyspace, threads, elapsedNanos, latenciesNanos);
        } finally {
            deleteRecursively(workDir);
        }
    }

    private static void runSoakScenario(int durationSec, int operationsPerCycle, int keyspace, int threads) throws Exception {
        if (durationSec <= 0) {
            throw new IllegalArgumentException("durationSec must be > 0");
        }

        long deadlineNanos = System.nanoTime() + TimeUnit.SECONDS.toNanos(durationSec);
        int cycle = 0;
        long totalOps = 0;

        while (System.nanoTime() < deadlineNanos) {
            cycle += 1;
            runConcurrentReadScenario("soak-cycle-" + cycle, operationsPerCycle, keyspace, threads, Distribution.uniform());
            totalOps += operationsPerCycle;
        }

        System.out.println("scenario=soak");
        System.out.println("cycles=" + cycle);
        System.out.println("total_operations=" + totalOps);
        System.out.println("duration_sec=" + durationSec);
    }

    private static void preload(RocksDbKeyValueStore store, int keyspace) {
        for (int i = 0; i < keyspace; i++) {
            store.put(key(i), value(i));
        }
    }

    private static void emitResult(
        String scenario,
        int operations,
        int keyspace,
        int threads,
        long elapsedNanos,
        long[] latenciesNanos
    ) {
        double throughput = operations / (elapsedNanos / 1_000_000_000.0);
        double p50Ms = nanosToMillis(percentile(latenciesNanos, 50));
        double p95Ms = nanosToMillis(percentile(latenciesNanos, 95));
        double p99Ms = nanosToMillis(percentile(latenciesNanos, 99));

        System.out.println("scenario=" + scenario);
        System.out.println("operations=" + operations);
        System.out.println("keyspace=" + keyspace);
        System.out.println("threads=" + threads);
        System.out.printf("throughput_rps=%.2f%n", throughput);
        System.out.printf("latency_ms_p50=%.3f%n", p50Ms);
        System.out.printf("latency_ms_p95=%.3f%n", p95Ms);
        System.out.printf("latency_ms_p99=%.3f%n", p99Ms);
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

    private interface Distribution {
        int nextKeyIndex(ThreadLocalRandom random, int keyspace, long sequenceIndex);

        static Distribution uniform() {
            return (random, keyspace, sequenceIndex) -> random.nextInt(keyspace);
        }

        static Distribution sequential() {
            return (random, keyspace, sequenceIndex) -> (int) (sequenceIndex % keyspace);
        }

        static Distribution zipf(int keyspace, double theta) {
            return new ZipfDistribution(keyspace, theta);
        }
    }

    private static final class ZipfDistribution implements Distribution {
        private final double[] cumulative;

        private ZipfDistribution(int keyspace, double theta) {
            if (keyspace <= 0) {
                throw new IllegalArgumentException("keyspace must be > 0");
            }
            if (theta <= 0.0 || theta >= 1.0) {
                throw new IllegalArgumentException("theta must be between 0 and 1");
            }

            this.cumulative = new double[keyspace];
            double normalizer = 0.0;
            for (int i = 1; i <= keyspace; i++) {
                normalizer += 1.0 / Math.pow(i, theta);
            }

            double running = 0.0;
            for (int i = 1; i <= keyspace; i++) {
                running += (1.0 / Math.pow(i, theta)) / normalizer;
                cumulative[i - 1] = running;
            }
            cumulative[keyspace - 1] = 1.0;
        }

        @Override
        public int nextKeyIndex(ThreadLocalRandom random, int keyspace, long sequenceIndex) {
            double sample = random.nextDouble();
            int idx = Arrays.binarySearch(cumulative, sample);
            if (idx >= 0) {
                return idx;
            }
            int insertion = -idx - 1;
            return Math.min(insertion, cumulative.length - 1);
        }
    }
}
