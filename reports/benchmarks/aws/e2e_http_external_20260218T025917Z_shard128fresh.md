# NotDynamo E2E HTTP Benchmark Report

- Status: **PASS**
- Timestamp (UTC): 2026-02-18T02:59:41Z
- Scenario: `e2e-http`
- Category: `external-client-port-forward`
- Context: `eks:notdynamo-eks/notdynamo/notdynamo-data`
- Endpoint: `http://127.0.0.1:18080`

## Configuration

| Field | Value |
|---|---|
| Operations | 2000 |
| Keyspace | 500 |
| Threads | 8 |
| Read ratio | 0.90 |
| Distribution | uniform |
| Zipf theta | 0.90 |
| Value bytes | 256 |
| Preload | false |
| Connect timeout ms | 3000 |
| Request timeout ms | 5000 |

## Results

| Metric | Value |
|---|---|
| Throughput (rps) | 107.10 |
| Success throughput (rps) | 107.10 |
| p50 latency (ms) | 78.953 |
| p95 latency (ms) | 91.030 |
| p99 latency (ms) | 100.920 |
| Success count | 2000 |
| Error count | 0 |
| Error rate (%) | 0.0000 |
| Read count | 1804 |
| Write count | 196 |
| Read not found count | 655 |
| Preload attempted | 0 |
| Preload success | 0 |
| Preload failed | 0 |
| Effective distribution | uniform |

## Artifacts

- JSON report: `reports/benchmarks/aws/e2e_http_external_20260218T025917Z_shard128fresh.json`
- Raw log: `/tmp/notdynamo-e2e-http-20260218T025921Z.log`
- Command:

```bash
./gradlew :bench:run --args='--scenario e2e-http --baseUrl http://127.0.0.1:18080 --operations 2000 --keyspace 500 --threads 8 --readRatio 0.90 --distribution uniform --zipfTheta 0.90 --valueBytes 256 --preload false --connectTimeoutMs 3000 --requestTimeoutMs 5000'
```
