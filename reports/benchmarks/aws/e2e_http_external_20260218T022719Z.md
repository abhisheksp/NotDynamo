# NotDynamo E2E HTTP Benchmark Report

- Status: **WARN**
- Timestamp (UTC): 2026-02-18T02:28:48Z
- Scenario: `e2e-http`
- Category: `external-client-port-forward`
- Context: `eks:notdynamo-eks/notdynamo/notdynamo-data`
- Endpoint: `http://127.0.0.1:18080`

## Configuration

| Field | Value |
|---|---|
| Operations | 8000 |
| Keyspace | 1000 |
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
| Throughput (rps) | 94.96 |
| Success throughput (rps) | 90.11 |
| p50 latency (ms) | 78.445 |
| p95 latency (ms) | 195.150 |
| p99 latency (ms) | 249.020 |
| Success count | 7591 |
| Error count | 409 |
| Error rate (%) | 5.1125 |
| Read count | 7251 |
| Write count | 749 |
| Read not found count | 4842 |
| Preload attempted | 0 |
| Preload success | 0 |
| Preload failed | 0 |
| Effective distribution | uniform |

## Error Samples

- `http_status=503`
- `http_status=503`
- `http_status=503`
- `http_status=503`
- `http_status=503`
- `http_status=503`
- `http_status=503`
- `http_status=503`

## Artifacts

- JSON report: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/aws/e2e_http_external_20260218T022719Z.json`
- Raw log: `/tmp/notdynamo-e2e-http-20260218T022723Z.log`
- Command:

```bash
./gradlew :bench:run --args='--scenario e2e-http --baseUrl http://127.0.0.1:18080 --operations 8000 --keyspace 1000 --threads 8 --readRatio 0.90 --distribution uniform --zipfTheta 0.90 --valueBytes 256 --preload false --connectTimeoutMs 3000 --requestTimeoutMs 5000'
```
