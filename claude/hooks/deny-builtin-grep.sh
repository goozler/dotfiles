#!/usr/bin/env bash
# Denies the built-in Grep tool and redirects the model to `Bash: rtk rg ...`.
#
# Why: the built-in Grep tool bypasses the rtk-rewrite hook (which only fires
# on Bash). Subagents that reach for the built-in tool miss both ripgrep's
# speed and rtk's token compression. This hook forces them onto Bash + rtk rg.

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
PATTERN=$(printf '%s' "$INPUT" | jq -r '.tool_input.pattern // empty')
PATH_ARG=$(printf '%s' "$INPUT" | jq -r '.tool_input.path // empty')
GLOB=$(printf '%s' "$INPUT" | jq -r '.tool_input.glob // empty')

q() { printf '%q' "$1"; }

if [ -n "$PATTERN" ] && [ -n "$PATH_ARG" ]; then
  SUGGEST="rtk rg $(q "$PATTERN") $(q "$PATH_ARG")"
elif [ -n "$PATTERN" ]; then
  SUGGEST="rtk rg $(q "$PATTERN")"
else
  SUGGEST="rtk rg <pattern> [path]"
fi

if [ -n "$GLOB" ]; then
  SUGGEST="$SUGGEST -g $(q "$GLOB")"
fi

REASON="Built-in Grep tool is disabled in this environment. Use Bash with: ${SUGGEST} — ripgrep is significantly faster than grep across this multi-repo workspace, and rtk wraps it to compress output. For context flags use -A/-B/-C; for case-insensitive use -i; for file-type filter use -t (e.g. -t ts). Note rg respects .gitignore by default — add --no-ignore if you need to search ignored files."

jq -n --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
