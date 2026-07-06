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

DEBUG = (
    os.environ.get("CC_TMUX_DEBUG") == "1"
    or os.path.exists("/tmp/cc-tmux-debug-on")
)
SUBPROC_TIMEOUT = 1.0

SEVERITY = {"": 0, "working": 1, "done": 1, "waiting": 2, "permission": 3}

# Auto-rename window via the local model. Three moments, all through Ollama
# (no regex slug):
#   1. A quick initial name from the 1st prompt alone, the instant it's
#      submitted (UserPromptSubmit) — so the window is labelled before Claude
#      even starts replying.
#   2. A refined name when the 1st answer completes (Stop), now that there's a
#      prompt+answer to summarise.
#   3. One more refined name when the 2nd answer completes (Stop).
# The refined names (2 and 3) summarise the session's OPENING prompts (the stated
# goal) together with the most recent turns and Claude's prose replies (read from
# the transcript, tool calls / file reads / thinking stripped) — see
# _rename_context — so the name reflects what the work is actually about, not just
# whatever the last turn happened to touch. After the 2nd answer the name stays
# put unless you force a refresh with the prefix+r hotkey (tmux run-shell → the
# "rename" action, see action_rename).
# Every name is folder-led: the model is given the project directory this pane
# works in (see _pane_folder) and asked to lead with exactly ONE distinctive word
# from it ("tprov", not "tenant-provisioning-work-tprov") — so you can tell tabs
# apart by WHERE the work happens without the location eating the whole label.
# _finalize_name enforces the one-word rule even when the model echoes the full
# multi-word folder (see _anchor_word).
RENAME_UNTIL_TURN = 2  # re-name on the Stop of turns 1..this; 0 disables it
# TOPIC_MAX_LEN is the length we aim for and ask the model to hit. The trimmer
# never splits a word, so it may stretch up to TOPIC_HARD_MAX_LEN to keep a
# whole word — and a single word longer than that is kept in full, never cut.
# The label leads with ONE word for the project folder and then the task
# (anchor-then-task, e.g. "tprov-fix-enrollment"), so the budget is a little
# wider than a bare topic.
TOPIC_MAX_LEN = 26
TOPIC_HARD_MAX_LEN = 32
# Names are built from the opening prompts + recent dialogue (see _rename_context),
# capped at RENAME_DIALOGUE_MAX chars total, split between the two ends on line
# boundaries. 4000 chars (~1.1k tokens) keeps recent user prompts from being
# crowded out by Claude's verbose replies, while staying well inside the model's
# num_ctx=4096 (system + this + output ≈ 1.5k tokens). num_ctx caps the useful
# ceiling around ~13k chars; bigger than ~4k mostly dilutes a 3B model's label.
RENAME_DIALOGUE_MAX = 4000
# Names anchor on BOTH ends of the session: the first RENAME_FIRST_TURNS prompts
# (which state the actual goal) and the last RENAME_RECENT_TURNS turns (where the
# work is now). Summarising only the tail let the name drift to whatever
# sub-detail the last couple of turns happened to touch. Both are tunable.
RENAME_RECENT_TURNS = 2
RENAME_FIRST_TURNS = 2
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
OLLAMA_MODEL = os.environ.get("CC_TMUX_OLLAMA_MODEL", "qwen2.5:3b")
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
# A "reheat" is a turn whose first API call re-created more context than it read
# from cache (cache_creation > cache_read, with creation past a floor) — i.e.
# the prompt cache was mostly cold and this turn paid to rebuild it. Measured
# empirically: a long-idle session no longer goes fully cold at 1h — a small
# stable prefix (tools+system) can stay warm for hours, so cache_read is rarely
# exactly 0; the create>read test catches the partial reheats that read==0
# missed. We read the ACTUAL token counts from the session transcript (the Stop
# hook payload carries transcript_path) rather than guess.
REHEAT_LOG = os.path.join(TOUCHED_FILES_DIR, "cache-reheats.log")
REHEAT_MIN_TOKENS = int(os.environ.get("CC_REHEAT_MIN_TOKENS", "10000"))
# Diagnostic log of EVERY turn's first-call cache usage (not just flagged
# reheats), with the real idle gap before the turn. Lets you verify whether a
# long-idle session actually goes cold (read==0) or the prompt cache is still
# warm (read>0) — i.e. whether the cache TTL is longer than the assumed 1h.
# Off by default; set CC_REHEAT_DEBUG=1 to re-enable (used to diagnose the
# create>read detection rule — see cache-debug.log).
REHEAT_DEBUG = os.environ.get("CC_REHEAT_DEBUG") == "1"
REHEAT_DEBUG_LOG = os.path.join(TOUCHED_FILES_DIR, "cache-debug.log")
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


def _bump_workflow(pane: str, delta: int) -> None:
    """Adjust the in-flight background-task count on this window.

    Drives the "background work running — wait for it" tab colour. Stored
    as a positive integer while one or more background tasks (Workflow runs,
    background Agents, background Bash commands) are in flight, and unset once
    the count returns to zero. We unset rather than store "0" because tmux
    treats the non-empty string "0" as truthy in #{?...}.
    """
    try:
        n = int(get_option(pane, "@cc-workflow") or "0")
    except ValueError:
        n = 0
    n = max(0, n + delta)
    if n > 0:
        set_option(pane, "@cc-workflow", str(n))
    else:
        unset_option(pane, "@cc-workflow")


