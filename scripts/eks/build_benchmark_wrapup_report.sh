#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
READ_SWEEP_JSON=""
READ_K6_JSON=""
WRITE_SWEEP_JSON="$ROOT_DIR/reports/benchmarks/aws/e54_write_gate_sweep_n11_17_23_29_35_v1.json"
OUTPUT_PREFIX=""
READ_INPUT_KIND=""
READ_SOURCE_DISPLAY_ABS=""

usage() {
  cat <<'USAGE'
Usage: build_benchmark_wrapup_report.sh [options]

Builds a consolidated benchmark wrap-up report from a read upper-bound sweep (E56)
or an existing single read-hit k6 artifact, plus an existing write upper-bound
baseline sweep (E54).

Options:
  --read-sweep-json <path>    Read upper-bound sweep JSON (E56-style)
  --read-k6-json <path>       Existing single read-hit k6 benchmark JSON (fallback if no read sweep)
  --write-sweep-json <path>   Write sweep JSON (default: E54 v1 path)
  --output-prefix <path>      Output prefix for .json/.md/.csv (default: reports/benchmarks/aws/benchmark_wrapup_<YYYYMMDD>_v1)
  --help                      Show help
USAGE
}

while (( $# > 0 )); do
  case "$1" in
    --read-sweep-json)
      READ_SWEEP_JSON="$2"
      shift 2
      ;;
    --read-k6-json)
      READ_K6_JSON="$2"
      shift 2
      ;;
    --write-sweep-json)
      WRITE_SWEEP_JSON="$2"
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

