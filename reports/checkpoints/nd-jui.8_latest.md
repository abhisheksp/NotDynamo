# Task Checkpoint

- Timestamp (UTC): `2026-02-18 07:39:21Z`
- Issue: `nd-jui.8`
- Claimed now: `0`
- Status override: `none`
- Closed now: `1`
- Note: `Acceptance met: one command executes failure verification matrix and produces machine/human-readable report artifacts`

## Issue Snapshot

```text
✓ nd-jui.8 · E29 Correctness verification matrix for failure modes   [● P1 · CLOSED]
Owner: Abhishek Srinivasa Raju Padmavathi · Assignee: Abhishek Srinivasa Raju Padmavathi · Type: task
Created: 2026-02-18 · Updated: 2026-02-18
Close reason: Closed

DESCRIPTION
Codify correctness assertions per failure mode: availability envelope, durability, leader election recovery, and replica catch-up correctness.

NOTES
[2026-02-18 07:39:07Z] Start E29: codify failure-mode verification matrix command and reports
[2026-02-18 07:39:14Z] Added scripts/verify/failure_matrix.sh to run failure matrix and emit reports/verification plus latest pointers
[2026-02-18 07:39:21Z] Acceptance met: one command executes failure verification matrix and produces machine/human-readable report artifacts

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

📋 Ready work (1 issues with no blockers):

1. [● P2] [task] nd-jui.9: E30 External benchmark path via LoadBalancer/NLB

```

## Git Snapshot

```text
codex/e20-true-raft-integration
162e93c e28: add local failure injection harness with reproducible reports
 M reports/tasks/issues_latest.jsonl
 M reports/tasks/issues_latest_tree.txt
?? reports/checkpoints/nd-jui.8_20260218T073907Z.md
?? reports/checkpoints/nd-jui.8_20260218T073914Z.md
?? reports/checkpoints/nd-jui.8_20260218T073921Z.md
?? reports/checkpoints/nd-jui.8_latest.md
?? reports/failures/
?? reports/verification/
?? scripts/verify/failure_matrix.sh
```