def _touch_cache_ts(pane: str, now: int | None = None) -> None:
    """Record 'now' as the last moment this session touched the prompt cache.

    Anthropic's prompt cache refreshes its 5-min TTL on every read, and the
    agentic loop reads it at turn start and after every tool result. So the
    cache stays warm for the WHOLE time Claude is working — the idle expiry
    clock only starts when the turn ends. We therefore bump this on every
    API-call boundary (prompt submit, tool completion, waiting, done) and the
    status-bar countdown anchors on it, not on the prompt-submit time.
    """
    set_option(pane, "@cc-cache-ts", str(now if now is not None else int(time.time())))


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


# Whole-word synonym / abbreviation groups, collapsed so a label never says the
# same idea twice two ways ("context-ctx", "config-cfg"). Within a name the FIRST
# form encountered is kept and any later equivalent is dropped. Matched on whole
# words only — never substrings — so "auth" never swallows "author". Kept short
# and conservative: add a row only when the forms truly mean the same thing in a
# tab label.
_SYNONYM_GROUPS = [
    {"context", "ctx"},
    {"config", "cfg", "configuration"},
    {"repo", "repository"},
    {"auth", "authentication", "authn"},
    {"env", "environment"},
    {"db", "database"},
    {"k8s", "kubernetes"},
    {"docs", "doc", "documentation"},
    {"app", "application"},
    {"deps", "dependencies", "dependency"},
]
# word -> group index, for O(1) concept lookup.
_SYNONYM_CANON = {w: i for i, group in enumerate(_SYNONYM_GROUPS) for w in group}


def _dedupe_words(name: str) -> str:
    """Drop repeated words AND synonym/abbreviation duplicates, keeping order.

    Two passes of redundancy are removed, first occurrence wins:
      - exact repeats — the tiny model echoes a folder word in the task half
        ("mobile-…-mobile") or repeats a topic word ("tdd-…-tdd");
      - same idea said two ways — a word whose synonym/abbreviation was already
        kept ("context" then "ctx"), via _SYNONYM_CANON.
    Safe for these short labels, where a genuine repeated word is rare.
    """
    seen_words: set[str] = set()
    seen_concepts: set[int] = set()
    out = []
    for word in name.split("-"):
        if not word or word in seen_words:
            continue
        concept = _SYNONYM_CANON.get(word)
        if concept is not None:
            if concept in seen_concepts:
                continue  # a synonym/abbrev of this idea is already in the name
            seen_concepts.add(concept)
        seen_words.add(word)
        out.append(word)
    return "-".join(out)


# Articles / prepositions / linking words that carry no signal in a label and
# just eat the character budget. Stripped from the generated name.
_STOPWORDS = {
    "a", "an", "the", "of", "to", "for", "and", "or", "but", "nor",
    "in", "on", "at", "by", "with", "from", "into", "onto", "as",
    "is", "are", "be", "was", "were",
}


def _strip_stopwords(name: str) -> str:
    """Drop stopwords (a, the, of, …) from a kebab name to shorten and de-noise.

    "examples-of-the-real-topic" → "examples-real-topic". Keeps the original if
    every word is a stopword, so a degenerate input isn't blanked here — that's
    _is_degenerate_name's job.
    """
    words = [w for w in name.split("-") if w]
    kept = [w for w in words if w not in _STOPWORDS]
    return "-".join(kept) if kept else "-".join(words)


# Trailing folder words that add no signal — dropped so "mobile-app" leads with
# "mobile" and "auth-service" with "auth". Only stripped when something precedes
# them, so a folder literally named "app" or "api" survives.
GENERIC_FOLDER_SUFFIXES = {
    "app", "application", "service", "svc", "api", "web", "ui",
    "frontend", "backend", "server", "client",
}

# Folder words that carry no project signal ANYWHERE in the name, not just as a
# suffix — skipped when picking the one anchor word ("tenant-provisioning-work-
# tprov" should anchor on "tprov", never "work"). Only ignored while choosing;
# if every word is generic the folder's own words are used as-is.
GENERIC_FOLDER_WORDS = {
    "work", "working", "wip", "dev", "devel", "main", "misc", "new", "old",
}

# Folders whose name carries no project signal — when work happens in one of
# these the location is dropped and the label is task-only (no "tmp-" prefix).
# Compared lowercase. Add throwaway/parent dirs you never want in a tab name.
EXCLUDED_FOLDER_NAMES = {
    "tmp", "temp", "tmpdir", "scratch", "sandbox", "work", "workspace",
    "downloads", "desktop", "documents", "home", "src", "code", "projects",
}


def _folder_words(folder: str) -> list:
    """Folder name as a list of kebab words. [] for an empty folder."""
    folder = re.sub(r"[^a-z0-9-]+", "-", folder.lower()).strip("-")
    folder = re.sub(r"-+", "-", folder)
    return [w for w in folder.split("-") if w]


def _pick_anchor(words: list) -> str:
    """The single most distinctive word of a folder-word list.

    Heuristic: skip GENERIC_FOLDER_WORDS, then take the SHORTEST remaining word
    (ties → first). Short wins because project aliases/abbreviations are short
    ("tprov" in "tenant-provisioning-work-tprov", "java" in "java-upgrade",
    "irx" in "irx-dev") while filler is long ("consolidation", "provisioning").
    Falls back to the full list when every word is generic. "" for [].
    """
    if not words:
        return ""
    kept = [w for w in words if w not in GENERIC_FOLDER_WORDS] or words
    return min(kept, key=len)


def _anchor_word(folder: str) -> str:
    """The ONE word that stands for this folder in a tab label.

    "mobile-app" → "mobile", "java-upgrade" → "java",
    "tenant-provisioning-work-tprov" → "tprov", "irx-dev" → "irx".
    Used both to hint the model and to guarantee a location word is present if
    the model omits it. "" for an empty folder.
    """
    words = _folder_words(folder)
    while len(words) > 1 and words[-1] in GENERIC_FOLDER_SUFFIXES:
        words.pop()
    return _pick_anchor(words)


