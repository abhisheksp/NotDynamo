# Task Checkpoint

- Timestamp (UTC): `2026-02-22 22:09:25Z`
- Issue: `nd-jui.35`
- Claimed now: `0`
- Status override: `blocked`
- Closed now: `0`
- Note: `AWS spend cap hit before execution. Implemented scripts/eks/eks_read_hit_upperbound_sweep.sh and validated CLI/syntax, but skipped new EKS read N-sweep benchmark run. Using existing E48 read-hit artifact for wrap-up instead.`

## Issue Snapshot

```text
● nd-jui.35 · E56 Read-hit upper-bound EKS sweep (staged preload + measured reads)   [● P1 · BLOCKED]
Owner: Abhishek Srinivasa Raju Padmavathi · Assignee: Abhishek Srinivasa Raju Padmavathi · Type: task
Created: 2026-02-22 · Updated: 2026-02-22

DESCRIPTION
Run lockstep single-AZ EKS sweep for N=11,17,23,29,35 with staged preload-only k6 job followed by measured read-hit-heavy k6 runs (2 trials/point) and median aggregation.

NOTES
[2026-02-22 18:48:23Z] Started E56 implementation: added staged read-hit upper-bound EKS sweep script and beginning validation.
[2026-02-22 22:09:25Z] AWS spend cap hit before execution. Implemented scripts/eks/eks_read_hit_upperbound_sweep.sh and validated CLI/syntax, but skipped new EKS read N-sweep benchmark run. Using existing E48 read-hit artifact for wrap-up instead.

LABELS: benchmark, roadmap, single-az

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
5. [● P1] [task] nd-jui.34: E55 Milestone closeout profile freeze
6. [● P1] [task] nd-jui.36: E57 Consolidated benchmark wrap-up report (read + write)
7. [● P1] [task] nd-jui.37: E58 README benchmark snapshot refresh
8. [● P1] [task] nd-jui.38: E59 Wrap-up verification, checkpoints, and publish

```

## Git Snapshot

```text
codex/e20-true-raft-integration
a19a910 E54 sweep execution: scale 11-35, shard coverage guard, and EKS spread fix
 M README.md
 M reports/checkpoints/nd-jui.33_latest.md
 M reports/tasks/issues_latest.jsonl
 M reports/tasks/issues_latest_tree.txt
?? reports/benchmarks/aws/benchmark_wrapup_20260222_v1.csv
?? reports/benchmarks/aws/benchmark_wrapup_20260222_v1.json
?? reports/benchmarks/aws/benchmark_wrapup_20260222_v1.md
?? reports/benchmarks/aws/benchmark_wrapup_latest.csv
?? reports/benchmarks/aws/benchmark_wrapup_latest.json
?? reports/benchmarks/aws/benchmark_wrapup_latest.md
?? reports/benchmarks/aws/calib_incluster_20260218T091413Z.json
?? reports/benchmarks/aws/calib_incluster_20260218T091413Z.md
?? reports/benchmarks/aws/cleanup_audit_20260222T220507Z.json
?? reports/benchmarks/aws/cleanup_audit_20260222T220507Z.md
?? reports/benchmarks/aws/cleanup_audit_latest.json
?? reports/benchmarks/aws/cleanup_audit_latest.md
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
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T124853Z.json
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T124853Z.md
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T125229Z.json
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T125229Z.md
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T125417Z.json
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T125417Z.md
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T125856Z.json
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T125856Z.md
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T130042Z.json
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T130042Z.md
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T131036Z.json
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T131036Z.md
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T131228Z.json
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T131228Z.md
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T131638Z.json
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T131638Z.md
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T131832Z.json
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T131832Z.md
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T132405Z.json
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T132405Z.md
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T132601Z.json
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T132601Z.md
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T133802Z.json
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T133802Z.md
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T134006Z.json
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T134006Z.md
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T134813Z.json
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T134813Z.md
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T135024Z.json
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T135024Z.md
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T140102Z.json
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T140102Z.md
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T140317Z.json
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T140317Z.md
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T141601Z.json
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T141601Z.md
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T141820Z.json
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T141820Z.md
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T143726Z.json
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T143726Z.md
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T143955Z.json
?? reports/benchmarks/aws/e2e_http_incluster_k6_20260221T143955Z.md
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
?? reports/benchmarks/aws/e54_write_gate_sweep_n3_5_7.csv
?? reports/benchmarks/aws/e54_write_gate_sweep_n3_5_7_runs/
?? reports/benchmarks/aws/e54_write_gate_sweep_n3_5_7_v2.csv
?? reports/benchmarks/aws/e54_write_gate_sweep_n3_5_7_v2_runs/
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
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221124853/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221125229/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221125417/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221125856/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221130042/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221131036/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221131228/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221131638/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221131832/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221132405/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221132601/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221133802/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221134006/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221134813/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221135024/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221140102/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221140317/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221141601/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221141820/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221143726/
?? reports/benchmarks/aws/incluster_runs/notdynamo-bench-k6-20260221143955/
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
?? reports/checkpoints/nd-jui.33_20260222T184823Z.md
?? reports/checkpoints/nd-jui.35_20260222T184823Z.md
?? reports/checkpoints/nd-jui.35_20260222T220925Z.md
?? reports/checkpoints/nd-jui.35_latest.md
?? reports/checkpoints/nd-jui_20260218T223330Z.md
?? reports/checkpoints/nd-jui_20260219T090040Z.md
?? scripts/eks/build_benchmark_wrapup_report.sh
?? scripts/eks/eks_read_hit_upperbound_sweep.sh
```
