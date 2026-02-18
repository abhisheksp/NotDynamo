# NotDynamo E2E HTTP Benchmark Report

- Status: **WARN**
- Timestamp (UTC): 2026-02-18T02:33:41Z
- Scenario: `e2e-http`
- Category: `external-client-port-forward`
- Context: `eks:notdynamo-eks/notdynamo/notdynamo-data`
- Endpoint: `http://127.0.0.1:18080`

## Configuration

| Field | Value |
|---|---|
| Operations | 200 |
| Keyspace | 50 |
| Threads | 4 |
| Read ratio | 0.90 |
| Distribution | uniform |
| Zipf theta | 0.90 |
| Value bytes | 64 |
| Preload | false |
| Connect timeout ms | 1000 |
| Request timeout ms | 1000 |

## Results

| Metric | Value |
|---|---|
| Throughput (rps) | 8.64 |
| Success throughput (rps) | 5.74 |
| p50 latency (ms) | 80.026 |
| p95 latency (ms) | 1002.583 |
| p99 latency (ms) | 1002.942 |
| Success count | 133 |
| Error count | 67 |
| Error rate (%) | 33.5000 |
| Read count | 187 |
| Write count | 13 |
| Read not found count | 82 |
| Preload attempted | 0 |
| Preload success | 0 |
| Preload failed | 0 |
| Effective distribution | uniform |

## Error Samples

- `HttpTimeoutException:request_timed_out`
- `HttpTimeoutException:request_timed_out`
- `HttpTimeoutException:request_timed_out`
- `HttpTimeoutException:request_timed_out`
- `HttpTimeoutException:request_timed_out`
- `HttpTimeoutException:request_timed_out`
- `HttpTimeoutException:request_timed_out`
- `HttpTimeoutException:request_timed_out`

## Artifacts

- JSON report: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/aws/e2e_http_external_20260218T023313Z.json`
- Raw log: `/tmp/notdynamo-e2e-http-20260218T023316Z.log`
- Command:

```bash
./gradlew :bench:run --args='--scenario e2e-http --baseUrl http://127.0.0.1:18080 --operations 200 --keyspace 50 --threads 4 --readRatio 0.90 --distribution uniform --zipfTheta 0.90 --valueBytes 64 --preload false --connectTimeoutMs 1000 --requestTimeoutMs 1000'
```
