package io.notdynamo.bench;

import io.notdynamo.storage.KeyValueStore;
import io.notdynamo.storage.RocksDbKeyValueStore;
import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;

public final class BenchmarkMain {
    private static final int ERROR_SAMPLE_LIMIT = 8;

    private BenchmarkMain() {
    }

    public static void main(String[] args) throws Exception {
        Map<String, String> options = parseArgs(args);
        String scenario = options.getOrDefault("scenario", "single-node-sanity");

        switch (scenario) {
            case "single-node-sanity" -> runSingleNodeSanity(
                parsePositiveInt(options, "operations", 100_000),
                parsePositiveInt(options, "keyspace", 10_000)
            );
            case "cluster-read", "target-1m" -> runConcurrentReadScenario(
                "cluster-read",
                parsePositiveInt(options, "operations", 1_000_000),
                parsePositiveInt(options, "keyspace", 100_000),
                parsePositiveInt(options, "threads", Integer.parseInt(defaultThreadCount())),
                Distribution.uniform()
            );
            case "hotkey-zipf" -> runConcurrentReadScenario(
                "hotkey-zipf",
                parsePositiveInt(options, "operations", 1_000_000),
                parsePositiveInt(options, "keyspace", 100_000),
                parsePositiveInt(options, "threads", Integer.parseInt(defaultThreadCount())),
                Distribution.zipf(
                    parsePositiveInt(options, "keyspace", 100_000),
                    parseRatio(options, "zipfTheta", 0.9)
                )
            );
            case "soak" -> runSoakScenario(
                parsePositiveInt(options, "durationSec", 60),
                parsePositiveInt(options, "operationsPerCycle", 200_000),
                parsePositiveInt(options, "keyspace", 100_000),
                parsePositiveInt(options, "threads", Integer.parseInt(defaultThreadCount()))
            );
            case "e2e-http" -> runEndToEndHttpScenario(options, false);
            case "e2e-http-zipf" -> runEndToEndHttpScenario(options, true);
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

    private static void runEndToEndHttpScenario(Map<String, String> options, boolean forceZipfDistribution) throws Exception {
        String baseUrl = normalizeBaseUrl(options.getOrDefault("baseUrl", "http://127.0.0.1:8080"));
        int operations = parsePositiveInt(options, "operations", 200_000);
        int keyspace = parsePositiveInt(options, "keyspace", 20_000);
        int threads = parsePositiveInt(options, "threads", Integer.parseInt(defaultThreadCount()));
        int valueBytes = parsePositiveInt(options, "valueBytes", 256);
        int connectTimeoutMs = parsePositiveInt(options, "connectTimeoutMs", 3_000);
        int requestTimeoutMs = parsePositiveInt(options, "requestTimeoutMs", 5_000);
        boolean preload = Boolean.parseBoolean(options.getOrDefault("preload", "true"));
        double readRatio = parseFraction(options, "readRatio", 0.9);

        DistributionSpec distributionSpec = resolveDistribution(options, keyspace, forceZipfDistribution);

        HttpClient client = HttpClient.newBuilder()
            .connectTimeout(Duration.ofMillis(connectTimeoutMs))
            .build();

        byte[] valuePayload = payload(valueBytes);
        PreloadSummary preloadSummary = new PreloadSummary(0, 0, 0);
        if (preload) {
            preloadSummary = preloadRemote(client, baseUrl, keyspace, valuePayload, requestTimeoutMs);
        }

        long[] latenciesNanos = new long[operations];
        CountDownLatch startLatch = new CountDownLatch(1);
        CountDownLatch doneLatch = new CountDownLatch(threads);
        ExecutorService executor = Executors.newFixedThreadPool(threads);

        int baseOpsPerThread = operations / threads;
        int remainder = operations % threads;

        AtomicLong globalIndex = new AtomicLong(0);
        AtomicLong successCount = new AtomicLong(0);
        AtomicLong errorCount = new AtomicLong(0);
        AtomicLong readCount = new AtomicLong(0);
        AtomicLong writeCount = new AtomicLong(0);
        AtomicLong readNotFoundCount = new AtomicLong(0);
        ConcurrentLinkedQueue<String> errorSamples = new ConcurrentLinkedQueue<>();

        for (int threadId = 0; threadId < threads; threadId++) {
            int threadOps = baseOpsPerThread + (threadId < remainder ? 1 : 0);
            executor.submit(() -> {
                try {
                    startLatch.await();
                    ThreadLocalRandom random = ThreadLocalRandom.current();

                    for (int i = 0; i < threadOps; i++) {
                        long opIndex = globalIndex.getAndIncrement();
                        int keyIndex = distributionSpec.distribution().nextKeyIndex(random, keyspace, opIndex);
                        String key = "key-" + keyIndex;
                        boolean read = random.nextDouble() < readRatio;

                        if (read) {
                            readCount.incrementAndGet();
                        } else {
                            writeCount.incrementAndGet();
                        }

                        long before = System.nanoTime();
                        try {
                            int statusCode;
                            if (read) {
                                statusCode = httpGet(client, baseUrl, key, requestTimeoutMs);
                            } else {
                                statusCode = httpPut(client, baseUrl, key, valuePayload, requestTimeoutMs);
                            }
                            long after = System.nanoTime();
                            latenciesNanos[(int) opIndex] = after - before;

                            if (statusCode == 200) {
                                successCount.incrementAndGet();
                            } else if (read && statusCode == 404) {
                                successCount.incrementAndGet();
                                readNotFoundCount.incrementAndGet();
                            } else {
                                errorCount.incrementAndGet();
                                recordError(errorSamples, "http_status=" + statusCode);
                            }
                        } catch (Exception e) {
                            long after = System.nanoTime();
                            latenciesNanos[(int) opIndex] = after - before;
                            errorCount.incrementAndGet();
                            recordError(errorSamples, e.getClass().getSimpleName() + ":" + e.getMessage());
                        }
                    }
                } catch (Exception e) {
                    recordError(errorSamples, "thread_failure:" + e.getClass().getSimpleName() + ":" + e.getMessage());
                } finally {
                    doneLatch.countDown();
                }
            });
        }

        long startNanos = System.nanoTime();
        startLatch.countDown();
        boolean finished = doneLatch.await(30, TimeUnit.MINUTES);
        long elapsedNanos = System.nanoTime() - startNanos;

        executor.shutdownNow();
        if (!finished) {
            throw new IllegalStateException("e2e benchmark threads did not finish within timeout");
        }

        Arrays.sort(latenciesNanos);
        emitEndToEndResult(
            baseUrl,
            operations,
            keyspace,
            threads,
            valueBytes,
            readRatio,
            preload,
            distributionSpec.name(),
            elapsedNanos,
            latenciesNanos,
            successCount.get(),
            errorCount.get(),
            readCount.get(),
            writeCount.get(),
            readNotFoundCount.get(),
            preloadSummary,
            errorSamples
        );
    }

    private static int httpGet(HttpClient client, String baseUrl, String key, int requestTimeoutMs) throws Exception {
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(baseUrl + "/v1/kv/" + encodePathSegment(key)))
            .timeout(Duration.ofMillis(requestTimeoutMs))
            .GET()
            .build();
        HttpResponse<byte[]> response = client.send(request, HttpResponse.BodyHandlers.ofByteArray());
        return response.statusCode();
    }

    private static int httpPut(HttpClient client, String baseUrl, String key, byte[] value, int requestTimeoutMs) throws Exception {
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(baseUrl + "/v1/kv/" + encodePathSegment(key)))
            .timeout(Duration.ofMillis(requestTimeoutMs))
            .header("Content-Type", "application/octet-stream")
            .PUT(HttpRequest.BodyPublishers.ofByteArray(value))
            .build();
        HttpResponse<byte[]> response = client.send(request, HttpResponse.BodyHandlers.ofByteArray());
        return response.statusCode();
    }

