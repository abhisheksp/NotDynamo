# NotDynamo Benchmark Plan (E2E First)

## Objective

Cover benchmark categories that map to real deployment paths, with machine-readable + human-readable reports per run.

Categories:

1. External client via `kubectl port-forward` (workstation-driven E2E)
2. External client via Kubernetes `LoadBalancer`/NLB (production-like ingress hop)
3. In-cluster benchmark job (pod-driven E2E over cluster network)

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

### Category A1: External client via port-forward

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

### Category A2: External client via LoadBalancer/NLB

Run networked E2E benchmark against EKS through managed load balancer ingress.

```bash
./scripts/eks/eks_bench_http.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --endpoint-mode load-balancer \
  --lb-type nlb \
  --lb-scheme internet-facing
```

By default, the script temporarily patches the service to `LoadBalancer`, runs benchmark, then restores the service to its original type.

Artifacts:
- `reports/benchmarks/aws/e2e_http_external_lb_*.json`
- `reports/benchmarks/aws/e2e_http_external_lb_*.md`
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

# run matrix with external category through LB/NLB
./scripts/eks/eks_bench_matrix.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --external-mode load-balancer
```

Artifacts:
- `reports/benchmarks/aws/benchmark_matrix_*.json`
- `reports/benchmarks/aws/benchmark_matrix_*.md`

## Phase 3: Scale AWS Benchmarking (now)

Run controlled node-count and data-replica sweeps with one command:

```bash
./scripts/eks/eks_scaling_sweep.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --node-counts 2,3,4 \
  --data-replicas 3,6 \
  --operations 10000 \
  --preload false
```

Artifacts:
- `reports/benchmarks/aws/scaling_sweep_*.json`
- `reports/benchmarks/aws/scaling_sweep_*.md`
- `reports/benchmarks/aws/scaling_sweep_*.csv`
- `reports/benchmarks/aws/scaling_sweep_*_runs/run_*/benchmark_matrix.json|md`

### Required additions

1. Add richer aggregation (per-pod latency histograms, percentile merge) for larger runs.
2. Add automated sweep profiles for port-forward vs load-balancer vs in-cluster comparability.
3. Add repeat-run statistical confidence (multiple trials per sweep point).

## Acceptance criteria for AWS benchmark phase

1. No public data endpoint is required for smoke tests or port-forward benchmark mode.
2. Benchmarks can run entirely within VPC/cluster network (in-cluster job mode).
3. External load-balancer benchmark mode is available for production-like ingress path testing.
4. One-command setup/deploy/smoke/bench/teardown workflow.
5. Cost controls:
   - cluster teardown command always executed at end,
   - optional ECR cleanup,
   - orphan EBS cleanup retained.
