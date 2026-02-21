# Task Checkpoint

- Timestamp (UTC): `2026-02-21 02:57:01Z`
- Issue: `nd-jui.30`
- Claimed now: `0`
- Status override: `none`
- Closed now: `1`
- Note: `Acceptance met: leader snapshot override routing tests pass and forward path reduction instrumentation present.`

## Issue Snapshot

```text
✓ nd-jui.30 · E51 Forward-path reduction via leader snapshot cache   [● P1 · CLOSED]
Owner: Abhishek Srinivasa Raju Padmavathi · Assignee: Abhishek Srinivasa Raju Padmavathi · Type: task
Created: 2026-02-20 · Updated: 2026-02-21
Close reason: Closed

DESCRIPTION
Add periodic consensus leader snapshot API and router cache-first lookup to reduce forward timeout exposure.

NOTES
[2026-02-21 02:56:59Z] Implemented leader snapshot cache refresh path and forwarding preference via consensus leaderIdSnapshot with fallback behavior and telemetry for forward-hop ratio.
[2026-02-21 02:57:01Z] Acceptance met: leader snapshot override routing tests pass and forward path reduction instrumentation present.

ACCEPTANCE CRITERIA
Forward hop ratio metric is emitted; fewer request-time leader lookups; router uses snapshot fallback safely.

LABELS: roadmap, single-az

PARENT
  ↑ ◐ nd-jui: (EPIC) E21 Program: Single-AZ True Sharding and Replication ● P1

```

## Ready Work Snapshot

```text

📋 Ready work (8 issues with no blockers):

1. [● P3] [epic] nd-jui.12: E33 Multi-AZ resilience phase (deferred)
2. [● P2] [task] nd-jui.15: E36 External-path NLB sweeps at representative scales
3. [● P2] [task] nd-jui.16: E37 Generator capacity validation
4. [● P2] [task] nd-jui.17: E38 Vertical + horizontal scaling matrix
5. [● P1] [task] nd-jui.31: E52 Per-shard consensus inflight pacing
6. [● P1] [task] nd-jui.32: E53 Control-plane hot-shard leader rebalance
7. [● P1] [task] nd-jui.33: E54 Horizontal write scaling sweep (single-AZ)
8. [● P1] [task] nd-jui.34: E55 Milestone closeout profile freeze

```

## Git Snapshot

```text
codex/e20-true-raft-integration
5b1b472 E45 baseline: capture write-heavy k6 metrics with in-flight telemetry
 M control-plane/src/main/java/io/notdynamo/controlplane/ControlPlaneMain.java
 M deploy/k8s/base/deployment-control-plane.yaml
 M deploy/k8s/base/service-data-headless.yaml
 M deploy/k8s/base/statefulset-data.yaml
 M deploy/k8s/overlays/eks/kustomization.yaml
 M node/src/main/java/io/notdynamo/node/NodeMain.java
 M node/src/main/java/io/notdynamo/node/cluster/GrpcNodeRpcClient.java
 M node/src/main/java/io/notdynamo/node/cluster/RatisKvRouter.java
 M node/src/main/java/io/notdynamo/node/http/HttpBridgeServer.java
 M node/src/test/java/io/notdynamo/node/cluster/RatisKvRouterTest.java
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
?? reports/benchmarks/aws/e45_k6_write_heavy_backpressure128_20260220T134716Z.json
?? reports/benchmarks/aws/e45_k6_write_heavy_backpressure128_20260220T134716Z.md
?? reports/benchmarks/aws/e45_k6_write_heavy_backpressure192_20260220T135949Z.json
?? reports/benchmarks/aws/e45_k6_write_heavy_backpressure192_20260220T135949Z.md
?? reports/benchmarks/aws/e45_k6_write_heavy_backpressure_20260220T133557Z.json
?? reports/benchmarks/aws/e45_k6_write_heavy_backpressure_20260220T133557Z.md
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
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220133559/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220134719/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260220135952/
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
?? reports/checkpoints/nd-jui.24_20260220T140231Z.md
?? reports/checkpoints/nd-jui.24_latest.md
?? reports/checkpoints/nd-jui.28_20260221T025653Z.md
?? reports/checkpoints/nd-jui.28_20260221T025654Z.md
?? reports/checkpoints/nd-jui.28_latest.md
?? reports/checkpoints/nd-jui.29_20260221T025656Z.md
?? reports/checkpoints/nd-jui.29_20260221T025657Z.md
?? reports/checkpoints/nd-jui.29_latest.md
?? reports/checkpoints/nd-jui.30_20260221T025659Z.md
?? reports/checkpoints/nd-jui.30_20260221T025701Z.md
?? reports/checkpoints/nd-jui.30_latest.md
?? reports/checkpoints/nd-jui_20260218T223330Z.md
?? reports/checkpoints/nd-jui_20260219T090040Z.md
?? scripts/eks/analyze_write_gate.sh
?? scripts/eks/eks_bench_nodegroup_up.sh
?? scripts/eks/eks_lockstep_sweep.sh
?? scripts/eks/eks_single_az_index.sh
?? scripts/eks/eks_write_gate_run.sh
?? scripts/eks/eks_write_gate_sweep.sh
```
