# Local Testing Utilities

These scripts provide a simple local test loop for NotDynamo on kind.

## Typical flow

```bash
# 3 Kubernetes nodes total (1 control-plane + 2 workers)
./scripts/local/kind_up.sh --name notdynamo --workers 2

# Build image, deploy local manifests, scale data plane to 3 pods
./scripts/local/kind_deploy.sh --name notdynamo --data-replicas 3

# Port-forward + PUT/GET/DELETE smoke
./scripts/local/kind_smoke.sh
```

## Teardown

```bash
./scripts/local/kind_down.sh --name notdynamo
```

## Notes

- `kind_up.sh` and `kind_deploy.sh` support `--provider auto|docker|nerdctl`.
- For Finch users, scripts create a temporary `nerdctl` shim that delegates to `finch`.
- Current smoke path uses HTTP bridge at `/v1/kv/{key}`.
