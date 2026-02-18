# NotDynamo E2E HTTP Benchmark Report

- Status: **PASS**
- Timestamp (UTC): 2026-02-18T03:14:31Z
- Scenario: `e2e-http`
- Category: `external-client-port-forward`
- Context: `eks:notdynamo-eks/notdynamo/notdynamo-data`
- Endpoint: `http://127.0.0.1:18080`

## Configuration

| Field | Value |
|---|---|
| Operations | 20000 |
| Keyspace | 5000 |
| Threads | 24 |
| Read ratio | 0.90 |
| Distribution | uniform |
| Zipf theta | 0.90 |
| Value bytes | 256 |
| Preload | true |
| Connect timeout ms | 3000 |
| Request timeout ms | 5000 |

## Results

| Metric | Value |
|---|---|
| Throughput (rps) | 308.86 |
| Success throughput (rps) | 308.86 |
| p50 latency (ms) | 79.852 |
| p95 latency (ms) | 91.191 |
| p99 latency (ms) | 99.886 |
| Success count | 20000 |
| Error count | 0 |
| Error rate (%) | 0.0000 |
| Read count | 18004 |
| Write count | 1996 |
| Read not found count | 0 |
| Preload attempted | 5000 |
| Preload success | 5000 |
| Preload failed | 0 |
| Effective distribution | uniform |

## Artifacts

- JSON report: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/aws/e2e_http_external_20260218T030626Z.json`
- Raw log: `/tmp/notdynamo-e2e-http-20260218T030630Z.log`
- Command:

```bash
./gradlew :bench:run --args='--scenario e2e-http --baseUrl http://127.0.0.1:18080 --operations 20000 --keyspace 5000 --threads 24 --readRatio 0.90 --distribution uniform --zipfTheta 0.90 --valueBytes 256 --preload true --connectTimeoutMs 3000 --requestTimeoutMs 5000'
```
