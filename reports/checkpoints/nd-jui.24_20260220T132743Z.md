# Task Checkpoint

- Timestamp (UTC): `2026-02-20 13:27:43Z`
- Issue: `nd-jui.24`
- Claimed now: `0`
- Status override: `in_progress`
- Closed now: `0`
- Note: `E45 grpc-qualified reruns complete on EKS (11x11, write-heavy). New runs: grpcsplit_20260220T132050Z (161.33 rps, 101.02 success_tps, 37.38% errors; 1 empty summary pod) and grpcsplit_rerun_20260220T132413Z (153.81 rps, 87.36 success_tps, 43.20% errors). Aggregated stage errors remain timeout-dominant with grpc detail: forward TIMEOUT/DEADLINE_EXCEEDED=12031, consensus_reply TIMEOUT=6379, forward INTERNAL grpc=CANCELLED=1084; observed leader lookup failures remain 0. Next slice: add explicit write backpressure/fast-fail signaling and rerun for timeout-fraction reduction.`

## Issue Snapshot

```text
◐ nd-jui.24 · E45 Write-path stall root cause: fast-fail and consensus observability   [● P1 · IN_PROGRESS]
Owner: Abhishek Srinivasa Raju Padmavathi · Type: task
Created: 2026-02-19 · Updated: 2026-02-20

DESCRIPTION
Investigate and reduce PUT timeout-dominated failures in RAFT path. Add write-path stage timing and result counters (forward->leader, consensus submit, consensus reply/timeout), expose per-shard leader/reply errors, and implement bounded fast-fail behavior so failed writes return quickly instead of hanging until client timeout.

NOTES
Started E45 execution: using new k6 EKS in-cluster path to capture write-heavy baseline before adding write-path stage telemetry and fast-fail behavior.
[2026-02-20 13:27:43Z] E45 grpc-qualified reruns complete on EKS (11x11, write-heavy). New runs: grpcsplit_20260220T132050Z (161.33 rps, 101.02 success_tps, 37.38% errors; 1 empty summary pod) and grpcsplit_rerun_20260220T132413Z (153.81 rps, 87.36 success_tps, 43.20% errors). Aggregated stage errors remain timeout-dominant with grpc detail: forward TIMEOUT/DEADLINE_EXCEEDED=12031, consensus_reply TIMEOUT=6379, forward INTERNAL grpc=CANCELLED=1084; observed leader lookup failures remain 0. Next slice: add explicit write backpressure/fast-fail signaling and rerun for timeout-fraction reduction.

ACCEPTANCE CRITERIA
1) Per-stage write latency/error telemetry appears in benchmark report artifacts. 2) Failed writes return server errors before client request timeout in representative lockstep run. 3) Lockstep rerun demonstrates improved TPS and lower timeout-error fraction at same workload.

LABELS: benchmark, roadmap, single-az

PARENT
  ↑ ◐ nd-jui: (EPIC) E21 Program: Single-AZ True Sharding and Replication ● P1

COMMENTS
  2026-02-19 22:47 Abhishek Srinivasa Raju Padmavathi
    Baseline with k6 dedicated in-cluster loadgen collected. Read-heavy reference: 9,883.41 rps, p99 77.536ms, 0% errors (e48_k6_read_hit_heavy_fix_20260219T222038Z). Write-heavy baseline: 307.11 rps, p99 3700.002ms, 0% errors (e45_k6_write_heavy_baseline_20260219T223429Z) => write throughput is ~3.11% of read throughput. Improved telemetry sampling now preserves in-flight benchmark-pod snapshots; validation run shows generator_pod_count=8, generator_cpu_mcores_sum=227, service_cpu_mcores_sum=832, attribution=service-pressure-dominant (e45_k6_write_heavy_telemetryfix2_20260219T224627Z). Stage-level write timing + fast-fail behavior changes still pending for E45 acceptance criteria.
  2026-02-20 12:27 Abhishek Srinivasa Raju Padmavathi
    E45 progress update (2026-02-20 UTC): implemented DNS + probe/threading stabilization and reran write-heavy 11x11 k6 workload. Changes: (1) headless service now publishNotReadyAddresses=true to avoid pod FQDN disappearance during readiness flaps; (2) HTTP bridge worker threads raised (NOTDYNAMO_HTTP_WORKER_THREADS, default >=32, set to 64 in k8s) and probe thresholds relaxed (timeout=5s, higher failureThreshold) to avoid false liveness kills under load. Results at same 90s, 11x11, VU32, read_ratio=0.10: baseline 12:01Z = throughput 73.86 rps, success_tps 1.08, error 98.54%; after DNS-only redeploy 12:13Z = throughput 71.83, success_tps 1.65, error 97.70%; after HTTP/probe fix 12:23Z = throughput 173.98, success_tps 106.98, error 38.51%, with zero data-pod restarts during run. Diagnostic with request_timeout_ms=20000 (12:26Z) reduced throughput/success_tps (86.83/51.09) and did not materially reduce error-rate, indicating saturation/queueing bottleneck rather than just aggressive timeout cutoff. Remaining bottleneck is write-path service pressure + shard/leader timeout concentration (consensus/forward timeout-heavy on subset of leaders), not generator capacity.
  2026-02-20 12:31 Abhishek Srinivasa Raju Padmavathi
    Next execution slice started: implement dynamic Raft-leader-aware write targeting (route PUT/DELETE to observed consensus leader when known, fallback to replica-map leader), plus mismatch counters in write telemetry. Goal is to remove extra forward hops and reduce consensus_reply timeout concentration observed after HTTP/probe stabilization.
  2026-02-20 12:44 Abhishek Srinivasa Raju Padmavathi
    Implemented next E45 slice in router: (1) skip observed-leader lookup on non-replica nodes, (2) add backoff cache for failed observed-leader lookups (2s TTL), (3) add guarded retry-to-mapped-leader when observed-leader override forward fails with INTERNAL/UNAVAILABLE, and (4) expose new telemetry counters: observed_leader_lookup_skipped_non_replica, observed_leader_override_retry_attempts, observed_leader_override_retry_success. Build + router tests pass. Next: deploy to EKS and rerun same 11x11 write-heavy benchmark for before/after comparison.
  2026-02-20 12:53 Abhishek Srinivasa Raju Padmavathi
    Benchmark rerun with dynamic-leader lookup skip + retry logic completed (e45_k6_write_heavy_leaderroute_retry_20260220T124918Z). Key findings: observed_leader_lookup_failures dropped from 7691 -> 0 (expected from non-replica skip), but observed-leader retry path had 540 attempts / 0 success and did not improve throughput (171.94 rps vs 174.25 baseline). Started corrective slice: disable observed-leader override retry by default, keep non-replica lookup skip + failure backoff, and rerun same workload for cleaner signal.
  2026-02-20 13:04 Abhishek Srinivasa Raju Padmavathi
    Observed new instability during repeated no-retry runs: 3 data pods remained Running but NotReady with repeated /healthz probe timeouts while CPU remained high (no container restarts). This reduced effective service endpoints and materially depressed throughput. Implemented mitigation for next validation run: switch StatefulSet data pod probes (startup/readiness/liveness) from HTTP /healthz to tcpSocket on port 8080 to avoid shared-HTTP-worker starvation causing probe flaps under load.
  2026-02-20 13:14 Abhishek Srinivasa Raju Padmavathi
    Post-probe-fix validation complete (e45_k6_write_heavy_probefix_20260220T131201Z). Using tcpSocket probes and clean 11/11 healthy pods, write-heavy 11x11 run improved materially vs prior baseline: throughput 197.39 rps (from 174.25), success_tps 132.26 (from 107.49), error_rate 32.9988% (from 38.3122%). After run, all 11 data pods remained Ready with 0 restarts. Observed leader lookup failures remain eliminated (0), but forward/internal errors still present and now more visible in telemetry; next slice should focus on forward internal root-cause (transport/status taxonomy and hotspot shard distribution) under stable probe behavior.

```

