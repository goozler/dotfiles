#!/bin/bash
# One-shot fetcher for the Fable-scoped weekly limit.
#
# The 5h and weekly all-model limits arrive on the statusline stdin payload, but
# the Fable cap only exists in this endpoint's limits[] array (the top-level
# seven_day_opus / seven_day_sonnet fields are null). Called by context-bar.sh
# when the cache is stale; runs once and exits.
#
# Cache format (single line, pre-parsed so the statusline needs no jq to read it):
#   <percent> <reset_epoch> <fetched_epoch>      percent -1 when there is no cap

CACHE_FILE="/tmp/claude-fable-cache"

now=$(date +%s)

creds=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null) || exit 1
token=$(printf '%s' "$creds" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null) || exit 1
[ -z "$token" ] && exit 1

response=$(curl -s --max-time 10 \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" \
    https://api.anthropic.com/api/oauth/usage 2>/dev/null) || exit 1

# Bail out without touching the cache if the response is not the expected shape,
# so a transient failure keeps the previous values instead of blanking the bar.
printf '%s' "$response" | jq -e 'has("limits") or has("five_hour")' >/dev/null 2>&1 || exit 1

line=$(printf '%s' "$response" | jq -r --argjson now "$now" '
    def epoch: if . == null then -1 else (split(".")[0] + "Z" | fromdate) end;
    # The endpoint intermittently returns the envelope with limits null. That is
    # not evidence the cap is gone, so say so rather than reporting an absence
    # and blanking the segment for a whole TTL.
    if (.limits | type) != "array" then "inconclusive"
    else
        .limits
        | map(select(.kind == "weekly_scoped"
                     and ((.scope.model.display_name // "") | ascii_downcase) == "fable"))
        | first
        | if . == null then "-1 -1 \($now)"
          else "\((.percent // -1) | floor) \((.resets_at // null) | epoch) \($now)"
          end
    end
' 2>/dev/null) || exit 1

# Leave the cache alone: context-bar.sh already re-stamped it to claim the fetch
# window, so the previous values survive and we retry one TTL later.
[ "$line" = "inconclusive" ] && exit 0

case "$line" in
    ''|*[!0-9\ -]*) exit 1 ;;
esac

printf '%s\n' "$line" > "$CACHE_FILE"
