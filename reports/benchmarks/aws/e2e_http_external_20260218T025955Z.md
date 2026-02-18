# NotDynamo E2E HTTP Benchmark Report

- Status: **PASS**
- Timestamp (UTC): 2026-02-18T03:00:38Z
- Scenario: `e2e-http`
- Category: `external-client-port-forward`
- Context: `eks:notdynamo-eks/notdynamo/notdynamo-data`
- Endpoint: `http://127.0.0.1:18080`

## Configuration

| Field | Value |
|---|---|
| Operations | 4000 |
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
| Throughput (rps) | 106.39 |
| Success throughput (rps) | 106.39 |
| p50 latency (ms) | 78.245 |
| p95 latency (ms) | 91.082 |
| p99 latency (ms) | 111.163 |
| Success count | 4000 |
| Error count | 0 |
| Error rate (%) | 0.0000 |
| Read count | 3614 |
| Write count | 386 |
| Read not found count | 1114 |
| Preload attempted | 0 |
| Preload success | 0 |
| Preload failed | 0 |
| Effective distribution | uniform |

## Artifacts

- JSON report: `/Users/abhishek/workspace/projects/kivi2/NotDynamo/reports/benchmarks/aws/e2e_http_external_20260218T025955Z.json`
- Raw log: `/tmp/notdynamo-e2e-http-20260218T025959Z.log`
- Command:

```bash
./gradlew :bench:run --args='--scenario e2e-http --baseUrl http://127.0.0.1:18080 --operations 4000 --keyspace 1000 --threads 8 --readRatio 0.90 --distribution uniform --zipfTheta 0.90 --valueBytes 256 --preload false --connectTimeoutMs 3000 --requestTimeoutMs 5000'
```
