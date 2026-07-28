#!/usr/bin/env bash
# Print files Claude has changed for the current tmux pane's session.
#
# Source: ~/.claude/state/session-<sid>-touched.txt — written by
# tmux-claude-hooks.py on PostToolUse for Edit/Write/MultiEdit/NotebookEdit
# only, so the list is exactly what Claude edited this session (survives
# commits, never picks up unrelated dirty/untracked files from the repo).
#
# Output: one path per line, deduped, only files that exist on disk. Logged
# files are surfaced regardless of folder — a session that legitimately edits
# across repos (e.g. a fix in repo A plus a test in repo B) shows all of them.
#
# Session id lookup: tmux user-option @cc-session-id on the current window,
# set by tmux-claude-hooks.py on UserPromptSubmit. Prints nothing when the
# window has no Claude session (or it hasn't edited anything yet).

set -u
STATE_DIR="${HOME}/.claude/state"

sid=""
if [ -n "${TMUX:-}" ]; then
    sid=$(tmux show-options -wqv @cc-session-id 2>/dev/null || true)
fi

{
    if [ -n "$sid" ] && [ -f "${STATE_DIR}/session-${sid}-touched.txt" ]; then
        cat "${STATE_DIR}/session-${sid}-touched.txt"
    fi
} | awk 'NF && !seen[$0]++' | while IFS= read -r f; do
    [ -e "$f" ] && printf '%s\n' "$f"
done

exit 0