    private static PreloadSummary preloadRemote(HttpClient client, String baseUrl, int keyspace, byte[] value, int requestTimeoutMs) {
        int success = 0;
        int failed = 0;

        for (int i = 0; i < keyspace; i++) {
            boolean loaded = false;
            for (int attempt = 0; attempt < 3; attempt++) {
                try {
                    int status = httpPut(client, baseUrl, "key-" + i, value, requestTimeoutMs);
                    if (status == 200) {
                        loaded = true;
                        break;
                    }
                } catch (Exception ignored) {
                    // retry below
                }

                try {
                    Thread.sleep(5L * (attempt + 1));
                } catch (InterruptedException interrupted) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }

            if (loaded) {
                success += 1;
            } else {
                failed += 1;
            }
        }

        return new PreloadSummary(keyspace, success, failed);
    }

    private static void emitEndToEndResult(
        String baseUrl,
        int operations,
        int keyspace,
        int threads,
        int valueBytes,
        double readRatio,
        boolean preload,
        String distribution,
        long elapsedNanos,
        long[] latenciesNanos,
        long successCount,
        long errorCount,
        long readCount,
        long writeCount,
        long readNotFoundCount,
        PreloadSummary preloadSummary,
        ConcurrentLinkedQueue<String> errorSamples
    ) {
        double elapsedSec = elapsedNanos / 1_000_000_000.0;
        double throughput = operations / elapsedSec;
        double successThroughput = successCount / elapsedSec;
        double errorRate = operations == 0 ? 0.0 : ((double) errorCount / operations) * 100.0;

        double p50Ms = nanosToMillis(percentile(latenciesNanos, 50));
        double p95Ms = nanosToMillis(percentile(latenciesNanos, 95));
        double p99Ms = nanosToMillis(percentile(latenciesNanos, 99));

        System.out.println("scenario=e2e-http");
        System.out.println("base_url=" + baseUrl);
        System.out.println("operations=" + operations);
        System.out.println("keyspace=" + keyspace);
        System.out.println("threads=" + threads);
        System.out.println("value_bytes=" + valueBytes);
        System.out.printf("read_ratio=%.4f%n", readRatio);
        System.out.println("distribution=" + distribution);
        System.out.println("preload=" + preload);
        System.out.println("preload_attempted=" + preloadSummary.attempted());
        System.out.println("preload_success=" + preloadSummary.succeeded());
        System.out.println("preload_failed=" + preloadSummary.failed());
        System.out.println("success_count=" + successCount);
        System.out.println("error_count=" + errorCount);
        System.out.println("read_count=" + readCount);
        System.out.println("write_count=" + writeCount);
        System.out.println("read_not_found_count=" + readNotFoundCount);
        System.out.printf("error_rate_percent=%.4f%n", errorRate);
        System.out.printf("throughput_rps=%.2f%n", throughput);
        System.out.printf("success_throughput_rps=%.2f%n", successThroughput);
        System.out.printf("latency_ms_p50=%.3f%n", p50Ms);
        System.out.printf("latency_ms_p95=%.3f%n", p95Ms);
        System.out.printf("latency_ms_p99=%.3f%n", p99Ms);

        int sampleIndex = 0;
        for (String sample : errorSamples) {
            System.out.println("error_sample_" + (++sampleIndex) + "=" + sample);
        }
    }

