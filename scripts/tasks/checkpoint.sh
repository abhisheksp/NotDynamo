#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/tasks/checkpoint.sh --id <issue-id> [options]

Options:
  --id <issue-id>        Beads issue ID (required)
  --claim                Claim issue (assignee=self, status=in_progress)
  --status <status>      Explicit status update (open|in_progress|blocked|closed|deferred)
  --note <text>          Append timestamped note to issue
  --close                Close issue after optional note/status updates
  --help                 Show this help

Examples:
  ./scripts/tasks/checkpoint.sh --id nd-jui.1 --claim --status in_progress --note "Started metadata schema work"
  ./scripts/tasks/checkpoint.sh --id nd-jui.1 --note "Implemented endpoint and tests"
  ./scripts/tasks/checkpoint.sh --id nd-jui.1 --note "Acceptance met" --close
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "$REPO_ROOT"

if ! command -v bd >/dev/null 2>&1; then
  echo "bd command not found. Install beads first." >&2
  exit 1
fi

ISSUE_ID=""
SET_STATUS=""
NOTE=""
DO_CLAIM=0
DO_CLOSE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id)
      ISSUE_ID="${2:-}"
      shift 2
      ;;
    --status)
      SET_STATUS="${2:-}"
      shift 2
      ;;
    --note)
      NOTE="${2:-}"
      shift 2
      ;;
    --claim)
      DO_CLAIM=1
      shift
      ;;
    --close)
      DO_CLOSE=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$ISSUE_ID" ]]; then
  echo "--id is required" >&2
  usage >&2
  exit 1
fi

bd show "$ISSUE_ID" >/dev/null

TS_HUMAN="$(date -u +"%Y-%m-%d %H:%M:%SZ")"
TS_FILE="$(date -u +"%Y%m%dT%H%M%SZ")"

if [[ "$DO_CLAIM" -eq 1 ]]; then
  bd update "$ISSUE_ID" --claim >/dev/null
fi

if [[ -n "$SET_STATUS" ]]; then
  bd update "$ISSUE_ID" --status "$SET_STATUS" >/dev/null
fi

if [[ -n "$NOTE" ]]; then
  bd update "$ISSUE_ID" --append-notes "[$TS_HUMAN] $NOTE" >/dev/null
fi

if [[ "$DO_CLOSE" -eq 1 ]]; then
  bd close "$ISSUE_ID" >/dev/null
fi

mkdir -p reports/checkpoints reports/tasks
bd export -o reports/tasks/issues_latest.jsonl >/dev/null
bd list --tree --limit 0 > reports/tasks/issues_latest_tree.txt

SAFE_ID="$(echo "$ISSUE_ID" | tr '/: ' '___')"
CHECKPOINT_FILE="reports/checkpoints/${SAFE_ID}_${TS_FILE}.md"
LATEST_FILE="reports/checkpoints/${SAFE_ID}_latest.md"

{
  echo "# Task Checkpoint"
  echo
  echo "- Timestamp (UTC): \`$TS_HUMAN\`"
  echo "- Issue: \`$ISSUE_ID\`"
  echo "- Claimed now: \`$DO_CLAIM\`"
  echo "- Status override: \`${SET_STATUS:-none}\`"
  echo "- Closed now: \`$DO_CLOSE\`"
  echo "- Note: \`${NOTE:-none}\`"
  echo
  echo "## Issue Snapshot"
  echo
  echo '```text'
  bd show "$ISSUE_ID"
  echo '```'
  echo
  echo "## Ready Work Snapshot"
  echo
  echo '```text'
  bd ready --limit 20
  echo '```'
  echo
  echo "## Git Snapshot"
  echo
  echo '```text'
  git rev-parse --abbrev-ref HEAD
  git log -1 --oneline
  git status --short
  echo '```'
} > "$CHECKPOINT_FILE"

cp "$CHECKPOINT_FILE" "$LATEST_FILE"

echo "Checkpoint written: $CHECKPOINT_FILE"
echo "Backlog snapshot: reports/tasks/issues_latest.jsonl"
echo "Tree snapshot: reports/tasks/issues_latest_tree.txt"
