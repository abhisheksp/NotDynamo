#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

NAMESPACE="notdynamo"
LOCAL_PORT=8080
KEY="demo-key"
VALUE="hello-notdynamo"

usage() {
  cat <<'USAGE'
Usage: kind_smoke.sh [options]

Runs a local smoke flow against Kubernetes service by port-forwarding and issuing PUT/GET/DELETE.

Options:
  --namespace <ns>   Namespace (default: notdynamo)
  --port <n>         Local port for forwarding (default: 8080)
  --key <key>        Key for request cycle (default: demo-key)
  --value <value>    Value for request cycle (default: hello-notdynamo)
  --help             Show this help message
USAGE
}

while (( $# > 0 )); do
  case "$1" in
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --port)
      LOCAL_PORT="$2"
      shift 2
      ;;
    --key)
      KEY="$2"
      shift 2
      ;;
    --value)
      VALUE="$2"
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

if [[ ! "$LOCAL_PORT" =~ ^[0-9]+$ ]]; then
  echo "--port must be numeric" >&2
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "missing required command: kubectl" >&2
  exit 1
fi

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "namespace '$NAMESPACE' does not exist." >&2
  echo "Run ./scripts/local/kind_deploy.sh first." >&2
  exit 1
fi

PORT_FORWARD_LOG="/tmp/notdynamo-port-forward.log"
kubectl -n "$NAMESPACE" port-forward svc/notdynamo-data "${LOCAL_PORT}:8080" >"$PORT_FORWARD_LOG" 2>&1 &
PF_PID=$!

cleanup() {
  if kill -0 "$PF_PID" >/dev/null 2>&1; then
    kill "$PF_PID" >/dev/null 2>&1 || true
    wait "$PF_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

for _ in {1..30}; do
  if curl -fsS "http://127.0.0.1:${LOCAL_PORT}/healthz" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! curl -fsS "http://127.0.0.1:${LOCAL_PORT}/healthz" >/dev/null 2>&1; then
  echo "port-forward did not become ready. See $PORT_FORWARD_LOG" >&2
  exit 1
fi

"$ROOT_DIR/scripts/local/smoke_http.sh" "http://127.0.0.1:${LOCAL_PORT}" "$KEY" "$VALUE"
