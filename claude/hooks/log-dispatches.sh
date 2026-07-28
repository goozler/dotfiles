#!/usr/bin/env bash
# Append-only dispatch log for the delegation system (global since 2026-07-26;
# canonical docs: notes/delegation-system/).
#
# PostToolUse on Agent: every subagent dispatch lands as one JSONL line —
# timestamp, role/agent type, model argument (or the role default), label.
# This is the deterministic side of delegation tracking: delegation rate and
# the role/model mix come from this file, not from anyone's memory.
#
# Logs are central (one file per project, slug = project path with / → -), so
# no .claude/ litter appears inside work repos:
#   ~/.claude/dispatch-logs/<project-slug>.jsonl
# Summarize at checkpoint time with e.g.:
#   jq -s 'group_by(.agent)|map({agent:.[0].agent, n:length})' ~/.claude/dispatch-logs/<slug>.jsonl

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SLUG=$(printf '%s' "$DIR" | tr '/' '-')
LOG_DIR="$HOME/.claude/dispatch-logs"
mkdir -p "$LOG_DIR" 2>/dev/null
LOG="$LOG_DIR/${SLUG}.jsonl"

printf '%s' "$INPUT" | jq -c '{
  ts: (now | todate),
  session: (.session_id // "?"),
  agent: (.tool_input.subagent_type // "general-purpose"),
  model: (.tool_input.model // "role-default/inherit"),
  desc: (.tool_input.description // "")
}' >> "$LOG" 2>/dev/null

exit 0
