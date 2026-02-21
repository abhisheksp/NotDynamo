#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INPUT_JSON=""
OUTPUT_JSON=""
OUTPUT_MD=""

usage() {
  cat <<'USAGE'
Usage: analyze_write_gate.sh --input <benchmark-json> [options]

Analyzes one in-cluster benchmark JSON and emits a deterministic write-gate scorecard.

Options:
  --input <path>         Benchmark JSON file (required)
  --output-json <path>   Optional scorecard JSON output path
  --output-md <path>     Optional Markdown report output path
  --help                 Show help
USAGE
}

while (( $# > 0 )); do
  case "$1" in
    --input)
      INPUT_JSON="$2"
      shift 2
      ;;
    --output-json)
      OUTPUT_JSON="$2"
      shift 2
      ;;
    --output-md)
      OUTPUT_MD="$2"
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

if [[ -z "$INPUT_JSON" ]]; then
  echo "--input is required" >&2
  exit 1
fi

if [[ ! -f "$INPUT_JSON" ]]; then
  echo "input file not found: $INPUT_JSON" >&2
  exit 1
fi

INPUT_JSON_ABS="$(realpath "$INPUT_JSON")"

SCORECARD_JSON="$(
  jq --arg input_benchmark_json "$INPUT_JSON_ABS" '
    def num:
      if . == null or . == "" then 0
      elif type == "number" then .
      else (try tonumber catch 0)
      end;
    def samples:
      [
        .telemetry.write_stage_telemetry.samples[]?.sample
        | if type == "string" then (try fromjson catch null) else . end
        | select(. != null)
      ];
    def merge_shard_errors($sample):
      reduce (($sample.forward_error_by_shard // {}) | to_entries[]) as $e (.;
        .[$e.key] = ((.[$e.key] // 0) + ($e.value | num))
      )
      | reduce (($sample.consensus_reply_error_by_shard // {}) | to_entries[]) as $e (.;
          .[$e.key] = ((.[$e.key] // 0) + ($e.value | num))
        )
      | reduce (($sample.write_backpressure_rejections_by_shard // {}) | to_entries[]) as $e (.;
          .[$e.key] = ((.[$e.key] // 0) + ($e.value | num))
        );

    . as $root
    | (samples) as $samples
    | (reduce $samples[] as $s (0; . + (($s.forward_to_leader.error // 0) | num))) as $forward_errors
    | (reduce $samples[] as $s (0; . + (($s.consensus_reply.error // 0) | num))) as $consensus_errors
    | (reduce $samples[] as $s (0; . + (($s.put_total.error // 0) | num))) as $put_errors
    | (reduce $samples[] as $s (0; . + (($s.put_total.timeout // 0) | num))) as $put_timeouts
    | (reduce $samples[] as $s ({}; merge_shard_errors($s))) as $hotspot_raw
    | (reduce $samples[] as $s (0; . + (($s.forward_hop_ratio // 0) | num))) as $forward_hop_ratio_sum
    | (if ($samples | length) > 0 then ($forward_hop_ratio_sum / ($samples | length)) else 0 end) as $forward_hop_ratio_avg
    | (($root.results.success_throughput_rps_aggregate // 0) | num) as $success_tps
    | (($root.results.error_rate_percent // 0) | num) as $error_rate_percent
    | (($root.telemetry.signals.generator_to_service_cpu_ratio // 0) | num) as $generator_ratio
    | {
        benchmark: ($root.benchmark // "unknown"),
        category: ($root.category // "unknown"),
        timestamp_utc: ($root.timestamp_utc // null),
        input_benchmark_json: $input_benchmark_json,
        input_report: ($root | if has("artifacts") and (.artifacts.run_dir // "") != "" then .artifacts.run_dir else null end),
        scorecard: {
          success_tps: $success_tps,
          error_rate_percent: $error_rate_percent,
          put_error_count: $put_errors,
          put_timeout_count: $put_timeouts,
          put_timeout_fraction_of_put_errors: (if $put_errors > 0 then ($put_timeouts / $put_errors) else 0 end),
          forward_error_count: $forward_errors,
          consensus_reply_error_count: $consensus_errors,
          forward_error_fraction: (if ($forward_errors + $consensus_errors) > 0 then ($forward_errors / ($forward_errors + $consensus_errors)) else 0 end),
          consensus_reply_error_fraction: (if ($forward_errors + $consensus_errors) > 0 then ($consensus_errors / ($forward_errors + $consensus_errors)) else 0 end),
          forward_hop_ratio_avg: $forward_hop_ratio_avg,
          generator_to_service_cpu_ratio: $generator_ratio
        },
        hotspots: (
          $hotspot_raw
          | to_entries
          | map({shard_id: (.key | tonumber), error_events: .value})
          | sort_by(-.error_events)
          | .[0:10]
        ),
        acceptance_gate: {
          success_tps_gte_1000: ($success_tps >= 1000),
          error_rate_percent_lte_15: ($error_rate_percent <= 15),
          put_timeout_fraction_lte_0_60: (if $put_errors > 0 then (($put_timeouts / $put_errors) <= 0.60) else true end),
          generator_ratio_lt_0_25: ($generator_ratio < 0.25)
        }
      }
  ' "$INPUT_JSON"
)"

if [[ -n "$OUTPUT_JSON" ]]; then
  mkdir -p "$(dirname "$OUTPUT_JSON")"
  printf '%s\n' "$SCORECARD_JSON" >"$OUTPUT_JSON"
fi

if [[ -n "$OUTPUT_MD" ]]; then
  mkdir -p "$(dirname "$OUTPUT_MD")"
  success_tps="$(printf '%s' "$SCORECARD_JSON" | jq -r '.scorecard.success_tps')"
  error_rate="$(printf '%s' "$SCORECARD_JSON" | jq -r '.scorecard.error_rate_percent')"
  timeout_fraction="$(printf '%s' "$SCORECARD_JSON" | jq -r '.scorecard.put_timeout_fraction_of_put_errors')"
  forward_split="$(printf '%s' "$SCORECARD_JSON" | jq -r '.scorecard.forward_error_fraction')"
  consensus_split="$(printf '%s' "$SCORECARD_JSON" | jq -r '.scorecard.consensus_reply_error_fraction')"
  generator_ratio="$(printf '%s' "$SCORECARD_JSON" | jq -r '.scorecard.generator_to_service_cpu_ratio')"

  {
    echo "# NotDynamo Write Gate Scorecard"
    echo
    echo "- Input: \\`$(realpath "$INPUT_JSON")\\`"
    echo "- Timestamp (UTC): \\`$(printf '%s' "$SCORECARD_JSON" | jq -r '.timestamp_utc // "unknown"')\\`"
    echo
    echo "## Key Metrics"
    echo
    echo "| Metric | Value |"
    echo "|---|---:|"
    echo "| Success TPS | $success_tps |"
    echo "| Error rate % | $error_rate |"
    echo "| Put timeout fraction of put errors | $timeout_fraction |"
    echo "| Forward error split | $forward_split |"
    echo "| Consensus reply error split | $consensus_split |"
    echo "| Generator/service CPU ratio | $generator_ratio |"
    echo
    echo "## Top Hotspot Shards"
    echo
    echo "| Shard | Error events |"
    echo "|---:|---:|"
    printf '%s' "$SCORECARD_JSON" | jq -r '.hotspots[] | "| \(.shard_id) | \(.error_events) |"'
    echo
    echo "## Acceptance Gate"
    echo
    printf '%s' "$SCORECARD_JSON" | jq -r '.acceptance_gate | to_entries[] | "- \(.key): \(.value)"'
  } >"$OUTPUT_MD"
fi

printf '%s\n' "$SCORECARD_JSON"
