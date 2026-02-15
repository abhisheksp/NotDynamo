#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://127.0.0.1:8080}"
KEY="${2:-demo-key}"
VALUE="${3:-hello-notdynamo}"

echo "PUT ${BASE_URL}/v1/kv/${KEY}"
curl -sS -X PUT --data-binary "$VALUE" "${BASE_URL}/v1/kv/${KEY}"
echo

echo "GET ${BASE_URL}/v1/kv/${KEY}"
curl -sS "${BASE_URL}/v1/kv/${KEY}"
echo

echo "DELETE ${BASE_URL}/v1/kv/${KEY}"
curl -sS -X DELETE "${BASE_URL}/v1/kv/${KEY}"
echo
