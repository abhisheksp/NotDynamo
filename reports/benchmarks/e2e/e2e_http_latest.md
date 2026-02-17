# NotDynamo E2E HTTP Benchmark Report

- Status: **WARN**
- Timestamp (UTC): 2026-02-17T19:31:08Z
- Scenario: `e2e-http`
- Endpoint: `http://127.0.0.1:18080`

## Configuration

| Field | Value |
|---|---|
| Operations | 5000 |
| Keyspace | 2000 |
| Threads | 12 |
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
| Throughput (rps) | 224.31 |
| Success throughput (rps) | 208.47 |
| p50 latency (ms) | 50.589 |
| p95 latency (ms) | 60.972 |
| p99 latency (ms) | 69.371 |
| Success count | 4647 |
| Error count | 353 |
| Error rate (%) | 7.0600 |
| Read count | 4508 |
| Write count | 492 |
| Read not found count | 4265 |
| Preload attempted | 0 |
| Preload success | 0 |
| Preload failed | 0 |
| Effective distribution | uniform |

## Error Samples

- `http_status=500`
- `http_status=500`
- `http_status=500`
- `http_status=500`
- `http_status=500`
- `http_status=500`
- `http_status=500`
- `http_status=500`

## Artifacts

- JSON report: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/e2e/e2e_http_20260217T193045Z.json`
- Raw log: `/tmp/notdynamo-e2e-http-20260217T193045Z.log`
- Command:

```bash
./gradlew :bench:run --args='--scenario e2e-http --baseUrl http://127.0.0.1:18080 --operations 5000 --keyspace 2000 --threads 12 --readRatio 0.90 --distribution uniform --zipfTheta 0.90 --valueBytes 256 --preload false --connectTimeoutMs 3000 --requestTimeoutMs 5000'
```
