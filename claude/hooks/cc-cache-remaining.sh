#!/bin/sh
# Render the remaining Claude Code prompt-cache TTL as a tmux status segment.
#
# Invoked per-window from window-status-format in ~/.tmux.conf, gated so it
# only renders while the session is idle (not while Claude is working):
#   #{?#{==:#{@cc-status},working},,#(~/.claude/hooks/cc-cache-remaining.sh #{@cc-cache-ts})}
#
# @cc-cache-ts is set by ~/.claude/hooks/tmux-claude-hooks.py on every API-call
# boundary (prompt submit, each tool result, waiting, turn end). The prompt
# cache refreshes its TTL on each read, and the agentic loop reads it through
# the whole turn, so the cache stays warm while Claude is working — the idle
# clock only starts at turn end. Anchoring on the last cache touch (not the
# prompt-submit time) makes the countdown reflect actual idle time.
#
# TTL is 1 hour. This was measured empirically across 177 local sessions:
# turn-initial cache_read stayed >0 (warm) ~100% up to ~60 min idle, then
# collapsed to cold by ~80 min — the signature of Anthropic's 1h extended
# cache, not the 5-min default.
#
# To keep tabs quiet while warm, the countdown stays HIDDEN until the cache is
# within CC_CACHE_SHOW_UNDER seconds of expiry (default 1800 = last 30 min). Once
# the cache goes COLD, a persistent red "● Nm" marker shows how long ago it
# expired — so a blank tab unambiguously means "warm", and you know BEFORE
# sending that the next message will reheat the whole context (rather than after,
# the way the @cc-reheat token count only appears once the turn completes).
#
# A passive marker is easy to miss, so crossing 30 / 10 / 2 minutes left also
# plays a short sound, once each per idle stretch. This script is the only thing
# that ticks while a session sits idle (Claude's hooks fire only when Claude is
# doing something), which is why the alerting lives here rather than in a hook.
# Sounds come from the claudecode-sounds pack that is actually configured, at the
# volume configured there, so they sit alongside Claude's own cues instead of
# clashing with them. The three files are hand-picked from the error group, which
# fires least often, and get more insistent as the deadline approaches.
#
# Tunables: CC_CACHE_TTL (default 3600), CC_CACHE_SHOW_UNDER (default 1800),
# CC_CACHE_ALERTS=0 to silence the sounds, CC_CACHE_ALERT_VOLUME to override the
# pack's volume, CC_CACHE_ALERT_{30M,10M,2M} to point a threshold at another file.

# Sound thresholds, in seconds of remaining TTL, largest first.
ALERT_THRESHOLDS="1800 600 120"
SOUNDS_CONFIG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/claudecode-sounds.local.md"
SOUNDPACK_DIR="$HOME/.claude/plugins/claudecode-sounds/soundpacks"

# Read one frontmatter key out of the sound plugin's settings file.
sounds_setting() {
    [ -f "$SOUNDS_CONFIG" ] || return 0
    sed -n "s/^$1:[[:space:]]*//p" "$SOUNDS_CONFIG" 2>/dev/null |
        head -1 | tr -d '"'"'"' \r'
}

alert_sound_for() {
    case "$1" in
        1800) override="$CC_CACHE_ALERT_30M"; file=error-6 ;;
        600)  override="$CC_CACHE_ALERT_10M"; file=error-3 ;;
        *)    override="$CC_CACHE_ALERT_2M";  file=error-7 ;;
    esac
    if [ -n "$override" ]; then
        printf '%s' "$override"
        return 0
    fi
    pack="$(sounds_setting soundpack)"
    [ -z "$pack" ] && pack=warcraft3-en
    printf '%s/%s/%s.wav' "$SOUNDPACK_DIR" "$pack" "$file"
}

# One marker file per (cache timestamp, threshold): the status bar re-runs this
# script every couple of seconds, and each threshold must sound exactly once.
# Keying on the timestamp means a fresh turn (which moves @cc-cache-ts) starts a
# clean slate, with no state to reset anywhere.
ALERT_DIR="$HOME/.claude/state/cc-cache-alerts"

