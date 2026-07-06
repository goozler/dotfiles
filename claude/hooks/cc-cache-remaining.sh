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
# Tunables: CC_CACHE_TTL (default 3600), CC_CACHE_SHOW_UNDER (default 1800).

ts="$1"
[ -z "$ts" ] && exit 0
case "$ts" in *[!0-9]*) exit 0 ;; esac   # non-numeric guard

ttl="${CC_CACHE_TTL:-3600}"
show_under="${CC_CACHE_SHOW_UNDER:-1800}"
now=$(date +%s)
remaining=$(( ts + ttl - now ))

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
