#!/usr/bin/env bash
# Emits [TIME_SINCE_LAST_MESSAGE: Ns] on every user prompt.
# Per-session state keyed by Claude Code session_id (falls back to pwd hash).
set -u

: "${HOME:?HOME is required for this hook}"
STATE_DIR="${HOME}/.claude/state/message-timestamps"
mkdir -p "$STATE_DIR"

PAYLOAD=$(cat 2>/dev/null || true)
SESSION_ID=""
if command -v jq >/dev/null 2>&1 && [ -n "$PAYLOAD" ]; then
  SESSION_ID=$(printf '%s' "$PAYLOAD" | jq -r '.session_id // empty' 2>/dev/null || true)
fi
if [ -z "$SESSION_ID" ]; then
  SESSION_ID="dir-$(pwd | shasum -a 256 | cut -c1-16)"
fi

STATE_FILE="${STATE_DIR}/${SESSION_ID}"
LOCK_FILE="${STATE_FILE}.lock"
NOW=$(date +%s)

(
  flock -x 9 2>/dev/null || true
  if [ -f "$STATE_FILE" ]; then
    LAST=$(cat "$STATE_FILE" 2>/dev/null || true)
    case "$LAST" in
      ''|*[!0-9]*) ;;
      *)
        DELTA=$(( NOW - LAST ))
        printf '[TIME_SINCE_LAST_MESSAGE: %ss]\n' "$DELTA"
        ;;
    esac
  fi
  TMP=$(mktemp "${STATE_FILE}.XXXXXX") && \
    printf '%s\n' "$NOW" > "$TMP" && \
    mv "$TMP" "$STATE_FILE"
) 9> "$LOCK_FILE"

exit 0
