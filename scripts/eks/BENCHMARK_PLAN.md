# NotDynamo Benchmark Plan (E2E First)

## Objective

Cover benchmark categories that map to real deployment paths, with machine-readable + human-readable reports per run.

Categories:

1. External client via `kubectl port-forward` (workstation-driven E2E)
2. In-cluster benchmark job (pod-driven E2E over cluster network)
3. Optional external load balancer path (future hardening/perf phase)

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

## Phase 2: E2E Benchmark Categories (now)

### Category A: External client via port-forward

Run networked E2E benchmark against EKS through `kubectl port-forward` (private service).

### Command

```bash
./scripts/eks/eks_bench_http.sh --name notdynamo-eks --region us-west-2
```

For loops where you want correctness gating first:

```bash
./scripts/bench/run_gated_e2e_http_profile.sh --base-url http://127.0.0.1:18080
```

Artifacts:
- `reports/benchmarks/aws/e2e_http_external_*.json`
- `reports/benchmarks/aws/e2e_http_external_*.md`
- `/tmp/notdynamo-e2e-http-*.log`

### Category B: In-cluster benchmark job

Run benchmark workers as Kubernetes Job pods inside EKS to remove workstation/port-forward bottlenecks.

```bash
./scripts/eks/eks_bench_job_up.sh --name notdynamo-eks --region us-west-2
```

Cleanup benchmark jobs:

```bash
./scripts/eks/eks_bench_job_down.sh --name notdynamo-eks --region us-west-2
```

Artifacts:
- `reports/benchmarks/aws/e2e_http_incluster_*.json`
- `reports/benchmarks/aws/e2e_http_incluster_*.md`
- `reports/benchmarks/aws/incluster_runs/<job-name>/*.log`

### Category Matrix Runner

Run both categories and get one summary:

```bash
./scripts/eks/eks_bench_matrix.sh --name notdynamo-eks --region us-west-2
```

Artifacts:
- `reports/benchmarks/aws/benchmark_matrix_*.json`
- `reports/benchmarks/aws/benchmark_matrix_*.md`

## Phase 3: Scale AWS Benchmarking (later)

Both workstation-driven and in-cluster benchmark paths are available. The next step is to scale in-cluster worker cardinality and improve tail-latency aggregation quality for larger runs.

### Required additions

1. Increase in-cluster worker count and parameter sweeps for horizontal scaling envelopes.
2. Add optional load-balancer path benchmark if needed for external-network SLO characterization.
3. Add richer aggregation (per-pod latency histograms, percentile merge) for larger runs.

## Acceptance criteria for AWS benchmark phase

1. No public data endpoint is required.
2. Benchmarks can run entirely within VPC/cluster network (in-cluster job mode).
3. One-command setup/deploy/smoke/bench/teardown workflow.
4. Cost controls:
   - cluster teardown command always executed at end,
   - optional ECR cleanup,
   - orphan EBS cleanup retained.