maybe_alert() {
    remaining="$1"
    ts="$2"
    [ "${CC_CACHE_ALERTS:-1}" = "0" ] && return 0
    # Overrides default to empty so alert_sound_for can test them under `set -u`
    # semantics in any shell.
    CC_CACHE_ALERT_30M="${CC_CACHE_ALERT_30M:-}"
    CC_CACHE_ALERT_10M="${CC_CACHE_ALERT_10M:-}"
    CC_CACHE_ALERT_2M="${CC_CACHE_ALERT_2M:-}"
    due=""
    for th in $ALERT_THRESHOLDS; do
        [ "$remaining" -le "$th" ] || continue
        marker="$ALERT_DIR/${ts}-${th}"
        [ -f "$marker" ] && continue
        mkdir -p "$ALERT_DIR" 2>/dev/null || return 0
        : > "$marker" 2>/dev/null || return 0
        due="$th"   # loop runs largest → smallest, so this ends up the most urgent
    done
    [ -z "$due" ] && return 0
    # Attaching to a session that has been idle a while crosses several
    # thresholds at once; every one is marked above, but only the most urgent is
    # played, so it stays one sound per event rather than a chord.
    sound="$(alert_sound_for "$due")"
    [ -f "$sound" ] || return 0
    volume="${CC_CACHE_ALERT_VOLUME:-$(sounds_setting volume)}"
    [ -z "$volume" ] && volume=0.3
    afplay -v "$volume" "$sound" >/dev/null 2>&1 &
    # Markers are tiny but the timestamps never repeat, so sweep old ones.
    find "$ALERT_DIR" -type f -mtime +1 -delete >/dev/null 2>&1 &
    return 0
}

ts="$1"
[ -f /tmp/cc-cache-debug-on ] && printf '%s called ts=[%s]\n' "$(date +%H:%M:%S)" "$ts" >> /tmp/cc-cache-remaining.log
[ -z "$ts" ] && exit 0
case "$ts" in *[!0-9]*) exit 0 ;; esac   # non-numeric guard

ttl="${CC_CACHE_TTL:-3600}"
show_under="${CC_CACHE_SHOW_UNDER:-1800}"
now=$(date +%s)
remaining=$(( ts + ttl - now ))

# Sound the crossings before deciding what (if anything) to draw: the 30-minute
# alert has to fire even on the render where the countdown first becomes visible.
maybe_alert "$remaining" "$ts"

# Cold: the cache has expired. Show a persistent red marker with elapsed-since-
# expiry so a blank tab unambiguously means "warm" — and you can see, before
# sending, that the next message will reheat the whole context.
if [ "$remaining" -le 0 ]; then
    elapsed=$(( -remaining ))
    if [ "$elapsed" -lt 3600 ]; then
        ago="$(( elapsed / 60 ))m"
    else
        ago=$(printf '%dh%02dm' $(( elapsed / 3600 )) $(( elapsed % 3600 / 60 )))
    fi
    printf '#[fg=#dc322f]● %s#[default] ' "$ago"
    exit 0
fi

[ "$remaining" -gt "$show_under" ] && exit 0  # plenty of time left — stay hidden

if [ "$remaining" -le 120 ]; then
    color='#dc322f'      # solarized red — about to expire (<2 min)
elif [ "$remaining" -le 600 ]; then
    color='#b58900'      # solarized yellow — within the last 10 min
else
    color='#859900'      # solarized green — 10–30 min left (first appears here)
fi

# Format the visible window as M:SS (e.g. 9:58), or NNs under a minute.
if [ "$remaining" -ge 60 ]; then
    label=$(printf '%d:%02d' $(( remaining / 60 )) $(( remaining % 60 )))
else
    label="${remaining}s"
fi

printf '#[fg=%s]%s#[default] ' "$color" "$label"
