# NotDynamo Benchmark Plan (Local First, AWS Later)

## Objective

Validate correctness and operability on EKS first, then add production-like AWS benchmark runs without public data exposure.

## Phase 1: EKS Correctness + Smoke (now)

1. Create EKS cluster with restricted API endpoint access.
2. Deploy NotDynamo to EKS using `ClusterIP` service (no public data endpoint).
3. Run smoke tests through `kubectl port-forward`.
4. Teardown cluster and confirm cleanup.

### Commands

```bash
./scripts/eks/eks_up.sh --name notdynamo-eks --region us-west-2
./scripts/eks/eks_deploy.sh --name notdynamo-eks --region us-west-2 --provider nerdctl
./scripts/eks/eks_smoke.sh --name notdynamo-eks --region us-west-2
./scripts/eks/eks_down.sh --name notdynamo-eks --region us-west-2
```

## Phase 2: Local Baseline (now)

Keep a consistent local baseline in source control before cloud perf runs.

### Command

```bash
./scripts/bench/run_local_canonical_profile.sh
```

Artifacts:
- `reports/benchmarks/local/cluster_read.*`
- `reports/benchmarks/local/hotkey_zipf.*`
- `reports/benchmarks/local/summary.json`

## Phase 3: AWS Benchmarking (later)

Current bench tool (`bench` module) measures local RocksDB code paths, not networked EKS service latency.

To benchmark EKS service performance, implement a dedicated remote benchmark client (HTTP/gRPC), then run it inside the cluster as a Job/CronJob.

### Required additions

1. Add `bench-client` module:
   - Generates GET/PUT traffic to NotDynamo service.
   - Reports throughput and p50/p95/p99 latency.
   - Supports read/write ratio, keyspace size, hot-key skew, and concurrency.
2. Add `scripts/eks/eks_bench_run.sh`:
   - Creates a benchmark Job in namespace `notdynamo-bench`.
   - Streams logs and writes JSON summary to `reports/benchmarks/aws/`.
3. Add `scripts/eks/eks_bench_cleanup.sh`:
   - Deletes benchmark jobs/pods/configmaps.

## Acceptance criteria for AWS benchmark phase

1. No public data endpoint is required.
2. Benchmarks run entirely within VPC/cluster network.
3. One-command setup/deploy/smoke/bench/teardown workflow.
4. Cost controls:
   - cluster teardown command always executed at end,
   - optional ECR cleanup,
   - orphan EBS cleanup retained.
