# EKS Utilities

These scripts provide a low-friction EKS setup/deploy/smoke/teardown loop for NotDynamo.

## Goals

- Keep local and cloud manifests aligned by reusing the same Kubernetes base.
- Make cluster lifecycle explicit so AWS billing only accrues during active test windows.
- Avoid exposing NotDynamo service publicly by default.

## Prerequisites

Install required tools:

```bash
brew install awscli eksctl kubernetes-cli
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
  --read-ratio 0.90

# 5) Teardown when done (stop billing)
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
- `eks_bench_http.sh` runs end-to-end HTTP benchmark without exposing a public data endpoint.
- Benchmark roadmap: `scripts/eks/BENCHMARK_PLAN.md`.
