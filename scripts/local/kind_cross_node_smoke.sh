#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="notdynamo"
PUT_POD="notdynamo-data-0"
GET_POD="notdynamo-data-1"
PUT_PORT=18080
GET_PORT=18081
KEY="cross-node-demo-key"
VALUE="cross-node-demo-value"

usage() {
  cat <<'USAGE'
Usage: kind_cross_node_smoke.sh [options]

Runs PUT through one pod and GET through another pod to validate cross-node routing.

Options:
  --namespace <ns>   Namespace (default: notdynamo)
  --put-pod <name>   Pod used for PUT requests (default: notdynamo-data-0)
  --get-pod <name>   Pod used for GET requests (default: notdynamo-data-1)
  --put-port <n>     Local port for put pod forward (default: 18080)
  --get-port <n>     Local port for get pod forward (default: 18081)
  --key <key>        Test key (default: cross-node-demo-key)
  --value <value>    Test value (default: cross-node-demo-value)
  --help             Show this help message
USAGE
}

while (( $# > 0 )); do
  case "$1" in
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --put-pod)
      PUT_POD="$2"
      shift 2
      ;;
    --get-pod)
      GET_POD="$2"
      shift 2
      ;;
    --put-port)
      PUT_PORT="$2"
      shift 2
      ;;
    --get-port)
      GET_PORT="$2"
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

for n in "$PUT_PORT" "$GET_PORT"; do
  if [[ ! "$n" =~ ^[0-9]+$ ]]; then
    echo "--put-port and --get-port must be numeric" >&2
    exit 1
  fi
done

require_bin() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

require_bin kubectl
require_bin curl

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "namespace '$NAMESPACE' does not exist." >&2
  exit 1
fi

kubectl -n "$NAMESPACE" get pod "$PUT_POD" >/dev/null
kubectl -n "$NAMESPACE" get pod "$GET_POD" >/dev/null
kubectl -n "$NAMESPACE" wait --for=condition=Ready "pod/$PUT_POD" --timeout=180s >/dev/null
kubectl -n "$NAMESPACE" wait --for=condition=Ready "pod/$GET_POD" --timeout=180s >/dev/null

PUT_LOG="/tmp/notdynamo-put-pod-forward.log"
GET_LOG="/tmp/notdynamo-get-pod-forward.log"

kubectl -n "$NAMESPACE" port-forward "pod/$PUT_POD" "${PUT_PORT}:8080" >"$PUT_LOG" 2>&1 &
PUT_PF_PID=$!
kubectl -n "$NAMESPACE" port-forward "pod/$GET_POD" "${GET_PORT}:8080" >"$GET_LOG" 2>&1 &
GET_PF_PID=$!

cleanup() {
  if kill -0 "$PUT_PF_PID" >/dev/null 2>&1; then
    kill "$PUT_PF_PID" >/dev/null 2>&1 || true
    wait "$PUT_PF_PID" >/dev/null 2>&1 || true
  fi
  if kill -0 "$GET_PF_PID" >/dev/null 2>&1; then
    kill "$GET_PF_PID" >/dev/null 2>&1 || true
    wait "$GET_PF_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

wait_for_health() {
  local base_url="$1"
  local log_file="$2"
  for _ in {1..30}; do
    if curl -fsS "${base_url}/healthz" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "port-forward did not become ready for ${base_url}. See ${log_file}" >&2
  exit 1
}

PUT_BASE_URL="http://127.0.0.1:${PUT_PORT}"
GET_BASE_URL="http://127.0.0.1:${GET_PORT}"

wait_for_health "$PUT_BASE_URL" "$PUT_LOG"
wait_for_health "$GET_BASE_URL" "$GET_LOG"

put_status="$(curl -sS -o /tmp/notdynamo-cross-put.out -w "%{http_code}" -X PUT --data-binary "$VALUE" "${PUT_BASE_URL}/v1/kv/${KEY}")"
if [[ "$put_status" != "200" ]]; then
  echo "PUT failed via pod '$PUT_POD' with status=$put_status" >&2
  cat /tmp/notdynamo-cross-put.out >&2
  exit 1
fi

get_status="$(curl -sS -o /tmp/notdynamo-cross-get.out -w "%{http_code}" "${GET_BASE_URL}/v1/kv/${KEY}")"
if [[ "$get_status" != "200" ]]; then
  echo "GET failed via pod '$GET_POD' with status=$get_status" >&2
  cat /tmp/notdynamo-cross-get.out >&2
  exit 1
fi

get_value="$(cat /tmp/notdynamo-cross-get.out)"
if [[ "$get_value" != "$VALUE" ]]; then
  echo "unexpected GET value via pod '$GET_POD': expected='$VALUE' actual='$get_value'" >&2
  exit 1
fi

delete_status="$(curl -sS -o /tmp/notdynamo-cross-delete.out -w "%{http_code}" -X DELETE "${GET_BASE_URL}/v1/kv/${KEY}")"
if [[ "$delete_status" != "200" ]]; then
  echo "DELETE failed via pod '$GET_POD' with status=$delete_status" >&2
  cat /tmp/notdynamo-cross-delete.out >&2
  exit 1
fi

post_delete_status="$(curl -sS -o /tmp/notdynamo-cross-post-delete.out -w "%{http_code}" "${PUT_BASE_URL}/v1/kv/${KEY}")"
if [[ "$post_delete_status" != "404" ]]; then
  echo "expected 404 after delete via pod '$PUT_POD', got status=$post_delete_status" >&2
  cat /tmp/notdynamo-cross-post-delete.out >&2
  exit 1
fi

echo "Cross-node smoke succeeded: PUT via $PUT_POD, GET/DELETE via $GET_POD."
