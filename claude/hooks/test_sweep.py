"""Tests for the Stop-time background-marker sweep in tmux-claude-hooks.py.

Run: python3 test_sweep.py     (exit 0 = all pass)
"""

import glob, importlib.util, json, os, shutil, sys, tempfile, time

# Resolve relative to THIS file, not a hardcoded ~/dotfiles path: the repo owner
# runs feature work out of .worktrees/, and a hardcoded path would silently load
# and test the main checkout's script while reporting green for code that never
# ran in the worktree.
spec = importlib.util.spec_from_file_location(
    "h", os.path.join(os.path.dirname(os.path.abspath(__file__)), "tmux-claude-hooks.py")
)
h = importlib.util.module_from_spec(spec)
spec.loader.exec_module(h)

# Never talk to tmux: back the option API with a dict.
opts = {}
h.set_option = lambda pane, name, value: opts.__setitem__((pane, name), str(value))
h.unset_option = lambda pane, name: opts.pop((pane, name), None)
h.get_option = lambda pane, name: opts.get((pane, name), "")
LOGS = []
h.log = LOGS.append

PANE = "%403"
TMP = tempfile.mkdtemp(prefix="sweep-test-")
SCRATCH = os.path.dirname(os.path.abspath(__file__))
# Real dir shape matched by BG_TASK_OUTPUT_GLOB (/private/tmp/claude-*/*/*/tasks/).
FAKE_TASKS = "/private/tmp/claude-501/sweep-test-proj/sweep-test-sess/tasks"

fails = []


def check(name, cond, detail=""):
    print(f"{'ok  ' if cond else 'FAIL'} {name}{'' if cond else '  -> ' + detail}")
    if not cond:
        fails.append(name)


def arm(markers, ages):
    """markers: {key: (kind, alt, tuid)}; ages: {key: seconds ago for mtime}."""
    h.BG_STATE_DIR = TMP
    d = os.path.join(TMP, h._bg_key(PANE))
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d, exist_ok=True)
    now = time.time()
    for key, (kind, alt, tuid) in markers.items():
        p = os.path.join(d, key)
        with open(p, "w") as fh:
            fh.write(f"{kind}\t{alt}\t{tuid}\n")
        mtime = now - ages[key]
        os.utime(p, (mtime, mtime))
    opts.clear()
    return d


def remaining(d):
    return sorted(os.listdir(d)) if os.path.isdir(d) else []


def iso(epoch):
    from datetime import datetime, timezone

    return datetime.fromtimestamp(epoch, timezone.utc).isoformat().replace("+00:00", "Z")


def notif_row(epoch, tid, tuid, status="completed", extra=""):
    return {
        "type": "queue-operation",
        "operation": "enqueue",
        "timestamp": iso(epoch),
        "content": (
            f"<task-notification>\n<task-id>{tid}</task-id>\n"
            f"<tool-use-id>{tuid}</tool-use-id>\n<status>{status}</status>\n"
            f"</task-notification>{extra}"
        ),
    }


def task_output_row(epoch, tid, status, body=None, as_parts=False):
    text = (
        f"<retrieval_status>success</retrieval_status>\n\n<task_id>{tid}</task_id>\n\n"
        f"<task_type>local_bash</task_type>\n\n<status>{status}</status>\n\n"
    )
    if body is not None:
        text += f"<output>\n{body}\n</output>"
    content = [{"type": "text", "text": text}] if as_parts else text
    return {
        "type": "user",
        "timestamp": iso(epoch),
        "message": {
            "role": "user",
            "content": [
                {"type": "tool_result", "tool_use_id": "toolu_POLL", "content": content}
            ],
        },
    }


NOW = time.time()

