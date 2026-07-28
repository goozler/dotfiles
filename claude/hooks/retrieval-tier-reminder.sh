#!/usr/bin/env bash
# Deny-once speed bump nudging bulk external reads onto a cheaper tier.
#
# Why: retrieval (Slack/Jira/web/MCP get_*|search_*|read_* ...) read inline in
# the main loop is re-paid as cache at the session model's rate on every later
# turn. The model-delegation rule says to dispatch bulk reads to a Sonnet
# subagent that returns a distilled brief. CLAUDE.md states that as prose;
# this hook turns it into a deterministic reminder at the moment of the call.
#
# PreToolUse cannot inject NON-blocking context to the model (additionalContext
# is only honored for UserPromptSubmit/SessionStart). The only channel that
# reaches the model from PreToolUse is a `deny` + reason. So this fires ONCE per
# session: the first matching retrieval call is denied with a reminder, a
# per-session marker is written, and every later retrieval call passes silently.
# It never truly gates work — the model either delegates (the goal) or re-issues
# the identical call to proceed (the exception path).
#
# Scope is set by the settings.json matcher (a regex on retrieval verbs across
# ALL mcp__ servers + WebFetch/WebSearch), so new MCP servers are covered with
# no edits here. This script only (a) skips a short denylist of tiny metadata
# calls so the one-shot isn't spent on them, and (b) manages the marker.

# Fail open if jq is unavailable — never break a tool call over a reminder.
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')

# Short, stable denylist: tools that MATCH the retrieval regex but are trivial
# metadata calls where delegation makes no sense. Extend as needed — this is a
# denylist (short, stable), never an allowlist (would grow forever).
DENY_RE='(list_labels|list_calendars|list_drafts|get_file_metadata|get_file_permissions|getAccessibleAtlassianResources|getVisibleJiraProjects|atlassianUserInfo|list_datadog_skills|list_mcp)'
if [[ "$TOOL_NAME" =~ $DENY_RE ]]; then
  exit 0
fi

# Per-session marker. Once written, the reminder is considered "delivered" for
# this session and all later retrieval calls pass through untouched.
MARKER_DIR="${TMPDIR:-/tmp}"
MARKER="${MARKER_DIR%/}/cc-retrieval-tier-reminder-${SESSION_ID:-nosession}"

if [ -f "$MARKER" ]; then
  exit 0
fi

# First matching retrieval call this session: drop the marker and remind.
: > "$MARKER" 2>/dev/null

REASON="Retrieval call detected (fires once per session). Per the model-delegation rule, prefer dispatching bulk external reads to a cheaper tier: Agent(subagent_type: \"general-purpose\", model: \"sonnet\", prompt: <what to find>) returns a distilled brief instead of dumping raw content into the main context (which is then re-paid as cache every later turn). If inline reading is genuinely right here — a small (<=100-line) one-off, decision-critical nuance summarization would lose, or a file you are about to Edit — just issue the exact same call again; this reminder will not fire again this session and will not block the retry."

jq -n --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
