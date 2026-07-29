#!/bin/bash
# Claude Code statusline.
#   line 1: model | directory | git branch
#   line 2: ⏱ session 5h | 📖 weekly Fable-scoped | 📅 weekly all-model | 🧠 context window
#
# The 5h / weekly / context values are carried on the statusline stdin payload,
# so the common render costs one jq plus one git. Two gaps get filled from a
# pre-normalized out-of-band cache (usage-fetcher.sh, one request per TTL for the
# whole machine): the Fable cap is never on stdin at all, and the 5h / weekly
# values are null there until the session's first API response. stdin wins
# whenever it has a value; the cache only fills in.

# Color theme
C_RESET='\033[0m'
C_GRAY='\033[38;5;245m'
C_ACCENT='\033[38;5;74m'
C_GREEN='\033[38;5;71m'
C_YELLOW='\033[38;5;136m'
C_RED='\033[38;5;167m'

BAR_W=6                                   # bar cells; 6 keeps pace buckets at ~17%
# "<u5h> <e5h> <u7d> <e7d> <ufable> <efable> <fetched_epoch>"
LIMITS_CACHE="/tmp/claude-limits-cache"
LIMITS_TTL=60
FETCHER_SCRIPT="$HOME/.claude/scripts/usage-fetcher.sh"

input=$(cat)