def _finalize_name(name: str, folder: str) -> str:
    """Guarantee the label leads with ONE location word, then dedupe and trim.

    Two repairs, both enforcing the one-word-location rule:
      - The model echoed the folder ("tenant-provisioning-work-planning"):
        the leading run of folder words is collapsed to the single anchor word
        ("tprov-planning") so a multi-word folder never eats the label.
      - The model produced a task-only label (ignored the folder): the anchor
        word is prefixed so the tab still shows WHERE the work happens.
    A label that already leads with one folder word passes through unchanged.
    """
    if not name:
        return ""
    words = set(_folder_words(folder))
    anchor = _anchor_word(folder)
    if not anchor:
        return name
    parts = name.split("-")
    run = 0
    while run < len(parts) and parts[run] in words:
        run += 1
    if run:
        lead = parts[:run]
        best = anchor if anchor in lead else _pick_anchor(lead)
        parts = [best] + parts[run:]
    else:
        parts = [anchor] + parts
    return _truncate_kebab(_dedupe_words("-".join(parts)))


# Example labels shown to the model for format guidance. Defined once and reused in
# both the summariser prompt and the reject set below so the two cannot drift apart.
# They use the fictional folder "acme" to demonstrate the folder-then-task shape
# without colliding with a real project name (so rejecting an exact echo is safe).
RENAME_EXAMPLE_LABELS = ("acme-fix-auth-bug", "acme-update-readme", "acme-add-dark-mode")

# A tiny local model that fails to summarise regurgitates its own instructions
# ("2-3 lowercase words joined by hyphens" → "2-3-lowercase-words-joined"), echoes
# one of the example labels verbatim ("acme-fix-auth-bug" on an unrelated chat),
# or emits a generic meta-word. Reject all three so a junk name is never applied —
# once applied it sticks, since the refined renames stop after RENAME_UNTIL_TURN.
# The example labels are generic and unlikely to be a real topic, so rejecting an
# exact echo costs nothing; only the full string is blocked, not its words (a
# genuinely auth-related chat still gets a variant like "auth-fix").
# Only entries NOT already caught by a more general rule below belong here —
# anything containing a _REJECT_TOKENS word, a "gpt" word, or the "chat-with-"
# prefix is handled there, so listing it here too would be dead weight.
_REJECT_NAMES = {
    # Instruction-echo phrases with no _REJECT_TOKENS word to catch them.
    "two-or-three-words", "two-three-words", "2-3-words",
    "topic-name", "topic", "label",
    # Medium-not-topic outputs (see _MEDIUM_NAME_RE): two-word "<medium>-<medium>"
    # labels the model emits on a contentless opener, not matched by the regex.
    "ai-assistant", "ai-chat", "chat-assistant", "chat-conversation",
    "ai-conversation", "chat-session", "hello-chat", "chat-start",
} | set(RENAME_EXAMPLE_LABELS)
_REJECT_TOKENS = {
    "lowercase", "kebab", "hyphen", "hyphens", "identifier", "placeholder",
}
# A second failure mode of the tiny model: given a contentless opening prompt
# ("ok", "yes", "hi", "test") it has no topic to extract, so it names the
# *medium* — the conversation itself — e.g. "chat-gpt-4-test",
# "chat-gpt-4-interview", "gpt-3.5-turbo", "chat-with-ai". None of these describe
# the work, so reject them. We key on "gpt" as a word (the tell of a
# self-referential model name) and the "chat-with-<agent>" shape, while leaving
# genuine topics that merely contain "chat"/"ai"/"model" (e.g. "chat-export-bug",
# "model-training") untouched — those words are only rejected in the medium
# shapes above, never on their own.
_MEDIUM_NAME_RE = re.compile(r"(^|-)gpt(\d|-|$)|^chat-with-")


def _is_degenerate_name(name: str) -> bool:
    """True for outputs that echo the instructions or name the medium, not the chat."""
    if not name:
        return True
    if not re.search(r"[a-z]", name):  # digits/hyphens only — not a real topic
        return True
    if name in _REJECT_NAMES:
        return True
    if _MEDIUM_NAME_RE.search(name):  # labels the conversation itself, not the work
        return True
    return bool(_REJECT_TOKENS & set(name.split("-")))


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
    cleaned = _strip_stopwords(cleaned)
    cleaned = _dedupe_words(cleaned)
    cleaned = _truncate_kebab(cleaned)
    return "" if _is_degenerate_name(cleaned) else cleaned


