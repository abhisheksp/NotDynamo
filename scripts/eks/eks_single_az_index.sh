#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_FILE="$ROOT_DIR/docs/benchmark/SINGLE_AZ_INDEX.md"
REPORT_ROOT="$ROOT_DIR/reports/benchmarks/aws"

latest_matching() {
  local candidate=""
  candidate="$(ls -t "$@" 2>/dev/null | head -n1 || true)"
  echo "$candidate"
}

latest_lockstep_json="$(latest_matching \
  "$REPORT_ROOT"/e43_lockstep_isolated_fast_20*.json \
  "$REPORT_ROOT"/e43_lockstep_isolated_20*.json \
  "$REPORT_ROOT"/lockstep_sweep_20*.json \
)"
latest_lockstep_md=""
latest_lockstep_csv=""
latest_lockstep_run_root=""
if [[ -n "$latest_lockstep_json" ]]; then
  latest_lockstep_md="${latest_lockstep_json%.json}.md"
  latest_lockstep_csv="${latest_lockstep_json%.json}.csv"
  latest_lockstep_run_root_rel="$(jq -r '.run_reports_root // empty' "$latest_lockstep_json" 2>/dev/null || true)"
  if [[ -n "$latest_lockstep_run_root_rel" ]]; then
    latest_lockstep_run_root="$ROOT_DIR/$latest_lockstep_run_root_rel"
  fi
fi

point_n11_json=""
point_n29_json=""
point_n35_json=""
if [[ -n "$latest_lockstep_run_root" ]]; then
  point_n11_json="$latest_lockstep_run_root/lockstep_n11.json"
  point_n29_json="$latest_lockstep_run_root/lockstep_n29.json"
  point_n35_json="$latest_lockstep_run_root/lockstep_n35.json"
fi

latest_incluster_json="$(latest_matching \
  "$REPORT_ROOT"/e2e_http_incluster_e42_validation_20*.json \
  "$REPORT_ROOT"/e2e_http_incluster_20*.json \
  "$REPORT_ROOT"/e2e_http_incluster_latest.json \
)"
latest_incluster_md=""
if [[ -n "$latest_incluster_json" ]]; then
  latest_incluster_md="${latest_incluster_json%.json}.md"
fi

latest_matrix_json="$(latest_matching \
  "$REPORT_ROOT"/benchmark_matrix_latest.json \
  "$REPORT_ROOT"/benchmark_matrix_20*.json \
)"
latest_matrix_md=""
if [[ -n "$latest_matrix_json" ]]; then
  latest_matrix_md="${latest_matrix_json%.json}.md"
fi

latest_scaling_json="$(latest_matching \
  "$REPORT_ROOT"/scaling_sweep_latest.json \
  "$REPORT_ROOT"/scaling_sweep_20*.json \
)"
latest_scaling_md=""
if [[ -n "$latest_scaling_json" ]]; then
  latest_scaling_md="${latest_scaling_json%.json}.md"
fi

rel() {
  local p="$1"
  if [[ -z "$p" ]]; then
    echo ""
    return
  fi
  if [[ "$p" == "$ROOT_DIR/"* ]]; then
    echo "${p#"$ROOT_DIR/"}"
  else
    echo "$p"
  fi
}

path_or_na() {
  local p="$1"
  if [[ -n "$p" && -e "$p" ]]; then
    echo "\`$(rel "$p")\`"
  else
    echo "n/a"
  fi
}

mkdir -p "$(dirname "$OUT_FILE")"

{
  echo "# NotDynamo Single-AZ Benchmark Index"
  echo
  echo "Timestamp (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo "## Canonical Artifacts"
  echo
  if [[ -n "$latest_lockstep_json" ]]; then
    echo "- Lockstep summary JSON: $(path_or_na "$latest_lockstep_json")"
    echo "- Lockstep summary Markdown: $(path_or_na "$latest_lockstep_md")"
    echo "- Lockstep summary CSV: $(path_or_na "$latest_lockstep_csv")"
    echo "- Lockstep run root: $(path_or_na "$latest_lockstep_run_root")"
    echo "- Point n=11: $(path_or_na "$point_n11_json")"
    echo "- Point n=29: $(path_or_na "$point_n29_json")"
    echo "- Point n=35: $(path_or_na "$point_n35_json")"
  else
    echo "- Lockstep summary JSON: n/a"
  fi
  echo "- Latest in-cluster benchmark JSON: $(path_or_na "$latest_incluster_json")"
  echo "- Latest in-cluster benchmark Markdown: $(path_or_na "$latest_incluster_md")"
  echo "- Latest benchmark matrix JSON: $(path_or_na "$latest_matrix_json")"
  echo "- Latest benchmark matrix Markdown: $(path_or_na "$latest_matrix_md")"
  echo "- Latest scaling sweep JSON: $(path_or_na "$latest_scaling_json")"
  echo "- Latest scaling sweep Markdown: $(path_or_na "$latest_scaling_md")"
  if [[ -n "$latest_lockstep_json" && -e "$latest_lockstep_json" ]]; then
    lockstep_status="$(jq -r '.status // "unknown"' "$latest_lockstep_json" 2>/dev/null || echo unknown)"
    best_node="$(jq -r '.best_run.node_count // empty' "$latest_lockstep_json" 2>/dev/null || true)"
    best_tps="$(jq -r '.best_run.incluster_tps // empty' "$latest_lockstep_json" 2>/dev/null || true)"
    echo "- Lockstep overall status: \`$lockstep_status\`"
    if [[ -n "$best_node" && -n "$best_tps" ]]; then
      echo "- Lockstep best point: \`n=$best_node tps=$best_tps\`"
    fi
  fi
  echo
  echo "## Commands"
  echo
  echo '```bash'
  echo 'IMAGE_REF=<aws-account>.dkr.ecr.us-west-2.amazonaws.com/notdynamo/notdynamo-bench:<tag>'
  echo './scripts/eks/eks_lockstep_sweep.sh --name notdynamo-eks --region us-west-2 --nodegroup-name notdynamo-bench-ng --counts 11,29,35 --operations 500 --keyspace 200 --threads 2 --connect-timeout-ms 1000 --request-timeout-ms 1500 --incluster-parallelism 1 --incluster-completions 1 --incluster-bench-node-label notdynamo.io/workload=benchmark --incluster-skip-build --incluster-image "$IMAGE_REF"'
  echo './scripts/eks/eks_bench_job_up.sh --name notdynamo-eks --region us-west-2 --operations 500 --keyspace 200 --threads 2 --parallelism 1 --completions 1 --connect-timeout-ms 1000 --request-timeout-ms 1500 --preload false --skip-build --image "$IMAGE_REF" --bench-node-label notdynamo.io/workload=benchmark'
  echo '```'
} > "$OUT_FILE"

echo "Wrote: $(rel "$OUT_FILE")"
