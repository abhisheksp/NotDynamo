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
- Estimated max cost is calculated using only:
  - EKS control-plane hourly cost
  - `nodes-max` x node hourly estimate
  - gp3 EBS estimate for node root volumes
- If estimated cost exceeds the cap, cluster creation is blocked unless you pass `--allow-over-budget`.

Excluded from that estimate:
- inter-AZ / regional data transfer (`EC2 - Other`, including `InterZone-In` / `InterZone-Out`)
- NAT data processing
- T-family CPU credits
- support plan and tax

Postmortem learning from NotDynamo EKS benchmark runs:
- The large bill spike was dominated by inter-AZ transfer during high-throughput multi-node runs.
- Treat `--max-daily-usd` as a preflight compute estimate only, not a full spend ceiling.
- For stricter spend control, prefer single-AZ benchmarking and keep cluster lifetime short.
- See `/docs/benchmark/AWS_COST_POSTMORTEM_2026-02.md`.

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

# 4) Optional but recommended: create dedicated benchmark-generator nodegroup
#    This isolates benchmark clients from data/control-plane pods.
./scripts/eks/eks_bench_nodegroup_up.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --nodegroup-name notdynamo-benchmark-ng \
  --node-type t3.medium \
  --nodes 2 \
  --bench-node-label notdynamo.io/workload=benchmark \
  --bench-node-taint notdynamo.io/workload=benchmark:NoSchedule

# 5) Run E2E benchmark against EKS service (via port-forward)
./scripts/eks/eks_bench_http.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --operations 200000 \
  --threads 32 \
  --read-ratio 0.90 \
  --preload false

# 6) Run E2E benchmark through external LoadBalancer/NLB (production-like ingress hop)
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

# 7) Run in-cluster E2E benchmark job (recommended for higher-signal perf)
#    With --bench-node-label set, benchmark pods are pinned to dedicated benchmark nodes.
./scripts/eks/eks_bench_job_up.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --operations 200000 \
  --parallelism 4 \
  --completions 4 \
  --bench-node-label notdynamo.io/workload=benchmark

# 7b) Run in-cluster E2E benchmark job using k6 (readily available load generator)
#     This keeps generator infra separate from service infra and emits JSON+Markdown reports.
./scripts/eks/eks_bench_job_k6_up.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --parallelism 11 \
  --completions 11 \
  --vus 32 \
  --duration 120s \
  --read-ratio 1.0 \
  --distribution uniform \
  --preload false \
  --bench-node-label notdynamo.io/workload=benchmark

# 7c) Preload then read-hit-heavy with k6
#     Stage 1: deterministic preload (single pod; setup() writes keyspace)
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

#     Stage 2: read-hit-heavy (same keyspace, preload disabled)
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

# 7d) Standardized write-gate run (write-heavy k6 profile + scorecard)
./scripts/eks/eks_write_gate_run.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --namespace notdynamo \
  --bench-node-label notdynamo.io/workload=benchmark

# 7e) Horizontal write-gate sweep with repeats+median per point
#     (lockstep mode: node_count == data_replicas)
./scripts/eks/eks_write_gate_sweep.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --node-counts 5,7,9 \
  --repeats 2 \
  --bench-node-label notdynamo.io/workload=benchmark

# Optional: run both categories and get one matrix summary
./scripts/eks/eks_bench_matrix.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --incluster-bench-node-label notdynamo.io/workload=benchmark

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
  --preload false \
  --incluster-bench-node-label notdynamo.io/workload=benchmark

# Optional: run lockstep sweeps where node_count == data_replicas
./scripts/eks/eks_lockstep_sweep.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --counts 5,6,7,8 \
  --operations 2000 \
  --incluster-parallelism 1 \
  --incluster-completions 1 \
  --incluster-bench-node-label notdynamo.io/workload=benchmark

# 8) Teardown when done (stop billing)
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

## One-Command Runbook

