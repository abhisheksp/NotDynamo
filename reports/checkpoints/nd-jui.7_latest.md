# Task Checkpoint

- Timestamp (UTC): `2026-02-18 07:36:47Z`
- Issue: `nd-jui.7`
- Claimed now: `0`
- Status override: `none`
- Closed now: `1`
- Note: `Acceptance met: all failure modes have reproducible command paths with captured pass/fail report output`

## Issue Snapshot

```text
✓ nd-jui.7 · E28 Failure injection harness (pod, leader, node, restart)   [● P1 · CLOSED]
Owner: Abhishek Srinivasa Raju Padmavathi · Assignee: Abhishek Srinivasa Raju Padmavathi · Type: task
Created: 2026-02-18 · Updated: 2026-02-18
Close reason: Closed

DESCRIPTION
Automate fault injection against Kubernetes for single-AZ failure modes: pod kill, leader kill, node drain, process restart, and cold restart.

NOTES
[2026-02-18 07:33:15Z] Start E28: consolidate Kubernetes failure injection harness with reproducible outputs
[2026-02-18 07:36:40Z] Added local failure harness covering pod restart, leader restart, process restart, and node drain with per-scenario pass/fail logs and reports
[2026-02-18 07:36:47Z] Acceptance met: all failure modes have reproducible command paths with captured pass/fail report output

ACCEPTANCE CRITERIA
Each injected failure has reproducible command path and captured pass/fail output.

LABELS: failure, roadmap, single-az

PARENT
  ↑ ◐ nd-jui: (EPIC) E21 Program: Single-AZ True Sharding and Replication ● P1

DEPENDS ON
  → ✓ nd-jui.6: E27 Rebalance executor (stream/catchup/switch) ● P1

BLOCKS
  ← ○ nd-jui.8: E29 Correctness verification matrix for failure modes ● P1

```

## Ready Work Snapshot

```text

📋 Ready work (1 issues with no blockers):

1. [● P1] [task] nd-jui.8: E29 Correctness verification matrix for failure modes

```

## Git Snapshot

```text
codex/e20-true-raft-integration
0271f29 e27: add explicit catchup gating and rebalance data continuity test
 M reports/tasks/issues_latest.jsonl
 M reports/tasks/issues_latest_tree.txt
 M scripts/local/README.md
 M scripts/verify/g11.sh
?? reports/checkpoints/nd-jui.7_20260218T073315Z.md
?? reports/checkpoints/nd-jui.7_20260218T073640Z.md
?? reports/checkpoints/nd-jui.7_20260218T073647Z.md
?? reports/checkpoints/nd-jui.7_latest.md
?? scripts/local/kind_failure_harness.sh
```