    private static DistributionSpec resolveDistribution(Map<String, String> options, int keyspace, boolean forceZipfDistribution) {
        if (forceZipfDistribution) {
            double theta = parseRatio(options, "zipfTheta", 0.9);
            return new DistributionSpec("zipf", Distribution.zipf(keyspace, theta));
        }

        String distribution = options.getOrDefault("distribution", "uniform").trim().toLowerCase();
        return switch (distribution) {
            case "uniform" -> new DistributionSpec("uniform", Distribution.uniform());
            case "sequential" -> new DistributionSpec("sequential", Distribution.sequential());
            case "zipf" -> {
                double theta = parseRatio(options, "zipfTheta", 0.9);
                yield new DistributionSpec("zipf", Distribution.zipf(keyspace, theta));
            }
            default -> throw new IllegalArgumentException("unsupported distribution: " + distribution);
        };
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

    private static int parsePositiveInt(Map<String, String> options, String key, int defaultValue) {
        String value = options.get(key);
        int parsed = value == null ? defaultValue : Integer.parseInt(value);
        if (parsed <= 0) {
            throw new IllegalArgumentException(key + " must be > 0");
        }
        return parsed;
    }

    private static double parseRatio(Map<String, String> options, String key, double defaultValue) {
        String value = options.get(key);
        double parsed = value == null ? defaultValue : Double.parseDouble(value);
        if (parsed <= 0.0 || parsed >= 1.0) {
            throw new IllegalArgumentException(key + " must be between 0 and 1 (exclusive)");
        }
        return parsed;
    }

    private static double parseFraction(Map<String, String> options, String key, double defaultValue) {
        String value = options.get(key);
        double parsed = value == null ? defaultValue : Double.parseDouble(value);
        if (parsed < 0.0 || parsed > 1.0) {
            throw new IllegalArgumentException(key + " must be between 0 and 1 (inclusive)");
        }
        return parsed;
    }

    private static String normalizeBaseUrl(String baseUrl) {
        if (baseUrl.endsWith("/")) {
            return baseUrl.substring(0, baseUrl.length() - 1);
        }
        return baseUrl;
    }

    private static String encodePathSegment(String key) {
        String encoded = URLEncoder.encode(key, StandardCharsets.UTF_8);
        return encoded.replace("+", "%20");
    }

    private static byte[] payload(int valueBytes) {
        byte[] payload = new byte[valueBytes];
        byte[] seed = "notdynamo-e2e-bench".getBytes(StandardCharsets.UTF_8);
        for (int i = 0; i < valueBytes; i++) {
            payload[i] = seed[i % seed.length];
        }
        return payload;
    }

    private static void recordError(ConcurrentLinkedQueue<String> errorSamples, String message) {
        if (errorSamples.size() >= ERROR_SAMPLE_LIMIT) {
            return;
        }
        if (message == null) {
            errorSamples.add("unknown");
            return;
        }
        errorSamples.add(message.replaceAll("\\s+", "_"));
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

    private record DistributionSpec(String name, Distribution distribution) {
    }

    private record PreloadSummary(int attempted, int succeeded, int failed) {
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
