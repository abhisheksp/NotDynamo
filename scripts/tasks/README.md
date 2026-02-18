# Task Scripts

These scripts standardize Beads task lifecycle updates and checkpoint artifacts.

## `checkpoint.sh`

Updates task status/notes and emits checkpoint artifacts:

- `reports/checkpoints/<issue>_<timestamp>.md`
- `reports/checkpoints/<issue>_latest.md`
- `reports/tasks/issues_latest.jsonl`
- `reports/tasks/issues_latest_tree.txt`

### Examples

```bash
# Start work on a task
./scripts/tasks/checkpoint.sh --id nd-jui.1 --claim --status in_progress --note "Started implementation"

# Mid-task progress checkpoint
./scripts/tasks/checkpoint.sh --id nd-jui.1 --note "Added integration tests"

# Final checkpoint and close
./scripts/tasks/checkpoint.sh --id nd-jui.1 --note "Acceptance criteria met" --close
```
