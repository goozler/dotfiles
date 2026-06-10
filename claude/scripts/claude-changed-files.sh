#!/usr/bin/env bash
# Print files Claude has changed for the current tmux pane's session.
#
# Union of:
#   1. git working tree (modified vs HEAD + untracked, like the original
#      :ClaudeChanged) — covers uncommitted edits.
#   2. ~/.claude/state/session-<sid>-touched.txt — written by
#      tmux-attention.py on PostToolUse. Covers files Claude edited that
#      have since been committed, which git status alone would miss.
#
# Output: one path per line, deduped, only files that exist on disk. The
# per-session edit log is the authoritative record of what Claude changed this
# session, so logged files are surfaced regardless of folder — a session that
# legitimately edits across repos (e.g. a fix in repo A plus a test in repo B)
# shows all of them. The git portion is repo-local by nature.
#
# Session id lookup: tmux user-option @cc-session-id on the current window,
# set by tmux-attention.py on UserPromptSubmit. Returns nothing if not set.

set -u
STATE_DIR="${HOME}/.claude/state"

sid=""
if [ -n "${TMUX:-}" ]; then
    sid=$(tmux show-options -wqv @cc-session-id 2>/dev/null || true)
fi

{
    git diff --name-only HEAD 2>/dev/null || true
    git ls-files --others --exclude-standard 2>/dev/null || true
    if [ -n "$sid" ] && [ -f "${STATE_DIR}/session-${sid}-touched.txt" ]; then
        cat "${STATE_DIR}/session-${sid}-touched.txt"
    fi
} | awk 'NF && !seen[$0]++' | while IFS= read -r f; do
    [ -e "$f" ] && printf '%s\n' "$f"
done

exit 0