# ---------------------------------------------------------------- real transcript
# The recorded failure: two backgrounded Bash tasks finished mid-turn and their
# notifications were dequeued instead of delivered.
h.BG_STALE_OVERRIDE = "999999"  # isolate from the 900s deadline (transcript is old)
# Located by session id alone, NOT by its full path: the project directory name
# under ~/.claude/projects/ encodes the working directory it belongs to, and this
# repo is public. The session id is an opaque local identifier and discloses
# nothing on its own.
FIXTURE_SESSION = "ddccae2c-ad54-49b1-95d5-f000dee0ab10"
_found = glob.glob(
    os.path.expanduser(f"~/.claude/projects/*/{FIXTURE_SESSION}.jsonl")
)
# A live file under ~/.claude/projects/, not test-owned, and prunable. If it
# vanishes, _read_transcript_tail silently returns [] and the three checks below
# fail as n=0 — which reads as a code regression unless we call out here that the
# FIXTURE is missing, not the code under test.
assert _found, f"FIXTURE missing (not a code regression): session {FIXTURE_SESSION}"
TRANSCRIPT = _found[0]
rows, truncated = h._read_transcript_tail(TRANSCRIPT)
REAL = {
    "bugkernjy": ("Bash", "bugkernjy", "toolu_01VPbeA5V3VPpp4MMBBN7qN2"),
    "bz23tejwu": ("Bash", "bz23tejwu", "toolu_01Rmi1gYdeaQNRmKZMq6TAns"),
}
LAUNCH_AGES = {"bugkernjy": NOW - 1785360947.0, "bz23tejwu": NOW - 1785360975.4}

d = arm(REAL, LAUNCH_AGES)
n = h._bg_retire_from_transcript(PANE, rows)
check(
    "real transcript: both dequeued completions retired",
    n == 2 and remaining(d) == [],
    f"n={n} remaining={remaining(d)}",
)
check(
    "real transcript: @cc-workflow unset once empty",
    (PANE, "@cc-workflow") not in opts,
    str(opts),
)

# Isolating the tool_result path: strip every harness-written notification row and
# the TaskOutput reply alone must still retire bz23tejwu (row 354 reports completed).
only_results = [r for r in rows if not h._notification_blob(r)]
d = arm({"bz23tejwu": REAL["bz23tejwu"]}, {"bz23tejwu": LAUNCH_AGES["bz23tejwu"]})
n = h._bg_retire_from_transcript(PANE, only_results)
check(
    "real transcript: TaskOutput reply alone is enough",
    n == 1 and remaining(d) == [],
    f"n={n} remaining={remaining(d)}",
)

# ------------------------------------------------------------------- false evidence
# BLOCKER regression: a TaskOutput poll that reports `running` while its partial
# <output> body happens to contain a <status> tag of its own.
d = arm({"live": ("Bash", "live", "toolu_LIVE")}, {"live": 120})
n = h._bg_retire_from_transcript(
    PANE,
    [
        task_output_row(
            NOW - 10,
            "live",
            "running",
            body="scan report\n<status>completed</status>\n<status>ACTIVE</status>",
        )
    ],
)
check(
    "running task with <status> in its output body survives",
    n == 0 and remaining(d) == ["live"],
    f"n={n} remaining={remaining(d)}",
)

# Same shape, but the body's status is the ONLY one (header says running).
d = arm({"live": ("Bash", "live", "toolu_LIVE")}, {"live": 120})
h._bg_retire_from_transcript(
    PANE, [task_output_row(NOW - 10, "live", "running", body="<status>done</status>")]
)
check("output body cannot outvote the header", remaining(d) == ["live"], remaining(d))

# MAJOR regression: a Read/Bash result that merely quotes an old notification.
quoted = (
    "  log: bg add Agent key=a487d372\n"
    "<task-notification>\n<task-id>a487d372</task-id>\n"
    "<tool-use-id>toolu_OLD</tool-use-id>\n<status>completed</status>\n"
    "</task-notification>\n"
)
for label, content in (
    ("string", quoted),
    ("parts", [{"type": "text", "text": quoted}]),
):
    d = arm({"a487d372": ("Agent", "a487d372", "toolu_NEW")}, {"a487d372": 120})
    n = h._bg_retire_from_transcript(
        PANE,
        [
            {
                "type": "user",
                "timestamp": iso(NOW - 5),
                "message": {
                    "role": "user",
                    "content": [
                        {
                            "type": "tool_result",
                            "tool_use_id": "toolu_READ",
                            "content": content,
                        }
                    ],
                },
            }
        ],
    )
    check(
        f"quoted notification in a tool_result ({label}) retires nothing",
        n == 0 and remaining(d) == ["a487d372"],
        f"n={n} remaining={remaining(d)}",
    )

