# EKS Utilities

These scripts provide a low-friction EKS setup/deploy/smoke/teardown loop for NotDynamo.

## Goals

- Keep local and cloud manifests aligned by reusing the same Kubernetes base.
- Make cluster lifecycle explicit so AWS billing only accrues during active test windows.
- Avoid exposing NotDynamo service publicly by default.

## Prerequisites

Install required tools:

```bash
brew install awscli eksctl kubernetes-cli jq
```

Container runtime for image build/push:

- `docker`, or
- `finch` (scripts support a temporary `nerdctl` shim via Finch)

Authenticate AWS:

```bash
aws configure
aws sts get-caller-identity
```

## Security defaults

- Data service in EKS overlay is `ClusterIP` (no public `LoadBalancer`).
- Smoke tests use `kubectl port-forward` over the Kubernetes API.
- `eks_up.sh` defaults to restricted API access:
  - public endpoint enabled but CIDR-limited to your current public IP (`/32`)
  - private endpoint enabled

You can override API endpoint mode:

```bash
# Allow broad public API endpoint (not recommended)
./scripts/eks/eks_up.sh --public-api

# Disable public API endpoint entirely (requires VPN/VPC access)
./scripts/eks/eks_up.sh --private-api-only

# Explicit CIDR restriction
./scripts/eks/eks_up.sh --public-cidr 203.0.113.10/32
```

## Cost guardrails

- `eks_up.sh` enforces a budget guard by default: `--max-daily-usd 20`.
- Estimated max cost is calculated using:
  - EKS control-plane hourly cost
  - `nodes-max` x node hourly estimate
  - gp3 EBS estimate for node root volumes
- If estimated cost exceeds the cap, cluster creation is blocked unless you pass `--allow-over-budget`.

Example:

```bash
./scripts/eks/eks_up.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --max-daily-usd 20
```

## Typical EKS Session

```bash
cd /Users/abhishek/workspace/projects/kivi2/NotDynamo

# 1) Create EKS cluster (ephemeral)
./scripts/eks/eks_up.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --node-type t3.large \
  --nodes 2 \
  --nodes-min 2 \
  --nodes-max 4

# (eks_up also configures EBS CSI + IAM role so PVC provisioning works)

# 2) Build + push image to ECR and deploy to EKS
./scripts/eks/eks_deploy.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --data-replicas 3 \
  --control-plane-replicas 1 \
  --provider nerdctl

# 3) Smoke test via kubectl port-forward (no public data endpoint)
./scripts/eks/eks_smoke.sh \
  --name notdynamo-eks \
  --region us-west-2

# 4) Run E2E benchmark against EKS service (via port-forward)
./scripts/eks/eks_bench_http.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --operations 200000 \
  --threads 32 \
  --read-ratio 0.90 \
  --preload false

# 5) Run E2E benchmark through external LoadBalancer/NLB (production-like ingress hop)
#    By default this temporarily patches service type to LoadBalancer and restores it after the run.
./scripts/eks/eks_bench_http.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --endpoint-mode load-balancer \
  --lb-type nlb \
  --lb-scheme internet-facing \
  --operations 200000 \
  --threads 32 \
  --read-ratio 0.90 \
  --preload false

# 6) Run in-cluster E2E benchmark job (recommended for higher-signal perf)
./scripts/eks/eks_bench_job_up.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --operations 200000 \
  --parallelism 4 \
  --completions 4

# Optional: run both categories and get one matrix summary
./scripts/eks/eks_bench_matrix.sh \
  --name notdynamo-eks \
  --region us-west-2

# Optional: run matrix with external category via LoadBalancer/NLB
./scripts/eks/eks_bench_matrix.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --external-mode load-balancer

# Optional: run horizontal scaling sweeps (node count x data replicas)
./scripts/eks/eks_scaling_sweep.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --node-counts 2,3,4 \
  --data-replicas 3,6 \
  --operations 10000 \
  --preload false

# 7) Teardown when done (stop billing)
./scripts/eks/eks_down.sh \
  --name notdynamo-eks \
  --region us-west-2
```

## Optional cleanup

Delete ECR repo too:

```bash
./scripts/eks/eks_down.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --delete-ecr-repo
```

## Notes

- `eks_deploy.sh` defaults to building and pushing a timestamped image tag.
- To deploy an existing image without rebuild/push:

```bash
./scripts/eks/eks_deploy.sh --name notdynamo-eks --region us-west-2 --skip-build --image <image-ref>
```

- `eks_down.sh` deletes app namespace, EKS cluster, and by default performs best-effort cleanup of orphaned EBS volumes tagged to the cluster.
- `eks_bench_http.sh` supports `--endpoint-mode port-forward` (default) and `--endpoint-mode load-balancer`.
- In load-balancer mode, service exposure is temporary by default; use `--lb-keep-service-lb` only when you explicitly want it to remain exposed.
- `eks_bench_job_up.sh` runs in-cluster benchmark workers and writes aggregated reports.
- `eks_bench_job_down.sh` removes benchmark jobs created for in-cluster benchmarking.
- `eks_bench_matrix.sh` runs both benchmark categories and emits one summary report.
- `eks_scaling_sweep.sh` runs node/pod scaling sweeps and emits per-run matrix artifacts plus sweep summaries (JSON/Markdown/CSV).
- `eks_bench_http.sh` defaults to `--preload true`; use `--preload false` for faster smoke-level benchmark iteration.
- each benchmark run writes both JSON and human-readable Markdown reports.
- Benchmark roadmap: `scripts/eks/BENCHMARK_PLAN.md`.