Run setup -> deploy -> smoke -> benchmark -> teardown -> cleanup-audit in one command:

```bash
./scripts/eks/eks_runbook.sh \
  --name notdynamo-eks \
  --region us-west-2 \
  --max-daily-usd 20 \
  --operations 10000 \
  --preload false
```

Artifacts:
- `reports/benchmarks/aws/runbook_*.json|md`
- `reports/benchmarks/aws/runbook_*_artifacts/benchmark_matrix.json|md`
- `reports/benchmarks/aws/runbook_*_artifacts/cleanup_audit.json|md`

## Notes

- `eks_deploy.sh` defaults to building and pushing a timestamped image tag.
- To deploy an existing image without rebuild/push:

```bash
./scripts/eks/eks_deploy.sh --name notdynamo-eks --region us-west-2 --skip-build --image <image-ref>
```

- `eks_down.sh` deletes app namespace, EKS cluster, and by default performs best-effort cleanup of orphaned EBS volumes tagged to the cluster.
- `eks_bench_nodegroup_up.sh` creates/scales a dedicated benchmark nodegroup with label+taint isolation for in-cluster benchmark pods.
- `eks_bench_http.sh` supports `--endpoint-mode port-forward` (default) and `--endpoint-mode load-balancer`.
- In load-balancer mode, service exposure is temporary by default; use `--lb-keep-service-lb` only when you explicitly want it to remain exposed.
- `eks_bench_job_up.sh` runs in-cluster benchmark workers and writes aggregated reports; use `--bench-node-label` to pin workers to dedicated benchmark nodes.
- `eks_bench_job_up.sh` now emits telemetry artifacts per run under `incluster_runs/<job>/telemetry/` (pod/node top snapshots + placement + group summaries) and includes normalized attribution signals in JSON/Markdown reports.
- `eks_bench_job_k6_up.sh` runs in-cluster benchmark workers with `k6` (ready-made load generation tool), pinned to dedicated benchmark nodes via `--bench-node-label`.
- `eks_bench_job_k6_up.sh` writes `reports/benchmarks/aws/e2e_http_incluster_k6_*.json|md` and updates `e2e_http_incluster_k6_latest.json|md`.
- `eks_write_gate_run.sh` executes the canonical write-heavy in-cluster gate profile and emits deterministic scorecards.
- `eks_write_gate_sweep.sh` scales node counts, runs repeated write-gate trials per point, and reports median success/error/timeout metrics.
- `eks_bench_job_down.sh` removes benchmark jobs created for in-cluster benchmarking and also cleans k6 script ConfigMaps.
- `eks_bench_matrix.sh` runs both benchmark categories and emits one summary report; use `--incluster-bench-node-label` to pin in-cluster jobs.
- `eks_scaling_sweep.sh` runs node/pod scaling sweeps and emits per-run matrix artifacts plus sweep summaries (JSON/Markdown/CSV); supports `--incluster-bench-node-label`.
- `eks_lockstep_sweep.sh` runs lockstep scaling (`node_count=data_replicas`) with cost + shard density context and quota pre-checks; supports `--incluster-bench-node-label`.
- `eks_cleanup_audit.sh` checks for potentially billable residual AWS resources and writes JSON/Markdown reports.
- `eks_runbook.sh` runs the end-to-end EKS lifecycle with deterministic teardown and cleanup audit reporting.
- `eks_lockstep_sweep.sh` fails fast when requested counts exceed account EC2 vCPU quotas for the nodegroup instance type.
- `eks_single_az_index.sh` generates a consolidated index of latest single-AZ benchmark artifacts at `docs/benchmark/SINGLE_AZ_INDEX.md`.
- `eks_bench_http.sh` defaults to `--preload true`; use `--preload false` for faster smoke-level benchmark iteration.
- each benchmark run writes both JSON and human-readable Markdown reports.
- Benchmark roadmap: `scripts/eks/BENCHMARK_PLAN.md`.