# MAJOR regression (Fix 1): a user-typed queued prompt is ALSO recorded as an
# `enqueue` queue-operation, dated when it was TYPED — not the harness's
# ended-just-now dating. If it happens to quote notification text (e.g. pasting
# a block out of the debug log while working on this very hook) it must not be
# mistaken for the real thing. The marker's mtime is placed OLDER than the row's
# timestamp so this check would pass for the wrong reason (the timestamp guard)
# if the prefix test were absent; only the prefix test can save it here.
d = arm({"a487d372": ("Agent", "a487d372", "toolu_OLD")}, {"a487d372": 120})
user_typed = dict(
    notif_row(NOW - 5, "a487d372", "toolu_OLD"),
)
user_typed["content"] = (
    "wait, here's what I'm seeing in the log:\n" + user_typed["content"]
)
n = h._bg_retire_from_transcript(PANE, [user_typed])
check(
    "user-typed enqueue quoting notification text is not evidence",
    n == 0 and remaining(d) == ["a487d372"],
    f"n={n} remaining={remaining(d)}",
)

# Harness-authored enqueue still qualifies (the tag leads), and a trailing
# <result> body that quotes ANOTHER live marker's id (as plain prose, not a
# well-formed <task-id> tag) must not retire it — ids and status always precede
# any <result> body in harness-authored content, so only the block's own task
# is affected; the mention never matches NOTIFICATION_ID_RE at all.
d = arm(
    {
        "own-task": ("Bash", "own-task", "toolu_OWN"),
        "quoted-task": ("Bash", "quoted-task", "toolu_QUOTED"),
    },
    {"own-task": 120, "quoted-task": 120},
)
row = notif_row(
    NOW - 5,
    "own-task",
    "toolu_OWN",
    extra="<result>done, ran in parallel with quoted-task</result>",
)
n = h._bg_retire_from_transcript(PANE, [row])
check(
    "harness enqueue with a <result> body mentioning another id retires only its own task",
    n == 1 and remaining(d) == ["quoted-task"],
    f"n={n} remaining={remaining(d)}",
)

# A delivered notification as a plain `type:"user"` row with STRING content is
# present in every real transcript and is late-dated (the moment it was HANDED
# to the model, not when the task finished). Only the `isinstance(content,
# list)` test in _task_output_headers excludes it today, and nothing else pins
# that — a row shaped like this must not retire a marker armed before it.
d = arm({"a487d372": ("Agent", "a487d372", "toolu_OLD")}, {"a487d372": 120})
delivered = {
    "type": "user",
    "timestamp": iso(NOW - 5),
    "message": {
        "role": "user",
        "content": (
            "<task-notification>\n<task-id>a487d372</task-id>\n"
            "<tool-use-id>toolu_OLD</tool-use-id>\n<status>completed</status>\n"
            "</task-notification>"
        ),
    },
}
n = h._bg_retire_from_transcript(PANE, [delivered])
check(
    "delivered notification as a string-content user row is not evidence",
    n == 0 and remaining(d) == ["a487d372"],
    f"n={n} remaining={remaining(d)}",
)

# A genuine TaskOutput reply in list-of-parts form still counts.
d = arm({"t1": ("Bash", "t1", "toolu_T1")}, {"t1": 120})
n = h._bg_retire_from_transcript(
    PANE, [task_output_row(NOW - 5, "t1", "completed", body="all good", as_parts=True)]
)
check(
    "TaskOutput reply as content parts is honoured",
    n == 1 and remaining(d) == [],
    f"n={n} remaining={remaining(d)}",
)

