#!/usr/bin/env bash
# Deny-once speed bump nudging source-code writes in the main loop onto a
# delegated subagent (implementer / mech-worker with a pinned cheaper model).
#
# Sibling of ~/.claude/hooks/retrieval-tier-reminder.sh (same pattern, different
# target): the delegation policy lives in prose (CLAUDE.md, model-delegation
# skill) and is advisory; this hook makes the reminder deterministic at the
# moment the orchestrator starts typing code itself.
#
# Semantics:
# - Fires only on Edit/Write of SOURCE files (code extension allowlist below).
#   Docs, configs, workspace notes pass untouched — the orchestrator legitimately
#   owns those.
# - Deny-once with TTL: first matching call is denied with a reminder; a marker
#   arms; later calls pass. The marker expires after TTL_MIN minutes so long
#   sessions (where compaction erodes prose rules) get re-reminded.
# - Never truly gates: re-issuing the identical call proceeds. Subagents share
#   the session's hooks, so a delegated implementer may eat the deny — the
#   reason text tells it to just re-issue.

if ! command -v jq &>/dev/null; then
  exit 0
fi

TTL_MIN=45

INPUT=$(cat)
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')

[ -z "$FILE_PATH" ] && exit 0

# Source-code extensions only. Everything else (md, json, yaml, toml, txt,
# lock, env, …) is orchestrator-legitimate and passes.
CODE_EXT_RE='\.(ts|tsx|js|jsx|mjs|cjs|java|go|py|rb|rs|kt|kts|swift|c|h|cc|cpp|hpp|cs|sql|scala|groovy)$'
if ! [[ "$FILE_PATH" =~ $CODE_EXT_RE ]]; then
  exit 0
fi

# Paths where inline writes are fine: hooks/agents themselves, scratchpads.
SKIP_PATH_RE='(/\.claude/|/scratchpad/|/claude-501/|/dotfiles/)'
if [[ "$FILE_PATH" =~ $SKIP_PATH_RE ]]; then
  exit 0
fi

MARKER_DIR="${TMPDIR:-/tmp}"
MARKER="${MARKER_DIR%/}/cc-delegate-writes-reminder-${SESSION_ID:-nosession}"

# Armed and fresh → pass. Expired → re-arm and remind again.
if [ -f "$MARKER" ]; then
  if [ -n "$(find "$MARKER" -mmin -"$TTL_MIN" 2>/dev/null)" ]; then
    exit 0
  fi
fi

: > "$MARKER" 2>/dev/null

REASON="Source-code write in the main loop detected (speed bump; re-arms every ${TTL_MIN}m). Per the delegation policy, code is written by a pinned-model subagent, not the orchestrator: dispatch the 'implementer' role (scoped change needing judgment) or 'mech-worker' (fully-specified mechanical edit) with a self-contained task brief — invoke by role name, omit the model argument (the agent definition owns routing) — then review the returned diff. If you ARE a delegated subagent (implementer/mech-worker/etc.), or this is genuinely a tiny orchestrator-level touch-up (<~10 lines, one-off), just re-issue the exact same call — it will pass."

jq -n --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
