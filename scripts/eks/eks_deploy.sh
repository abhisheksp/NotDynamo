#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CLUSTER_NAME="${NOTDYNAMO_EKS_CLUSTER:-notdynamo-eks}"
REGION="${AWS_REGION:-us-west-2}"
NAMESPACE="notdynamo"
IMAGE_REPO="notdynamo/notdynamo"
IMAGE_TAG="dev-$(date -u +%Y%m%dT%H%M%SZ)"
IMAGE=""
IMAGE_PLATFORM="linux/amd64"
DOCKERFILE_PATH="Dockerfile.runtime"
DATA_REPLICAS=3
CONTROL_PLANE_REPLICAS=1
PROVIDER="${IMAGE_PROVIDER:-auto}"
SKIP_BUILD=0

usage() {
  cat <<'USAGE'
Usage: eks_deploy.sh [options]

Builds and pushes image to ECR, deploys EKS overlay, updates image, and scales workloads.

Options:
  --name <cluster-name>         EKS cluster name (default: notdynamo-eks)
  --region <aws-region>         AWS region (default: AWS_REGION or us-west-2)
  --namespace <ns>              Kubernetes namespace (default: notdynamo)
  --image <image-ref>           Full image reference to deploy (skips ECR build/push)
  --image-repo <repo>           ECR repo path (default: notdynamo/notdynamo)
  --image-tag <tag>             Image tag (default: dev-<utc timestamp>)
  --platform <platform>         Image platform for build (default: linux/amd64)
  --dockerfile <path>           Dockerfile path relative to repo root (default: Dockerfile.runtime)
  --data-replicas <n>           Data pod replicas (default: 3)
  --control-plane-replicas <n>  Control-plane replicas (default: 1)
  --provider <auto|docker|nerdctl>
                                Container provider for build/push (default: auto)
  --skip-build                  Skip build/push and use --image
  --help                        Show this help message
USAGE
}

while (( $# > 0 )); do
  case "$1" in
    --name)
      CLUSTER_NAME="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
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
    --image-repo)
      IMAGE_REPO="$2"
      shift 2
      ;;
    --image-tag)
      IMAGE_TAG="$2"
      shift 2
      ;;
    --platform)
      IMAGE_PLATFORM="$2"
      shift 2
      ;;
    --dockerfile)
      DOCKERFILE_PATH="$2"
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
  cat >"$shim_dir/nerdctl" <<'EOF_SHIM'
#!/usr/bin/env bash
exec finch "$@"
EOF_SHIM
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

cluster_exists() {
  aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" >/dev/null 2>&1
}

create_ecr_repo_if_missing() {
  if aws ecr describe-repositories --region "$REGION" --repository-names "$IMAGE_REPO" >/dev/null 2>&1; then
    return
  fi
  aws ecr create-repository --region "$REGION" --repository-name "$IMAGE_REPO" >/dev/null
}

ecr_login() {
  local provider="$1"
  local registry="$2"
  if [[ "$provider" == "docker" ]]; then
    aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$registry" >/dev/null
  else
    ensure_nerdctl_path
    require_bin finch
    aws ecr get-login-password --region "$REGION" | finch login --username AWS --password-stdin "$registry" >/dev/null
  fi
}

build_and_push() {
  local provider="$1"
  local image_ref="$2"
  local platform="$3"
  local dockerfile="$4"

  if [[ "$provider" == "docker" ]]; then
    require_bin docker
    docker build --platform "$platform" -f "$dockerfile" -t "$image_ref" "$ROOT_DIR"
    docker push "$image_ref"
  else
    ensure_nerdctl_path
    require_bin finch
    finch build --platform "$platform" -f "$dockerfile" -t "$image_ref" "$ROOT_DIR"
    finch push "$image_ref"
  fi
}

build_distribution() {
  (cd "$ROOT_DIR" && ./gradlew :node:installDist --no-daemon)
}

require_bin aws
require_bin kubectl
require_bin eksctl

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "AWS credentials are not configured or not valid." >&2
  echo "Run: aws configure" >&2
  exit 1
fi

if ! cluster_exists; then
  echo "EKS cluster '$CLUSTER_NAME' not found in region '$REGION'." >&2
  echo "Run: $ROOT_DIR/scripts/eks/eks_up.sh --name $CLUSTER_NAME --region $REGION" >&2
  exit 1
fi

aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" >/dev/null

if (( SKIP_BUILD == 1 )) && [[ -z "$IMAGE" ]]; then
  echo "--skip-build requires --image <image-ref>" >&2
  exit 1
fi

if (( SKIP_BUILD == 0 )) && [[ -z "$IMAGE" ]]; then
  if [[ ! -f "$ROOT_DIR/$DOCKERFILE_PATH" ]]; then
    echo "dockerfile not found: $ROOT_DIR/$DOCKERFILE_PATH" >&2
    exit 1
  fi

  build_distribution

  ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
  REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
  IMAGE="${REGISTRY}/${IMAGE_REPO}:${IMAGE_TAG}"

  create_ecr_repo_if_missing
  EFFECTIVE_PROVIDER="$(resolve_provider)"
  if [[ "$EFFECTIVE_PROVIDER" != "docker" && "$EFFECTIVE_PROVIDER" != "nerdctl" ]]; then
    echo "unsupported provider: $EFFECTIVE_PROVIDER" >&2
    exit 1
  fi

  ecr_login "$EFFECTIVE_PROVIDER" "$REGISTRY"
  build_and_push "$EFFECTIVE_PROVIDER" "$IMAGE" "$IMAGE_PLATFORM" "$ROOT_DIR/$DOCKERFILE_PATH"
fi

kubectl apply -k "$ROOT_DIR/deploy/k8s/overlays/eks"

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "namespace '$NAMESPACE' was not created by manifest apply" >&2
  exit 1
fi

kubectl -n "$NAMESPACE" set image statefulset/notdynamo-data node="$IMAGE"
kubectl -n "$NAMESPACE" set image deployment/notdynamo-control-plane control-plane="$IMAGE"

kubectl -n "$NAMESPACE" scale statefulset notdynamo-data --replicas="$DATA_REPLICAS"
kubectl -n "$NAMESPACE" scale deployment notdynamo-control-plane --replicas="$CONTROL_PLANE_REPLICAS"
kubectl -n "$NAMESPACE" set env statefulset/notdynamo-data \
  NOTDYNAMO_CLUSTER_SIZE="$DATA_REPLICAS" \
  NOTDYNAMO_NAMESPACE="$NAMESPACE" \
  NOTDYNAMO_RUNTIME_MODE="partitioned" \
  NOTDYNAMO_RPC_MODE="grpc" \
  NOTDYNAMO_WRITE_POLICY="leader-quorum" \
  NOTDYNAMO_WRITE_QUORUM_ACKS="2" >/dev/null

kubectl -n "$NAMESPACE" rollout status statefulset/notdynamo-data --timeout=1200s
kubectl -n "$NAMESPACE" rollout status deployment/notdynamo-control-plane --timeout=1200s

kubectl -n "$NAMESPACE" get pods -o wide
kubectl -n "$NAMESPACE" get svc notdynamo-data

echo
echo "Deployment complete."
echo "Next: $ROOT_DIR/scripts/eks/eks_smoke.sh --name $CLUSTER_NAME --region $REGION --namespace $NAMESPACE"