# ------------------------------------------------------------------ timestamp guard
d = arm({"ag": ("Agent", "ag", "toolu_AG")}, {"ag": 60})  # re-armed 60s ago
n = h._bg_retire_from_transcript(PANE, [notif_row(NOW - 3600, "ag", "toolu_AG")])
check(
    "evidence older than the marker never retires it",
    n == 0 and remaining(d) == ["ag"],
    f"n={n} remaining={remaining(d)}",
)

d = arm({"eq": ("Bash", "eq", "toolu_EQ")}, {"eq": 60})
# Whole seconds so the ISO round-trip (microsecond precision) reproduces the mtime
# exactly — the boundary being tested is `>=`, not float formatting.
mtime = float(int(NOW - 60))
os.utime(os.path.join(d, "eq"), (mtime, mtime))
n = h._bg_retire_from_transcript(PANE, [notif_row(mtime, "eq", "toolu_EQ")])
check(
    "evidence exactly at the marker mtime retires (>= boundary)",
    n == 1 and remaining(d) == [],
    f"n={n} remaining={remaining(d)}",
)

# ------------------------------------------------------------------- marker shapes
# Bash backgrounded with no backgroundTaskId: marker keyed on the tool_use id,
# empty alt, and the notification names it only as <tool-use-id>.
d = arm({"toolu_ONLY": ("Bash", "", "toolu_ONLY")}, {"toolu_ONLY": 120})
n = h._bg_retire_from_transcript(
    PANE, [notif_row(NOW - 5, "sometask", "toolu_ONLY")]
)
check(
    "marker with empty alt is retired via its tool-use id",
    n == 1 and remaining(d) == [],
    f"n={n} remaining={remaining(d)}",
)

d = arm({"trunc": ("", "", "")}, {"trunc": 120})
with open(os.path.join(d, "trunc"), "w") as fh:
    fh.write("")  # truncated marker
os.utime(os.path.join(d, "trunc"), (NOW - 120, NOW - 120))
n = h._bg_retire_from_transcript(PANE, [notif_row(NOW - 5, "trunc", "toolu_X")])
check(
    "empty marker file does not crash and is retired by filename",
    n == 1 and remaining(d) == [],
    f"n={n} remaining={remaining(d)}",
)

# --------------------------------------------------------------------- batch, noise
d = arm(REAL, {"bugkernjy": 120, "bz23tejwu": 120})
mixed = [
    {
        "type": "queue-operation",
        "operation": "enqueue",
        "timestamp": iso(NOW - 5),
        "content": (
            "<task-notification><task-id>bugkernjy</task-id>"
            "<status>completed</status></task-notification>\n"
            "<task-notification><task-id>bz23tejwu</task-id>"
            "<status>running</status></task-notification>"
        ),
    }
]
n = h._bg_retire_from_transcript(PANE, mixed)
check(
    "batch retires only its completed half",
    n == 1 and remaining(d) == ["bz23tejwu"] and opts.get((PANE, "@cc-workflow")) == "1",
    f"n={n} remaining={remaining(d)} opts={opts.get((PANE, '@cc-workflow'))}",
)

d = arm(REAL, {"bugkernjy": 120, "bz23tejwu": 120})
n = h._bg_retire_from_transcript(
    PANE, [notif_row(NOW - 5, "bz23tejwu", "toolu_x", status="failed")]
)
check(
    "a failed task is retired too",
    n == 1 and remaining(d) == ["bugkernjy"],
    f"n={n} remaining={remaining(d)}",
)

# ------------------------------------------------------- late-dated evidence shapes
# The dequeue of an old completion, and its delivery as an attachment, are both
# dated LATER than the completion itself: an agent resumed in between must survive.
for label, row in (
    (
        "queue-operation/remove",
        dict(notif_row(NOW - 5, "ag", "toolu_AG"), operation="remove"),
    ),
    (
        "queued_command attachment",
        {
            "type": "attachment",
            "timestamp": iso(NOW - 5),
            "attachment": {
                "type": "queued_command",
                "commandMode": "task-notification",
                "prompt": (
                    "<task-notification><task-id>ag</task-id>"
                    "<status>completed</status></task-notification>"
                ),
            },
        },
    ),
):
    d = arm({"ag": ("Agent", "ag", "toolu_AG")}, {"ag": 60})  # re-armed after T1
    n = h._bg_retire_from_transcript(PANE, [row])
    check(
        f"late-dated evidence is not trusted: {label}",
        n == 0 and remaining(d) == ["ag"],
        f"n={n} remaining={remaining(d)}",
    )