# Single jq call. `now` comes from jq too: /bin/bash on macOS is 3.2, so
# $EPOCHSECONDS does not exist and this saves a `date` subprocess.
eval "$(printf '%s' "$input" | jq -r '
    "now=" + (now | floor | tostring) +
    " model=" + ((.model.display_name // .model.id // "?") | @sh) +
    " cwd=" + ((.cwd // "") | @sh) +
    " dir=" + ((((.cwd // "") | split("/") | last) // "?") | @sh) +
    " u5h=" + ((.rate_limits.five_hour.used_percentage // -1) | floor | tostring) +
    " u7d=" + ((.rate_limits.seven_day.used_percentage // -1) | floor | tostring) +
    " e5h=" + ((.rate_limits.five_hour.resets_at // -1) | floor | tostring) +
    " e7d=" + ((.rate_limits.seven_day.resets_at // -1) | floor | tostring) +
    " uctx=" + ((.context_window.used_percentage // -1) | floor | tostring) +
    " ctxtok=" + ((if .context_window == null then -1
                   else (.context_window.total_input_tokens // 0)
                        + (.context_window.total_output_tokens // 0) end) | floor | tostring)
' 2>/dev/null)"
: "${now:=0}" "${model:=?}" "${dir:=?}" "${u5h:=-1}" "${u7d:=-1}" "${e5h:=-1}" "${e7d:=-1}" "${uctx:=-1}" "${ctxtok:=-1}"

# "Opus 5 (1M context)" is 19 columns; the window size is already implied by the
# context bar's scale, so keep only a short marker.
case "$model" in
    *' (1M context)') model="${model% (1M context)}/1M" ;;
    *' ('*'context)') model="${model% (*}" ;;
esac

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

# --- Cached limits (out-of-band) ---
c5h=-1 ce5h=-1 c7d=-1 ce7d=-1 ufb=-1 efb=-1 fetched=0
if [ -f "$LIMITS_CACHE" ]; then
    read -r c5h ce5h c7d ce7d ufb efb fetched < "$LIMITS_CACHE" 2>/dev/null
fi
# The line is read positionally, so anything but seven integers — a partial
# write, or a cache left by an older format — has to be discarded whole rather
# than shifting values onto the wrong bars.
cache_ok=1
for v in "$c5h" "$ce5h" "$c7d" "$ce7d" "$ufb" "$efb" "$fetched"; do
    case "$v" in
        ''|*[!0-9-]*) cache_ok=0 ;;
    esac
done
if [ "$cache_ok" -eq 0 ]; then
    c5h=-1 ce5h=-1 c7d=-1 ce7d=-1 ufb=-1 efb=-1 fetched=0
fi
if [ "$now" -gt 0 ] && [ $(( now - fetched )) -ge "$LIMITS_TTL" ]; then
    # Re-stamp with the current values first to claim the fetch window, so
    # concurrent renders do not all spawn a fetcher.
    printf '%s %s %s %s %s %s %s\n' \
        "$c5h" "$ce5h" "$c7d" "$ce7d" "$ufb" "$efb" "$now" > "$LIMITS_CACHE"
    bash "$FETCHER_SCRIPT" >/dev/null 2>&1 &
fi

# Fall back to the cache only where stdin has nothing — i.e. before this
# session's first API response. Percent and reset move together as a pair so a
# bar never pairs a live percent with a stale countdown.
if [ "$u5h" -lt 0 ] && [ "$c5h" -ge 0 ]; then u5h=$c5h; e5h=$ce5h; fi
if [ "$u7d" -lt 0 ] && [ "$c7d" -ge 0 ]; then u7d=$c7d; e7d=$ce7d; fi

# --- Reset countdowns (whole minutes; -1 when unknown) ---
if [ "$e5h" -gt 0 ] && [ "$now" -gt 0 ]; then r5h_min=$(( (e5h - now) / 60 )); else r5h_min=-1; fi
if [ "$e7d" -gt 0 ] && [ "$now" -gt 0 ]; then r7d_min=$(( (e7d - now) / 60 )); else r7d_min=-1; fi
if [ "$efb" -gt 0 ] && [ "$now" -gt 0 ]; then rfb_min=$(( (efb - now) / 60 )); else rfb_min=-1; fi
[ "$r5h_min" -lt 0 ] 2>/dev/null && r5h_min=-1
[ "$r7d_min" -lt 0 ] 2>/dev/null && r7d_min=-1
[ "$rfb_min" -lt 0 ] 2>/dev/null && rfb_min=-1

# Format reset time (no parens — the position in the segment is unambiguous)
fmt_reset() {
    local m=$1
    if [ "$m" -lt 0 ]; then echo ""
    elif [ "$m" -lt 60 ]; then echo " ${m}m"
    elif [ "$m" -lt 1440 ]; then
        local h=$((m / 60)) rm=$((m % 60))
        printf ' %d:%02d' "$h" "$rm"
    else
        local d=$((m / 1440)) rh=$(( (m % 1440) / 60 ))
        if [ "$rh" -eq 0 ]; then echo " ${d}d"
        else echo " ${d}d ${rh}h"; fi
    fi
}

# Color helper for usage values
usage_color() {
    local v=$1
    if [ "$v" -le 50 ]; then echo "$C_GREEN"
    elif [ "$v" -le 80 ]; then echo "$C_YELLOW"
    else echo "$C_RED"; fi
}

# Format token count compactly (e.g. 160k, 1.0M)
fmt_tokens() {
    local t=$1
    if [ "$t" -lt 0 ]; then echo "--"
    elif [ "$t" -ge 1000000 ]; then printf '%d.%dM' $((t / 1000000)) $(((t % 1000000) / 100000))
    else printf '%dk' $(((t + 500) / 1000)); fi
}

# Context fills up every session, so it earns later warnings than a quota does
ctx_color() {
    local v=$1
    if [ "$v" -le 60 ]; then echo "$C_GREEN"
    elif [ "$v" -le 85 ]; then echo "$C_YELLOW"
    else echo "$C_RED"; fi
}

# Mini bar builder with optional pace marker (│ at the elapsed position, so a
# fill ahead of the marker means burning faster than the clock)
mini_bar() {
    local v=$1 pace=${2:--1}
    local f=$(( (v * BAR_W + 50) / 100 ))
    [ "$f" -gt "$BAR_W" ] && f=$BAR_W
    [ "$f" -lt 0 ] && f=0
    # Any real usage must show at least one cell: at 6 cells anything under 9%
    # would otherwise round to an empty bar and read as "nothing used".
    [ "$f" -eq 0 ] && [ "$v" -gt 0 ] && f=1

    local p=-1
    if [ "$pace" -ge 0 ] 2>/dev/null; then
        p=$(( pace * BAR_W / 100 ))
        [ "$p" -gt $(( BAR_W - 1 )) ] && p=$(( BAR_W - 1 ))
    fi

    local bar="" i
    for ((i=0; i<BAR_W; i++)); do
        if [ "$i" -eq "$p" ]; then
            # Heavy marker when it sits on filled cells, light when on empty —
            # otherwise a marker at the far end hides that the bar is full.
            if [ "$i" -lt "$f" ]; then bar+="┃"; else bar+="│"; fi
        elif [ "$i" -lt "$f" ]; then bar+="▓"
        else bar+="░"
        fi
    done
    echo "$bar"
}

EMPTY_BAR=""
for ((i=0; i<BAR_W; i++)); do EMPTY_BAR+="░"; done

SEP="${C_GRAY} | "

# Segment labels. Emoji anchor each segment visually but cost one column more
# apiece than a letter pair; swapping these two lines is the whole difference.
L_5H="T:" L_7D="W:" L_FB="F:" L_CTX="C:"
# L_5H="⏱ " L_7D="📅 " L_FB="📖 " L_CTX="🧠 "

printf '%b\n' "${C_ACCENT}${model}${C_GRAY} | 📁 ${dir}${git_segment}${C_RESET}"

# --- Line 2: ⏱ (5h) | 📖 (weekly Fable) | 📅 (weekly, shared timer) | 🧠 (context) ---
line2=""

# ⏱ — 5h rolling window (300 min)
if [ "$u5h" -ge 0 ]; then
    if [ "$r5h_min" -ge 0 ]; then pace5h=$(( (300 - r5h_min) * 100 / 300 )); else pace5h=-1; fi
    line2+="$(usage_color "$u5h")${L_5H}$(mini_bar "$u5h" "$pace5h")${C_GRAY} ${u5h}%$(fmt_reset "$r5h_min")"
else
    line2+="${C_GRAY}${L_5H}${EMPTY_BAR} --"
fi

# 📖 — weekly Fable-scoped window; omitted entirely when the account has no such
# cap. Printed before 📅 so the timer the two share lands after both of them
# rather than between them; it prints its own only if the resets ever diverge.
if [ "$ufb" -ge 0 ]; then
    if [ "$rfb_min" -ge 0 ]; then pacefb=$(( (10080 - rfb_min) * 100 / 10080 )); else pacefb=-1; fi
    resetfb=""
    if [ "$rfb_min" -ge 0 ]; then
        if [ "$r7d_min" -lt 0 ]; then
            resetfb=$(fmt_reset "$rfb_min")
        else
            skew=$(( rfb_min - r7d_min ))
            [ "$skew" -lt 0 ] && skew=$(( -skew ))
            [ "$skew" -gt 5 ] && resetfb=$(fmt_reset "$rfb_min")
        fi
    fi
    line2+="${SEP}$(usage_color "$ufb")${L_FB}$(mini_bar "$ufb" "$pacefb")${C_GRAY} ${ufb}%${resetfb}"
fi

# 📅 — weekly all-model window (10080 min); carries the shared weekly timer
if [ "$u7d" -ge 0 ]; then
    if [ "$r7d_min" -ge 0 ]; then pace7d=$(( (10080 - r7d_min) * 100 / 10080 )); else pace7d=-1; fi
    line2+="${SEP}$(usage_color "$u7d")${L_7D}$(mini_bar "$u7d" "$pace7d")${C_GRAY} ${u7d}%$(fmt_reset "$r7d_min")"
else
    line2+="${SEP}${C_GRAY}${L_7D}${EMPTY_BAR} --"
fi

# 🧠 — context window for this session (no pace marker: context has no clock)
if [ "$uctx" -ge 0 ]; then
    line2+="${SEP}$(ctx_color "$uctx")${L_CTX}$(mini_bar "$uctx")${C_GRAY} $(fmt_tokens "$ctxtok")"
else
    line2+="${SEP}${C_GRAY}${L_CTX}${EMPTY_BAR} --"
fi

printf '%b\n' "  ${line2}${C_RESET}"
