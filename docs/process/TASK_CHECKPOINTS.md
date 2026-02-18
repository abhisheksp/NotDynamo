# Task Checkpoint Policy

NotDynamo uses Beads (`bd`) as the source of truth for implementation tasks.

Every task must be checkpointed at least:

1. On task start
2. After major implementation or verification milestones
3. At task close

## Workflow

1. Pick next ready task:

```bash
bd ready --limit 20
```

2. Start task and checkpoint:

```bash
./scripts/tasks/checkpoint.sh --id <issue-id> --claim --status in_progress --note "Start <short summary>"
```

3. Add one or more progress checkpoints:

```bash
./scripts/tasks/checkpoint.sh --id <issue-id> --note "Implemented <change>"
./scripts/tasks/checkpoint.sh --id <issue-id> --note "Validated with <test/command>"
```

4. Close task with final checkpoint:

```bash
./scripts/tasks/checkpoint.sh --id <issue-id> --note "Acceptance criteria met" --close
```

## Artifact Contract

Each checkpoint run updates:

- `reports/checkpoints/<issue>_<timestamp>.md`
- `reports/checkpoints/<issue>_latest.md`
- `reports/tasks/issues_latest.jsonl`
- `reports/tasks/issues_latest_tree.txt`

This guarantees the plan and its progress are persisted in-repo alongside code changes.