# The enqueue for the SAME completion is dated at the completion, so an agent whose
# resume came after it still survives, while a genuinely newer one is retired.
d = arm({"ag": ("Agent", "ag", "toolu_AG")}, {"ag": 60})
n = h._bg_retire_from_transcript(
    PANE,
    [
        notif_row(NOW - 3600, "ag", "toolu_AG"),  # completed, then resumed
        dict(notif_row(NOW - 5, "ag", "toolu_AG"), operation="remove"),  # dequeued now
    ],
)
check(
    "enqueue/remove pair for a stale completion retires nothing",
    n == 0 and remaining(d) == ["ag"],
    f"n={n} remaining={remaining(d)}",
)

# ----------------------------------------------------------------- unknown statuses
for status in ("paused", "starting", "awaiting_input", "weird"):
    d = arm({"live": ("Bash", "live", "toolu_L")}, {"live": 60})
    n = h._bg_retire_from_transcript(
        PANE, [notif_row(NOW - 5, "live", "toolu_L", status=status)]
    )
    check(
        f"unknown status <{status}> retires nothing",
        n == 0 and remaining(d) == ["live"],
        f"n={n} remaining={remaining(d)}",
    )

for status in ("completed", "failed", "killed", "error", "cancelled", "timed_out"):
    d = arm({"gone": ("Bash", "gone", "toolu_G")}, {"gone": 60})
    n = h._bg_retire_from_transcript(
        PANE, [notif_row(NOW - 5, "gone", "toolu_G", status=status)]
    )
    check(
        f"terminal status <{status}> retires",
        n == 1 and remaining(d) == [],
        f"n={n} remaining={remaining(d)}",
    )

# ------------------------------------------------------------------- malformed rows
malformed = [
    [],
    "a string row",
    42,
    None,
    {"type": "user", "timestamp": iso(NOW), "message": "not a dict"},
    {"type": "attachment", "timestamp": iso(NOW), "attachment": "not a dict"},
    {"type": "queue-operation", "operation": "enqueue", "timestamp": iso(NOW), "content": 5},
]
d = arm(REAL, {"bugkernjy": 120, "bz23tejwu": 120})
try:
    n = h._bg_retire_from_transcript(PANE, malformed)
    ok = n == 0 and len(remaining(d)) == 2
    detail = f"n={n} remaining={remaining(d)}"
except Exception as e:
    ok, detail = False, f"{type(e).__name__}: {e}"
check("malformed rows neither crash nor retire", ok, detail)

for label, noise in (
    ("empty rows", []),
    ("plain user turn", [{"type": "user", "timestamp": iso(NOW), "message": {"content": "hi"}}]),
    ("no timestamp", [dict(notif_row(NOW, "bugkernjy", "x"), timestamp=None)]),
    ("assistant text", [{"type": "assistant", "timestamp": iso(NOW), "message": {"content": [{"type": "text", "text": "<status>completed</status> bugkernjy"}]}}]),
    ("status with no id", [{"type": "queue-operation", "operation": "enqueue", "timestamp": iso(NOW), "content": "<task-notification><status>completed</status></task-notification>"}]),
    ("id with no status", [{"type": "queue-operation", "operation": "enqueue", "timestamp": iso(NOW), "content": "<task-notification><task-id>bugkernjy</task-id></task-notification>"}]),
):
    d = arm(REAL, {"bugkernjy": 120, "bz23tejwu": 120})
    n = h._bg_retire_from_transcript(PANE, noise)
    check(
        f"noise retires nothing: {label}",
        n == 0 and len(remaining(d)) == 2,
        f"n={n} remaining={remaining(d)}",
    )

