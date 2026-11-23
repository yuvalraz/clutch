"""Tests for ops_sync.py: the unit seam (pure functions) and the CLI seam
(the tool as a subprocess under a scratch HOME, with the real prelude.sh).

Run: /usr/bin/python3 -B tools/ops_sync/test_ops_sync.py
"""
from __future__ import annotations

import contextlib
import hashlib
import io
import json
import os
import random
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import unittest
import unittest.mock

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ops_sync  # noqa: E402

TOOL = os.path.join(HERE, "ops_sync.py")
TAG = "@1a2b3c4d"
TAG2 = "@0f0f0f0f"
URL = "https://claude.ai/artifact/demo-ops-view"
ID_RE = re.compile(r"^[A-Za-z0-9_.~:@+-]{1,200}$")
SESSION_KEYS = {"kind", "tag", "repo", "on", "on_at", "moves", "ticket", "tickets", "last_at", "updated_at"}
WAIT_KEYS = {"kind", "ref", "wait_kind", "tag", "repo", "baseline", "text", "ticket", "state",
             "opened_at", "closed_at", "updated_at"}

# IF-3 shared vector table, V11-V12 from the approved IF3-fix (pinned verbatim in board_sync's tests too).
TICKET_VECTORS = [
    ("V1", ["feat/eng-2048-slice-b"], [], "ENG-2048"),
    ("V2", ["eng-2119"], ["merge queue of ENG-2127"], "ENG-2119"),
    ("V3", ["main"], ["re-review of ENG-2127 and OPS-676"], "ENG-2127"),
    ("V4", ["projects"], ["utf-8 and eng-12 in lower case"], None),
    ("V5", [], ["SHA-256 pin, then ENG-7"], "ENG-7"),
    ("V6", ["fix/utf-8-bug"], [], None),
    ("V7", [None, "eng-5"], [None], "ENG-5"),
    ("V8", ["claude/zen-bassi-1a2b"], ["build2ENG-12 and ENG-1234567"], None),
    ("V9", [], ["(ENG-42)."], "ENG-42"),
    ("V10", [], [], None),
    ("V11", [], ["P-ENG-301 then ENG-1925"], "ENG-1925"),
    ("V12", [], ["OD-1 kept; ENG-1781"], "ENG-1781"),
]

# IF-2 id table.
ID_VECTORS = [
    ("gh:yuvalraz/clutch#32", "gh:yuvalraz~2Fclutch~2332"),
    ("slack:C0978/1795349629.465929", "slack:C0978~2F1795349629.465929"),
    ("linear:ENG-12", "linear:ENG-12"),
    ("cal:a b@c~", "cal:a~20b~40c~7E"),
    ("slack:é", "slack:~C3~A9"),
    (".", "~2E"),
    ("..", "~2E~2E"),
    ("...", "..."),
    ("a.", "a."),
    ("a" * 300, "~h" + hashlib.sha256(b"a" * 300).hexdigest()[:40]),
]


def iso(epoch):
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(epoch))


def decode_id(doc_id):
    """Invert IF-2 by its rule: None for the hash form, else the key."""
    if doc_id.startswith("~h"):
        return None
    out = bytearray()
    i = 0
    while i < len(doc_id):
        if doc_id[i] == "~":
            out.append(int(doc_id[i + 1:i + 3], 16))
            i += 3
        else:
            out.append(ord(doc_id[i]))
            i += 1
    return out.decode("utf-8")


def tree(path):
    """Every path under `path` with a content hash for files."""
    seen = {}
    for base, dirs, files in os.walk(path):
        for name in dirs:
            seen[os.path.join(base, name)] = "dir"
        for name in files:
            full = os.path.join(base, name)
            with open(full, "rb") as handle:
                seen[full] = hashlib.sha256(handle.read()).hexdigest()
    return seen


class Scratch:
    """A scratch HOME with ~/.clutch, the tool run as a subprocess against it."""

    def __init__(self, test, home_name="home"):
        self.base = tempfile.mkdtemp()
        test.addCleanup(self.cleanup)
        self.home = os.path.join(self.base, home_name)
        self.clutch = os.path.join(self.home, ".clutch")
        os.makedirs(self.clutch)
        self.now = int(time.time())

    def cleanup(self):
        for base, dirs, _ in os.walk(self.base):
            for name in dirs:
                os.chmod(os.path.join(base, name), 0o755)
        shutil.rmtree(self.base, ignore_errors=True)

    def path(self, *parts):
        return os.path.join(self.clutch, *parts)

    def config(self, obj=None, raw=None):
        with open(self.path("opsview.json"), "w") as handle:
            handle.write(raw if raw is not None else json.dumps(obj if obj is not None else {"url": URL}))

    def worklog(self, lines, mode="w"):
        data = b"".join((line if isinstance(line, bytes) else line.encode("utf-8")) + b"\n" for line in lines)
        with open(self.path("worklog.md"), mode + "b") as handle:
            handle.write(data)

    def run(self, *args, env=None):
        if env is None:
            env = dict(os.environ)
            env["HOME"] = self.home
        env["PYTHONDONTWRITEBYTECODE"] = "1"
        proc = subprocess.run([sys.executable, "-B", TOOL] + list(args), env=env, cwd=self.base,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60)
        return proc.returncode, proc.stdout.decode("utf-8"), proc.stderr.decode("utf-8")

    def state(self):
        with open(self.path("opsview", "state.json")) as handle:
            return json.load(handle)

    def state_bytes(self):
        try:
            with open(self.path("opsview", "state.json"), "rb") as handle:
                return handle.read()
        except FileNotFoundError:
            return None


