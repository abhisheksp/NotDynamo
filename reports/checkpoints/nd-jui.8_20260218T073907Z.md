# Task Checkpoint

- Timestamp (UTC): `2026-02-18 07:39:07Z`
- Issue: `nd-jui.8`
- Claimed now: `1`
- Status override: `in_progress`
- Closed now: `0`
- Note: `Start E29: codify failure-mode verification matrix command and reports`

## Issue Snapshot

```text
◐ nd-jui.8 · E29 Correctness verification matrix for failure modes   [● P1 · IN_PROGRESS]
Owner: Abhishek Srinivasa Raju Padmavathi · Assignee: Abhishek Srinivasa Raju Padmavathi · Type: task
Created: 2026-02-18 · Updated: 2026-02-18

DESCRIPTION
Codify correctness assertions per failure mode: availability envelope, durability, leader election recovery, and replica catch-up correctness.

NOTES
[2026-02-18 07:39:07Z] Start E29: codify failure-mode verification matrix command and reports

ACCEPTANCE CRITERIA
One command runs matrix and produces human-readable + machine-readable report.

LABELS: roadmap, single-az, verification

PARENT
  ↑ ◐ nd-jui: (EPIC) E21 Program: Single-AZ True Sharding and Replication ● P1

DEPENDS ON
  → ✓ nd-jui.7: E28 Failure injection harness (pod, leader, node, restart) ● P1

BLOCKS
  ← ○ nd-jui.9: E30 External benchmark path via LoadBalancer/NLB ● P2

```

## Ready Work Snapshot

```text

✨ No ready work found (all issues have blocking dependencies)

```

## Git Snapshot

```text
codex/e20-true-raft-integration
162e93c e28: add local failure injection harness with reproducible reports
 M reports/tasks/issues_latest.jsonl
 M reports/tasks/issues_latest_tree.txt
?? reports/checkpoints/nd-jui.8_20260218T073907Z.md
?? reports/failures/
?? reports/verification/
?? scripts/verify/failure_matrix.sh
```
