# NotDynamo Benchmark Plan (E2E First)

## Objective

Validate end-to-end service performance first (HTTP client -> NotDynamo API), then expand to larger AWS benchmark runs.

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

## Phase 2: E2E Benchmark (now)

Run networked E2E benchmark against EKS through `kubectl port-forward` (private service).

### Command

```bash
./scripts/eks/eks_bench_http.sh --name notdynamo-eks --region us-west-2
```

Artifacts:
- `reports/benchmarks/aws/e2e_http_*.json`
- `/tmp/notdynamo-e2e-http-*.log`

## Phase 3: Scale AWS Benchmarking (later)

Current E2E benchmark client runs from your workstation via API server port-forward. It is correct for functional E2E and small/medium throughput. For higher throughput, move benchmark workers into the cluster network.

### Required additions

1. Add in-cluster benchmark job runner:
   - `scripts/eks/eks_bench_job_up.sh`
   - `scripts/eks/eks_bench_job_down.sh`
2. Package benchmark client image and run N parallel benchmark pods.
3. Aggregate pod metrics into one report under `reports/benchmarks/aws/`.

## Acceptance criteria for AWS benchmark phase

1. No public data endpoint is required.
2. Benchmarks can run entirely within VPC/cluster network (job mode).
3. One-command setup/deploy/smoke/bench/teardown workflow.
4. Cost controls:
   - cluster teardown command always executed at end,
   - optional ECR cleanup,
   - orphan EBS cleanup retained.