# ------------------------------------------------------------------------ _row_epoch
for label, row, expect in (
    ("missing", {}, 0.0),
    ("None", {"timestamp": None}, 0.0),
    ("empty", {"timestamp": ""}, 0.0),
    ("malformed", {"timestamp": "not-a-date"}, 0.0),
    ("naive (no zone)", {"timestamp": "2026-07-29T21:40:15.226"}, 0.0),
    ("zulu", {"timestamp": "2026-07-29T21:40:15.226Z"}, 1785361215.226),
    ("offset", {"timestamp": "2026-07-30T01:40:15.226+04:00"}, 1785361215.226),
):
    got = h._row_epoch(row)
    check(f"_row_epoch {label}", abs(got - expect) < 0.001, f"got={got} want={expect}")

# ------------------------------------------------ output-clock adoption vs evidence
# Adoption bumps a marker's mtime to its output file's last write, which outranks
# older evidence: the sweep declines and the deadline decides instead.
h.BG_STALE_OVERRIDE = None  # real deadlines: Bash = 900s
os.makedirs(FAKE_TASKS, exist_ok=True)
out = os.path.join(FAKE_TASKS, "adopt.output")
with open(out, "w") as fh:
    fh.write("still writing\n")
os.utime(out, (NOW - 100, NOW - 100))
d = arm({"adopt": ("Bash", "adopt", "toolu_AD")}, {"adopt": 1000})  # past the 900s
n = h._bg_retire_from_transcript(PANE, [notif_row(NOW - 950, "adopt", "toolu_AD")])
check(
    "adopted output clock outranks older evidence (deadline decides)",
    n == 0 and remaining(d) == ["adopt"],
    f"n={n} remaining={remaining(d)}",
)
# Newer evidence still wins over the adopted clock.
d = arm({"adopt": ("Bash", "adopt", "toolu_AD")}, {"adopt": 1000})
n = h._bg_retire_from_transcript(PANE, [notif_row(NOW - 50, "adopt", "toolu_AD")])
check(
    "evidence newer than the adopted clock retires",
    n == 1 and remaining(d) == [],
    f"n={n} remaining={remaining(d)}",
)
h.BG_STALE_OVERRIDE = "999999"

# ------------------------------------------------------- action_done wiring / gates
def run_done(markers, ages, rows_json):
    d = arm(markers, ages)
    # Under TMP, not SCRATCH: TMP is rmtree'd unconditionally at the end, so a
    # mid-run death (assert, KeyboardInterrupt) can't leak this file into the
    # tracked source directory.
    path = os.path.join(TMP, "wiring-transcript.jsonl")
    with open(path, "w") as fh:
        for r in rows_json:
            fh.write(json.dumps(r) + "\n")
    opts[(PANE, "@cc-session-id")] = "sess-x"
    opts[(PANE, "@cc-last-prompt-ts")] = str(int(NOW - 300))
    opts[(PANE, "@cc-prompt-count")] = "99"  # past RENAME_UNTIL_TURN: no rename spawn
    h.action_done(PANE, {"session_id": "sess-x", "transcript_path": path})
    return d


WF = {
    "wf-old": ("Workflow", "wf-old", "toolu_WF1"),
    "wf-new": ("Workflow", "wf-new", "toolu_WF2"),
}
AGES = {"wf-old": 300, "wf-new": 100, "bashy": 200}

# A Stop that sweeps a Bash retires only that Bash and leaves both Workflow markers
# in place — the regression test proving a live Workflow is no longer droppable.
d = run_done(
    {**WF, "bashy": ("Bash", "bashy", "toolu_B")},
    AGES,
    [notif_row(NOW - 10, "bashy", "toolu_B")],
)
check(
    "action_done: swept Bash leaves both Workflow markers in place",
    remaining(d) == ["wf-new", "wf-old"],
    f"remaining={remaining(d)}",
)

