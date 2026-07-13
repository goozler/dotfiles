#!/usr/bin/env bash
# rtk-with-rg.sh — PreToolUse Bash hook that prefers `rtk rg` (ripgrep)
# over `rtk grep` for simple grep invocations, then delegates to the
# standard rtk-rewrite.sh for everything else.
#
# Why: RTK's registry rewrites `grep ... -> rtk grep ...` (token compression
# only, still slow GNU grep underneath). Ripgrep is dramatically faster on
# large/multi-repo workspaces, and `rtk rg` also compresses output, so for
# simple invocations there's no downside.
#
# Scope (conservative — falls through if any check fails):
#   - Command starts with bare `grep ` (not `git grep`, not piped, etc.)
#   - No shell metachars: | > < & ; ` $(
#   - Only short flags from a known-safe set: rRniIvFwocl
#   - Optional -E / --extended-regexp / --recursive (dropped — rg's defaults)
#   - Pattern and paths must be plain tokens (no embedded whitespace/quotes)
#
# Everything else (--include, -P, -A/-B/-C, quoted patterns with spaces,
# pipes, etc.) falls through to rtk-rewrite.sh unchanged.

RTK_HOOK="/Users/goozler/.claude/hooks/rtk-rewrite.sh"

if ! command -v jq &>/dev/null; then
  exec "$RTK_HOOK"
fi

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$CMD" ]; then
  exit 0
fi

passthrough() {
  printf '%s' "$INPUT" | "$RTK_HOOK"
  exit
}

# Reject shell metachars that would make any naive rewrite unsafe.
case "$CMD" in
  *'|'*|*'>'*|*'<'*|*'&'*|*';'*|*'`'*|*'$('*) passthrough ;;
esac

# Match the safe-subset form:
#   grep [<flag>]* <pattern> [<path>...]
# where each flag is one of:
#   -<safeChars>     combined short flags from [rRniIvFwocl]
#   -E | --extended-regexp | --recursive   (dropped — rg defaults)
# Pattern and paths must not start with '-' and must not contain whitespace.
SAFE_RE='^grep(\ +(-[rRniIvFwocl]+|-E|--extended-regexp|--recursive))*\ +([^[:space:]-][^[:space:]]*)(\ +([^[:space:]-][^[:space:]]+))*\ *$'

if ! [[ "$CMD" =~ $SAFE_RE ]]; then
  passthrough
fi

# Transform: grep -> rtk rg, strip recursion flags (rg default), strip -E
# (rg's regex is ERE-ish by default), strip 'r'/'R' from combined short flags.
REWRITTEN=$(printf '%s' "$CMD" | sed -E '
  s/^grep/rtk rg/
  s/ --recursive( |$)/ /g
  s/ --extended-regexp( |$)/ /g
  s/ -E( |$)/ /g
  : strip_R
  s/ (-[a-zA-Z]*)R([a-zA-Z]*)( |$)/ \1\2\3/
  t strip_R
  : strip_r
  s/ (-[a-zA-Z]*)r([a-zA-Z]*)( |$)/ \1\2\3/
  t strip_r
  s/ -( |$)/ /g
  s/  +/ /g
  s/ +$//
')

# Defensive: if transformation produced no actual change (shouldnt happen for
# matched grep commands, but guard anyway), fall through.
if [ -z "$REWRITTEN" ] || [ "$REWRITTEN" = "$CMD" ]; then
  passthrough
fi

ORIGINAL_INPUT=$(printf '%s' "$INPUT" | jq -c '.tool_input')
UPDATED_INPUT=$(printf '%s' "$ORIGINAL_INPUT" | jq --arg cmd "$REWRITTEN" '.command = $cmd')

jq -n --argjson updated "$UPDATED_INPUT" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    permissionDecisionReason: "Rewrote grep to rtk rg (ripgrep is faster on large repos; rtk still compresses output)",
    updatedInput: $updated
  }
}'
