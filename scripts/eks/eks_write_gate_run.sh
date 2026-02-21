#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CLUSTER_NAME="${NOTDYNAMO_EKS_CLUSTER:-notdynamo-eks}"
REGION="${AWS_REGION:-us-west-2}"
NAMESPACE="notdynamo"
DATA_STATEFULSET="notdynamo-data"
SERVICE_NAME="notdynamo-data"
KEYSPACE=20000
VALUE_BYTES=256
DISTRIBUTION="uniform"
ZIPF_THETA=0.90
PRELOAD="false"
VUS=32
DURATION="90s"
READ_RATIO="0.10"
REQUEST_TIMEOUT_MS=5000
K6_SETUP_TIMEOUT="10m"
WAIT_TIMEOUT_SEC=1800
SKIP_BUILD=0
IMAGE=""
BENCH_NODE_LABEL=""
BENCH_TAINT_EFFECT="NoSchedule"
OUTPUT_PREFIX=""

usage() {
  cat <<'USAGE'
Usage: eks_write_gate_run.sh [options]

Runs the standardized in-cluster write-heavy gate profile and generates
an analyzer scorecard for milestone decisions.

Gate profile:
  read_ratio=0.10
  vus=32
  duration=90s
  request_timeout_ms=5000
  parallelism=completions=data replicas

Options:
  --name <cluster-name>        EKS cluster name (default: notdynamo-eks)
  --region <aws-region>        AWS region (default: AWS_REGION or us-west-2)
  --namespace <ns>             Namespace (default: notdynamo)
  --data-statefulset <name>    Data StatefulSet name (default: notdynamo-data)
  --service <name>             Service name (default: notdynamo-data)
  --keyspace <n>               Keyspace (default: 20000)
  --value-bytes <n>            Value bytes (default: 256)
  --distribution <name>        uniform|sequential|zipf (default: uniform)
  --zipf-theta <0..1>          Zipf theta (default: 0.90)
  --preload <true|false>       Preload phase (default: false)
  --skip-build                 Reuse existing benchmark image
  --image <image-ref>          k6 image override
  --bench-node-label <k=v>     Pin benchmark pods to benchmark nodes
  --bench-taint-effect <e>     Toleration effect (default: NoSchedule)
  --wait-timeout-sec <n>       Benchmark job timeout (default: 1800)
  --output-prefix <path>       Prefix for analyzer outputs (without extension)
  --help                       Show help
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
    --data-statefulset)
      DATA_STATEFULSET="$2"
      shift 2
      ;;
    --service)
      SERVICE_NAME="$2"
      shift 2
      ;;
    --keyspace)
      KEYSPACE="$2"
      shift 2
      ;;
    --value-bytes)
      VALUE_BYTES="$2"
      shift 2
      ;;
    --distribution)
      DISTRIBUTION="$2"
      shift 2
      ;;
    --zipf-theta)
      ZIPF_THETA="$2"
      shift 2
      ;;
    --preload)
      PRELOAD="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --image)
      IMAGE="$2"
      shift 2
      ;;
    --bench-node-label)
      BENCH_NODE_LABEL="$2"
      shift 2
      ;;
    --bench-taint-effect)
      BENCH_TAINT_EFFECT="$2"
      shift 2
      ;;
    --wait-timeout-sec)
      WAIT_TIMEOUT_SEC="$2"
      shift 2
      ;;
    --output-prefix)
      OUTPUT_PREFIX="$2"
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

for n in "$KEYSPACE" "$VALUE_BYTES" "$WAIT_TIMEOUT_SEC"; do
  if [[ ! "$n" =~ ^[0-9]+$ ]] || (( n <= 0 )); then
    echo "keyspace/value-bytes/wait-timeout-sec must be positive integers" >&2
    exit 1
  fi
done

if (( SKIP_BUILD == 1 )) && [[ -z "$IMAGE" ]]; then
  echo "--skip-build requires --image <image-ref>" >&2
  exit 1
fi

replicas="$(kubectl -n "$NAMESPACE" get statefulset "$DATA_STATEFULSET" -o jsonpath='{.spec.replicas}')"
if [[ -z "$replicas" || ! "$replicas" =~ ^[0-9]+$ || "$replicas" == "0" ]]; then
  echo "failed to determine data replicas from statefulset/$DATA_STATEFULSET" >&2
  exit 1
fi

echo "Running write gate profile with data replicas=$replicas (parallelism=completions=$replicas)"

cmd=(
  "$ROOT_DIR/scripts/eks/eks_bench_job_k6_up.sh"
  --name "$CLUSTER_NAME"
  --region "$REGION"
  --namespace "$NAMESPACE"
  --service "$SERVICE_NAME"
  --keyspace "$KEYSPACE"
  --value-bytes "$VALUE_BYTES"
  --read-ratio "$READ_RATIO"
  --distribution "$DISTRIBUTION"
  --zipf-theta "$ZIPF_THETA"
  --preload "$PRELOAD"
  --vus "$VUS"
  --duration "$DURATION"
  --setup-timeout "$K6_SETUP_TIMEOUT"
  --request-timeout-ms "$REQUEST_TIMEOUT_MS"
  --parallelism "$replicas"
  --completions "$replicas"
  --wait-timeout-sec "$WAIT_TIMEOUT_SEC"
)

if (( SKIP_BUILD == 1 )); then
  cmd+=(--skip-build)
fi
if [[ -n "$IMAGE" ]]; then
  cmd+=(--image "$IMAGE")
fi
if [[ -n "$BENCH_NODE_LABEL" ]]; then
  cmd+=(--bench-node-label "$BENCH_NODE_LABEL" --bench-taint-effect "$BENCH_TAINT_EFFECT")
fi

"${cmd[@]}"

RUN_JSON="$(ls -1t "$ROOT_DIR"/reports/benchmarks/aws/e2e_http_incluster_k6_*.json | head -n 1)"
if [[ -z "$RUN_JSON" || ! -f "$RUN_JSON" ]]; then
  echo "failed to locate benchmark JSON output" >&2
  exit 1
fi

RUN_TS="$(date -u +%Y%m%dT%H%M%SZ)"
if [[ -n "$OUTPUT_PREFIX" ]]; then
  SCORE_JSON="${OUTPUT_PREFIX}.json"
  SCORE_MD="${OUTPUT_PREFIX}.md"
else
  SCORE_JSON="$ROOT_DIR/reports/benchmarks/aws/write_gate_scorecard_${RUN_TS}.json"
  SCORE_MD="$ROOT_DIR/reports/benchmarks/aws/write_gate_scorecard_${RUN_TS}.md"
fi

"$ROOT_DIR/scripts/eks/analyze_write_gate.sh" \
  --input "$RUN_JSON" \
  --output-json "$SCORE_JSON" \
  --output-md "$SCORE_MD" >/dev/null

LATEST_JSON="$ROOT_DIR/reports/benchmarks/aws/write_gate_scorecard_latest.json"
LATEST_MD="$ROOT_DIR/reports/benchmarks/aws/write_gate_scorecard_latest.md"
cp "$SCORE_JSON" "$LATEST_JSON"
cp "$SCORE_MD" "$LATEST_MD"

echo "Write gate benchmark complete"
echo "Benchmark JSON: $RUN_JSON"
echo "Scorecard JSON: $SCORE_JSON"
echo "Scorecard Markdown: $SCORE_MD"
echo "Latest scorecard JSON: $LATEST_JSON"
echo "Latest scorecard Markdown: $LATEST_MD"
