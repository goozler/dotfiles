#!/bin/bash
# One-shot fetcher for the account's usage limits (5h rolling, weekly all-model,
# weekly Fable-scoped).
#
# The 5h and weekly all-model limits also arrive on the statusline stdin payload,
# but only once the session has had an API response — before the first prompt
# they are null. The Fable cap never arrives there at all (the top-level
# seven_day_opus / seven_day_sonnet fields are null). One request carries all
# three, so cache all three and let context-bar.sh prefer the live stdin values
# and fall back to this cache when they are missing. Called by context-bar.sh
# when the cache is stale; runs once and exits.
#
# Read from limits[], not the top-level five_hour / seven_day objects: the
# top-level per-model fields are already null, so limits[] is the maintained
# shape.
#
# Cache format (single line, pre-parsed so the statusline needs no jq to read
# it) — seven fields, percent/epoch -1 when a cap is absent:
#   <u5h> <e5h> <u7d> <e7d> <ufable> <efable> <fetched_epoch>

CACHE_FILE="/tmp/claude-limits-cache"

now=$(date +%s)

creds=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null) || exit 1
token=$(printf '%s' "$creds" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null) || exit 1
[ -z "$token" ] && exit 1

response=$(curl -s --max-time 10 \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" \
    https://api.anthropic.com/api/oauth/usage 2>/dev/null) || exit 1

# Bail out without touching the cache if the response is not the expected shape,
# so a transient failure keeps the previous values instead of blanking the bars.
printf '%s' "$response" | jq -e 'has("limits") or has("five_hour")' >/dev/null 2>&1 || exit 1

line=$(printf '%s' "$response" | jq -r --argjson now "$now" '
    def epoch: if . == null then -1 else (split(".")[0] + "Z" | fromdate) end;
    def pick(f): (.limits | map(select(f)) | first);
    # A missing entry renders as "-1 -1" so the field count stays fixed at seven
    # and the statusline can validate the line by shape alone.
    def fmt: if . == null then "-1 -1"
             else "\((.percent // -1) | floor) \((.resets_at // null) | epoch)" end;
    # The endpoint intermittently returns the envelope with limits null. That is
    # not evidence the caps are gone, so say so rather than reporting an absence
    # and blanking the segments for a whole TTL.
    if (.limits | type) != "array" then "inconclusive"
    else
        (pick(.kind == "session") | fmt) + " "
        + (pick(.kind == "weekly_all") | fmt) + " "
        + (pick(.kind == "weekly_scoped"
                and ((.scope.model.display_name // "") | ascii_downcase) == "fable") | fmt) + " "
        + ($now | tostring)
    end
' 2>/dev/null) || exit 1

# Leave the cache alone: context-bar.sh already re-stamped it to claim the fetch
# window, so the previous values survive and we retry one TTL later.
[ "$line" = "inconclusive" ] && exit 0

case "$line" in
    ''|*[!0-9\ -]*) exit 1 ;;
esac

# Refuse to write a short line: the statusline reads positionally, so a
# truncated write would silently shift every value one field to the left.
set -- $line
[ "$#" -eq 7 ] || exit 1

printf '%s\n' "$line" > "$CACHE_FILE"
