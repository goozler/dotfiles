#!/bin/bash

# Color theme
C_RESET='\033[0m'
C_GRAY='\033[38;5;245m'
C_ACCENT='\033[38;5;74m'
C_GREEN='\033[38;5;71m'
C_YELLOW='\033[38;5;136m'
C_RED='\033[38;5;167m'

input=$(cat)

# Single jq call to extract all fields
eval "$(echo "$input" | jq -r '
    "model=" + (.model.display_name // .model.id // "?" | @sh) +
    " modelid=" + ((.model.id // .model.display_name // "") | @sh) +
    " cwd=" + ((.cwd // "") | @sh) +
    " dir=" + ((.cwd // "") | split("/") | last // "?" | @sh) +
    " transcript=" + ((.transcript_path // "") | @sh)
')"

# --- Git branch + worktree detection (single git call) ---
branch=""
is_worktree=false
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
    if git_info=$(git -C "$cwd" rev-parse --abbrev-ref HEAD --absolute-git-dir --path-format=absolute --git-common-dir 2>/dev/null); then
        {
            IFS= read -r branch
            IFS= read -r gdir
            IFS= read -r gcommon
        } <<< "$git_info"
        # Detached HEAD → short SHA
        if [ "$branch" = "HEAD" ]; then
            branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
        fi
        # Worktree when git-dir differs from git-common-dir (both absolute)
        [ "$gdir" != "$gcommon" ] && is_worktree=true
        # Truncate very long branch names
        if [ "${#branch}" -gt 33 ]; then
            branch="${branch:0:32}…"
        fi
    fi
fi

# Truncate very long directory names
if [ "${#dir}" -gt 33 ]; then
    dir="${dir:0:32}…"
fi

# Build git segment
git_segment=""
if [ -n "$branch" ]; then
    if [ "$is_worktree" = true ]; then
        git_segment=" | ${C_GRAY}⌥ ${C_YELLOW}${branch}${C_GRAY}"
    else
        git_segment=" | ${C_GRAY}⎇ ${C_ACCENT}${branch}${C_GRAY}"
    fi
fi

# --- Usage limits (5h / 7d) ---
USAGE_CACHE="/tmp/claude-usage-cache.json"
USAGE_TTL=60
FETCHER_SCRIPT="$HOME/.claude/scripts/usage-fetcher.sh"

# Fetch if cache is missing or older than TTL
needs_fetch=false
if [ ! -f "$USAGE_CACHE" ]; then
    needs_fetch=true
else
    cache_age=$(( $(date +%s) - $(stat -f %m "$USAGE_CACHE") ))
    [ "$cache_age" -ge "$USAGE_TTL" ] && needs_fetch=true
fi
if [ "$needs_fetch" = true ]; then
    # Touch cache first to claim the fetch window (prevents duplicate fetches)
    touch "$USAGE_CACHE"
    bash "$FETCHER_SCRIPT" &
fi

# Read cached usage
if [ -f "$USAGE_CACHE" ] && [ -s "$USAGE_CACHE" ]; then
    eval "$(jq -r '
        def delta_min: split(".")[0] + "Z" | fromdate - now | . / 60 | floor;
        "u5h=" + ((.five_hour.utilization // -1) | floor | tostring | @sh) +
        " u7d=" + ((.seven_day.utilization // -1) | floor | tostring | @sh) +
        " r5h_min=" + ((.five_hour.resets_at // null) | if . then delta_min | tostring else "-1" end | @sh) +
        " r7d_min=" + ((.seven_day.resets_at // null) | if . then delta_min | tostring else "-1" end | @sh)
    ' "$USAGE_CACHE" 2>/dev/null)"
fi
: "${u5h:=-1}" "${u7d:=-1}" "${r5h_min:=-1}" "${r7d_min:=-1}"

# Format reset time
fmt_reset() {
    local m=$1
    if [ "$m" -lt 0 ]; then echo ""
    elif [ "$m" -lt 60 ]; then echo "(${m}m)"
    elif [ "$m" -lt 1440 ]; then
        local h=$((m / 60)) rm=$((m % 60))
        printf '(%d:%02d)' "$h" "$rm"
    else
        local d=$((m / 1440)) rh=$(( (m % 1440) / 60 ))
        if [ "$rh" -eq 0 ]; then echo "(${d}d)"
        else echo "(${d}d ${rh}h)"; fi
    fi
}

# Color helper for usage values
usage_color() {
    local v=$1
    if [ "$v" -le 50 ]; then echo "$C_GREEN"
    elif [ "$v" -le 80 ]; then echo "$C_YELLOW"
    else echo "$C_RED"; fi
}

# Mini bar builder (8-char) with optional pace marker
mini_bar() {
    local v=$1 pace=${2:--1}
    local f=$(( (v * 8 + 50) / 100 ))
    [ "$f" -gt 8 ] && f=8
    [ "$f" -lt 0 ] && f=0

    local p=-1
    if [ "$pace" -ge 0 ] 2>/dev/null; then
        p=$(( pace * 8 / 100 ))
        [ "$p" -gt 7 ] && p=7
    fi

    local bar="" i
    for ((i=0; i<8; i++)); do
        if [ "$i" -eq "$p" ]; then bar+="│"
        elif [ "$i" -lt "$f" ]; then bar+="▓"
        else bar+="░"
        fi
    done
    echo "$bar"
}

# --- Context window size (current session) ---
# Read the most recent assistant message's usage from the transcript.
# tail -r reverses the file so the newest entry is first; jq selects the
# first line carrying usage and head -1 closes the pipe (early-exit via
# SIGPIPE), so even large transcripts are cheap.
ctx_tokens=-1
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
    ctx_tokens=$(tail -r "$transcript" 2>/dev/null | jq -c '
        select(.message.usage != null)
        | .message.usage
        | (.input_tokens // 0) + (.cache_read_input_tokens // 0)
          + (.cache_creation_input_tokens // 0) + (.output_tokens // 0)
    ' 2>/dev/null | head -1)
    [ -z "$ctx_tokens" ] && ctx_tokens=-1
fi

# Color helper for context: yellow at 300k+, red at 450k+
ctx_color() {
    local t=$1
    if [ "$t" -ge 450000 ]; then echo "$C_RED"
    elif [ "$t" -ge 300000 ]; then echo "$C_YELLOW"
    else echo "$C_GREEN"; fi
}

# Format token count compactly (e.g. 160k, 1.0M)
fmt_tokens() {
    local t=$1
    if [ "$t" -lt 0 ]; then echo "--"
    elif [ "$t" -ge 1000000 ]; then printf '%d.%dM' $((t / 1000000)) $(((t % 1000000) / 100000))
    else printf '%dk' $(((t + 500) / 1000)); fi
}

EMPTY_STR="░░░░░░░░"

# Context window limit: 1M for [1m] variants, 200k otherwise
case "$modelid" in
    *1m*|*1M*|*\[1m\]*) ctx_max=1000000 ;;
    *)                  ctx_max=200000 ;;
esac

# Build context segment (8-char bar scaled to the model's window)
if [ "$ctx_tokens" -ge 0 ]; then
    C_CTX=$(ctx_color "$ctx_tokens")
    ctx_pct=$(( ctx_tokens * 100 / ctx_max ))   # tokens → % of model window
    barctx=$(mini_bar "$ctx_pct")
    ctx_str=$(fmt_tokens "$ctx_tokens")
    ctx_segment=" | ${C_CTX}🧠 ${barctx}${C_GRAY} ${ctx_str}"
else
    ctx_segment=" | ${C_GRAY}🧠 ${EMPTY_STR} --"
fi

printf '%b\n' "${C_ACCENT}${model}${C_GRAY} | 📁 ${dir}${git_segment}${C_RESET}"

if [ "$u5h" -ge 0 ] && [ "$u7d" -ge 0 ]; then
    # Elapsed-time pace (% of window consumed)
    if [ "$r5h_min" -ge 0 ]; then pace5h=$(( (300 - r5h_min) * 100 / 300 ))
    else pace5h=-1; fi
    if [ "$r7d_min" -ge 0 ]; then pace7d=$(( (10080 - r7d_min) * 100 / 10080 ))
    else pace7d=-1; fi

    C_5H=$(usage_color "$u5h")
    C_7D=$(usage_color "$u7d")
    bar5h=$(mini_bar "$u5h" "$pace5h")
    bar7d=$(mini_bar "$u7d" "$pace7d")
    reset5h=$(fmt_reset "$r5h_min")
    reset7d=$(fmt_reset "$r7d_min")
    printf '%b\n' "  ${C_5H}⏱ ${bar5h}${C_GRAY} ${u5h}% ${reset5h} | ${C_7D}📅 ${bar7d}${C_GRAY} ${u7d}% ${reset7d}${ctx_segment}${C_RESET}"
else
    printf '%b\n' "  ${C_GRAY}⏱ ${EMPTY_STR} -- | 📅 ${EMPTY_STR} --${ctx_segment}${C_RESET}"
fi