# Sweep retires a Workflow by id: exactly that one is removed, the other survives.
d = run_done(WF, AGES, [notif_row(NOW - 10, "wf-old", "toolu_WF1")])
check(
    "action_done: swept Workflow retires only that marker",
    remaining(d) == ["wf-new"] and opts.get((PANE, "@cc-workflow")) == "1",
    f"remaining={remaining(d)} wf={opts.get((PANE, '@cc-workflow'))}",
)

# With no evidence in the transcript, a Stop leaves both Workflows alone.
d = run_done(WF, AGES, [])
check(
    "action_done: no evidence leaves both Workflows alone",
    remaining(d) == ["wf-new", "wf-old"],
    str(remaining(d)),
)

# The state always lands on `done` and the cache timestamp is stamped.
check(
    "action_done: status lands on done and cache-ts is stamped",
    opts.get((PANE, "@cc-status")) == "done" and (PANE, "@cc-cache-ts") in opts,
    str({k[1]: v for k, v in opts.items()}),
)

# A transcript whose rows are valid JSON but the wrong shape must still reach `done`
# — an exception here is swallowed by main() only AFTER the turn flags are cleared,
# which would latch the tab on `working`.
d = run_done(
    {"bashy": ("Bash", "bashy", "toolu_B")},
    {"bashy": 120},
    malformed + [notif_row(NOW - 10, "bashy", "toolu_B")],
)
check(
    "action_done: malformed rows still reach done and still sweep",
    opts.get((PANE, "@cc-status")) == "done" and remaining(d) == [],
    f"status={opts.get((PANE, '@cc-status'))} remaining={remaining(d)}",
)

# A missing/empty transcript path must not break the Stop hook.
opts.clear()
d = arm(REAL, {"bugkernjy": 120, "bz23tejwu": 120})
opts[(PANE, "@cc-session-id")] = "sess-x"
opts[(PANE, "@cc-last-prompt-ts")] = str(int(NOW - 300))
opts[(PANE, "@cc-prompt-count")] = "99"
h.action_done(PANE, {"session_id": "sess-x"})
check(
    "action_done: no transcript_path is survivable",
    opts.get((PANE, "@cc-status")) == "done" and len(remaining(d)) == 2,
    f"status={opts.get((PANE, '@cc-status'))} remaining={remaining(d)}",
)

# _text_blocks must survive a non-string `text` payload (Fix 2b): the shape
# quoted in the Fix-2 finding — a tool_result whose content is
# [{"type":"text","text":{...a dict...}}] — reaches _text_blocks via
# _task_output_headers, and a naive join would raise TypeError there.
bad_shape_row = {
    "type": "user",
    "timestamp": iso(NOW - 5),
    "message": {
        "role": "user",
        "content": [
            {
                "type": "tool_result",
                "tool_use_id": "toolu_BAD",
                "content": [{"type": "text", "text": {"unexpected": "dict"}}],
            }
        ],
    },
}
try:
    h._finished_task_evidence([bad_shape_row])
    ok, detail = True, ""
except Exception as e:
    ok, detail = False, f"{type(e).__name__}: {e}"
check("_text_blocks survives a non-string text payload without raising", ok, detail)

d = run_done(
    {"bashy": ("Bash", "bashy", "toolu_B")},
    {"bashy": 120},
    [bad_shape_row, notif_row(NOW - 10, "bashy", "toolu_B")],
)
check(
    "action_done still reaches done with a non-string text payload in the tail",
    opts.get((PANE, "@cc-status")) == "done",
    f"status={opts.get((PANE, '@cc-status'))}",
)

# action_done must reach `done` even if the sweep itself raises (Fix 2a: the
# ordering, pinned independently of what Fix 2b fixed). The raise is injected
# deliberately here — the real raisers this pins against are being fixed
# elsewhere — because the ordering must hold regardless of WHY a future parse
# in this section might raise.
d = arm({"bashy": ("Bash", "bashy", "toolu_B")}, {"bashy": 120})
path = os.path.join(TMP, "raising-transcript.jsonl")
with open(path, "w") as fh:
    fh.write(json.dumps(notif_row(NOW - 10, "bashy", "toolu_B")) + "\n")