def _llm_summarize(prompt: str, folder: str = "") -> str:
    """Ask the local Ollama model for a folder-led kebab-case label.

    The label leads with ONE word standing for the project location (the folder
    this pane works in, compressed to its most distinctive word) and then the
    specific task — e.g. folder "tenant-provisioning-work-tprov" + a chat about
    planning → "tprov-planning". A single non-streaming HTTP call to a tiny
    model on localhost: no agent, no tool use, no token cost. Returns "" on
    connection failure, timeout, or unparseable output — no rename happens.
    """
    system = (
        "You name a tmux tab for a developer's coding session so they can tell "
        "their tabs apart. You are given the project FOLDER the work happens in "
        "and a few you:/claude: lines of the chat. Reply with ONE short "
        "kebab-case label: one location word first, then the specific task — "
        f"two or three words total, max {TOPIC_MAX_LEN} characters, using only "
        "lowercase letters, digits, and single hyphens. "
        "The location must be exactly ONE word: pick the single most "
        "distinctive word of the folder name, preferring a short project alias "
        "('tprov' from 'tenant-provisioning-work-tprov', 'java' from "
        "'java-upgrade', 'mobile' from 'mobile-app'). NEVER copy a multi-word "
        "folder name whole. After the location word, every word must describe "
        "the task discussed in the chat — never another folder word or its "
        "abbreviation. "
        "Never repeat a word, and never say the same idea twice with a synonym "
        "or abbreviation (not 'context-ctx', not 'config-cfg'). "
        "Name the SPECIFIC task of THIS chat. Do not echo "
        "these instructions or the example labels. Output ONLY the label on a "
        "single line — no quotes, preamble, or explanation. Example labels (do "
        f"not reuse): {', '.join(RENAME_EXAMPLE_LABELS)}."
    )
    user = f"Project folder: {folder}\n\n{prompt}" if folder else prompt
    body = json.dumps(
        {
            "model": OLLAMA_MODEL,
            "system": system,
            "prompt": user,
            "stream": False,
            "keep_alive": OLLAMA_KEEP_ALIVE,
            # num_ctx pins the namer's window independent of Ollama's global
            # setting: ~200 tok system + up to ~600 tok dialogue + 32 tok out
            # fits well inside 4096, so the tab-rename stays lean no matter how
            # large the global context is set for other Ollama uses.
            "options": {
                "temperature": 0.2,
                "num_predict": 32,
                "num_ctx": 4096,
                "stop": ["\n"],
            },
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
    return _finalize_name(_clean_llm_output(data.get("response", "")), folder)


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
                prompt[:RENAME_DIALOGUE_MAX],
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
            close_fds=True,
        )
    except OSError as e:
        log(f"llm rename spawn failed: {e}")


def _pane_folder(pane: str) -> str:
    """The project folder this pane works in — git repo root name, else cwd base.

    Read from the pane's current path via tmux (the dir Claude was launched in).
    Prefer the git top-level basename so the name stays stable from any subdir;
    fall back to the directory's own basename when it isn't a repo. "" when the
    path can't be read.
    """
    path = tmux(
        "display-message", "-p", "-t", pane, "#{pane_current_path}", capture=True
    )
    if not path:
        return ""
    try:
        result = subprocess.run(
            ["git", "-C", path, "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            timeout=SUBPROC_TIMEOUT,
        )
        if result.returncode == 0 and result.stdout.strip():
            path = result.stdout.strip()
    except (subprocess.TimeoutExpired, OSError):
        pass  # git missing / slow / not a repo — keep the pane path
    if path.rstrip("/") == os.path.expanduser("~").rstrip("/"):
        return ""  # running in $HOME — the basename is just your username
    base = os.path.basename(path.rstrip("/"))
    if base.lower() in EXCLUDED_FOLDER_NAMES:
        return ""  # no project signal (e.g. tmp) — name the task only
    return base


def action_llm_rename(pane: str, prompt: str) -> None:
    """Background worker entrypoint: ask the local model for a name and apply it."""
    name = _llm_summarize(prompt, _pane_folder(pane))
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


def maybe_auto_rename(pane: str, payload: dict, count: int) -> None:
    """Instant initial name on the 1st prompt, from that prompt alone.

    Fires the moment the first prompt is submitted — before Claude replies — so
    the window is labelled immediately. The refined, answer-aware renames happen
    later, on the Stop hook (see maybe_rename_on_answer). No regex slug: if
    Ollama is unreachable the window just keeps its current name.
    """
    if count != 1:
        return
    prompt = payload.get("prompt", "") or ""
    if not prompt or not safe_to_auto_rename(pane):
        return
    # A contentless opener ("ok", "yes", "hi", "test") gives the tiny model
    # nothing to summarise, so it labels the medium instead ("chat-gpt-4-test").
    # Skip the instant rename for such openers and let the answer-aware refine on
    # the turn-1 Stop name the window from the actual exchange (which by then has
    # Claude's reply in the transcript). The _MEDIUM_NAME_RE guard still backstops
    # any longer prompt that slips through.
    if len(prompt.split()) < 3:
        return
    _spawn_llm_rename(pane, prompt)


def maybe_rename_on_answer(pane: str, rows: list, transcript: str) -> None:
    """Refined rename when an answer completes (Stop hook), turns 1..N.

    Summarises the session's opening prompts plus the most recent turns and
    Claude's prose replies (see _rename_context; `rows` is the already-parsed
    transcript tail holding the just-finished answer, `transcript` its path for
    the head read) so the name reflects the goal, not just the latest sub-detail.
    Runs only for the first RENAME_UNTIL_TURN answers, then leaves the name alone.
    Does nothing if there's no dialogue or the window isn't ours to rename.
    """
    if RENAME_UNTIL_TURN <= 0:
        return
    try:
        count = int(get_option(pane, "@cc-prompt-count") or "0")
    except ValueError:
        return
    if not 1 <= count <= RENAME_UNTIL_TURN:
        return
    ctx = _rename_context(rows, transcript, RENAME_RECENT_TURNS, RENAME_FIRST_TURNS)
    if not ctx or not safe_to_auto_rename(pane):
        return
    _spawn_llm_rename(pane, ctx)


def action_rename(pane: str, _payload: dict) -> None:
    """Manual rename, bound to prefix+r — re-name the window from the chat now.

    Replaces the old "rename the window to RENAME" sentinel flow with an explicit
    hotkey. Summarises the recent dialogue (your last couple of prompts plus
    Claude's prose replies) from the transcript recorded on the pane
    (@cc-transcript) and applies a fresh name. The keypress is explicit consent,
    so it overwrites the current name regardless of what it is. No-op if no
    transcript has been recorded yet or Ollama is unreachable.
    """
    transcript = get_option(pane, "@cc-transcript")
    rows, _ = _read_transcript_tail(transcript)
    ctx = _rename_context(rows, transcript, RENAME_RECENT_TURNS, RENAME_FIRST_TURNS)
    if not ctx:
        return
    # Explicit consent to overwrite: mark the current name as ours so the async
    # worker's safe-to-rename check passes and applies the model's name.
    set_option(pane, "@cc-auto-name", get_window_name(pane))
    _spawn_llm_rename(pane, ctx)


def _is_system_notification(prompt: str) -> bool:
    """True when a UserPromptSubmit payload is a harness notification, not a user.

    A background Bash/Agent task completing re-invokes Claude with a synthetic
    prompt wrapped in <task-notification> (observed empirically; Workflow
    completions fire no prompt-submit at all). Such a turn must NOT count as
    user-initiated: @cc-turn-had-prompt stays unset so its Stop retires one
    background task from the background-work marker (see action_done), and it must not
    advance the prompt counter or trigger a rename.
    """
    return prompt.lstrip().startswith("<task-notification>")


def action_prompt_submit(pane: str, payload: dict) -> None:
    sid = payload.get("session_id", "")
    if sid:
        set_option(pane, "@cc-session-id", sid)
    # Record how long the cache sat idle before THIS turn (now minus the last
    # cache touch from the previous turn) for the per-turn debug log. Must read
    # @cc-cache-ts BEFORE _touch_cache_ts below overwrites it.
    now = int(time.time())
    prev_ts = get_option(pane, "@cc-cache-ts")
    if prev_ts.isdigit():
        set_option(pane, "@cc-prev-idle", str(now - int(prev_ts)))
    set_option(pane, "@cc-last-prompt-ts", str(now))
    _touch_cache_ts(pane, now)
    # A new turn starts warm; clear the previous turn's reheat marker.
    unset_option(pane, "@cc-reheat")
    # Force-set "working" (bypasses severity merge — a new turn always overrides).
    set_option(pane, "@cc-status", "working")
    unset_option(pane, "@cc-waiting-tool")  # any pending question died with the old turn
    # A harness notification (background task completing) is a system
    # re-invocation, not a user turn: leave @cc-turn-had-prompt unset so this
    # turn's Stop retires one background task from the background-work marker, and don't
    # let it advance the prompt counter or trigger a rename.
    if _is_system_notification(payload.get("prompt", "") or ""):
        return
    # Mark this turn as user-initiated. The Stop hook reads it to tell a real
    # prompt turn apart from a system re-invocation (a background Workflow
    # reporting back fires no prompt-submit at all; a background Bash/Agent
    # completion fires one, filtered above) — see action_done's bookkeeping.
    set_option(pane, "@cc-turn-had-prompt", "1")

    # Per-window prompt counter — drives the instant 1st-prompt rename here and
    # the answer-aware renames on the Stop hook.
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
    unset_option(pane, "@cc-workflow")
    unset_option(pane, "@cc-turn-had-prompt")
    # Reset the per-session prompt counter; keep @cc-auto-name so a new session
    # in the same window can update *our* prior auto-name but never clobber a
    # manual one.
    unset_option(pane, "@cc-prompt-count")
    unset_option(pane, "@cc-waiting-tool")
    # Drop the previous session's transcript pointer (prefix+r reads it) so a
    # manual rename can't summarise a stale conversation.
    unset_option(pane, "@cc-transcript")


def action_session_end(pane: str, _payload: dict) -> None:
    unset_option(pane, "@cc-status")
    unset_option(pane, "@cc-workflow")
    unset_option(pane, "@cc-turn-had-prompt")
    unset_option(pane, "@cc-waiting-tool")
    # Clear the cache markers too — without this the countdown timer
    # (@cc-cache-ts) keeps running and the reheat/cold-cache marker
    # (@cc-reheat) stays visible after Claude has closed, even though the
    # colour (@cc-status) already reset to grey.
    unset_option(pane, "@cc-cache-ts")
    unset_option(pane, "@cc-reheat")
    # The session is gone; its transcript pointer (read by prefix+r) is stale.
    unset_option(pane, "@cc-transcript")


def action_reset(pane: str, _payload: dict) -> None:
    """Manual clear (tmux prefix+u): drop every attention marker on this window.

    The only reliable recovery for states no hook can clear — chiefly an ESC
    interrupt (no Stop fires, so "working" would otherwise stay latched) and a
    background-workflow marker left stuck because its completion never produced
    a no-prompt Stop (killed run, batched concurrent completions).
    """
    unset_option(pane, "@cc-status")
    unset_option(pane, "@cc-workflow")
    unset_option(pane, "@cc-turn-had-prompt")
    unset_option(pane, "@cc-waiting-tool")
    # Full clear: also drop the cache markers, so a manual reset recovers a
    # window left with a stale countdown timer (@cc-cache-ts) or cold-cache
    # marker (@cc-reheat) — e.g. after a hard kill that fired no SessionEnd.
    unset_option(pane, "@cc-cache-ts")
    unset_option(pane, "@cc-reheat")


def action_set_state(pane: str, new_state: str) -> None:
    current = get_option(pane, "@cc-status")
    if severity_merge(current, new_state):
        set_option(pane, "@cc-status", new_state)


def _append_line(path: str, line: str, what: str) -> None:
    """Append `line` to a log file under TOUCHED_FILES_DIR, best-effort.

    Ensures the directory exists and swallows OSError (logging it under the
    `what` label). Shared by the touched-files and reheat logs.
    """
    try:
        os.makedirs(TOUCHED_FILES_DIR, exist_ok=True)
        with open(path, "a", encoding="utf-8") as fh:
            fh.write(line)
    except OSError as e:
        log(f"{what}: {type(e).__name__}: {e}")


def _resolve_session_id(pane: str, payload: dict, default: str = "") -> str:
    """Session id from the hook payload, else the stored @cc-session-id option."""
    return payload.get("session_id") or get_option(pane, "@cc-session-id") or default


def _append_touched_file(session_id: str, file_path: str) -> None:
    """Append a Claude-edited file path to the per-session touched-files log."""
    path = os.path.join(TOUCHED_FILES_DIR, f"session-{session_id}-touched.txt")
    _append_line(path, file_path + "\n", "touched-log")


# Tools that run in the background only when asked to via run_in_background.
# Workflow is background always and is special-cased in _is_background_launch.
BACKGROUND_CAPABLE_TOOLS = {"Agent", "Bash"}


def _is_background_launch(payload: dict) -> bool:
    """True when this PostToolUse is a background-task LAUNCH, not a completion.

    Covers every tool whose completion later re-invokes Claude with a no-prompt
    Stop (the retirement signal in action_done): Workflow (always background)
    and Agent / Bash called with run_in_background=true. Blocking calls of the
    same tools keep the turn open — the tab stays blue on @cc-status alone — so
    they are not counted.
    """
    tool = payload.get("tool_name", "")
    if tool == "Workflow":
        return True
    if tool in BACKGROUND_CAPABLE_TOOLS:
        return bool((payload.get("tool_input") or {}).get("run_in_background"))
    return False


def action_waiting(pane: str, payload: dict) -> None:
    # The model just made an API call that needs you (permission / idle prompt),
    # so the cache was read moments ago — anchor the idle clock here too.
    _touch_cache_ts(pane)
    # Remember WHICH tool is waiting on you. PermissionRequest carries the
    # tool_name (no tool_use_id, so the name is the best key available);
    # tool-completed reverts waiting→working only when a tool with THIS name
    # finishes. Without the key, a session running parallel agents cleared a
    # pending AskUserQuestion within seconds: every subagent Bash/Read
    # completion tripped the old "any tool finished → waiting resolved" rule
    # while the question was still on screen. An idle/elicitation Notification
    # has no tool — the key is unset and any completion reverts, as before.
    tool_name = payload.get("tool_name") or ""
    if tool_name:
        set_option(pane, "@cc-waiting-tool", tool_name)
    else:
        unset_option(pane, "@cc-waiting-tool")
    action_set_state(pane, "waiting")


def action_tool_completed(pane: str, payload: dict) -> None:
    # A tool finished; the next API call (which re-reads the cache) is imminent.
    _touch_cache_ts(pane)

    # Background launches return immediately, so this PostToolUse fires at
    # LAUNCH, not at completion: the Workflow tool is always background, and
    # Agent / Bash are when called with run_in_background. Mark the task in
    # flight → the tab takes the background-work colour so the turn's grey "done" look still says
    # "Claude is waiting on ITS OWN work, not on you". It's retired later in
    # action_done, when the completion re-invocation ends with a no-prompt Stop.
    if _is_background_launch(payload):
        _bump_workflow(pane, +1)
    # When the tool that asked for permission finishes, the `waiting` state is
    # resolved — revert to working. Force-set because severity would block the
    # waiting→working transition. Matched by tool NAME (@cc-waiting-tool, set
    # in action_waiting): completions of OTHER tools — parallel agents'
    # Bash/Read flurries — must not clear a question still on screen. When no
    # name was recorded (idle Notification), any completion reverts, as before.
    if get_option(pane, "@cc-status") == "waiting":
        waiting_tool = get_option(pane, "@cc-waiting-tool")
        if not waiting_tool or waiting_tool == payload.get("tool_name"):
            set_option(pane, "@cc-status", "working")
            unset_option(pane, "@cc-waiting-tool")

    # Log file edits so :ClaudeChanged / prefix+E can find them later, even
    # after they're committed (git status alone misses post-commit files).
    tool_name = payload.get("tool_name", "")
    if tool_name not in FILE_TOUCHING_TOOLS:
        return
    tool_input = payload.get("tool_input") or {}
    file_path = tool_input.get("file_path") or tool_input.get("notebook_path")
    if not file_path:
        return
    session_id = _resolve_session_id(pane, payload)
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


def _text_blocks(content) -> str:
    """Concatenate the `text` of a message's content — `text` blocks only.

    Accepts the str or list form of a transcript message's content. Non-text
    blocks (tool_use, tool_result, thinking, images) are dropped, so tool calls
    and file reads never leak into the topic context.
    """
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, list):
        parts = [
            b.get("text", "")
            for b in content
            if isinstance(b, dict) and b.get("type") == "text"
        ]
        return "\n".join(p for p in parts if p).strip()
    return ""


def _is_main_assistant(row: dict) -> bool:
    """True for a main-chain assistant row (an assistant turn, not a sidechain)."""
    return row.get("type") == "assistant" and not row.get("isSidechain")


def _assistant_text(row: dict) -> str:
    """Claude's prose from an assistant transcript row (sidechains excluded)."""
    if not _is_main_assistant(row):
        return ""
    return _text_blocks((row.get("message") or {}).get("content"))


def _user_prompt_text(row: dict) -> str:
    """The user's text from a genuine prompt row (not a tool_result continuation)."""
    if not _is_user_prompt(row):
        return ""
    return _text_blocks((row.get("message") or {}).get("content"))


def _cut_head(text: str, limit: int) -> str:
    """Trim `text` to `limit` chars from the start, on a line/word boundary.

    Avoids feeding the model a fragment cut mid-word (which it then parrots).
    """
    if len(text) <= limit:
        return text
    cut = text[:limit]
    nl = cut.rfind("\n")
    if nl > 0:
        return cut[:nl]
    sp = cut.rfind(" ")
    return cut[:sp] if sp > 0 else cut


def _cut_tail(text: str, limit: int) -> str:
    """Keep the last `limit` chars of `text`, starting on a line/word boundary.

    A raw `text[-limit:]` can begin mid-word ("…mpl|es of the topic"); we drop
    that partial leading token so the model sees clean dialogue.
    """
    if len(text) <= limit:
        return text
    cut = text[-limit:]
    nl = cut.find("\n")
    if nl != -1:
        return cut[nl + 1:]
    sp = cut.find(" ")
    return cut[sp + 1:] if sp != -1 else cut


def _recent_dialogue(
    rows: list,
    recent_turns: int,
    max_chars: int = RENAME_DIALOGUE_MAX,
) -> str:
    """Recent you/Claude dialogue from already-parsed transcript rows.

    Keeps the last `recent_turns` user prompts and every assistant prose reply
    after the earliest kept prompt, in order, as alternating `you:` / `claude:`
    lines. Assistant tool calls / file reads / thinking are excluded (see
    _assistant_text). Returns the most recent `max_chars` characters, or "" when
    `rows` is empty — callers then fall back to user-only context.
    """
    if not rows:
        return ""
    user_idxs = [i for i, r in enumerate(rows) if _is_user_prompt(r)]
    if not user_idxs:
        return ""
    start = (
        user_idxs[-recent_turns]
        if len(user_idxs) >= recent_turns
        else user_idxs[0]
    )
    lines = []
    for row in rows[start:]:
        is_user = _is_user_prompt(row)
        text = _user_prompt_text(row) if is_user else _assistant_text(row)
        if text:
            lines.append(f"{'you' if is_user else 'claude'}: {text}")
    return _cut_tail("\n".join(lines), max_chars)


def _first_prompts(path: str, count: int) -> list:
    """The first `count` user-prompt texts, read from the HEAD of the transcript.

    Reads line by line from the start and stops as soon as `count` prompts are
    found, so it stays cheap even on a huge transcript. Unlike the tail read used
    elsewhere, this reaches the session's OPENING prompts — which state the goal —
    even in a long session whose start is past the tail window. [] on any failure.
    """
    if not path or count <= 0:
        return []
    out = []
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    row = json.loads(line)
                except ValueError:
                    continue
                if _is_user_prompt(row):
                    text = _user_prompt_text(row)
                    if text:
                        out.append(text)
                        if len(out) >= count:
                            break
    except OSError:
        return []
    return out


def _rename_context(
    rows: list,
    path: str,
    recent_turns: int,
    first_turns: int,
    max_chars: int = RENAME_DIALOGUE_MAX,
) -> str:
    """Dialogue for the namer: the opening prompts PLUS the most recent turns.

    The first prompts state the actual goal; the recent turns (with Claude's
    prose, via _recent_dialogue) show where the work is now. Anchoring on both
    ends keeps the name on-topic instead of drifting to whatever the last turn
    touched. The opening is read from the transcript head (_first_prompts) so it
    survives long sessions whose start is past the tail window. When the opening
    is already inside the recent window (short session) only the recent dialogue
    is returned, so nothing is duplicated.
    """
    recent = _recent_dialogue(rows, recent_turns, max_chars)
    heads = _first_prompts(path, first_turns)
    if not heads:
        return recent
    if heads[0] and heads[0] in recent:
        return recent  # short session — the opening is already in the recent tail
    head = _cut_head("\n".join(f"you: {t}" for t in heads), max_chars // 2)
    tail = _cut_tail(recent, max_chars - len(head) - 4) if recent else ""
    return f"{head}\n…\n{tail}" if tail else head


def _analyze_reheat(rows: list, truncated: bool) -> tuple:
    """Inspect the last turn's first API call, from already-parsed transcript rows.

    Return (is_reheat, tokens_spent, read, create, inp) — the raw cache_read /
    cache_creation / input token counts of that first call are surfaced for the
    per-turn debug log.

    A reheat = the prompt cache went cold over an idle gap and this turn's first
    assistant call paid to rebuild it. Signature: the warm context SHRANK — this
    call's cache_read dropped well below what the PREVIOUS turn had cached
    (prev_cached = that turn's last read+create) — AND at least REHEAT_MIN_TOKENS
    were re-created. The bulk of the ~1h cache expires while a small stable prefix
    (tools + system, on its own longer-lived cache) stays warm for hours, so a
    partial reheat collapses read toward that prefix (e.g. 62k→16k) rather than to
    0. Testing the DROP (read < prev_cached) — not create > read — is what tells an
    idle reheat apart from a big mid-conversation content paste (a large skill or
    file load): a paste leaves read at or above prev_cached and merely ADDS on top,
    so its create can exceed read without any cache having expired. The old
    create > read test false-flagged those whenever the pasted block was larger
    than the already-cached context. tokens_spent is the full non-cached input that
    turn paid for: fresh input + re-cached context.

    The first turn of a brand-new session is ALSO a big cold create (there is no
    cache yet), but that is an unavoidable cold start, not an idle-expiry reheat
    — so it is not flagged. We detect it as: no prior main-chain assistant call
    before this turn, in a transcript read in full (small file). A --resume after
    a long gap still flags (it has prior history); long sessions are unaffected
    (their previous turn sits in the tail).
    """
    if not rows:
        return False, 0, 0, 0, 0
    start = None
    for i in range(len(rows) - 1, -1, -1):
        if _is_user_prompt(rows[i]):
            start = i
            break
    if start is None:
        return False, 0, 0, 0, 0
    # Cached-context size at the end of the PREVIOUS turn: read+create of the last
    # main-chain assistant call before this turn's prompt. A genuine reheat collapses
    # this (the body cache expired); a mid-conversation content paste or a big skill /
    # file load leaves it intact and simply adds on top.
    prev_cached = 0
    prior_call = False
    for r in rows[:start]:
        if not _is_main_assistant(r):
            continue
        usage = (r.get("message") or {}).get("usage") or {}
        if not usage:
            continue
        prior_call = True
        prev_cached = (usage.get("cache_read_input_tokens") or 0) + (
            usage.get("cache_creation_input_tokens") or 0
        )
    first_turn_of_session = not prior_call and not truncated
    for row in rows[start + 1:]:
        if not _is_main_assistant(row):
            continue
        usage = (row.get("message") or {}).get("usage") or {}
        if not usage:
            continue
        read = usage.get("cache_read_input_tokens") or 0
        create = usage.get("cache_creation_input_tokens") or 0
        inp = usage.get("input_tokens") or 0
        is_reheat = (
            create >= REHEAT_MIN_TOKENS
            and read < prev_cached - REHEAT_MIN_TOKENS
            and not first_turn_of_session
        )
        return is_reheat, create + inp, read, create, inp
    return False, 0, 0, 0, 0


def _log_reheat(pane: str, payload: dict, tokens: int) -> None:
    """Append one reheat record to REHEAT_LOG for later review."""
    ts = datetime.now().isoformat(timespec="seconds")
    win = get_window_name(pane) or "?"
    sid = _resolve_session_id(pane, payload, "?")
    _append_line(
        REHEAT_LOG,
        f"{ts}  reheat  tokens={tokens}  win={win}  pane={pane}  session={sid}\n",
        "reheat-log",
    )


def _log_reheat_debug(
    pane: str, payload: dict, read: int, create: int, inp: int,
    tokens: int, is_reheat: bool,
) -> None:
    """Append one per-turn cache-usage record to REHEAT_DEBUG_LOG.

    Records EVERY turn's first-call usage, not just flagged reheats, so you can
    confirm whether an idle session actually went cold. A line with a long
    idle=<N>s but read>0 means the prompt cache was still warm — the TTL is
    longer than the assumed 1h, which is why no reheat fires.
    """
    if not REHEAT_DEBUG:
        return
    ts = datetime.now().isoformat(timespec="seconds")
    idle = get_option(pane, "@cc-prev-idle") or "?"
    win = get_window_name(pane) or "?"
    sid = _resolve_session_id(pane, payload, "?")
    _append_line(
        REHEAT_DEBUG_LOG,
        f"{ts}  idle={idle}s  read={read}  create={create}  "
        f"input={inp}  tokens={tokens}  "
        f"reheat={'yes' if is_reheat else 'no'}  "
        f"win={win}  session={sid}\n",
        "reheat-debug",
    )


def action_done(pane: str, payload: dict) -> None:
    stored_session = get_option(pane, "@cc-session-id")
    hook_session = payload.get("session_id", "")
    if stored_session and hook_session and stored_session != hook_session:
        return  # stale hook from prior session
    if not get_option(pane, "@cc-last-prompt-ts"):
        return  # no prompt seen in this session yet, defensive
    # A turn that set no @cc-turn-had-prompt is a system re-invocation, not a
    # user turn — a background task (Workflow, background Agent or Bash)
    # finishing and reporting back. Empirically a Workflow completion fires no
    # prompt-submit at all, while a background Bash/Agent completion fires one
    # with a <task-notification> payload — which action_prompt_submit filters
    # out, leaving had_prompt unset either way. Treat that Stop as one
    # background task retiring from the background-work marker. User turns (had_prompt
    # set) leave the count alone, so the marker survives the launching turn and
    # any prompts sent while the run is still in flight.
    had_prompt = get_option(pane, "@cc-turn-had-prompt")
    unset_option(pane, "@cc-turn-had-prompt")
    if not had_prompt:
        _bump_workflow(pane, -1)
    action_set_state(pane, "done")
    # Turn just ended → the cache was last read now; the idle clock starts here.
    _touch_cache_ts(pane)
    # Parse the transcript tail ONCE and share it: the answer-aware rename and the
    # reheat analysis both read the same just-finished turn at the end of the file.
    # (Reading it separately doubled the disk read + JSON parse on every Stop.)
    transcript = payload.get("transcript_path", "") or ""
    rows, truncated = _read_transcript_tail(transcript)
    # The answer is now in the transcript — refine the window name from the
    # opening goal plus this exchange (early turns only; see maybe_rename_on_answer).
    maybe_rename_on_answer(pane, rows, transcript)
    # Did this turn reheat a cold prompt cache? Read the real token cost from the
    # transcript and flag it (status marker + log) so an expensive cache-miss
    # turn is visible after the fact.
    is_reheat, tokens, read, create, inp = _analyze_reheat(rows, truncated)
    _log_reheat_debug(pane, payload, read, create, inp, tokens, is_reheat)
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
    "reset": action_reset,
    "rename": action_rename,
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
    # Stash the transcript path on the pane on every hook that carries one, so the
    # manual rename hotkey (prefix+r → "rename", which has no stdin payload) can
    # find the current session's transcript to summarise.
    transcript = payload.get("transcript_path")
    if transcript:
        set_option(pane, "@cc-transcript", transcript)
    log(
        f"action={action} pane={pane} "
        f"tool={payload.get('tool_name')} "
        f"event={payload.get('hook_event_name')} "
        f"payload_keys={list(payload.keys())}"
    )
    try:
        ACTIONS[action](pane, payload)
    except Exception as e:
        log(f"unhandled: {type(e).__name__}: {e}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
