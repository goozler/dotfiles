#!/usr/bin/env python3
"""tmux per-pane attention indicator for Claude Code.

Sets/clears tmux user-options on the window containing the current pane,
driven by Claude Code hooks. The status bar renders @cc-status visually.

Spec: ~/tmp/tmux-claude-attention/docs/specs/2026-06-03-tmux-claude-attention-design.md
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime

DEBUG = os.environ.get("CC_TMUX_DEBUG") == "1"
SUBPROC_TIMEOUT = 1.0

SEVERITY = {"": 0, "working": 1, "done": 1, "waiting": 2, "permission": 3}

# Auto-rename window via the local model: an initial name on the 1st
# UserPromptSubmit, then a refined name (with more accumulated context) on the
# Nth. Both go through Ollama — there is no regex slug.
TOPIC_PROMPT_THRESHOLD = 3
# TOPIC_MAX_LEN is the length we aim for and ask the model to hit. The trimmer
# never splits a word, so it may stretch up to TOPIC_HARD_MAX_LEN to keep a
# whole word — and a single word longer than that is kept in full, never cut.
TOPIC_MAX_LEN = 20
TOPIC_HARD_MAX_LEN = 26
RENAME_CTX_MAX = 500   # cap on the accumulated prompt text fed to the model
# Manually renaming the window to this sentinel flags it for a fresh rename
# on the next UserPromptSubmit — using THAT prompt as the topic, not the
# accumulated session context. Lets you refresh mid-session without restarting.
SENTINEL_RENAME = "RENAME"
# Window names come solely from a tiny local model via Ollama on localhost.
# This is a plain HTTP call — no API tokens, no cost, and (critically) no nested
# `claude` process. The previous implementation shelled out to `claude -p`, which
# booted a full agent (~33k-500k tokens per rename) AND inherited TMUX_PANE, so
# its Stop hook fired stray "done" sounds/colours on this pane. The HTTP worker
# has neither problem. There is no regex fallback: if Ollama is unreachable the
# window simply keeps its current name. Set CC_TMUX_DISABLE_LLM_RENAME=1 to
# disable auto-renaming entirely.
OLLAMA_URL = os.environ.get(
    "CC_TMUX_OLLAMA_URL", "http://localhost:11434/api/generate"
)
OLLAMA_MODEL = os.environ.get("CC_TMUX_OLLAMA_MODEL", "qwen2.5:1.5b")
OLLAMA_KEEP_ALIVE = os.environ.get("CC_TMUX_OLLAMA_KEEP_ALIVE", "10m")
OLLAMA_TIMEOUT_SECONDS = 20
# Window names that are safe to overwrite (shells, default process names).
DEFAULT_WINDOW_NAME_RE = re.compile(
    r"^(zsh|bash|sh|fish|tmux|claude|node|vim|nvim|less|man|"
    r"python|python3|ipython|ruby|irb|git|ssh|pnpm|npm|yarn|make)$"
)

# Per-session log of files Claude edited — consumed by :ClaudeChanged and
# the prefix+E tmux popup. One absolute path per line, append-only.
TOUCHED_FILES_DIR = os.path.expanduser("~/.claude/state")
FILE_TOUCHING_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}

# --- Prompt-cache reheat detection -------------------------------------------
# A "reheat" is a turn whose first API call read nothing from the prompt cache
# (cache_read_input_tokens == 0) and had to re-create the whole context — i.e.
# the ~1-hour cache had expired (or was cleared) and this turn paid full
# price for the entire context. We read the ACTUAL token count from the session
# transcript (the Stop hook payload carries transcript_path) rather than guess.
REHEAT_LOG = os.path.join(TOUCHED_FILES_DIR, "cache-reheats.log")
REHEAT_MIN_TOKENS = int(os.environ.get("CC_REHEAT_MIN_TOKENS", "10000"))
# Only the tail of the transcript is read — the just-finished turn lives at the
# end of the file, so this bounds the work regardless of total session size.
REHEAT_TAIL_BYTES = int(os.environ.get("CC_REHEAT_TAIL_BYTES", "2000000"))


def severity_merge(current: str, new: str) -> bool:
    """Return True iff `new` should replace `current`.

    Unknown values map to severity 0, so an unrecognized current state
    does not latch the marker forever.
    """
    return SEVERITY.get(new, 0) >= SEVERITY.get(current, 0)


def log(msg: str) -> None:
    if not DEBUG:
        return
    try:
        with open("/tmp/cc-tmux-claude-hooks.log", "a") as f:
            f.write(f"{datetime.now().isoformat()} [{os.getpid()}] {msg}\n")
    except Exception:
        pass


def tmux(*args: str, capture: bool = False) -> str | None:
    """Run tmux with a short timeout.

    Returns stdout string if capture=True, "" on success without capture,
    None on any failure (missing binary, nonzero exit, timeout, OS error).
    Never raises.
    """
    if not shutil.which("tmux"):
        return None
    cmd = ["tmux", *args]
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=SUBPROC_TIMEOUT,
        )
    except (subprocess.TimeoutExpired, OSError) as e:
        log(f"tmux {args} -> {type(e).__name__}: {e}")
        return None
    if result.returncode != 0:
        log(f"tmux {args} -> rc={result.returncode} stderr={result.stderr.strip()}")
        return None
    return result.stdout.rstrip("\n") if capture else ""


def get_option(pane: str, name: str) -> str:
    """Return option value or "" if unset/unreachable."""
    out = tmux("show-options", "-qwv", "-t", pane, name, capture=True)
    return out or ""


def set_option(pane: str, name: str, value: str) -> None:
    tmux("set-option", "-w", "-t", pane, name, value)


def unset_option(pane: str, name: str) -> None:
    tmux("set-option", "-w", "-u", "-t", pane, name)


def _touch_cache_ts(pane: str) -> None:
    """Record 'now' as the last moment this session touched the prompt cache.

    Anthropic's prompt cache refreshes its 5-min TTL on every read, and the
    agentic loop reads it at turn start and after every tool result. So the
    cache stays warm for the WHOLE time Claude is working — the idle expiry
    clock only starts when the turn ends. We therefore bump this on every
    API-call boundary (prompt submit, tool completion, waiting, done) and the
    status-bar countdown anchors on it, not on the prompt-submit time.
    """
    set_option(pane, "@cc-cache-ts", str(int(time.time())))


def read_stdin_json() -> dict:
    try:
        raw = sys.stdin.read()
    except Exception:
        return {}
    if not raw:
        return {}
    try:
        return json.loads(raw)
    except Exception:
        return {}


def _truncate_kebab(
    name: str,
    target_len: int = TOPIC_MAX_LEN,
    hard_max: int = TOPIC_HARD_MAX_LEN,
) -> str:
    """Trim a kebab-case string at word boundaries only — never mid-word.

    Keeps whole hyphen-separated words, preferring to stay within target_len
    but stretching up to hard_max when that lets one more whole word fit. The
    first word is always kept in full, so a single word longer than hard_max
    is returned intact rather than cut.
    """
    if not name or len(name) <= target_len:
        return name
    words = name.split("-")
    result = words[0]  # always keep the first whole word, however long
    for word in words[1:]:
        if len(result) >= target_len:
            break  # already at the target — don't keep growing
        candidate = f"{result}-{word}"
        if len(candidate) > hard_max:
            break  # the next whole word won't fit the hard cap
        result = candidate
    return result


def _clean_llm_output(raw: str) -> str:
    """Coerce the model's output into a kebab-case identifier, tolerantly.

    Handles bare identifiers ("fix-auth-bug"), preambled identifiers
    ("Identifier: fix-auth-bug"), quoted/backticked, and multi-line.
    """
    if not raw:
        return ""
    lines = [line.strip() for line in raw.strip().split("\n") if line.strip()]
    if not lines:
        return ""
    candidate = lines[-1]
    candidate = re.sub(r"^.*?[:=]\s*", "", candidate)  # drop "label:" prefix
    candidate = candidate.strip("\"'`*_<>[]() ")
    cleaned = re.sub(r"[^a-z0-9-]+", "-", candidate.lower())
    cleaned = re.sub(r"-+", "-", cleaned).strip("-")
    return _truncate_kebab(cleaned)


def _llm_summarize(prompt: str) -> str:
    """Ask the local Ollama model for a kebab-case topic identifier.

    A single non-streaming HTTP call to a tiny model on localhost. The
    system prompt fully constrains the output, so there is no agent, no
    tool use, and no token cost. Returns "" on connection failure, timeout,
    or unparseable output — in which case no rename happens.
    """
    system = (
        "You convert a user request into a short kebab-case identifier: "
        "2-3 lowercase words joined by hyphens, max "
        f"{TOPIC_MAX_LEN} characters, using only lowercase letters, digits, "
        "and hyphens. Output ONLY the identifier on a single line. No quotes, "
        "no preamble, no explanation. Examples: fix-auth-bug, update-readme, "
        "review-tmux-config."
    )
    body = json.dumps(
        {
            "model": OLLAMA_MODEL,
            "system": system,
            "prompt": prompt,
            "stream": False,
            "keep_alive": OLLAMA_KEEP_ALIVE,
            "options": {"temperature": 0.2, "num_predict": 24, "stop": ["\n"]},
        }
    ).encode()
    req = urllib.request.Request(
        OLLAMA_URL, data=body, headers={"Content-Type": "application/json"}
    )
    try:
        with urllib.request.urlopen(req, timeout=OLLAMA_TIMEOUT_SECONDS) as resp:
            data = json.loads(resp.read().decode())
    except (urllib.error.URLError, OSError, ValueError) as e:
        log(f"ollama call failed: {type(e).__name__}: {e}")
        return ""
    return _clean_llm_output(data.get("response", ""))


def _spawn_llm_rename(pane: str, prompt: str) -> None:
    """Fire-and-forget background worker. Hook returns immediately."""
    if os.environ.get("CC_TMUX_DISABLE_LLM_RENAME") == "1":
        return
    try:
        subprocess.Popen(
            [
                sys.executable,
                os.path.abspath(__file__),
                "_llm-rename",
                pane,
                prompt[:500],
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
            close_fds=True,
        )
    except OSError as e:
        log(f"llm rename spawn failed: {e}")


def action_llm_rename(pane: str, prompt: str) -> None:
    """Background worker entrypoint: ask the local model for a name and apply it."""
    name = _llm_summarize(prompt)
    if not name:
        return
    if not safe_to_auto_rename(pane):
        return  # user renamed between slug-apply and now; respect that
    tmux("rename-window", "-t", pane, name)
    set_option(pane, "@cc-auto-name", name)


def get_window_name(pane: str) -> str:
    out = tmux("display-message", "-p", "-t", pane, "#W", capture=True)
    return out or ""


def safe_to_auto_rename(pane: str) -> bool:
    """Only rename windows that look auto-generated or were last named by us.

    Considered auto-generated:
      - Shell / common process names (DEFAULT_WINDOW_NAME_RE)
      - Names with no alphabetic characters (versions like "2.1.153", IPs,
        raw numbers) — these come from OSC title sequences or tmux-resurrect
        snapshots, not user input.
    """
    current = get_window_name(pane)
    if not current:
        return True
    if DEFAULT_WINDOW_NAME_RE.match(current):
        return True
    if not re.search(r"[A-Za-z]", current):
        return True
    last_auto = get_option(pane, "@cc-auto-name")
    return bool(last_auto) and current == last_auto


def _accumulate_rename_ctx(pane: str, prompt: str) -> str:
    """Append this prompt to the per-window rename context and return it.

    The 1st-prompt name is built from the 1st prompt alone; the refined Nth name
    uses the first N prompts joined, so the model has the fuller topic to work
    from. Capped at RENAME_CTX_MAX characters.
    """
    if not prompt:
        return get_option(pane, "@cc-rename-ctx")
    prev = get_option(pane, "@cc-rename-ctx")
    combined = (prev + "\n" + prompt) if prev else prompt
    combined = combined[:RENAME_CTX_MAX]
    set_option(pane, "@cc-rename-ctx", combined)
    return combined


def maybe_auto_rename(pane: str, payload: dict, count: int) -> None:
    # Rename via the local model on the 1st prompt (quick initial name) and
    # again on the Nth (refined with accumulated context). No regex slug — if
    # Ollama is unreachable the window just keeps its current name.
    if count > TOPIC_PROMPT_THRESHOLD:
        return
    ctx = _accumulate_rename_ctx(pane, payload.get("prompt", "") or "")
    if count not in (1, TOPIC_PROMPT_THRESHOLD):
        return
    if not ctx or not safe_to_auto_rename(pane):
        return
    _spawn_llm_rename(pane, ctx)


def _force_rename(pane: str, prompt: str) -> None:
    """Re-rename the window via the local model using `prompt` as the topic.

    Triggered when the user manually sets the window name to SENTINEL_RENAME —
    the sentinel itself is explicit consent to overwrite. Resets the rename
    context to this prompt. (If Ollama is down the window stays at "RENAME".)
    """
    if not prompt:
        return
    set_option(pane, "@cc-rename-ctx", prompt[:RENAME_CTX_MAX])
    # Mark the current (sentinel) name as ours so the async worker's
    # safe-to-rename check passes and applies the model's name.
    set_option(pane, "@cc-auto-name", get_window_name(pane))
    _spawn_llm_rename(pane, prompt)


def action_prompt_submit(pane: str, payload: dict) -> None:
    sid = payload.get("session_id", "")
    if sid:
        set_option(pane, "@cc-session-id", sid)
    set_option(pane, "@cc-last-prompt-ts", str(int(time.time())))
    _touch_cache_ts(pane)
    # A new turn starts warm; clear the previous turn's reheat marker.
    unset_option(pane, "@cc-reheat")
    # Force-set "working" (bypasses severity merge — a new turn always overrides).
    set_option(pane, "@cc-status", "working")

    # Sentinel check: window manually renamed to RENAME → use *this* prompt
    # as the topic and re-rename immediately. Counter logic doesn't run.
    if get_window_name(pane) == SENTINEL_RENAME:
        _force_rename(pane, payload.get("prompt", "") or "")
        return

    # Per-window prompt counter — drives auto-rename on the Nth prompt.
    try:
        count = int(get_option(pane, "@cc-prompt-count") or "0") + 1
    except ValueError:
        count = 1
    set_option(pane, "@cc-prompt-count", str(count))
    maybe_auto_rename(pane, payload, count)


def action_session_start(pane: str, payload: dict) -> None:
    sid = payload.get("session_id", "")
    if sid:
        set_option(pane, "@cc-session-id", sid)
    unset_option(pane, "@cc-status")
    unset_option(pane, "@cc-reheat")
    unset_option(pane, "@cc-cache-ts")
    # Reset per-session counters; keep @cc-auto-name so a new session in the
    # same window can update *our* prior auto-name but never clobber a manual one.
    unset_option(pane, "@cc-prompt-count")
    unset_option(pane, "@cc-rename-ctx")


def action_session_end(pane: str, _payload: dict) -> None:
    unset_option(pane, "@cc-status")


def action_set_state(pane: str, new_state: str) -> None:
    current = get_option(pane, "@cc-status")
    if severity_merge(current, new_state):
        set_option(pane, "@cc-status", new_state)


def _append_touched_file(session_id: str, file_path: str) -> None:
    """Append a Claude-edited file path to the per-session touched-files log."""
    try:
        os.makedirs(TOUCHED_FILES_DIR, exist_ok=True)
        path = os.path.join(TOUCHED_FILES_DIR, f"session-{session_id}-touched.txt")
        with open(path, "a", encoding="utf-8") as fh:
            fh.write(file_path + "\n")
    except OSError as e:
        log(f"touched-log: {type(e).__name__}: {e}")


def action_waiting(pane: str, _payload: dict) -> None:
    # The model just made an API call that needs you (permission / idle prompt),
    # so the cache was read moments ago — anchor the idle clock here too.
    _touch_cache_ts(pane)
    action_set_state(pane, "waiting")


def action_tool_completed(pane: str, payload: dict) -> None:
    # A tool finished; the next API call (which re-reads the cache) is imminent.
    _touch_cache_ts(pane)
    # When a tool finishes, a prior `waiting` state (set by PermissionRequest)
    # is resolved — revert to working. Force-set because severity would block
    # the waiting→working transition.
    if get_option(pane, "@cc-status") == "waiting":
        set_option(pane, "@cc-status", "working")

    # Log file edits so :ClaudeChanged / prefix+E can find them later, even
    # after they're committed (git status alone misses post-commit files).
    tool_name = payload.get("tool_name", "")
    if tool_name not in FILE_TOUCHING_TOOLS:
        return
    tool_input = payload.get("tool_input") or {}
    file_path = tool_input.get("file_path") or tool_input.get("notebook_path")
    if not file_path:
        return
    session_id = payload.get("session_id") or get_option(pane, "@cc-session-id")
    if not session_id:
        return
    _append_touched_file(session_id, file_path)


def _human_tokens(n: int) -> str:
    """Compact token count for a status marker: 980, 9.8k, 62k, 1.2M."""
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M"
    if n >= 10_000:
        return f"{round(n / 1000)}k"
    if n >= 1000:
        return f"{n / 1000:.1f}k"
    return str(n)


def _read_transcript_tail(path: str) -> tuple:
    """Parse the trailing REHEAT_TAIL_BYTES of a JSONL transcript.

    Reads only the end of the file (the just-finished turn lives there), drops a
    possibly-truncated first line, and returns (rows, truncated). `truncated` is
    True when the file exceeded REHEAT_TAIL_BYTES so only its tail was read (i.e.
    a long session — the start of the session is NOT in `rows`). Returns
    ([], False) on any failure — reheat detection is best-effort, never raises.
    """
    try:
        size = os.path.getsize(path)
        truncated = size > REHEAT_TAIL_BYTES
        with open(path, "rb") as fh:
            if truncated:
                fh.seek(size - REHEAT_TAIL_BYTES)
            raw = fh.read()
    except OSError:
        return [], False
    lines = raw.split(b"\n")
    if truncated:
        lines = lines[1:]  # first line is probably truncated
    rows = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line.decode("utf-8", "replace")))
        except ValueError:
            continue
    return rows, truncated


def _is_user_prompt(row: dict) -> bool:
    """True for a genuine user prompt, False for a tool_result continuation."""
    if row.get("type") != "user":
        return False
    content = (row.get("message") or {}).get("content")
    if isinstance(content, str):
        return True
    if isinstance(content, list):
        types = {b.get("type") for b in content if isinstance(b, dict)}
        return "tool_result" not in types
    return False


def _analyze_reheat(transcript_path: str) -> tuple:
    """Inspect the last turn's first API call. Return (is_reheat, tokens_spent).

    A reheat = the turn's first assistant call read 0 tokens from cache and
    re-created at least REHEAT_MIN_TOKENS of context (the cache had expired or
    was cleared). tokens_spent is the full non-cached input that turn paid for:
    fresh input + re-cached context.

    The first turn of a brand-new session is ALSO read==0 + big create (there is
    no cache yet), but that is an unavoidable cold start, not an idle-expiry
    reheat — so it is not flagged. We detect it as: no prior main-chain
    assistant call before this turn, in a transcript read in full (small file).
    A --resume after a long gap still flags (it has prior history); long
    sessions are unaffected (their previous turn sits in the tail).
    """
    if not transcript_path:
        return False, 0
    rows, truncated = _read_transcript_tail(transcript_path)
    if not rows:
        return False, 0
    start = None
    for i in range(len(rows) - 1, -1, -1):
        if _is_user_prompt(rows[i]):
            start = i
            break
    if start is None:
        return False, 0
    prior_call = any(
        r.get("type") == "assistant"
        and not r.get("isSidechain")
        and (r.get("message") or {}).get("usage")
        for r in rows[:start]
    )
    first_turn_of_session = not prior_call and not truncated
    for row in rows[start + 1:]:
        if row.get("type") != "assistant" or row.get("isSidechain"):
            continue
        usage = (row.get("message") or {}).get("usage") or {}
        if not usage:
            continue
        read = usage.get("cache_read_input_tokens") or 0
        create = usage.get("cache_creation_input_tokens") or 0
        inp = usage.get("input_tokens") or 0
        is_reheat = (
            read == 0
            and create >= REHEAT_MIN_TOKENS
            and not first_turn_of_session
        )
        return is_reheat, create + inp
    return False, 0


def _log_reheat(pane: str, payload: dict, tokens: int) -> None:
    """Append one reheat record to REHEAT_LOG for later review."""
    try:
        os.makedirs(TOUCHED_FILES_DIR, exist_ok=True)
        ts = datetime.now().isoformat(timespec="seconds")
        win = get_window_name(pane) or "?"
        sid = payload.get("session_id") or get_option(pane, "@cc-session-id") or "?"
        with open(REHEAT_LOG, "a", encoding="utf-8") as fh:
            fh.write(
                f"{ts}  reheat  tokens={tokens}  win={win}  "
                f"pane={pane}  session={sid}\n"
            )
    except OSError as e:
        log(f"reheat-log: {type(e).__name__}: {e}")


def action_done(pane: str, payload: dict) -> None:
    stored_session = get_option(pane, "@cc-session-id")
    hook_session = payload.get("session_id", "")
    if stored_session and hook_session and stored_session != hook_session:
        return  # stale hook from prior session
    if not get_option(pane, "@cc-last-prompt-ts"):
        return  # no prompt seen in this session yet, defensive
    action_set_state(pane, "done")
    # Turn just ended → the cache was last read now; the idle clock starts here.
    _touch_cache_ts(pane)
    # Did this turn reheat a cold prompt cache? Read the real token cost from the
    # transcript and flag it (status marker + log) so an expensive cache-miss
    # turn is visible after the fact.
    is_reheat, tokens = _analyze_reheat(payload.get("transcript_path", ""))
    if is_reheat:
        set_option(pane, "@cc-reheat", _human_tokens(tokens))
        _log_reheat(pane, payload, tokens)


ACTIONS = {
    "prompt-submit": action_prompt_submit,
    "session-start": action_session_start,
    "session-end": action_session_end,
    "waiting": action_waiting,
    "done": action_done,
    "tool-completed": action_tool_completed,
}


def main() -> int:
    if len(sys.argv) < 2:
        return 0
    action = sys.argv[1]
    # Background worker mode — invoked by _spawn_llm_rename. Args carry
    # the pane id and prompt text directly; TMUX_PANE / stdin not used.
    if action == "_llm-rename":
        if len(sys.argv) < 4:
            return 0
        try:
            action_llm_rename(sys.argv[2], sys.argv[3])
        except Exception as e:
            log(f"llm rename worker unhandled: {type(e).__name__}: {e}")
        return 0
    if action not in ACTIONS:
        log(f"unknown action: {action}")
        return 0
    pane = os.environ.get("TMUX_PANE")
    if not pane:
        return 0
    payload = read_stdin_json()
    log(f"action={action} pane={pane} payload_keys={list(payload.keys())}")
    try:
        ACTIONS[action](pane, payload)
    except Exception as e:
        log(f"unhandled: {type(e).__name__}: {e}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
