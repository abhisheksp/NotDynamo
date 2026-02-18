#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://127.0.0.1:8080}"
KEY="${2:-demo-key}"
VALUE="${3:-hello-notdynamo}"
MAX_TIME_SEC="${NOTDYNAMO_SMOKE_TIMEOUT_SEC:-10}"

echo "PUT ${BASE_URL}/v1/kv/${KEY}"
PUT_RESPONSE="$(curl --fail-with-body --max-time "$MAX_TIME_SEC" -sS -X PUT --data-binary "$VALUE" "${BASE_URL}/v1/kv/${KEY}")"
echo "$PUT_RESPONSE"
if ! echo "$PUT_RESPONSE" | grep -Eq '"version"[[:space:]]*:[[:space:]]*[0-9]+'; then
  echo "PUT response missing version field" >&2
  exit 1
fi

echo "GET ${BASE_URL}/v1/kv/${KEY}"
GET_RESPONSE="$(curl --fail-with-body --max-time "$MAX_TIME_SEC" -sS "${BASE_URL}/v1/kv/${KEY}")"
echo "$GET_RESPONSE"
if [[ "$GET_RESPONSE" != "$VALUE" ]]; then
  echo "GET response mismatch: expected '$VALUE'" >&2
  exit 1
fi

echo "DELETE ${BASE_URL}/v1/kv/${KEY}"
DELETE_RESPONSE="$(curl --fail-with-body --max-time "$MAX_TIME_SEC" -sS -X DELETE "${BASE_URL}/v1/kv/${KEY}")"
echo "$DELETE_RESPONSE"
if ! echo "$DELETE_RESPONSE" | grep -Eq '"version"[[:space:]]*:[[:space:]]*[0-9]+'; then
  echo "DELETE response missing version field" >&2
  exit 1
fi
