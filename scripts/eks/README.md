# EKS Utilities

These scripts provide a low-friction EKS setup/deploy/smoke/teardown loop for NotDynamo.

## Goals

- Keep local and cloud manifests aligned by reusing the same Kubernetes base.
- Make cluster lifecycle explicit so AWS billing only accrues during active test windows.

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

# 3) Smoke test against AWS LoadBalancer endpoint
./scripts/eks/eks_smoke.sh \
  --name notdynamo-eks \
  --region us-west-2

# 4) Run local benchmark profile (separate from AWS)
./scripts/bench/run_local_canonical_profile.sh

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
