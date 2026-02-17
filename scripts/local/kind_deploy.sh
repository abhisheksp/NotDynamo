#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CLUSTER_NAME="notdynamo"
NAMESPACE="notdynamo"
IMAGE="ghcr.io/notdynamo/notdynamo:dev"
DATA_REPLICAS=3
CONTROL_PLANE_REPLICAS=1
PROVIDER="${KIND_PROVIDER:-auto}"
SKIP_BUILD=0
TMP_ARCHIVE=""

usage() {
  cat <<'USAGE'
Usage: kind_deploy.sh [options]

Builds image, loads it into kind, deploys local overlay, and scales data/control-plane.

Options:
  --name <cluster-name>         kind cluster name (default: notdynamo)
  --namespace <ns>              Kubernetes namespace (default: notdynamo)
  --image <image-ref>           Image tag (default: ghcr.io/notdynamo/notdynamo:dev)
  --data-replicas <n>           notdynamo-data replicas (default: 3)
  --control-plane-replicas <n>  control-plane replicas (default: 1)
  --provider <auto|docker|nerdctl>
                                Container provider (default: auto)
  --skip-build                  Skip image build/load
  --help                        Show this help message
USAGE
}

while (( $# > 0 )); do
  case "$1" in
    --name)
      CLUSTER_NAME="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --image)
      IMAGE="$2"
      shift 2
      ;;
    --data-replicas)
      DATA_REPLICAS="$2"
      shift 2
      ;;
    --control-plane-replicas)
      CONTROL_PLANE_REPLICAS="$2"
      shift 2
      ;;
    --provider)
      PROVIDER="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
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

for n in "$DATA_REPLICAS" "$CONTROL_PLANE_REPLICAS"; do
  if [[ ! "$n" =~ ^[0-9]+$ ]]; then
    echo "replica counts must be non-negative integers" >&2
    exit 1
  fi
done

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

cleanup() {
  if [[ -n "$TMP_ARCHIVE" && -f "$TMP_ARCHIVE" ]]; then
    rm -f "$TMP_ARCHIVE"
  fi
}
trap cleanup EXIT

build_and_load_image() {
  local effective_provider="$1"
  TMP_ARCHIVE="$(make_tmp_file notdynamo-image)"

  if [[ "$effective_provider" == "docker" ]]; then
    require_bin docker
    docker build -t "$IMAGE" "$ROOT_DIR"
    docker save -o "$TMP_ARCHIVE" "$IMAGE"
  else
    ensure_nerdctl_path
    require_bin finch
    finch build -t "$IMAGE" "$ROOT_DIR"
    finch save "$IMAGE" -o "$TMP_ARCHIVE"
    export KIND_EXPERIMENTAL_PROVIDER=nerdctl
  fi

  kind load image-archive "$TMP_ARCHIVE" --name "$CLUSTER_NAME"
}

require_bin kind
require_bin kubectl

if ! kind get clusters | rg -xq "$CLUSTER_NAME"; then
  echo "kind cluster '$CLUSTER_NAME' not found. Run scripts/local/kind_up.sh first." >&2
  exit 1
fi

EFFECTIVE_PROVIDER="$(resolve_provider)"
if [[ "$EFFECTIVE_PROVIDER" != "docker" && "$EFFECTIVE_PROVIDER" != "nerdctl" ]]; then
  echo "unsupported provider: $EFFECTIVE_PROVIDER" >&2
  exit 1
fi

if (( SKIP_BUILD == 0 )); then
  build_and_load_image "$EFFECTIVE_PROVIDER"
fi

kubectl apply -k "$ROOT_DIR/deploy/k8s/overlays/local"
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "namespace '$NAMESPACE' was not created by manifest apply" >&2
  exit 1
fi
kubectl -n "$NAMESPACE" scale statefulset notdynamo-data --replicas="$DATA_REPLICAS"
kubectl -n "$NAMESPACE" scale deployment notdynamo-control-plane --replicas="$CONTROL_PLANE_REPLICAS"

kubectl -n "$NAMESPACE" rollout status statefulset/notdynamo-data --timeout=300s
kubectl -n "$NAMESPACE" rollout status deployment/notdynamo-control-plane --timeout=300s

kubectl -n "$NAMESPACE" get pods -o wide

echo
echo "Deployment complete."
echo "Next:"
echo "  kubectl -n $NAMESPACE port-forward svc/notdynamo-data 8080:8080"
echo "  $ROOT_DIR/scripts/local/smoke_http.sh http://127.0.0.1:8080 demo-key hello-world"