## Ready Work Snapshot

```text

📋 Ready work (4 issues with no blockers):

1. [● P3] [epic] nd-jui.12: E33 Multi-AZ resilience phase (deferred)
2. [● P2] [task] nd-jui.15: E36 External-path NLB sweeps at representative scales
3. [● P2] [task] nd-jui.16: E37 Generator capacity validation
4. [● P2] [task] nd-jui.17: E38 Vertical + horizontal scaling matrix

```

## Git Snapshot

```text
codex/e20-true-raft-integration
5b1b472 E45 baseline: capture write-heavy k6 metrics with in-flight telemetry
 M deploy/k8s/base/service-data-headless.yaml
 M deploy/k8s/base/statefulset-data.yaml
 M deploy/k8s/overlays/eks/kustomization.yaml
 M node/src/main/java/io/notdynamo/node/NodeMain.java
 M node/src/main/java/io/notdynamo/node/cluster/GrpcNodeRpcClient.java
 M node/src/main/java/io/notdynamo/node/cluster/RatisKvRouter.java
 M node/src/main/java/io/notdynamo/node/http/HttpBridgeServer.java
 M raft-ratis/src/main/java/io/notdynamo/ratis/ConsensusEngine.java
 M raft-ratis/src/main/java/io/notdynamo/ratis/RatisMultiShardConsensusEngine.java
 M reports/benchmarks/aws/benchmark_matrix_latest.json
 M reports/benchmarks/aws/benchmark_matrix_latest.md
 M reports/benchmarks/aws/e2e_http_incluster_k6_latest.json
 M reports/benchmarks/aws/e2e_http_incluster_k6_latest.md
 M reports/benchmarks/aws/e2e_http_incluster_latest.json
 M reports/benchmarks/aws/e2e_http_incluster_latest.md
 M reports/tasks/issues_latest.jsonl
 M reports/tasks/issues_latest_tree.txt
 M scripts/eks/BENCHMARK_PLAN.md
 M scripts/eks/README.md
 M scripts/eks/eks_bench_job_down.sh
 M scripts/eks/eks_bench_job_k6_up.sh
 M scripts/eks/eks_bench_job_up.sh
 M scripts/eks/eks_bench_matrix.sh
 M scripts/eks/eks_runbook.sh
 M scripts/eks/eks_scaling_sweep.sh
?? deploy/k8s/overlays/eks/patch-eks-scheduling.yaml
?? docs/benchmark/
?? reports/benchmarks/aws/calib_incluster_20260218T091413Z.json
?? reports/benchmarks/aws/calib_incluster_20260218T091413Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260218T084607Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260218T084607Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260218T085108Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260218T085108Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260218T091026Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260218T091026Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260218T091601Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260218T091601Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260218T092150Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260218T092150Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260218T093512Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260218T093512Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260219T080357Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260219T080357Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260219T082626Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260219T082626Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260219T083957Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260219T083957Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260219T085355Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260219T085355Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260219T141920Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260219T141920Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260219T143527Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260219T143527Z.md
?? reports/benchmarks/aws/e2e_http_incluster_20260219T145317Z.json
?? reports/benchmarks/aws/e2e_http_incluster_20260219T145317Z.md
?? reports/benchmarks/aws/e2e_http_incluster_e42_validation_20260219T075408Z.json
?? reports/benchmarks/aws/e2e_http_incluster_e42_validation_20260219T075408Z.md
?? reports/benchmarks/aws/e43_lockstep_isolated_20260219T075725Z.csv
?? reports/benchmarks/aws/e43_lockstep_isolated_20260219T075725Z_runs/
?? reports/benchmarks/aws/e43_lockstep_isolated_20260219T080941Z.csv
?? reports/benchmarks/aws/e43_lockstep_isolated_20260219T080941Z_runs/
?? reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z.csv
?? reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z.json
?? reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z.md
?? reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z_runs/
?? reports/benchmarks/aws/e43_probe_20260219T081912Z.json
?? reports/benchmarks/aws/e43_probe_20260219T081912Z.md
?? reports/benchmarks/aws/e44_lockstep_timeout5x_20260219T141250Z.csv
?? reports/benchmarks/aws/e44_lockstep_timeout5x_20260219T141250Z.json
?? reports/benchmarks/aws/e44_lockstep_timeout5x_20260219T141250Z.md
?? reports/benchmarks/aws/e44_lockstep_timeout5x_20260219T141250Z_runs/
?? reports/benchmarks/aws/e45_k6_write_heavy_dnsfix_20260220T121134Z.json
?? reports/benchmarks/aws/e45_k6_write_heavy_dnsfix_20260220T121134Z.md
?? reports/benchmarks/aws/e45_k6_write_heavy_grpcsplit_20260220T132050Z.json
?? reports/benchmarks/aws/e45_k6_write_heavy_grpcsplit_20260220T132050Z.md
?? reports/benchmarks/aws/e45_k6_write_heavy_grpcsplit_rerun_20260220T132413Z.json
?? reports/benchmarks/aws/e45_k6_write_heavy_grpcsplit_rerun_20260220T132413Z.md
?? reports/benchmarks/aws/e45_k6_write_heavy_httpthreads_20260220T122111Z.json
?? reports/benchmarks/aws/e45_k6_write_heavy_httpthreads_20260220T122111Z.md
?? reports/benchmarks/aws/e45_k6_write_heavy_httpthreads_timeout20s_20260220T122455Z.json
?? reports/benchmarks/aws/e45_k6_write_heavy_httpthreads_timeout20s_20260220T122455Z.md
?? reports/benchmarks/aws/e45_k6_write_heavy_leaderroute_20260220T123818Z.json
?? reports/benchmarks/aws/e45_k6_write_heavy_leaderroute_20260220T123818Z.md
?? reports/benchmarks/aws/e45_k6_write_heavy_leaderroute_noretry_20260220T125803Z.json
?? reports/benchmarks/aws/e45_k6_write_heavy_leaderroute_noretry_20260220T125803Z.md
?? reports/benchmarks/aws/e45_k6_write_heavy_leaderroute_noretry_rerun_20260220T130031Z.json
?? reports/benchmarks/aws/e45_k6_write_heavy_leaderroute_noretry_rerun_20260220T130031Z.md
?? reports/benchmarks/aws/e45_k6_write_heavy_leaderroute_retry_20260220T124918Z.json
?? reports/benchmarks/aws/e45_k6_write_heavy_leaderroute_retry_20260220T124918Z.md
?? reports/benchmarks/aws/e45_k6_write_heavy_probefix_20260220T131201Z.json
?? reports/benchmarks/aws/e45_k6_write_heavy_probefix_20260220T131201Z.md
?? reports/benchmarks/aws/e45_k6_write_heavy_rpc5000_20260219T234523Z.json
?? reports/benchmarks/aws/e45_k6_write_heavy_rpc5000_20260219T234523Z.md
?? reports/benchmarks/aws/e45_k6_write_heavy_scale11_20260220T003609Z.json
?? reports/benchmarks/aws/e45_k6_write_heavy_scale11_20260220T003609Z.md
?? reports/benchmarks/aws/e45_k6_write_heavy_scale11_spread_20260220T005737Z.json
?? reports/benchmarks/aws/e45_k6_write_heavy_scale11_spread_20260220T005737Z.md
?? reports/benchmarks/aws/e45_k6_write_heavy_scale11_spread_stable_20260220T040259Z.json
?? reports/benchmarks/aws/e45_k6_write_heavy_scale11_spread_stable_20260220T040259Z.md
?? reports/benchmarks/aws/e45_k6_write_heavy_scale11_spread_stable_20260220T115932Z.json
?? reports/benchmarks/aws/e45_k6_write_heavy_scale11_spread_stable_20260220T115932Z.md
?? reports/benchmarks/aws/e45_k6_write_heavy_telemetryfix_20260219T224117Z.json
?? reports/benchmarks/aws/e45_k6_write_heavy_telemetryfix_20260219T224117Z.md
?? reports/benchmarks/aws/e46_read_upperbound_p12_t64_20260219T173000Z.json
?? reports/benchmarks/aws/e46_read_upperbound_p12_t64_20260219T173000Z.md
?? reports/benchmarks/aws/e46_read_upperbound_p4_t32_20260219T172103Z.json
?? reports/benchmarks/aws/e46_read_upperbound_p4_t32_20260219T172103Z.md
?? reports/benchmarks/aws/e46_read_upperbound_p8_t64_20260219T172435Z.json
?? reports/benchmarks/aws/e46_read_upperbound_p8_t64_20260219T172435Z.md
?? reports/benchmarks/aws/e47_preload_seed_20260219T181757Z.json
?? reports/benchmarks/aws/e47_preload_seed_20260219T181757Z.md
?? reports/benchmarks/aws/e47_read_hit_balanced_20260219T182702Z.json
?? reports/benchmarks/aws/e47_read_hit_balanced_20260219T182702Z.md
?? reports/benchmarks/aws/e47_read_hit_heavy_20260219T182232Z.json
?? reports/benchmarks/aws/e47_read_hit_heavy_20260219T182232Z.md
?? reports/benchmarks/aws/e48_k6_preload_seed_20260219T211125Z.json
?? reports/benchmarks/aws/e48_k6_preload_seed_20260219T211125Z.md
?? reports/benchmarks/aws/e48_k6_preload_seed_20260219T212724Z.json
?? reports/benchmarks/aws/e48_k6_preload_seed_20260219T212724Z.md
?? reports/benchmarks/aws/e48_k6_read_hit_heavy_20260219T213236Z.json
?? reports/benchmarks/aws/e48_k6_read_hit_heavy_20260219T213236Z.md
?? reports/benchmarks/aws/e48_k6_trace_20260219T210318Z.json
?? reports/benchmarks/aws/e48_k6_trace_20260219T210318Z.md
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218084615/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218085116/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218091033/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218091421/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218091609/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218092158/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218093520/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218165352/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218182151/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218182533/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218182651/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218184807/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218185102/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218190935/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218214957/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218220043/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260218220733/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219075411/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219080400/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219081512/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219081914/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219082629/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219083959/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219085357/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219141923/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219143530/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219145320/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219172120/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219172452/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219173003/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219181137/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219181759/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219182235/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-http-20260219182705/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219190357/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219210119/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219210237/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219210350/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219210632/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219210744/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219211127/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219212011/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219212757/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219213239/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219222110/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219222921/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219223502/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219224135/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219224629/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260219234526/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220003611/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220005740/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220042049/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220115934/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220121136/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220122114/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220122457/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220123820/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220124921/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220125805/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220130034/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220131204/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220132053/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220132416/
?? reports/benchmarks/aws/lockstep_incluster_qmax8_20260218T085005Z.csv
?? reports/benchmarks/aws/lockstep_incluster_qmax8_20260218T085005Z_runs/
?? reports/benchmarks/aws/lockstep_incluster_qmax8_20260218T085732Z.csv
?? reports/benchmarks/aws/lockstep_incluster_qmax8_20260218T085732Z_runs/
?? reports/benchmarks/aws/lockstep_incluster_qmax8_20260218T090710Z.csv
?? reports/benchmarks/aws/lockstep_incluster_qmax8_20260218T090710Z_runs/
?? reports/benchmarks/aws/lockstep_n11_29_35_fast_20260218T170753Z.csv
?? reports/benchmarks/aws/lockstep_n11_29_35_fast_20260218T170753Z_runs/
?? reports/benchmarks/aws/lockstep_qmax8_points_20260218T091507Z/
?? reports/benchmarks/aws/lockstep_smoke_20260218T083836Z.csv
?? reports/benchmarks/aws/lockstep_smoke_20260218T083836Z_runs/
?? reports/benchmarks/aws/lockstep_smoke_20260218T084516Z.csv
?? reports/benchmarks/aws/lockstep_smoke_20260218T084516Z.json
?? reports/benchmarks/aws/lockstep_smoke_20260218T084516Z.md
?? reports/benchmarks/aws/lockstep_smoke_20260218T084516Z_runs/
?? reports/benchmarks/aws/lockstep_sweep_20260218T164732Z.csv
?? reports/benchmarks/aws/lockstep_sweep_20260218T164732Z_runs/
?? reports/benchmarks/aws/lockstep_sweep_latest.csv
?? reports/benchmarks/aws/lockstep_sweep_latest.json
?? reports/benchmarks/aws/lockstep_sweep_latest.md
?? reports/benchmarks/aws/lockstep_to35_20260218T082855Z/
?? reports/benchmarks/aws/manual_highload_incluster_20260218T184750Z.json
?? reports/benchmarks/aws/manual_highload_incluster_20260218T184750Z.md
?? reports/benchmarks/aws/manual_highload_incluster_p8_t64_20260218T185030Z.json
?? reports/benchmarks/aws/manual_highload_incluster_p8_t64_20260218T185030Z.md
?? reports/benchmarks/aws/manual_highload_splitinfra_20260218T214925Z.json
?? reports/benchmarks/aws/manual_highload_splitinfra_20260218T214925Z.md
?? reports/benchmarks/aws/manual_highload_splitinfra_keepjob_20260218T220011Z.json
?? reports/benchmarks/aws/manual_highload_splitinfra_keepjob_20260218T220011Z.md
?? reports/benchmarks/aws/manual_lockstep_n11_29_35_fast_20260218T181946Z/
?? reports/benchmarks/aws/notdynamo-bench-splitprobe-20260218T215356.yaml
?? reports/benchmarks/aws/notdynamo-bench-splitprobe-20260218T215500.yaml
?? reports/benchmarks/aws/notdynamo-manual-bench-20260218191042.summary.json
?? reports/benchmarks/aws/notdynamo-manual-bench-20260218191208.pod_metrics.txt
?? reports/benchmarks/aws/scaling_sweep_latest.csv
?? reports/benchmarks/aws/scaling_sweep_latest.json
?? reports/benchmarks/aws/scaling_sweep_latest.md
?? reports/checkpoints/nd-jui.13_20260218T083352Z.md
?? reports/checkpoints/nd-jui.13_20260218T084800Z.md
?? reports/checkpoints/nd-jui.13_latest.md
?? reports/checkpoints/nd-jui.14_20260218T084955Z.md
?? reports/checkpoints/nd-jui.14_20260218T094449Z.md
?? reports/checkpoints/nd-jui.14_20260218T224816Z.md
?? reports/checkpoints/nd-jui.14_20260219T085709Z.md
?? reports/checkpoints/nd-jui.14_latest.md
?? reports/checkpoints/nd-jui.18_20260218T094504Z.md
?? reports/checkpoints/nd-jui.18_20260218T224819Z.md
?? reports/checkpoints/nd-jui.18_latest.md
?? reports/checkpoints/nd-jui.19_20260218T094506Z.md
?? reports/checkpoints/nd-jui.19_20260218T224818Z.md
?? reports/checkpoints/nd-jui.19_20260219T090021Z.md
?? reports/checkpoints/nd-jui.19_latest.md
?? reports/checkpoints/nd-jui.20_20260218T223255Z.md
?? reports/checkpoints/nd-jui.20_20260218T223256Z.md
?? reports/checkpoints/nd-jui.20_latest.md
?? reports/checkpoints/nd-jui.21_20260218T224821Z.md
?? reports/checkpoints/nd-jui.21_20260219T061614Z.md
?? reports/checkpoints/nd-jui.21_20260219T075711Z.md
?? reports/checkpoints/nd-jui.21_latest.md
?? reports/checkpoints/nd-jui.22_20260219T075712Z.md
?? reports/checkpoints/nd-jui.22_20260219T085653Z.md
?? reports/checkpoints/nd-jui.22_latest.md
?? reports/checkpoints/nd-jui.24_20260220T132743Z.md
?? reports/checkpoints/nd-jui_20260218T223330Z.md
?? reports/checkpoints/nd-jui_20260219T090040Z.md
?? scripts/eks/eks_bench_nodegroup_up.sh
?? scripts/eks/eks_lockstep_sweep.sh
?? scripts/eks/eks_single_az_index.sh
```
