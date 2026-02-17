#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CLUSTER_NAME="notdynamo"
WORKERS=2
PROVIDER="${KIND_PROVIDER:-auto}"

usage() {
  cat <<'USAGE'
Usage: kind_up.sh [options]

Creates a local kind cluster. Defaults to 3 Kubernetes nodes total
(1 control-plane + 2 workers).

Options:
  --name <cluster-name>   Cluster name (default: notdynamo)
  --workers <n>           Number of worker nodes (default: 2)
  --provider <auto|docker|nerdctl>
                          Container provider (default: auto)
  --help                  Show this help message
USAGE
}

while (( $# > 0 )); do
  case "$1" in
    --name)
      CLUSTER_NAME="$2"
      shift 2
      ;;
    --workers)
      WORKERS="$2"
      shift 2
      ;;
    --provider)
      PROVIDER="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! "$WORKERS" =~ ^[0-9]+$ ]]; then
  echo "--workers must be a non-negative integer" >&2
  exit 1
fi

require_bin() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

ensure_nerdctl_path() {
  if command -v nerdctl >/dev/null 2>&1; then
    return
  fi
  if ! command -v finch >/dev/null 2>&1; then
    echo "provider nerdctl requested, but neither nerdctl nor finch are installed" >&2
    exit 1
  fi

  local shim_dir="$ROOT_DIR/tmp/bin"
  mkdir -p "$shim_dir"
  cat >"$shim_dir/nerdctl" <<'EOF'
#!/usr/bin/env bash
exec finch "$@"
EOF
  chmod +x "$shim_dir/nerdctl"
  export PATH="$shim_dir:$PATH"
}

ensure_finch_vm_running() {
  if ! command -v finch >/dev/null 2>&1; then
    return
  fi

  local status
  status="$(finch vm status 2>/dev/null || true)"
  if [[ "$status" == "Running" ]]; then
    return
  fi

  echo "starting Finch VM..."
  if ! finch vm start >/dev/null 2>&1; then
    echo "failed to start Finch VM. Run 'finch vm init' once, then retry." >&2
    exit 1
  fi
}

resolve_provider() {
  if [[ "$PROVIDER" != "auto" ]]; then
    echo "$PROVIDER"
    return
  fi
  if command -v docker >/dev/null 2>&1; then
    echo "docker"
  else
    echo "nerdctl"
  fi
}

make_tmp_file() {
  local label="$1"
  if mktemp --version >/dev/null 2>&1; then
    mktemp "/tmp/${label}.XXXXXX"
  else
    mktemp -t "$label"
  fi
}

require_bin kind
require_bin kubectl

EFFECTIVE_PROVIDER="$(resolve_provider)"
if [[ "$EFFECTIVE_PROVIDER" != "docker" && "$EFFECTIVE_PROVIDER" != "nerdctl" ]]; then
  echo "unsupported provider: $EFFECTIVE_PROVIDER" >&2
  exit 1
fi

if kind get clusters | rg -xq "$CLUSTER_NAME"; then
  echo "kind cluster '$CLUSTER_NAME' already exists"
  exit 0
fi

if [[ "$EFFECTIVE_PROVIDER" == "nerdctl" ]]; then
  ensure_nerdctl_path
  ensure_finch_vm_running
  export KIND_EXPERIMENTAL_PROVIDER=nerdctl
fi

CONFIG_FILE="$(make_tmp_file notdynamo-kind-config)"
trap 'rm -f "$CONFIG_FILE"' EXIT

{
  echo "kind: Cluster"
  echo "apiVersion: kind.x-k8s.io/v1alpha4"
  echo "nodes:"
  echo "- role: control-plane"
  for ((i = 0; i < WORKERS; i++)); do
    echo "- role: worker"
  done
} >"$CONFIG_FILE"

kind create cluster --name "$CLUSTER_NAME" --config "$CONFIG_FILE"
kubectl cluster-info --context "kind-$CLUSTER_NAME" >/dev/null
echo "kind cluster '$CLUSTER_NAME' is ready with $((WORKERS + 1)) nodes"
