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

Recommended first: create a dedicated benchmark nodegroup and isolate benchmark pods:

```bash
./scripts/eks/eks_bench_nodegroup_up.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --nodegroup-name notdynamo-benchmark-ng \
  --node-type t3.medium \
  --nodes 2 \
  --bench-node-label notdynamo.io/workload=benchmark \
  --bench-node-taint notdynamo.io/workload=benchmark:NoSchedule
```

```bash
./scripts/eks/eks_bench_job_up.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --bench-node-label notdynamo.io/workload=benchmark
```

Alternative (recommended for ready-made load generation): run with `k6`.

```bash
./scripts/eks/eks_bench_job_k6_up.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --bench-node-label notdynamo.io/workload=benchmark \
  --parallelism 11 \
  --completions 11 \
  --vus 32 \
  --duration 120s \
  --read-ratio 1.0 \
  --distribution uniform
```

Preload + read-hit-heavy with `k6`:

```bash
# preload seed
./scripts/eks/eks_bench_job_k6_up.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --parallelism 1 \
  --completions 1 \
  --vus 1 \
  --duration 30s \
  --preload true \
  --skip-main true \
  --read-ratio 1.0 \
  --distribution sequential \
  --bench-node-label notdynamo.io/workload=benchmark

# read-hit-heavy
./scripts/eks/eks_bench_job_k6_up.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --parallelism 11 \
  --completions 11 \
  --vus 32 \
  --duration 120s \
  --preload false \
  --read-ratio 1.0 \
  --distribution uniform \
  --bench-node-label notdynamo.io/workload=benchmark
```

Cleanup benchmark jobs:

```bash
./scripts/eks/eks_bench_job_down.sh --name notdynamo-eks --region us-west-2
```

Artifacts:
- `reports/benchmarks/aws/e2e_http_incluster_*.json`
- `reports/benchmarks/aws/e2e_http_incluster_*.md`
- `reports/benchmarks/aws/e2e_http_incluster_k6_*.json`
- `reports/benchmarks/aws/e2e_http_incluster_k6_*.md`
- `reports/benchmarks/aws/incluster_runs/<job-name>/*.log`
- `reports/benchmarks/aws/incluster_runs/<job-name>/pod_placement.txt`
- `reports/benchmarks/aws/incluster_runs/<job-name>/telemetry/pods_top_snapshot.txt`
- `reports/benchmarks/aws/incluster_runs/<job-name>/telemetry/nodes_top_snapshot.txt`
- `reports/benchmarks/aws/incluster_runs/<job-name>/telemetry/*_top_summary.txt`

### Category Matrix Runner

Run both categories and get one summary:

```bash
./scripts/eks/eks_bench_matrix.sh --name notdynamo-eks --region us-west-2

# run matrix with external category through LB/NLB
./scripts/eks/eks_bench_matrix.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --external-mode load-balancer \
  --incluster-bench-node-label notdynamo.io/workload=benchmark
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
  --preload false \
  --incluster-bench-node-label notdynamo.io/workload=benchmark
```

Artifacts:
- `reports/benchmarks/aws/scaling_sweep_*.json`
- `reports/benchmarks/aws/scaling_sweep_*.md`
- `reports/benchmarks/aws/scaling_sweep_*.csv`
- `reports/benchmarks/aws/scaling_sweep_*_runs/run_*/benchmark_matrix.json|md`

Lockstep sweeps (node count == data replicas):

```bash
./scripts/eks/eks_lockstep_sweep.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --counts 5,6,7,8 \
  --operations 2000 \
  --incluster-parallelism 1 \
  --incluster-completions 1 \
  --incluster-bench-node-label notdynamo.io/workload=benchmark
```

Artifacts:
- `reports/benchmarks/aws/lockstep_sweep_*.json`
- `reports/benchmarks/aws/lockstep_sweep_*.md`
- `reports/benchmarks/aws/lockstep_sweep_*.csv`
- `reports/benchmarks/aws/lockstep_sweep_*_runs/lockstep_n*/benchmark_matrix.json|md`

Note:
- `eks_lockstep_sweep.sh` enforces EC2 vCPU quota feasibility (instance type + capacity type) and fails fast when requested counts exceed account limits.

Write-gate sweep (write-heavy, repeated trials + median scorecard by point):

```bash
./scripts/eks/eks_write_gate_sweep.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --node-counts 11,17,23 \
  --repeats 2 \
  --bench-node-label notdynamo.io/workload=benchmark
```

Artifacts:
- `reports/benchmarks/aws/write_gate_sweep_*.json`
- `reports/benchmarks/aws/write_gate_sweep_*.md`
- `reports/benchmarks/aws/write_gate_sweep_*.csv`
- `reports/benchmarks/aws/write_gate_sweep_*_runs/point_*/trial_*/write_gate_scorecard.json|md`

### Required additions

1. Add richer aggregation (per-pod latency histograms, percentile merge) for larger runs.
2. Add automated sweep profiles for port-forward vs load-balancer vs in-cluster comparability.

## Phase 4: One-Command Runbook (now)

Use the runbook automation for deterministic setup/deploy/bench/teardown:

```bash
./scripts/eks/eks_runbook.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --max-daily-usd 20 \
  --operations 10000 \
  --preload false
```

Important:
- `--max-daily-usd` is a compute-side estimate guard, not a hard billing cap.
- High-throughput multi-AZ runs can accumulate significant inter-AZ transfer charges.
- See `/docs/benchmark/AWS_COST_POSTMORTEM_2026-02.md` before running large node-count sweeps.

Artifacts:
- `reports/benchmarks/aws/runbook_*.json|md`
- `reports/benchmarks/aws/runbook_*_artifacts/benchmark_matrix.json|md`
- `reports/benchmarks/aws/runbook_*_artifacts/cleanup_audit.json|md`

## Acceptance criteria for AWS benchmark phase

1. No public data endpoint is required for smoke tests or port-forward benchmark mode.
2. Benchmarks can run entirely within VPC/cluster network (in-cluster job mode).
3. External load-balancer benchmark mode is available for production-like ingress path testing.
4. One-command setup/deploy/smoke/bench/teardown workflow.
5. Cost controls:
   - cluster teardown command always executed at end,
   - optional ECR cleanup,
   - orphan EBS cleanup retained.