require_bin() {
if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

to_repo_relative() {
  local path="$1"
  if [[ "$path" == "$ROOT_DIR/"* ]]; then
    printf '%s\n' "${path#"$ROOT_DIR/"}"
  else
    printf '%s\n' "$path"
  fi
}

require_bin jq

if [[ -z "$READ_SWEEP_JSON" && -z "$READ_K6_JSON" ]]; then
  echo "one of --read-sweep-json or --read-k6-json is required" >&2
  exit 1
fi
if [[ ! -f "$WRITE_SWEEP_JSON" ]]; then
  echo "write sweep JSON not found: $WRITE_SWEEP_JSON" >&2
  exit 1
fi
WRITE_SWEEP_JSON_ABS="$(cd "$(dirname "$WRITE_SWEEP_JSON")" && pwd)/$(basename "$WRITE_SWEEP_JSON")"

RUN_TS_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
RUN_DAY="$(date -u +%Y%m%d)"
REPORT_DIR="$ROOT_DIR/reports/benchmarks/aws"
if [[ -z "$OUTPUT_PREFIX" ]]; then
  OUTPUT_PREFIX="$REPORT_DIR/benchmark_wrapup_${RUN_DAY}_v1"
fi
OUT_JSON="${OUTPUT_PREFIX}.json"
OUT_MD="${OUTPUT_PREFIX}.md"
OUT_CSV="${OUTPUT_PREFIX}.csv"
LATEST_JSON="$REPORT_DIR/benchmark_wrapup_latest.json"
LATEST_MD="$REPORT_DIR/benchmark_wrapup_latest.md"
LATEST_CSV="$REPORT_DIR/benchmark_wrapup_latest.csv"
mkdir -p "$(dirname "$OUT_JSON")"

TMP_JSON="$(mktemp /tmp/notdynamo-wrapup.XXXXXX.json)"
TMP_READ_SWEEP=""
trap 'rm -f "$TMP_JSON" ${TMP_READ_SWEEP:+"$TMP_READ_SWEEP"}' EXIT

if [[ -n "$READ_SWEEP_JSON" ]]; then
  if [[ ! -f "$READ_SWEEP_JSON" ]]; then
    echo "read sweep JSON not found: $READ_SWEEP_JSON" >&2
    exit 1
  fi
  READ_SWEEP_JSON_ABS="$(cd "$(dirname "$READ_SWEEP_JSON")" && pwd)/$(basename "$READ_SWEEP_JSON")"
  READ_INPUT_KIND="read_sweep"
  READ_SOURCE_DISPLAY_ABS="$READ_SWEEP_JSON_ABS"
else
  if [[ ! -f "$READ_K6_JSON" ]]; then
    echo "read k6 JSON not found: $READ_K6_JSON" >&2
    exit 1
  fi
  READ_K6_JSON_ABS="$(cd "$(dirname "$READ_K6_JSON")" && pwd)/$(basename "$READ_K6_JSON")"
  READ_INPUT_KIND="read_k6_single_run"
  READ_SOURCE_DISPLAY_ABS="$READ_K6_JSON_ABS"
  TMP_READ_SWEEP="$(mktemp /tmp/notdynamo-read-singlepoint.XXXXXX.json)"
  jq -n \
    --arg source_json "$READ_K6_JSON_ABS" \
    --slurpfile k6 "$READ_K6_JSON_ABS" \
    '
    def num_or_null:
      if . == null then null
      elif type == "number" then .
      elif type == "string" then (try tonumber catch null)
      else null end;
    ($k6[0]) as $r |
    (($r.telemetry.signals.service_pod_count // null) | num_or_null) as $service_pods |
    (($r.results.throughput_rps_aggregate // $r.results.throughput_rps // null) | num_or_null) as $attempted_tps |
    (($r.results.success_throughput_rps_aggregate // $r.results.success_throughput_rps // null) | num_or_null) as $success_tps |
    (($r.results.error_rate_percent // $r.results.error_rate_percent_aggregate // null) | num_or_null) as $error_rate |
    (($r.results.latency_ms_p50_max_pod // $r.results.latency_ms_p50 // null) | num_or_null) as $p50 |
    (($r.results.latency_ms_p95_max_pod // $r.results.latency_ms_p95 // null) | num_or_null) as $p95 |
    (($r.results.latency_ms_p99_max_pod // $r.results.latency_ms_p99 // null) | num_or_null) as $p99 |
    (($r.results.read_count // $r.results.read_count_aggregate // null) | num_or_null) as $read_count |
    (($r.results.write_count // $r.results.write_count_aggregate // null) | num_or_null) as $write_count |
    (($r.results.read_not_found_count // $r.results.read_not_found_count_aggregate // null) | num_or_null) as $read_not_found_count |
    (($r.telemetry.signals.generator_to_service_cpu_ratio // null) | num_or_null) as $gen_ratio |
    (($r.telemetry.signals.service_cpu_mcores_sum // null) | num_or_null) as $svc_cpu |
    (($r.telemetry.signals.generator_cpu_mcores_sum // null) | num_or_null) as $gen_cpu |
    (($r.telemetry.signals.cluster_node_count // null) | num_or_null) as $cluster_nodes |
    (($r.config.request_timeout_ms // null) | num_or_null) as $req_timeout |
    (($r.config.keyspace // null) | num_or_null) as $keyspace |
    (($r.config.value_bytes // null) | num_or_null) as $value_bytes |
    (($r.config.vus_per_pod // null) | num_or_null) as $vus_per_pod |
    (($r.job.parallelism // null) | num_or_null) as $parallelism |
    (($r.job.completions // null) | num_or_null) as $completions |
    {
      benchmark: "existing_read_upperbound_single_point",
      status: ($r.status // "PASS"),
      timestamp_utc: ($r.timestamp_utc // null),
      cluster_name: ($r.cluster_name // null),
      region: ($r.region // null),
      namespace: ($r.namespace // null),
      nodegroup_name: null,
      node_type: null,
      sweep: {
        node_counts: (if $service_pods == null then "unknown" else ($service_pods|tostring) end),
        repeats: 1,
        mode: "single_point_existing_artifact"
      },
      benchmark_profile: {
        source_artifact_type: "k6_single_run",
        measured_stage: {
          read_ratio: (($r.config.read_ratio // null) | num_or_null),
          distribution: ($r.config.distribution // null),
          duration: ($r.config.duration // null),
          vus_per_pod: $vus_per_pod,
          parallelism: $parallelism,
          completions: $completions,
          keyspace: $keyspace,
          value_bytes: $value_bytes,
          request_timeout_ms: $req_timeout,
          preload: (($r.config.preload // null) == "true"),
          skip_main: (($r.config.skip_main // null) == "true")
        }
      },
      run_options: {
        source_artifact: $source_json,
        bench_node_label: ($r.job.bench_node_label // null),
        bench_taint_effect: ($r.job.bench_taint_effect // null)
      },
      cost_guardrail: null,
      restore_on_exit: false,
      shard_count: null,
      original_scale: null,
      best_point: {
        node_count: (if $service_pods == null then 0 else $service_pods end),
        data_replicas: (if $service_pods == null then 0 else $service_pods end),
        median_success_read_tps: (if $success_tps == null then 0 else $success_tps end)
      },
      summary_csv: null,
      run_reports_root: ($r.artifacts.run_dir // null),
      points: [
        {
          point_index: 1,
          node_count: (if $service_pods == null then 0 else $service_pods end),
          data_replicas: (if $service_pods == null then 0 else $service_pods end),
          status: ($r.status // "PASS"),
          estimated_hourly_usd_compute_only: null,
          preload: null,
          medians: {
            attempted_read_tps: $attempted_tps,
            success_read_tps: $success_tps,
            error_rate_percent: $error_rate,
            p50_ms: $p50,
            p95_ms: $p95,
            p99_ms: $p99,
            read_count: $read_count,
            write_count: $write_count,
            read_not_found_count: $read_not_found_count,
            generator_to_service_cpu_ratio: $gen_ratio,
            service_cpu_mcores_sum: $svc_cpu,
            generator_cpu_mcores_sum: $gen_cpu,
            cluster_node_count: $cluster_nodes
          },
          acceptance_gate_median: {
            write_count_zero: (($write_count // 0) == 0),
            read_not_found_zero: (($read_not_found_count // 0) == 0),
            all_trials_write_count_zero: (($write_count // 0) == 0),
            all_trials_read_not_found_zero: (($read_not_found_count // 0) == 0)
          },
          runs: [
            {
              run_index: 1,
              point_index: 1,
              node_count: (if $service_pods == null then 0 else $service_pods end),
              data_replicas: (if $service_pods == null then 0 else $service_pods end),
              trial: 1,
              status: ($r.status // "PASS"),
              exit_code: 0,
              attempted_read_tps: $attempted_tps,
              success_read_tps: $success_tps,
              error_rate_percent: $error_rate,
              p50_ms: $p50,
              p95_ms: $p95,
              p99_ms: $p99,
              read_count: $read_count,
              write_count: $write_count,
              read_not_found_count: $read_not_found_count,
              generator_to_service_cpu_ratio: $gen_ratio,
              service_cpu_mcores_sum: $svc_cpu,
              generator_cpu_mcores_sum: $gen_cpu,
              cluster_node_count: $cluster_nodes,
              preload: null,
              measured_json: $source_json,
              acceptance: {
                write_count_zero: (($write_count // 0) == 0),
                read_not_found_zero: (($read_not_found_count // 0) == 0)
              }
            }
          ]
        }
      ],
      runs: [
        {
          run_index: 1,
          point_index: 1,
          node_count: (if $service_pods == null then 0 else $service_pods end),
          data_replicas: (if $service_pods == null then 0 else $service_pods end),
          trial: 1,
          status: ($r.status // "PASS"),
          exit_code: 0,
          attempted_read_tps: $attempted_tps,
          success_read_tps: $success_tps,
          error_rate_percent: $error_rate,
          p50_ms: $p50,
          p95_ms: $p95,
          p99_ms: $p99,
          read_count: $read_count,
          write_count: $write_count,
          read_not_found_count: $read_not_found_count,
          generator_to_service_cpu_ratio: $gen_ratio,
          service_cpu_mcores_sum: $svc_cpu,
          generator_cpu_mcores_sum: $gen_cpu,
          cluster_node_count: $cluster_nodes,
          preload: null,
          measured_json: $source_json,
          acceptance: {
            write_count_zero: (($write_count // 0) == 0),
            read_not_found_zero: (($read_not_found_count // 0) == 0)
          }
        }
      ]
    }
    ' > "$TMP_READ_SWEEP"
  READ_SWEEP_JSON_ABS="$TMP_READ_SWEEP"
fi

jq -n \
  --arg generated_at "$RUN_TS_UTC" \
  --arg read_src "$READ_SOURCE_DISPLAY_ABS" \
  --arg read_input_type "$READ_INPUT_KIND" \
  --arg write_src "$WRITE_SWEEP_JSON_ABS" \
  --slurpfile read "$READ_SWEEP_JSON_ABS" \
  --slurpfile write "$WRITE_SWEEP_JSON_ABS" \
  '
  def num_or_null:
    if . == null then null
    elif type == "number" then .
    elif type == "string" then (try tonumber catch null)
    else null end;
  def round3: if . == null then null else (. * 1000 | round) / 1000 end;
  def median(vals):
    if (vals|length)==0 then null
    elif (vals|length)%2==1 then ((vals|sort)[((vals|length)/2|floor)])
    else ((vals|sort) as $v | (($v[(($v|length)/2)-1] + $v[(($v|length)/2)]) / 2)) end;
  ($read[0]) as $r |
  ($write[0]) as $w |
  (($w.benchmark_profile.read_ratio // 0.10) | num_or_null // 0.10) as $write_read_ratio |
  (1.0 - $write_read_ratio) as $write_write_ratio |
  (
    [ $r.points[] |
      {
        point_index,
        node_count,
        data_replicas,
        status,
        estimated_hourly_usd_compute_only: (.estimated_hourly_usd_compute_only | num_or_null),
        success_tps: (.medians.success_read_tps // .medians.success_tps | num_or_null),
        attempted_tps: (.medians.attempted_read_tps // .medians.attempted_tps // .medians.success_read_tps // .medians.success_tps | num_or_null),
        error_rate_percent: (.medians.error_rate_percent | num_or_null),
        p50_ms: (.medians.p50_ms | num_or_null),
        p95_ms: (.medians.p95_ms | num_or_null),
        p99_ms: (.medians.p99_ms | num_or_null),
        read_count: (.medians.read_count | num_or_null),
        write_count: (.medians.write_count | num_or_null),
        read_not_found_count: (.medians.read_not_found_count | num_or_null),
        generator_to_service_cpu_ratio: (.medians.generator_to_service_cpu_ratio | num_or_null),
        service_cpu_mcores_sum: (.medians.service_cpu_mcores_sum | num_or_null),
        generator_cpu_mcores_sum: (.medians.generator_cpu_mcores_sum | num_or_null),
        cluster_node_count: (.medians.cluster_node_count | num_or_null),
        acceptance_gate_median: (.acceptance_gate_median // {}),
        preload: (.preload // null)
      }
    ]
  ) as $read_points |
  (
    [ $w.points[] |
      (.medians.success_tps | num_or_null) as $success |
      (.medians.error_rate_percent | num_or_null) as $err |
      (.medians.attempted_total_tps | num_or_null) as $attempted_explicit |
      (if $attempted_explicit != null then $attempted_explicit
       elif ($success != null and $err != null and (100 - $err) > 0) then ($success / (1 - ($err / 100)))
       else null end) as $attempted_total |
      (.medians.attempted_read_tps | num_or_null) as $attempted_read_exact |
      (.medians.attempted_write_tps | num_or_null) as $attempted_write_exact |
      {
        point_index,
        node_count,
        data_replicas,
        status,
        estimated_hourly_usd_compute_only: (.estimated_hourly_usd_compute_only | num_or_null),
        success_tps: $success,
        attempted_tps_total: $attempted_total,
        attempted_tps_read: (if $attempted_read_exact != null then $attempted_read_exact elif $attempted_total != null then ($attempted_total * $write_read_ratio) else null end),
        attempted_tps_write: (if $attempted_write_exact != null then $attempted_write_exact elif $attempted_total != null then ($attempted_total * $write_write_ratio) else null end),
        attempted_split_mode: (if ($attempted_read_exact != null and $attempted_write_exact != null) then "exact" elif $attempted_total != null then "estimated_from_success_tps_error_rate_and_configured_mix" else "unavailable" end),
        error_rate_percent: $err,
        timeout_fraction: (.medians.timeout_fraction | num_or_null),
        forward_error_fraction: (.medians.forward_error_fraction | num_or_null),
        consensus_reply_error_fraction: (.medians.consensus_reply_error_fraction | num_or_null),
        forward_hop_ratio_avg: (.medians.forward_hop_ratio_avg | num_or_null),
        generator_to_service_cpu_ratio: (.medians.generator_to_service_cpu_ratio | num_or_null),
        acceptance_gate_median: (.acceptance_gate_median // {})
      }
    ]
  ) as $write_points |
  ($read_points | max_by(.success_tps // 0)) as $best_read |
  ($write_points | max_by(.success_tps // 0)) as $best_write |
  {
    metadata: {
      generated_at_utc: $generated_at,
      report_type: "notdynamo_benchmark_wrapup",
      sources: {
        read_input_json: $read_src,
        read_input_type: $read_input_type,
        write_sweep_json: $write_src
      }
    },
    methodology: {
      benchmark_scope: "single-az-eks",
      formal_path: "in-cluster-k6",
      throughput_semantics: "cluster-wide aggregate tps",
      notes: [
        (if ($r.sweep.mode // "") == "single_point_existing_artifact"
         then "Read upper-bound uses an existing single-point read-hit-heavy k6 artifact (budget-limited fallback; no new E56 N-sweep was run in this session)."
         else "Read upper-bound uses staged preload (setup-only) then measured 100% read-hit-heavy runs."
         end),
        "Write upper-bound baseline reuses E54 write-heavy mixed sweep (read_ratio=0.10), not pure 100% writes.",
        "GET 404 is treated as success in the k6 workload script; read-hit sweep checks read_not_found_count separately."
      ],
      read_upperbound_profile: {
        source_benchmark: ($r.benchmark // null),
        sweep: ($r.sweep // null),
        benchmark_profile: ($r.benchmark_profile // null),
        node_type: ($r.node_type // null),
        shard_count: ($r.shard_count // null)
      },
      write_upperbound_baseline_profile: {
        source_benchmark: ($w.benchmark // null),
        sweep: ($w.sweep // null),
        benchmark_profile: ($w.benchmark_profile // null),
        node_type: ($w.node_type // null),
        shard_count: ($w.shard_count // null)
      }
    },
    read_upperbound: {
      evidence_scope: (
        if (($r.sweep.mode // "") == "single_point_existing_artifact")
        then "single_point_existing_artifact"
        else "sweep"
        end
      ),
      claim_strength: (
        if (($r.sweep.mode // "") == "single_point_existing_artifact")
        then "evidence_only_not_proven_cluster_ceiling_across_scales"
        else "sweep_based_upperbound_candidate"
        end
      ),
      source_summary: {
        benchmark: ($r.benchmark // null),
        status: ($r.status // null),
        cluster_name: ($r.cluster_name // null),
        region: ($r.region // null),
        node_type: ($r.node_type // null),
        best_point: ($r.best_point // null),
        summary_csv: ($r.summary_csv // null),
        run_reports_root: ($r.run_reports_root // null)
      },
      points: ($read_points | map(. + { success_tps: (.success_tps|round3), attempted_tps: (.attempted_tps|round3), error_rate_percent: (.error_rate_percent|round3), p50_ms:(.p50_ms|round3), p95_ms:(.p95_ms|round3), p99_ms:(.p99_ms|round3), generator_to_service_cpu_ratio:(.generator_to_service_cpu_ratio|round3), service_cpu_mcores_sum:(.service_cpu_mcores_sum|round3), generator_cpu_mcores_sum:(.generator_cpu_mcores_sum|round3) })),
      best_point: ($best_read + { success_tps: ($best_read.success_tps|round3), attempted_tps: ($best_read.attempted_tps|round3) })
    },
    write_upperbound_baseline: {
      source_summary: {
        benchmark: ($w.benchmark // null),
        status: ($w.status // null),
        cluster_name: ($w.cluster_name // null),
        region: ($w.region // null),
        node_type: ($w.node_type // null),
        best_point: ($w.best_point // null),
        summary_csv: ($w.summary_csv // null),
        run_reports_root: ($w.run_reports_root // null)
      },
      attempted_split_fallback: {
        configured_read_ratio: $write_read_ratio,
        configured_write_ratio: $write_write_ratio,
        method_when_exact_missing: "attempted_total_tps = success_tps / (1 - error_rate_percent/100); split by configured read/write ratio"
      },
      points: ($write_points | map(. + {
        success_tps: (.success_tps|round3),
        attempted_tps_total: (.attempted_tps_total|round3),
        attempted_tps_read: (.attempted_tps_read|round3),
        attempted_tps_write: (.attempted_tps_write|round3),
        error_rate_percent: (.error_rate_percent|round3),
        timeout_fraction: (.timeout_fraction|round3),
        forward_error_fraction: (.forward_error_fraction|round3),
        consensus_reply_error_fraction: (.consensus_reply_error_fraction|round3),
        forward_hop_ratio_avg: (.forward_hop_ratio_avg|round3),
        generator_to_service_cpu_ratio: (.generator_to_service_cpu_ratio|round3)
      })),
      best_point: ($best_write + {
        success_tps: ($best_write.success_tps|round3),
        attempted_tps_total: ($best_write.attempted_tps_total|round3),
        attempted_tps_write: ($best_write.attempted_tps_write|round3)
      })
    },
    bottlenecks: {
      read_path: {
        summary: (
          if (($r.sweep.mode // "") == "single_point_existing_artifact")
          then "Read throughput currently uses single-point read-hit-heavy evidence only; it is not a proven cluster ceiling across N. Check read_not_found_count and write_count to confirm pure read-hit behavior."
          else "Read upper-bound should be interpreted using read-hit-heavy measured runs; check read_not_found_count and write_count to confirm pure read-hit behavior."
          end
        ),
        points_with_read_misses: [ $read_points[] | select((.read_not_found_count // 0) > 0) | {node_count, read_not_found_count} ],
        points_with_write_activity: [ $read_points[] | select((.write_count // 0) > 0) | {node_count, write_count} ]
      },
      write_path: {
        summary: "Current write bottleneck remains non-timeout write errors dominated by forward path pressure; generator CPU ratio is low, so generator is not the primary limiter at tested scales.",
        evidence_by_point: ($write_points | map({
          node_count,
          success_tps: (.success_tps|round3),
          error_rate_percent: (.error_rate_percent|round3),
          timeout_fraction: (.timeout_fraction|round3),
          forward_error_fraction: (.forward_error_fraction|round3),
          consensus_reply_error_fraction: (.consensus_reply_error_fraction|round3),
          forward_hop_ratio_avg: (.forward_hop_ratio_avg|round3),
          generator_to_service_cpu_ratio: (.generator_to_service_cpu_ratio|round3)
        })),
        high_confidence_observations: [
          "Horizontal scaling improves cluster success TPS substantially in E54.",
          "Write error rate remains materially above a 15% SLA gate across tested N values.",
          "Timeout fraction falls at higher N, implying non-timeout failures dominate remaining errors.",
          "Forward path metrics (forward_error_fraction and forward_hop_ratio_avg) remain high, indicating routing/leader-forward pressure."
        ]
      },
      generator_pressure: {
        read_points_generator_ratio_max: ([$read_points[] | .generator_to_service_cpu_ratio // 0] | max | round3),
        write_points_generator_ratio_max: ([$write_points[] | .generator_to_service_cpu_ratio // 0] | max | round3),
        interpretation: "If generator/service CPU ratio stays well below 1.0 and especially below 0.25 (write gate threshold), generator is unlikely to be the dominant bottleneck."
      }
    },
    next_steps: [
      {
        id: "next-1",
        title: "Reduce write forward-hop pressure",
        rationale: "Write errors are still forward-path heavy; improving leader-aware routing and reducing forwarding should lower non-timeout failures."
      },
      {
        id: "next-2",
        title: "Add exact attempted write/read TPS capture to write sweep artifacts",
        rationale: "E54 required derived attempted TPS because per-trial k6 JSON paths were not preserved in the sweep run artifacts."
      },
      {
        id: "next-3",
        title: "Run external-LB visibility benchmark after in-cluster baseline",
        rationale: "Validates production-like ingress path overhead without changing in-cluster gating methodology."
      }
    ],
    artifacts: {
      source_files: {
        read_sweep_json: $read_src,
        write_sweep_json: $write_src
      }
    }
  }
  ' > "$TMP_JSON"

cp "$TMP_JSON" "$OUT_JSON"

# CSV output (combined read+write rows)
{
  echo "workload,point_index,node_count,data_replicas,status,success_tps,attempted_tps_total,attempted_tps_read,attempted_tps_write,error_rate_percent,p50_ms,p95_ms,p99_ms,read_count,write_count,read_not_found_count,timeout_fraction,forward_error_fraction,consensus_reply_error_fraction,forward_hop_ratio_avg,generator_to_service_cpu_ratio,attempt_split_mode"
  jq -r '.read_upperbound.points[] |
    ["read_upperbound", .point_index, .node_count, .data_replicas, .status, .success_tps, .attempted_tps, .attempted_tps, 0, .error_rate_percent, .p50_ms, .p95_ms, .p99_ms, .read_count, .write_count, .read_not_found_count, null, null, null, null, .generator_to_service_cpu_ratio, "exact"]
    | @csv' "$OUT_JSON"
  jq -r '.write_upperbound_baseline.points[] |
    ["write_upperbound_baseline", .point_index, .node_count, .data_replicas, .status, .success_tps, .attempted_tps_total, .attempted_tps_read, .attempted_tps_write, .error_rate_percent, null, null, null, null, null, null, .timeout_fraction, .forward_error_fraction, .consensus_reply_error_fraction, .forward_hop_ratio_avg, .generator_to_service_cpu_ratio, .attempted_split_mode]
    | @csv' "$OUT_JSON"
} > "$OUT_CSV"

READ_WRAPUP_JSON_REL="$(to_repo_relative "$OUT_JSON")"
READ_WRAPUP_CSV_REL="$(to_repo_relative "$OUT_CSV")"
READ_SOURCE_REL="$(to_repo_relative "$READ_SOURCE_DISPLAY_ABS")"
WRITE_SWEEP_REL="$(to_repo_relative "$WRITE_SWEEP_JSON_ABS")"
READ_INPUT_TYPE="$(jq -r '.metadata.sources.read_input_type // "read_sweep"' "$OUT_JSON")"
READ_SWEEP_MODE="$(jq -r '.methodology.read_upperbound_profile.sweep.mode // "unknown"' "$OUT_JSON")"

read_best_node="$(jq -r '.read_upperbound.best_point.node_count // "n/a"' "$OUT_JSON")"
read_best_success="$(jq -r '.read_upperbound.best_point.success_tps // "n/a"' "$OUT_JSON")"
read_best_attempted="$(jq -r '.read_upperbound.best_point.attempted_tps // "n/a"' "$OUT_JSON")"
write_best_node="$(jq -r '.write_upperbound_baseline.best_point.node_count // "n/a"' "$OUT_JSON")"
write_best_success="$(jq -r '.write_upperbound_baseline.best_point.success_tps // "n/a"' "$OUT_JSON")"
write_best_attempted_write="$(jq -r '.write_upperbound_baseline.best_point.attempted_tps_write // "n/a"' "$OUT_JSON")"
write_split_method="$(jq -r '.write_upperbound_baseline.attempted_split_fallback.method_when_exact_missing' "$OUT_JSON")"

if [[ "$READ_INPUT_TYPE" == "read_k6_single_run" || "$READ_SWEEP_MODE" == "single_point_existing_artifact" ]]; then
  READ_EXEC_SUMMARY_LABEL="Read upper-bound evidence (existing single-point read-hit k6 run)"
  READ_METHOD_BULLET="- Read upper-bound: existing single-point read-hit-heavy in-cluster k6 artifact reused for wrap-up (budget-limited fallback; no new E56 N-sweep in this session). This is evidence, not a proven read ceiling across scales."
  READ_SOURCE_LABEL="Read k6 artifact"
else
  READ_EXEC_SUMMARY_LABEL="Read upper-bound (read-hit-heavy, preloaded)"
  READ_METHOD_BULLET="- Read upper-bound: staged preload-only job, then measured 100% read-only in-cluster k6 jobs per point (2 trials, median)."
  READ_SOURCE_LABEL="Read sweep JSON"
fi

{
  echo "# NotDynamo Benchmark Wrap-Up (Single-AZ EKS)"
  echo
  echo "- Generated (UTC): \`$(jq -r '.metadata.generated_at_utc' "$OUT_JSON")\`"
  echo "- Formal benchmark path: \`in-cluster-k6\`"
  echo "- Throughput semantics: **cluster-wide aggregate TPS**"
  echo
  echo "## Executive Summary"
  echo
  echo "- $READ_EXEC_SUMMARY_LABEL best median success TPS: \`N=$read_best_node => $read_best_success\` (attempted: \`$read_best_attempted\`)"
  if [[ "$READ_INPUT_TYPE" == "read_k6_single_run" || "$READ_SWEEP_MODE" == "single_point_existing_artifact" ]]; then
    echo "- Read result scope: **single-point evidence only** (not a proven multi-\`N\` cluster read ceiling)."
  fi
  echo "- Write upper-bound baseline (E54 write-heavy mixed, 90% writes / 10% reads) best median cluster success TPS: \`N=$write_best_node => $write_best_success\`"
  echo "- Write attempted TPS split is reported as exact only if preserved by sweep artifacts; for E54 it may be estimated from success TPS + error rate + configured mix."
  echo
  echo "## Methodology and Benchmark Categories"
  echo
  echo "$READ_METHOD_BULLET"
  echo "- Write upper-bound baseline: reused E54 in-cluster write-heavy mixed sweep (formal gate profile)."
  echo "- External LoadBalancer/NLB path remains a visibility benchmark, not a gating benchmark, for this wrap-up."
  echo
  echo "## Read Upper-Bound Results"
  echo
  echo "- Source ($READ_SOURCE_LABEL): \`$READ_SOURCE_REL\`"
  echo
  echo "| N (nodes=data replicas) | Success TPS | Attempted TPS | Error % | p95 (ms) | p99 (ms) | Read misses | Write count | Gen/Svc CPU ratio |"
  echo "|---:|---:|---:|---:|---:|---:|---:|---:|---:|"
  jq -r '.read_upperbound.points[] | "| \(.node_count) | \(.success_tps // "n/a") | \(.attempted_tps // "n/a") | \(.error_rate_percent // "n/a") | \(.p95_ms // "n/a") | \(.p99_ms // "n/a") | \(.read_not_found_count // "n/a") | \(.write_count // "n/a") | \(.generator_to_service_cpu_ratio // "n/a") |"' "$OUT_JSON"
  echo
  echo "## Write Upper-Bound Baseline Results (E54, Write-Heavy Mixed)"
  echo
  echo "- Source: \`$WRITE_SWEEP_REL\`"
  echo "- Profile caveat: \`read_ratio=0.10\` (not pure 100% write throughput)"
  echo "- Attempted TPS split fallback method (when exact not preserved): $write_split_method"
  echo
  echo "| N | Success TPS | Attempted TPS (total) | Attempted TPS (write) | Error % | Timeout frac | Forward split | Consensus split | Forward-hop ratio | Gen/Svc CPU ratio | Split mode |"
  echo "|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|"
  jq -r '.write_upperbound_baseline.points[] | "| \(.node_count) | \(.success_tps // "n/a") | \(.attempted_tps_total // "n/a") | \(.attempted_tps_write // "n/a") | \(.error_rate_percent // "n/a") | \(.timeout_fraction // "n/a") | \(.forward_error_fraction // "n/a") | \(.consensus_reply_error_fraction // "n/a") | \(.forward_hop_ratio_avg // "n/a") | \(.generator_to_service_cpu_ratio // "n/a") | \(.attempted_split_mode) |"' "$OUT_JSON"
  echo
  echo "## Write Error Interpretation"
  echo
  echo "- Client-visible k6 error rate is operation-level failure rate (non-success GET/PUT outcomes from the benchmark perspective)."
  echo "- Internal write attribution in E54 comes from sampled service telemetry and splits write-stage failures into:"
  echo "  - \`forward_to_leader\` failures"
  echo "  - \`consensus_reply\` failures"
  echo "- Lower timeout fraction at higher N indicates fewer timeout-dominant failures; remaining failures are still materially non-timeout and forward-path-heavy."
  echo "- \`forward_hop_ratio_avg\` tracks how often writes were forwarded to another node (proxy for leader-unaware routing pressure)."
  echo
  echo "## Bottleneck Analysis (Known vs Unknown)"
  echo
  echo "### Known (from current data)"
  echo
  jq -r '.bottlenecks.write_path.high_confidence_observations[] | "- " + .' "$OUT_JSON"
  echo
  echo "### Evidence by Point (Write Path)"
  echo
  echo "| N | Success TPS | Error % | Timeout frac | Forward split | Consensus split | Forward-hop ratio | Gen/Svc CPU ratio |"
  echo "|---:|---:|---:|---:|---:|---:|---:|---:|"
  jq -r '.bottlenecks.write_path.evidence_by_point[] | "| \(.node_count) | \(.success_tps // "n/a") | \(.error_rate_percent // "n/a") | \(.timeout_fraction // "n/a") | \(.forward_error_fraction // "n/a") | \(.consensus_reply_error_fraction // "n/a") | \(.forward_hop_ratio_avg // "n/a") | \(.generator_to_service_cpu_ratio // "n/a") |"' "$OUT_JSON"
  echo
  echo "### Unknown / Not Proven Yet"
  echo
  echo "- Pure 100% write throughput ceiling has not been measured in the same lockstep N sweep format."
  echo "- External-LB production-path overhead is not included in the formal gating numbers shown here."
  echo
  echo "## Benchmark Caveats"
  echo
  echo "- Read benchmark is an in-cluster path (benchmark pods inside EKS); it does not include external LB ingress hop."
  if [[ "$READ_INPUT_TYPE" == "read_k6_single_run" || "$READ_SWEEP_MODE" == "single_point_existing_artifact" ]]; then
    echo "- Read upper-bound currently reflects **existing single-point evidence** only because the planned read N-sweep was skipped to stay within AWS spend limits; treat it as provisional until the read N-sweep is executed."
  fi
  echo "- k6 GET \`404\` counts as success in the workload script. Read-hit upper-bound runs therefore explicitly report \`read_not_found_count\` and expect it to be zero (or documented if non-zero)."
  echo "- E54 write attempted read/write TPS split may be estimated if exact per-trial k6 JSONs were not preserved by the sweep artifacts."
  echo
  echo "## Next Engineering Steps"
  echo
  jq -r '.next_steps[] | "1. " + .title + " — " + .rationale' "$OUT_JSON"
  echo
  echo "## Artifacts"
  echo
  echo "- Wrap-up JSON: \`$READ_WRAPUP_JSON_REL\`"
  echo "- Wrap-up CSV: \`$READ_WRAPUP_CSV_REL\`"
  echo "- $READ_SOURCE_LABEL: \`$READ_SOURCE_REL\`"
  echo "- Write sweep JSON: \`$WRITE_SWEEP_REL\`"
} > "$OUT_MD"

cp "$OUT_JSON" "$LATEST_JSON"
cp "$OUT_MD" "$LATEST_MD"
cp "$OUT_CSV" "$LATEST_CSV"

echo "Benchmark wrap-up report generated."
echo "JSON: $(to_repo_relative "$OUT_JSON")"
echo "Markdown: $(to_repo_relative "$OUT_MD")"
echo "CSV: $(to_repo_relative "$OUT_CSV")"
echo "Latest JSON: $(to_repo_relative "$LATEST_JSON")"
echo "Latest Markdown: $(to_repo_relative "$LATEST_MD")"
echo "Latest CSV: $(to_repo_relative "$LATEST_CSV")"
