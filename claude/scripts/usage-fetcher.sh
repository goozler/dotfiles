#!/bin/bash
# One-shot fetcher for Claude usage limits (5h rolling + 7d weekly)
# Called by context-bar.sh when cache is stale; runs once and exits.

CACHE_FILE="/tmp/claude-usage-cache.json"

creds=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null) || exit 1
token=$(echo "$creds" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null) || exit 1
[ -z "$token" ] && exit 1

response=$(curl -s --max-time 10 \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" \
    https://api.anthropic.com/api/oauth/usage 2>/dev/null) || exit 1

echo "$response" | jq -e '.five_hour.utilization' >/dev/null 2>&1 || exit 1

echo "$response" > "$CACHE_FILE"