def doc_lines(out):
    """[(collection, doc_id, path, if_version or None)] from OPS_DOC lines."""
    rows = []
    for line in out.splitlines():
        if not line.startswith("OPS_DOC: "):
            continue
        parts = line[len("OPS_DOC: "):].split(" ")
        version = None
        if re.fullmatch(r"if_version=[0-9]+", parts[-1]):
            version = int(parts[-1].split("=")[1])
            parts = parts[:-1]
        rows.append((parts[0], parts[1], " ".join(parts[2:]), version))
    return rows


def load(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def ack_args(rows, version=1):
    return ["%s/%s=%d" % (c, d, version) for c, d, _, _ in rows]


# --- unit seam -------------------------------------------------------------


class TicketRule(unittest.TestCase):
    def test_ticket_vectors(self):
        for name, slugs, texts, want in TICKET_VECTORS:
            with self.subTest(name):
                self.assertEqual(ops_sync.ticket_of(slugs, texts), want)


class DocIds(unittest.TestCase):
    def test_doc_id_vectors(self):
        for key, want in ID_VECTORS:
            with self.subTest(key=key[:20]):
                self.assertEqual(ops_sync.enc_doc_id(key), want)

    def test_doc_id_random(self):
        rng = random.Random(2009)
        alphabet = "aZ09_.:-~ /@#h2Eé☃\n"
        keys = {".", "..", "...", "....", ".a", "~2E", "~h", "repo:a", "a" * 199, "a" * 200, "a" * 201}
        while len(keys) < 520:
            n = rng.choice([1, 2, 3, 5, 20, 80, 120])
            keys.add("".join(rng.choice(alphabet) for _ in range(n)))
            keys.add("." * rng.randint(1, 6))
        ids = {}
        for key in keys:
            doc_id = ops_sync.enc_doc_id(key)
            self.assertRegex(doc_id, ID_RE)
            self.assertNotIn(doc_id, (".", ".."))
            back = decode_id(doc_id)
            if back is None:
                self.assertEqual(len(doc_id), 42)
            else:
                self.assertEqual(back, key)
            self.assertNotIn(doc_id, ids, "two keys share one id")
            ids[doc_id] = key


class PeopleGuard(unittest.TestCase):
    def test_people_guard_blanks_containing_and_contained(self):
        guard = ["Canary Person Alpha is the CTO here", "canary bravo secret twelve"]
        doc = {"kind": "session", "tag": None, "repo": "demo-repo",
               "on": "met CANARY PERSON ALPHA IS THE CTO HERE today",
               "moves": [{"text": "Canary Bravo Secret", "at": "2026-11-23T10:00:00Z"},
                         {"text": "canary", "at": "2026-11-23T09:00:00Z"}],
               "ticket": "DEMO-1", "tickets": ["DEMO-1"]}
        self.assertEqual(ops_sync.people_guard(doc, guard), 2)
        self.assertIsNone(doc["on"])
        self.assertEqual(doc["moves"][0]["text"], "")
        self.assertEqual(doc["moves"][1]["text"], "canary")
        self.assertEqual(doc["repo"], "demo-repo")
        self.assertEqual(ops_sync.people_guard(doc, []), 0)


class ParseWorklog(unittest.TestCase):
    def test_parse_edges(self):
        now = 1_800_000_000
        lines = [
            "%d demo-a on: @alice reviewing DEMO-3" % (now - 50),
            "%d demo-a on: @ABCDEF12 upper is text" % (now - 49),
            "%d demo-a moved: gh:demo/app#1 %s merged it" % (now - 48, TAG),
            "%d demo-a moved: one two three %s fourth is text" % (now - 47, TAG),
            "%d demo-a on: in the future" % (now + 100),
            "%d demo-a on: six days old" % (now - 518400),
            "%d demo-a on: exactly five days" % (now - 432000),
            "notanepoch demo-a on: skipped",
            "%d demo-a on:" % (now - 40),
            "%d demo-a frobbed: unknown verb" % (now - 39),
        ]
        got = [(e["at"], e["repo"], e["verb"], e["tag"], e["text"]) for e in ops_sync.parse_worklog(lines, now)]
        self.assertEqual(got, [
            (now - 50, "demo-a", "on:", None, "@alice reviewing DEMO-3"),
            (now - 49, "demo-a", "on:", None, "@ABCDEF12 upper is text"),
            (now - 48, "demo-a", "moved:", TAG, "gh:demo/app#1 merged it"),
            (now - 47, "demo-a", "moved:", None, "one two three %s fourth is text" % TAG),
            (now - 432000, "demo-a", "on:", None, "exactly five days"),
        ])

    def test_build_docs_keys_sessions_by_tag_or_repo(self):
        now = 1_800_000_000
        lines = [
            "%d alpha on: untagged in alpha" % (now - 30),
            "%d beta on: untagged in beta" % (now - 20),
            "%d alpha on: %s tagged work DEMO-9" % (now - 10, TAG),
        ]
        docs = ops_sync.build_docs(lines, [], None, {}, now)
        self.assertEqual(sorted(docs), [("sessions", TAG), ("sessions", "repo:alpha"), ("sessions", "repo:beta")])
        self.assertEqual(docs[("sessions", TAG)]["ticket"], "DEMO-9")
        self.assertEqual(docs[("sessions", "repo:alpha")]["on"], "untagged in alpha")

    def test_wait_ref_that_strips_empty_has_no_doc(self):
        now = 1_800_000_000
        self.assertEqual(ops_sync.wait_docs(["%d demo-repo wait: ,;: b1 reply" % (now - 10)], {}, now), {})


# --- CLI seam --------------------------------------------------------------


class Off(unittest.TestCase):
    def test_off_no_home(self):
        s = Scratch(self)
        s.config()
        before = tree(s.base)
        for home in (None, ""):
            env = {k: v for k, v in os.environ.items() if k != "HOME"}
            if home is not None:
                env["HOME"] = home
            rc, out, err = s.run(env=env)
            self.assertEqual((rc, out, err), (0, "OPS: off\n", ""))
        self.assertEqual(tree(s.base), before)

    def test_off_no_config(self):
        s = Scratch(self)
        s.worklog(["%d demo-repo on: %s work" % (s.now - 10, TAG)])
        with open(s.path("people.md"), "w") as handle:
            handle.write("- someone with a long enough line\n")
        before = tree(s.base)
        rc, out, err = s.run()
        self.assertEqual((rc, out, err), (0, "OPS: off\n", ""))
        self.assertEqual(tree(s.base), before)


class Config(unittest.TestCase):
    def test_config_invalid_each_exit_1_without_the_value(self):
        cases = {
            "missing url": '{"other": 1}',
            "http url": '{"url": "http://plain.example"}',
            "url with space": '{"url": "https://a spaced.example"}',
            "2049 chars": json.dumps({"url": "https://" + "q" * 2041}),
            "not an object": '["https://list.example"]',
            "not json": "{nope",
            "url not a string": '{"url": 5}',
        }
        for name, raw in cases.items():
            with self.subTest(name):
                s = Scratch(self)
                s.config(raw=raw)
                rc, out, err = s.run()
                self.assertEqual(rc, 1)
                self.assertEqual(out, "")
                self.assertEqual(len(err.splitlines()), 1)
                self.assertTrue(err.startswith("ops_sync: ~/.clutch/opsview.json: "), err)
                for value in ("plain.example", "spaced", "qqqq", "list.example", "nope"):
                    self.assertNotIn(value, err)
                self.assertFalse(os.path.exists(s.path("opsview")))

    def test_config_2048_chars_is_valid(self):
        s = Scratch(self)
        url = "https://" + "q" * 2040
        s.config({"url": url})
        rc, out, _ = s.run()
        self.assertEqual((rc, out), (0, "OPS: %s\nOPS: unchanged\n" % url))


class Sync(unittest.TestCase):
    def fixture(self, s):
        n = s.now
        s.config({"url": URL, "extra": "ignored"})
        s.worklog([
            "%d demo-repo on: %s building DEMO-12 page" % (n - 3000, TAG),
            "%d demo-repo moved: gh:demo/app#7 %s pushed fix for DEMO-12" % (n - 2000, TAG),
            "%d other-repo on: untagged work in other repo" % (n - 1500),
            "%d demo-repo wait: gh:demo/app#9, 2026-11-23T10:00:00Z %s review from a peer" % (n - 1000, TAG),
            "%d demo-repo wait: slack:C01/123.456 123.456 nudge on DEMO-3" % (n - 900),
        ])

    def test_sync_emits_sessions_waits(self):
        s = Scratch(self)
        self.fixture(s)
        n = s.now
        rc, out, err = s.run()
        self.assertEqual((rc, err), (0, ""))
        lines = out.splitlines()
        self.assertEqual(lines[0], "OPS: " + URL)
        rows = doc_lines(out)
        self.assertEqual(len(rows), len(lines) - 1)
        keys = [(c, d) for c, d, _, _ in rows]
        self.assertEqual(sorted(keys), sorted([
            ("sessions", TAG), ("sessions", "repo:demo-repo"), ("sessions", "repo:other-repo"),
            ("waits", "gh:demo~2Fapp~239~20~401a2b3c4d"), ("waits", "slack:C01~2F123.456")]))
        docs = {}
        for c, d, path, version in rows:
            self.assertIsNone(version)
            self.assertRegex(d, ID_RE)
            self.assertNotIn(d, (".", ".."))
            self.assertEqual(path, os.path.join(s.home, ".clutch", "opsview", "docs", c, d + ".json"))
            with open(path, "rb") as handle:
                raw = handle.read()
            doc = json.loads(raw)
            self.assertEqual(raw, (json.dumps(doc, sort_keys=True, ensure_ascii=False, indent=1) + "\n").encode())
            docs[(c, d)] = doc
        updated = [docs[k]["updated_at"] for k in keys]
        self.assertEqual(updated, sorted(updated, reverse=True))
        self.assertEqual(docs[("sessions", TAG)], {
            "kind": "session", "tag": TAG, "repo": "demo-repo", "on": "building DEMO-12 page",
            "on_at": iso(n - 3000),
            "moves": [{"text": "gh:demo/app#7 pushed fix for DEMO-12", "at": iso(n - 2000)}],
            "ticket": "DEMO-12", "tickets": ["DEMO-12"], "last_at": iso(n - 1000), "updated_at": iso(n - 1000)})
        self.assertEqual(docs[("sessions", "repo:other-repo")], {
            "kind": "session", "tag": None, "repo": "other-repo", "on": "untagged work in other repo",
            "on_at": iso(n - 1500), "moves": [], "ticket": None, "tickets": [],
            "last_at": iso(n - 1500), "updated_at": iso(n - 1500)})
        self.assertEqual(docs[("waits", "gh:demo~2Fapp~239~20~401a2b3c4d")], {
            "kind": "wait", "ref": "gh:demo/app#9", "wait_kind": "gh", "tag": TAG, "repo": "demo-repo",
            "baseline": "2026-11-23T10:00:00Z", "text": "review from a peer", "ticket": None,
            "state": "open", "opened_at": iso(n - 1000), "closed_at": None, "updated_at": iso(n - 1000)})
        slack = docs[("waits", "slack:C01~2F123.456")]
        self.assertEqual((slack["tag"], slack["text"], slack["ticket"]), (None, "nudge on DEMO-3", "DEMO-3"))
        for (c, _), doc in docs.items():
            self.assertEqual(set(doc), SESSION_KEYS if c == "sessions" else WAIT_KEYS)

    def test_ack_then_unchanged(self):
        s = Scratch(self)
        self.fixture(s)
        _, out, _ = s.run()
        rows = doc_lines(out)
        rc, out, err = s.run("--ack", *ack_args(rows, 4))
        self.assertEqual((rc, out, err), (0, "OPS: acked\n", ""))
        rc, out, err = s.run()
        self.assertEqual((rc, out, err), (0, "OPS: %s\nOPS: unchanged\n" % URL, ""))
        # A changed document carries the acked version.
        s.worklog(["%d demo-repo moved: gh:demo/app#8 %s more" % (s.now - 5, TAG)], mode="a")
        _, out, _ = s.run()
        self.assertEqual([(c, d, v) for c, d, _, v in doc_lines(out)], [("sessions", TAG, 4)])
        self.assertTrue(out.splitlines()[1].endswith(" if_version=4"))

    def test_no_worklog(self):
        s = Scratch(self)
        s.config()
        rc, out, err = s.run()
        self.assertEqual((rc, out, err), (0, "OPS: %s\nOPS: unchanged\n" % URL, ""))
        docs = s.path("opsview", "docs")
        self.assertEqual([f for _, _, fs in os.walk(docs) for f in fs] if os.path.isdir(docs) else [], [])

    def test_worklog_unreadable(self):
        s = Scratch(self)
        self.fixture(s)
        os.chmod(s.path("worklog.md"), 0)
        rc, out, err = s.run()
        self.assertEqual((rc, out), (1, ""))
        self.assertEqual(len(err.splitlines()), 1)
        self.assertTrue(err.startswith("ops_sync: "))
        self.assertFalse(os.path.exists(s.path("opsview")))

    def test_worklog_dangling_link_is_unreadable(self):
        # A dangling link is not "no worklog": reading it as empty would close every open wait.
        s = Scratch(self)
        s.config()
        s.worklog(["%d demo-repo wait: gh:demo/app#5 b1 %s review" % (s.now - 100, TAG)])
        self.assertEqual(s.run()[0], 0)
        before = tree(s.path("opsview"))
        os.remove(s.path("worklog.md"))
        os.symlink(os.path.join(s.base, "gone.md"), s.path("worklog.md"))
        rc, out, err = s.run()
        self.assertEqual((rc, out, err), (1, "", "ops_sync: worklog unreadable\n"))
        self.assertEqual(tree(s.path("opsview")), before)

    def test_empty_worklog(self):
        s = Scratch(self)
        s.config()
        s.worklog([])
        self.assertEqual(os.path.getsize(s.path("worklog.md")), 0)
        rc, out, err = s.run()
        self.assertEqual((rc, out, err), (0, "OPS: %s\nOPS: unchanged\n" % URL, ""))

    def test_open_loops_timeout_is_exit_1(self):
        s = Scratch(self)
        self.fixture(s)
        out = io.StringIO()
        with unittest.mock.patch.dict(os.environ, {"HOME": s.home}), \
                unittest.mock.patch.object(ops_sync.subprocess, "run",
                                           side_effect=subprocess.TimeoutExpired("sh", 20)), \
                contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            rc = ops_sync.main([])
        self.assertEqual((rc, out.getvalue()), (1, ""))

    def test_invalid_utf8_parsed_with_replacement(self):
        s = Scratch(self)
        s.config()
        s.worklog([b"%d demo-repo on: caf\xff work" % (s.now - 10)])
        rc, out, err = s.run()
        self.assertEqual((rc, err), (0, ""))
        (row,) = doc_lines(out)
        self.assertEqual(load(row[2])["on"], "caf� work")

    def test_whitespace_path(self):
        s = Scratch(self, home_name="my home")
        self.fixture(s)
        rc, out, err = s.run()
        self.assertEqual((rc, out), (1, ""))
        self.assertTrue(err.startswith("ops_sync: "))
        self.assertFalse(os.path.exists(s.path("opsview")))

    def test_state_reset(self):
        for garbage in (b"garbage{", b"[]", b'{"versions": 3}'):
            with self.subTest(garbage):
                s = Scratch(self)
                self.fixture(s)
                os.makedirs(s.path("opsview"))
                with open(s.path("opsview", "state.json"), "wb") as handle:
                    handle.write(garbage)
                rc, out, err = s.run()
                self.assertEqual(rc, 0)
                self.assertEqual(len(doc_lines(out)), 5)
                self.assertEqual(err, "ops_sync: state reset\n")

    def test_batch_cap(self):
        s = Scratch(self)
        s.config()
        s.worklog(["%d demo-repo wait: gh:demo/app#%d base%d text %d" % (s.now - 1000 + i, i, i, i)
                   for i in range(1, 60)])
        rc, out, _ = s.run()
        first = doc_lines(out)
        self.assertEqual((rc, len(first)), (0, 50))
        stamps = [load(p)["updated_at"] for _, _, p, _ in first]
        self.assertEqual(stamps, sorted(stamps, reverse=True))
        self.assertIn(("waits", "gh:demo~2Fapp~2359"), [(c, d) for c, d, _, _ in first])
        self.assertEqual(s.run("--ack", *ack_args(first))[0], 0)
        _, out, _ = s.run()
        second = doc_lines(out)
        self.assertEqual(len(second), 10)
        self.assertEqual({d for _, d, _, _ in second}, {"gh:demo~2Fapp~23%d" % i for i in range(1, 11)})
        self.assertFalse({d for _, d, _, _ in second} & {d for _, d, _, _ in first})


class Waits(unittest.TestCase):
    REF_ID = "gh:demo~2Fapp~235~20~401a2b3c4d"

    def wait_doc(self, s):
        return load(s.path("opsview", "docs", "waits", self.REF_ID + ".json"))

    def test_wait_closed(self):
        s = Scratch(self)
        s.config()
        s.worklog(["%d demo-repo wait: gh:demo/app#5 b1 %s review" % (s.now - 100, TAG)])
        s.run()
        self.assertEqual(self.wait_doc(s)["state"], "open")
        s.worklog(["%d demo-repo moved: gh:demo/app#5 %s merged" % (s.now - 50, TAG)], mode="a")
        start = time.time()
        rc, out, _ = s.run()
        doc = self.wait_doc(s)
        self.assertEqual((rc, doc["state"]), (0, "closed"))
        self.assertIn(("waits", self.REF_ID), [(c, d) for c, d, _, _ in doc_lines(out)])
        self.assertGreaterEqual(doc["closed_at"], iso(int(start)))
        self.assertEqual(doc["updated_at"], doc["closed_at"])
        self.assertEqual(doc["opened_at"], iso(s.now - 100))
        time.sleep(1.1)
        s.run()
        self.assertEqual(self.wait_doc(s), doc)

    def test_wait_aged(self):
        s = Scratch(self)
        s.config()
        s.worklog(["%d demo-repo wait: gh:demo/app#5 b1 %s review" % (s.now - 100, TAG)])
        s.run()
        s.worklog(["%d demo-repo wait: gh:demo/app#5 b1 %s review" % (s.now - 500000, TAG)])
        s.run()
        doc = self.wait_doc(s)
        self.assertEqual(doc["state"], "closed")
        self.assertIsNotNone(doc["closed_at"])

    def test_wait_reopen(self):
        s = Scratch(self)
        s.config()
        s.worklog(["%d demo-repo wait: gh:demo/app#5 b1 %s review" % (s.now - 300, TAG)])
        s.run()
        s.worklog(["%d demo-repo moved: gh:demo/app#5 %s merged" % (s.now - 200, TAG)], mode="a")
        s.run()
        self.assertEqual(self.wait_doc(s)["state"], "closed")
        s.worklog(["%d demo-repo wait: gh:demo/app#5 b2 %s second review" % (s.now - 100, TAG)], mode="a")
        s.run()
        doc = self.wait_doc(s)
        self.assertEqual((doc["state"], doc["baseline"], doc["opened_at"], doc["closed_at"], doc["updated_at"]),
                         ("open", "b2", iso(s.now - 100), None, iso(s.now - 100)))


    def test_two_tags_waiting_on_one_ref(self):
        s = Scratch(self)
        s.config()
        s.worklog(["%d demo-repo wait: gh:demo/app#5 b1 %s review" % (s.now - 300, TAG),
                   "%d demo-repo wait: gh:demo/app#5 b1 %s review too" % (s.now - 200, TAG2)])
        s.run()
        other = "gh:demo~2Fapp~235~20~400f0f0f0f"
        path = lambda d: s.path("opsview", "docs", "waits", d + ".json")
        self.assertEqual((load(path(self.REF_ID))["state"], load(path(other))["state"]), ("open", "open"))
        s.worklog(["%d demo-repo moved: gh:demo/app#5 %s merged" % (s.now - 100, TAG)], mode="a")
        s.run()
        self.assertEqual((load(path(self.REF_ID))["state"], load(path(other))["state"]), ("closed", "open"))


class Ack(unittest.TestCase):
    def synced(self):
        s = Scratch(self)
        s.config()
        s.worklog(["%d demo-repo on: %s work" % (s.now - 10, TAG)])
        _, out, _ = s.run()
        return s, doc_lines(out)

    def test_ack_valid_records_version_and_hash(self):
        s, rows = self.synced()
        (c, d, path, _), = rows
        rc, out, _ = s.run("--ack", "%s/%s=7" % (c, d))
        self.assertEqual((rc, out), (0, "OPS: acked\n"))
        with open(path, "rb") as handle:
            digest = hashlib.sha256(handle.read()).hexdigest()
        state = s.state()
        self.assertEqual(state["versions"], {"sessions/" + TAG: 7})
        self.assertEqual(state["acked"], {"sessions/" + TAG: digest})

    def test_ack_rejects_leave_state_unchanged(self):
        s, rows = self.synced()
        s.run("--ack", "sessions/%s=1" % TAG)
        before = s.state_bytes()
        for args in (["sessions/%s" % TAG], ["meta/config=1"], ["sessions/a b=1"], ["waits/nope=1"],
                     ["sessions/%s=x" % TAG], ["sessions/..=1"], ["sessions/%s=2" % TAG, "waits/nope=1"], []):
            with self.subTest(args):
                rc, out, err = s.run("--ack", *args)
                self.assertEqual((rc, out), (2, ""))
                self.assertEqual(len(err.splitlines()), 1)
                self.assertTrue(err.startswith("ops_sync: "))
                self.assertNotIn("nope", err)
                self.assertEqual(s.state_bytes(), before)


class Failed(unittest.TestCase):
    def test_failed_quiet_then_speak(self):
        s = Scratch(self)
        s.config()
        s.worklog(["%d demo-repo on: %s work" % (s.now - 10, TAG)])
        _, out, _ = s.run()
        ack = ack_args(doc_lines(out))
        steps = [
            (["--failed", "r"], "OPS: quiet"),            # no mark
            (["--failed", "r"], "OPS: quiet"),            # unsaid
            (["--failed", "--speak", "r"], "OPS: say"),
            (["--failed", "r"], "OPS: quiet"),            # said
            (["--failed", "--speak", "r"], "OPS: quiet"),
            (["--ack"] + ack, "OPS: acked"),
            (["--failed", "--speak", "r"], "OPS: say"),
        ]
        for args, want in steps:
            rc, out, _ = s.run(*args)
            self.assertEqual((rc, out), (0, want + "\n"), args)

    def test_failed_reason_one_line_capped(self):
        s = Scratch(self)
        s.run("--failed", "a\nb\x07\x1b" + "x" * 300)
        self.assertEqual(s.state()["failed"], "ab" + "x" * 198)
        self.assertIs(s.state()["failed_said"], False)

    def test_failed_state_write_failure(self):
        s = Scratch(self)
        with open(s.path("opsview"), "w") as handle:
            handle.write("a file where the state dir goes")
        self.assertEqual(s.run("--failed", "r")[:2], (0, "OPS: quiet\n"))
        self.assertEqual(s.run("--failed", "--speak", "r")[:2], (0, "OPS: say\n"))

    def test_unchanged_clears_failed(self):
        s = Scratch(self)
        s.config()
        s.worklog(["%d demo-repo on: %s work" % (s.now - 10, TAG)])
        _, out, _ = s.run()
        s.run("--ack", *ack_args(doc_lines(out)))
        self.assertEqual(s.run("--failed", "--speak", "r")[1], "OPS: say\n")
        self.assertEqual(s.run()[1], "OPS: %s\nOPS: unchanged\n" % URL)
        self.assertNotIn("failed", s.state())
        self.assertEqual(s.run("--failed", "--speak", "r")[1], "OPS: say\n")


class People(unittest.TestCase):
    CANARIES = ("canary person alpha", "canary bravo secret")

    def test_people_guard_worklog(self):
        s = Scratch(self)
        s.config()
        with open(s.path("people.md"), "w") as handle:
            handle.write("# People\n- Canary Person Alpha is the CTO here\n> canary bravo secret twelve\n")
        s.worklog(["%d demo-repo on: %s met CANARY PERSON ALPHA IS THE CTO HERE today" % (s.now - 20, TAG),
                   "%d demo-repo moved: Canary Bravo Secret" % (s.now - 10)])
        rc, out, err = s.run()
        self.assertEqual(rc, 0)
        self.assertEqual(err, "ops_sync: people-file text kept out of 2 fields\n")
        for _, _, path, _ in doc_lines(out):
            with open(path, encoding="utf-8") as handle:
                text = handle.read().casefold()
            for canary in self.CANARIES:
                self.assertNotIn(canary, text)
        for canary in self.CANARIES:
            self.assertNotIn(canary, err.casefold())

    def test_people_guard_doc_ids(self):
        # A single-token canary in a wait ref and in a repo name never reaches an id or a path.
        canary = "dana.canary@example.com"
        s = Scratch(self)
        s.config()
        with open(s.path("people.md"), "w") as handle:
            handle.write("- %s\n" % canary)
        s.worklog(["%d %s on: planning" % (s.now - 20, canary),
                   "%d demo-repo wait: mail:%s b1 %s reply" % (s.now - 10, canary, TAG)])
        rc, out, err = s.run()
        self.assertEqual(rc, 0)
        rows = doc_lines(out)
        self.assertEqual(sorted(c for c, _, _, _ in rows), ["sessions", "sessions", "waits"])
        forms = (canary, ops_sync.enc_doc_id(canary), ops_sync.enc_doc_id(canary).replace("~", "%"))
        for _, d, path, _ in rows:
            self.assertRegex(d, ID_RE)
            self.assertNotIn(canary, decode_id(d) or "")
            for form in forms:
                self.assertNotIn(form.casefold(), d.casefold())
                self.assertNotIn(form.casefold(), path.casefold())
        hashed = [d for _, d, _, _ in rows if d.startswith("~h")]
        self.assertEqual(sorted(hashed), sorted([
            "~h" + hashlib.sha256(("repo:" + canary).encode()).hexdigest()[:40],
            "~h" + hashlib.sha256(("mail:%s %s" % (canary, TAG)).encode()).hexdigest()[:40]]))
        # Two fields (repo, ref) and two ids.
        self.assertEqual(err, "ops_sync: people-file text kept out of 4 fields\n")
        # A second run keeps the same ids: the hashed wait stays open, not closed and re-keyed.
        s.run("--ack", *ack_args(rows, 1))
        rc, out, _ = s.run()
        self.assertEqual((rc, out), (0, "OPS: %s\nOPS: unchanged\n" % URL))

    def test_people_guard_docs_already_on_disk(self):
        # Docs written before the guard line existed never go out under their old id or content.
        canary = "dana.canary@example.com"
        s = Scratch(self)
        s.config()
        s.worklog(["%d %s on: planning" % (s.now - 60, canary),
                   "%d demo-repo wait: mail:%s b1 %s reply" % (s.now - 50, canary, TAG),
                   "%d demo-repo wait: gh:demo/app#5 b1 %s ping %s" % (s.now - 40, TAG2, canary)])
        s.run()
        s.worklog(["%d demo-repo moved: gh:demo/app#5 %s merged" % (s.now - 30, TAG2)], mode="a")
        s.run()
        clean_id = "gh:demo~2Fapp~235~20~400f0f0f0f"
        self.assertIn(canary, load(s.path("opsview", "docs", "waits", clean_id + ".json"))["text"])
        with open(s.path("people.md"), "w") as handle:
            handle.write("- %s\n" % canary)
        s.worklog(["%d demo-repo moved: mail:%s %s answered" % (s.now - 20, canary, TAG)], mode="a")
        rc, out, err = s.run()
        self.assertEqual(rc, 0)
        rows = doc_lines(out)
        forms = [f.casefold() for f in (canary, ops_sync.enc_doc_id(canary),
                                        ops_sync.enc_doc_id(canary).replace("~", "%"))]
        for _, d, path, _ in rows:
            with open(path, encoding="utf-8") as handle:
                text = handle.read().casefold()
            self.assertNotIn(canary, (decode_id(d) or "").casefold())
            for form in forms:
                self.assertNotIn(form, d.casefold())
                self.assertNotIn(form, path.casefold())
                self.assertNotIn(form, text)
        ids = {(c, d) for c, d, _, _ in rows}
        wait_h = "~h" + hashlib.sha256(("mail:%s %s" % (canary, TAG)).encode()).hexdigest()[:40]
        self.assertIn(("sessions", "~h" + hashlib.sha256(("repo:" + canary).encode()).hexdigest()[:40]), ids)
        self.assertIn(("waits", wait_h), ids)
        self.assertIn(("waits", clean_id), ids)
        self.assertEqual(load(s.path("opsview", "docs", "waits", wait_h + ".json"))["state"], "closed")
        self.assertEqual(load(s.path("opsview", "docs", "waits", clean_id + ".json"))["text"], "")
        match = re.fullmatch(r"ops_sync: people-file text kept out of ([0-9]+) fields\n", err)
        self.assertIsNotNone(match, err)
        self.assertGreaterEqual(int(match.group(1)), 3)
        # The old files stay on disk (no delete path) and never come back.
        self.assertTrue(os.path.exists(s.path("opsview", "docs", "waits",
                                              ops_sync.enc_doc_id("mail:%s %s" % (canary, TAG)) + ".json")))
        s.run("--ack", *ack_args(rows, 1))
        rc, out, _ = s.run()
        self.assertEqual((rc, out), (0, "OPS: %s\nOPS: unchanged\n" % URL))
        self.assertEqual(load(s.path("opsview", "docs", "waits", wait_h + ".json"))["state"], "closed")

    def test_people_unreadable(self):
        s = Scratch(self)
        s.config()
        s.worklog(["%d demo-repo on: %s work" % (s.now - 10, TAG)])
        with open(s.path("people.md"), "w") as handle:
            handle.write("- someone\n")
        os.chmod(s.path("people.md"), 0)
        rc, out, err = s.run()
        self.assertEqual((rc, out), (1, ""))
        self.assertTrue(err.startswith("ops_sync: "))
        self.assertFalse(os.path.exists(s.path("opsview")))


class Safety(unittest.TestCase):
    def test_clutch_state_untouched(self):
        s = Scratch(self)
        s.config()
        s.worklog(["%d demo-repo on: %s work" % (s.now - 10, TAG),
                   "%d demo-repo wait: gh:demo/app#5 b1 %s review" % (s.now - 5, TAG)])
        for name, text in (("rituals.md", "- standup\n"), ("people.md", "- a person line long enough\n")):
            with open(s.path(name), "w") as handle:
                handle.write(text)
        os.makedirs(s.path("watch"))
        with open(s.path("watch", "w1"), "w") as handle:
            handle.write("armed\n")

        def snapshot():
            kept = {p: h for p, h in tree(s.clutch).items() if "/opsview" not in p[len(s.clutch):]}
            return kept

        before = snapshot()
        _, out, _ = s.run()
        for args in (["--ack"] + ack_args(doc_lines(out)), ["--failed", "r"], ["--failed", "--speak", "r"],
                     ["--ack", "bad"], []):
            s.run(*args)
        self.assertEqual(snapshot(), before)

    def test_state_atomic(self):
        s = Scratch(self)
        s.config()
        s.worklog(["%d demo-repo on: %s work" % (s.now - 10, TAG),
                   "%d other-repo on: more" % (s.now - 5)])
        real = os.replace
        calls = []

        def flaky(src, dst):
            calls.append(dst)
            if len(calls) == 2:
                raise OSError("disk full")
            return real(src, dst)

        out = io.StringIO()
        with unittest.mock.patch.dict(os.environ, {"HOME": s.home}), \
                unittest.mock.patch.object(ops_sync.os, "replace", side_effect=flaky), \
                contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            rc = ops_sync.main([])
        self.assertEqual((rc, out.getvalue()), (1, ""))
        docs = s.path("opsview", "docs", "sessions")
        for name in os.listdir(docs):
            if name.endswith(".json"):
                load(os.path.join(docs, name))
        rc, out, _ = s.run()
        self.assertEqual((rc, len(doc_lines(out))), (0, 2))
        # An ack whose state write fails leaves the old state file whole.
        s.run("--ack", *ack_args(doc_lines(out)[:1]))
        before = s.state_bytes()
        with unittest.mock.patch.dict(os.environ, {"HOME": s.home}), \
                unittest.mock.patch.object(ops_sync.os, "replace", side_effect=OSError("disk full")), \
                contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            rc = ops_sync.main(["--ack"] + ack_args(doc_lines(out)[1:]))
        self.assertNotEqual(rc, 0)
        self.assertEqual(s.state_bytes(), before)

    def test_no_delete_calls(self):
        with open(TOOL) as handle:
            source = handle.read()
        for call in ("os.remove", "os.unlink", "rmtree", ".unlink("):
            self.assertNotIn(call, source)

    def test_future_import_first(self):
        with open(TOOL) as handle:
            source = handle.read()
        self.assertRegex(source, r'^(#[^\n]*\n)*("""[\s\S]*?"""\n)?from __future__ import annotations\n')


if __name__ == "__main__":
    unittest.main()