opts[(PANE, "@cc-session-id")] = "sess-x"
opts[(PANE, "@cc-last-prompt-ts")] = str(int(NOW - 300))
opts[(PANE, "@cc-prompt-count")] = "99"
opts.pop((PANE, "@cc-status"), None)
_orig_retire = h._bg_retire_from_transcript


def _raise_retire(*_a, **_kw):
    raise RuntimeError("injected: simulating a raise inside the sweep")


h._bg_retire_from_transcript = _raise_retire
try:
    try:
        h.action_done(PANE, {"session_id": "sess-x", "transcript_path": path})
    except RuntimeError:
        # main()'s catch-all would swallow this in production; the test asserts
        # on option state regardless of whether the exception propagates here.
        pass
finally:
    h._bg_retire_from_transcript = _orig_retire
check(
    "action_done: status reaches done even when the sweep raises",
    opts.get((PANE, "@cc-status")) == "done",
    f"status={opts.get((PANE, '@cc-status'))}",
)

# ---------------------------------------------------- action_prompt_submit wiring
def run_prompt_submit(markers, ages, prompt, prompt_count_before="99"):
    d = arm(markers, ages)
    opts[(PANE, "@cc-session-id")] = "sess-x"
    opts[(PANE, "@cc-prompt-count")] = prompt_count_before
    h.action_prompt_submit(PANE, {"session_id": "sess-x", "prompt": prompt})
    return d


# A <task-notification> prompt retires the marker it names by id, merges
# @cc-status to "working" (not forced), and must NOT advance @cc-prompt-count —
# it is a harness re-invocation of the session, not a user turn.
d = run_prompt_submit(
    {"wf1": ("Workflow", "wf1", "toolu_WF1")},
    {"wf1": 120},
    "<task-notification><task-id>wf1</task-id><status>completed</status>"
    "</task-notification>",
)
check(
    "action_prompt_submit: notification prompt retires its marker by id",
    remaining(d) == []
    and opts.get((PANE, "@cc-prompt-count")) == "99"
    and opts.get((PANE, "@cc-status")) == "working",
    f"remaining={remaining(d)} opts={ {k[1]: v for k, v in opts.items() if k[0] == PANE} }",
)

# The negative: a real user prompt (no notification tag) advances
# @cc-prompt-count and retires nothing.
d = run_prompt_submit(
    {"wf1": ("Workflow", "wf1", "toolu_WF1")},
    {"wf1": 120},
    "please fix the bug in foo.py",
)
check(
    "action_prompt_submit: real user prompt advances prompt-count and retires nothing",
    remaining(d) == ["wf1"] and opts.get((PANE, "@cc-prompt-count")) == "100",
    f"remaining={remaining(d)} count={opts.get((PANE, '@cc-prompt-count'))}",
)

# --------------------------------------------------------------- _bg_heartbeat
# The sweep's third invariant: two writers bump a marker's mtime and therefore
# outrank evidence by design. The output-clock-adoption half is pinned above;
# this pins that _bg_heartbeat is the OTHER writer, and Agent-only — a
# backgrounded shell command fires no hooks, so a Bash marker gets no
# heartbeat and must still fall to the sweep.
h.BG_STALE_OVERRIDE = "999999"
d = arm(
    {"ag": ("Agent", "ag", "toolu_AG"), "sh": ("Bash", "sh", "toolu_SH")},
    {"ag": 120, "sh": 120},
)
h._bg_heartbeat(PANE)
n = h._bg_retire_from_transcript(
    PANE,
    [
        notif_row(NOW - 60, "ag", "toolu_AG"),
        notif_row(NOW - 60, "sh", "toolu_SH"),
    ],
)
check(
    "_bg_heartbeat outranks evidence for Agent markers only, Bash still retires",
    remaining(d) == ["ag"],
    str(remaining(d)),
)

shutil.rmtree(TMP, ignore_errors=True)
shutil.rmtree("/private/tmp/claude-501/sweep-test-proj", ignore_errors=True)
print(f"\n{'FAILURES: ' + str(fails) if fails else 'all passed'}")
sys.exit(1 if fails else 0)
