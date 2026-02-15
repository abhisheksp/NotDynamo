# NotDynamo Kubernetes Deployment

This deployment is intentionally provider-agnostic at the base layer.

## Layout

- `base/`: portable manifests shared by all environments.
- `overlays/local/`: local Kubernetes settings (NodePort, relaxed scheduling, single replica).
- `overlays/eks/`: EKS-specific settings (NLB annotations, `gp3` storage class).

## Apply to Local Kubernetes

```bash
kubectl apply -k deploy/k8s/overlays/local
```

## Apply to EKS

```bash
kubectl apply -k deploy/k8s/overlays/eks
```

## Build Runtime Image

```bash
docker build -t notdynamo:dev .
```

For local clusters (kind/minikube), load the image into the cluster before applying manifests.

## Local Utility Scripts

Use the helper scripts in `scripts/local/` for quick iteration:

```bash
./scripts/local/kind_up.sh --workers 2
./scripts/local/kind_deploy.sh --data-replicas 3
./scripts/local/kind_smoke.sh
./scripts/local/kind_down.sh
```
