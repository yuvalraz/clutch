"""Offline tests for scripts/tablet_inbox.py against temp state dirs.

Run: /usr/bin/python3 -B tests/tablet_inbox_test.py
Every fixture text is invented.
"""
import ast
import contextlib
import fcntl
import io
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import unittest
import unittest.mock

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "..", "scripts", "tablet_inbox.py")
sys.path.insert(0, os.path.join(HERE, "..", "scripts"))
sys.path.insert(0, os.path.join(HERE, "..", "tools", "aipaper"))
import tablet_inbox  # noqa: E402
import pull  # noqa: E402

tablet_inbox.LOCK_WAIT = 0
TODAY = "2026-11-10"


def todo(todo_id, content, day=10, delete=False):
    return {"id": todo_id, "content": content, "todo": 0, "isDelete": delete,
            "day": day, "month": 11, "year": 2026}


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp)
        self.state = os.path.join(self.tmp, "state")
        os.mkdir(self.state)
        self.inbox = os.path.join(self.state, "inbox", "aipaper")
        self.reading = os.path.join(self.state, "aipaper", "reading")
        self.held = os.path.join(self.state, "aipaper", "held")
        self.ledger_path = os.path.join(self.state, "aipaper", "ledger.json")
        self.personal = os.path.join(self.state, "personal.md")
        self.pool = os.path.join(self.state, "captures.md")
        self.work = os.path.join(self.tmp, "work")
        os.mkdir(self.work)
        self.focus = os.path.join(self.work, "focus.md")

    def run_main(self, *argv, stdin=""):
        out, err = io.StringIO(), io.StringIO()
        with unittest.mock.patch("sys.stdin", io.StringIO(stdin)), \
                contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = tablet_inbox.main(["--state-dir", self.state] + list(argv))
        return code, out.getvalue(), err.getvalue()

    def capture(self, section="APP_PAPER", name="Ideas--aaaaaaaa", fmt="notebook",
                pages=(("pageaaaa-1", "p00-pageaaaa.png"),), todos=None, png=True):
        directory = os.path.join(self.inbox, section, name)
        os.makedirs(directory)
        meta = {"appType": section, "noteId": "aaaaaaaa-note", "fileName": name.split("--")[0],
                "folder": [], "format": fmt,
                "pages": [{"file": f, "pageId": p, "order": i, "lastModifiedTime": 1}
                          for i, (p, f) in enumerate(pages)]}
        if todos is not None:
            meta["todos"] = todos
        with open(os.path.join(directory, "note.json"), "w") as handle:
            json.dump(meta, handle)
        if png:
            for _, f in pages:
                with open(os.path.join(directory, f), "wb") as handle:
                    handle.write(b"PNG")
        return directory

    def claim(self):
        code, out, err = self.run_main("claim")
        self.assertEqual((code, err), (0, ""))
        return [json.loads(line) for line in out.splitlines()]

    def claimed(self, **kw):
        self.capture(**kw)
        lines = self.claim()
        self.assertEqual(len(lines), 1)
        return lines[0]

    def route(self, folders, items, pages_read=None, focus=True, extra=()):
        if pages_read is None:
            pages_read = {f: self.page_ids(f) for f in folders}
        argv = ["route", "--work-state-dir", self.work, "--today", TODAY]
        if focus:
            argv += ["--focus-file", self.focus]
        argv += list(extra) + list(folders)
        code, out, err = self.run_main(*argv, stdin=json.dumps({"pages_read": pages_read, "items": items}))
        return code, [json.loads(line) for line in out.splitlines()], err

    def page_ids(self, folder):
        with open(os.path.join(folder, "note.json")) as handle:
            return [p["pageId"] for p in json.load(handle)["pages"]]

    def item(self, folder, text, kind="task", bucket="work", page_id="pageaaaa-1", **extra):
        it = {"folder": folder, "text": text, "kind": kind, "bucket": bucket}
        if "todo_id" not in extra:
            it["page_id"] = page_id
        it.update(extra)
        return it

    def read(self, path):
        with open(path, "rb") as handle:
            return handle.read()

    def text(self, path):
        with open(path) as handle:
            return handle.read()

    def ledger(self):
        with open(self.ledger_path) as handle:
            return json.load(handle)

    def write(self, path, text):
        with open(path, "w") as handle:
            handle.write(text)

    def claims_count(self, folder):
        with open(os.path.join(folder, ".claims")) as handle:
            return handle.read().strip()

    def lapse(self, folder):
        os.utime(folder, (0, 0))

    def snapshot(self):
        paths = (self.focus, self.personal, self.pool, self.ledger_path)
        return [self.read(p) if os.path.exists(p) else None for p in paths]

    def failing_writer(self, *fail_on, error=OSError):
        real = tablet_inbox.replace_file
        calls = [0]

        def writer(path, data, mode):
            calls[0] += 1
            if calls[0] in fail_on:
                raise error("injected")
            return real(path, data, mode)
        return unittest.mock.patch.object(tablet_inbox, "replace_file", writer)


class PureTest(unittest.TestCase):
    def test_norm(self):
        self.assertEqual(tablet_inbox.norm("  Call the Plumber!!  now "), "call the plumber now")

    def test_item_line_is_one_bounded_line(self):
        item = {"text": "# first\nsecond " + "x" * 2048, "kind": "task", "bucket": "work"}
        line = tablet_inbox.item_line(item, TODAY, "focus")
        self.assertNotIn("\n", line)
        self.assertTrue(line.startswith("- [ ] # first second x"))
        self.assertEqual(len(line), len("- [ ] ") + 300)

    def test_item_line_markers(self):
        line = tablet_inbox.item_line
        self.assertEqual(line({"text": "a", "kind": "note", "bucket": "work"}, TODAY, "focus"), "- a")
        self.assertEqual(line({"text": "a", "kind": "action", "bucket": "work"}, TODAY, "personal"), "- [ ] a (work)")
        self.assertEqual(line({"text": "a", "kind": "idea", "bucket": "unsure"}, TODAY, "personal"), "- idea: a (unsure)")
        self.assertEqual(line({"text": "a", "kind": "task", "bucket": "personal", "date": "2026-11-12"},
                              TODAY, "personal"), "- [ ] a (for Thu 11-12)")

    def test_insert_in_section(self):
        ins = tablet_inbox.insert_in_section
        self.assertEqual(ins("", "## H", ["- a"]), "## H\n- a\n")
        self.assertEqual(ins("# Top\nx", "## H", ["- a"]), "# Top\nx\n\n## H\n- a\n")
        self.assertEqual(ins("## H\n- a\n\n## Next\n- n\n", "## H", ["- b"]), "## H\n- a\n- b\n\n## Next\n- n\n")

    def test_overlaps(self):
        self.assertTrue(tablet_inbox.overlaps("/a/b", "/a/b"))
        self.assertTrue(tablet_inbox.overlaps("/a", "/a/b"))
        self.assertTrue(tablet_inbox.overlaps("/a/b/c", "/a/b"))
        self.assertFalse(tablet_inbox.overlaps("/a/b", "/a/bc"))

    def test_script_imports_no_network_module(self):
        banned = {"socket", "http", "urllib", "ssl", "subprocess", "ftplib", "smtplib"}
        with open(SCRIPT) as handle:
            tree = ast.parse(handle.read())
        names = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                names.update(alias.name.split(".")[0] for alias in node.names)
            elif isinstance(node, ast.ImportFrom):
                names.add((node.module or "").split(".")[0])
        self.assertTrue(names)
        self.assertEqual(names & banned, set())


class ClaimTest(Base):
    def test_claim_without_clutch_prints_nothing_and_creates_nothing(self):
        home = os.path.join(self.tmp, "home")
        os.mkdir(home)
        env = dict(os.environ, HOME=home, PYTHONDONTWRITEBYTECODE="1")
        for verb in ("claim", "release"):
            done = subprocess.run([sys.executable, "-B", SCRIPT, verb], env=env,
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertEqual((done.returncode, done.stdout, done.stderr), (0, b"", b""))
        self.assertEqual(os.listdir(home), [])

    def test_claim_with_no_inbox_creates_nothing(self):
        self.assertEqual(self.run_main("claim"), (0, "", ""))
        self.assertEqual(self.run_main("release"), (0, "", ""))
        self.assertEqual(os.listdir(self.state), [])

    def test_claim_ignores_empty_sections_and_stray_files(self):
        os.makedirs(os.path.join(self.inbox, "APP_MEMO"))
        self.write(os.path.join(self.inbox, "stray.txt"), "x")
        os.makedirs(os.path.join(self.inbox, "APP_PAPER"))
        self.write(os.path.join(self.inbox, "APP_PAPER", "stray.txt"), "x")
        self.assertEqual(self.claim(), [])
        self.assertTrue(os.path.isdir(os.path.join(self.inbox, "APP_MEMO")))
        self.assertTrue(os.path.isfile(os.path.join(self.inbox, "APP_PAPER", "stray.txt")))

    def test_claim_reads_a_capture_written_by_the_puller(self):
        puller = pull.Puller("127.0.0.1", 1, self.state)
        page = {"pageId": "pagedddd-1", "order": 0, "lastModifiedTime": 5, "isNote": 1, "data": b"PNG"}
        todos = [todo("t1", "call the plumber"), todo("t2", "water the fern", day=12), todo("t3", "buy stamps")]
        puller.write_note("APP_DAILY", [], {"noteId": "dddddddd-daily"}, "day_2026_11_10", 100,
                          "daily", [page], todos)
        line = self.claim()[0]
        folder = line["folder"]
        self.assertEqual(os.path.dirname(folder), os.path.realpath(self.reading))
        self.assertTrue(os.path.basename(folder).startswith("APP_DAILY__day_2026_11_10--dddddddd__"))
        self.assertEqual(os.listdir(os.path.join(self.inbox, "APP_DAILY")), [])
        self.assertEqual(line["section"], "Daily")
        self.assertEqual(line["note"], "day_2026_11_10")
        self.assertEqual(line["format"], "daily")
        self.assertEqual(line["pages"], [{"file": os.path.join(folder, "p00-pagedddd.png"),
                                          "page_id": "pagedddd-1", "known_lines": []}])
        self.assertEqual(line["todos"], [
            {"todo_id": "t1", "content": "call the plumber", "date": "2026-11-10"},
            {"todo_id": "t2", "content": "water the fern", "date": "2026-11-12"},
            {"todo_id": "t3", "content": "buy stamps", "date": "2026-11-10"}])
        self.assertEqual(self.claims_count(folder), "1")

    def test_claim_moves_capture_into_reading_and_prints_it(self):
        line = self.claimed(pages=(("pageaaaa-1", "p00-pageaaaa.png"), ("pagebbbb-2", "p01-pagebbbb.png")))
        os.remove(os.path.join(line["folder"], "p01-pagebbbb.png"))
        self.lapse(line["folder"])
        line = self.claim()[0]
        self.assertEqual([p["page_id"] for p in line["pages"]], ["pageaaaa-1"])
        self.assertEqual(line["section"], "Paper")
        self.assertEqual(line["todos"], [])

    def test_claim_drops_deleted_and_ledgered_todos(self):
        os.makedirs(os.path.dirname(self.ledger_path))
        self.write(self.ledger_path, json.dumps({"version": 1, "todos": {"t2": "work"}, "pages": {}}))
        line = self.claimed(section="APP_DAILY", name="day_2026_11_10--dddddddd", fmt="daily",
                            todos=[todo("t1", "a", delete=True), todo("t2", "b"), todo("t3", "c")])
        self.assertEqual([t["todo_id"] for t in line["todos"]], ["t3"])

    def test_claim_lists_known_lines_per_page(self):
        os.makedirs(os.path.dirname(self.ledger_path))
        self.write(self.ledger_path, json.dumps(
            {"version": 1, "todos": {}, "pages": {"pageaaaa-1": ["call the plumber"]}}))
        line = self.claimed()
        self.assertEqual(line["pages"][0]["known_lines"], ["call the plumber"])

    def test_claim_moves_unreadable_capture_to_held_once(self):
        for name, body in (("A--1", None), ("B--2", "not json"), ("C--3", "[1]")):
            directory = os.path.join(self.inbox, "APP_PAPER", name)
            os.makedirs(directory)
            if body is not None:
                self.write(os.path.join(directory, "note.json"), body)
        lines = self.claim()
        self.assertEqual([line["held"] for line in lines], ["unreadable"] * 3)
        for line in lines:
            self.assertEqual(os.path.dirname(line["folder"]), os.path.realpath(self.held))
            self.assertTrue(os.path.isdir(line["folder"]))
        self.assertEqual(os.listdir(self.reading), [])
        self.assertEqual(self.claim(), [])

    def test_claim_moves_a_folder_claimed_five_times_to_held(self):
        folders = {}
        for count in ("4", "5", "garbage"):
            directory = os.path.join(self.reading, "APP_PAPER__N%s--1__1" % count)
            os.makedirs(directory)
            self.write(os.path.join(directory, "note.json"), json.dumps(
                {"appType": "APP_PAPER", "fileName": "N", "format": "notebook", "pages": []}))
            self.write(os.path.join(directory, ".claims"), count)
            self.lapse(directory)
            folders[count] = directory
        lines = self.claim()
        by_name = {os.path.basename(line["folder"]): line for line in lines}
        five = by_name[os.path.basename(folders["5"])]
        self.assertEqual(five, {"folder": os.path.join(os.path.realpath(self.held), os.path.basename(folders["5"])),
                                "held": "not read"})
        self.assertTrue(os.path.isdir(five["folder"]))
        self.assertEqual(self.claims_count(folders["4"]), "5")
        self.assertEqual(self.claims_count(folders["garbage"]), "1")
        self.lapse(folders["4"])
        self.lapse(folders["garbage"])
        lines = self.claim()
        self.assertEqual(sorted(str(line.get("held")) for line in lines), ["None", "not read"])
        self.assertTrue(os.path.isdir(os.path.join(self.held, os.path.basename(folders["4"]))))

    def test_claim_skips_a_live_lease_and_takes_a_lapsed_one(self):
        line = self.claimed()
        self.assertEqual(self.claim(), [])
        self.lapse(line["folder"])
        again = self.claim()
        self.assertEqual([l["folder"] for l in again], [line["folder"]])
        self.assertGreater(os.stat(line["folder"]).st_mtime, time.time() - 60)

    def test_claim_waits_for_the_pullers_lock(self):
        self.capture()
        os.makedirs(os.path.join(self.state, "aipaper"))
        with open(os.path.join(self.state, "aipaper", "lock"), "w") as held:
            fcntl.flock(held, fcntl.LOCK_EX)
            code, out, err = self.run_main("claim")
        self.assertEqual((code, out), (3, ""))
        self.assertTrue(err.startswith("tablet: ") and err.count("\n") == 1)
        self.assertEqual(len(os.listdir(os.path.join(self.inbox, "APP_PAPER"))), 1)
        self.assertFalse(os.path.exists(self.reading))

    def test_unusable_ledger_stops_every_verb_untouched(self):
        folder = self.claimed()["folder"]
        self.lapse(folder)
        self.capture(name="Other--bbbbbbbb")
        for body in ("garbage", json.dumps({"version": 2, "todos": {}, "pages": {}})):
            self.write(self.ledger_path, body)
            code, out, err = self.run_main("claim")
            self.assertEqual((code, out), (4, ""))
            self.assertTrue(err.startswith("tablet: ") and err.count("\n") == 1)
            self.assertEqual(os.listdir(os.path.join(self.inbox, "APP_PAPER")), ["Other--bbbbbbbb"])
            self.assertEqual(self.claims_count(folder), "1")
            code, lines, err = self.route([folder], [self.item(folder, "call the plumber")])
            self.assertEqual((code, lines), (4, []))
            self.assertTrue(err.startswith("tablet: ") and err.count("\n") == 1)
            self.assertTrue(os.path.isdir(folder))
            self.assertFalse(os.path.exists(self.personal) or os.path.exists(self.pool))
            self.assertEqual(self.text(self.ledger_path), body)

    def test_missing_state_dir_is_refused_and_not_created(self):
        missing = os.path.join(self.tmp, "nope")
        for verb in ("claim", "release", "route"):
            out, err = io.StringIO(), io.StringIO()
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
                code = tablet_inbox.main(["--state-dir", missing, verb])
            self.assertEqual((code, out.getvalue()), (2, ""))
            self.assertTrue(err.getvalue().startswith("tablet: ") and err.getvalue().count("\n") == 1)
            self.assertFalse(os.path.exists(missing))


class RouteTest(Base):
    def setUp(self):
        super().setUp()
        self.write(self.focus, "# Focus\n\n## Critical path\n- ship it\n")

    def test_route_files_each_bucket_in_its_sink(self):
        folder = self.claimed()["folder"]
        items = [self.item(folder, "draft the quarterly memo"),
                 self.item(folder, "budget is due friday", kind="note"),
                 self.item(folder, "ping the vendor", kind="action"),
                 self.item(folder, "a dashboard for queues", kind="idea"),
                 self.item(folder, "call the plumber", bucket="personal"),
                 self.item(folder, "paint the shed", kind="idea", bucket="personal"),
                 self.item(folder, "read that book", bucket="unsure")]
        code, lines, err = self.route([folder], items)
        self.assertEqual((code, err), (0, ""))
        self.assertEqual(lines, [{"folder": folder, "status": "routed",
                                  "work": ["draft the quarterly memo", "budget is due friday", "ping the vendor"],
                                  "personal": ["call the plumber", "paint the shed"],
                                  "unsure": ["read that book"], "ideas": ["a dashboard for queues"]}])
        self.assertEqual(self.text(self.focus), "# Focus\n\n## Critical path\n- ship it\n\n## From the tablet\n"
                         "- [ ] draft the quarterly memo\n- budget is due friday\n- [ ] ping the vendor\n")
        self.assertEqual(self.text(self.personal), "## 2026-11-10\n- [ ] call the plumber\n"
                         "- idea: paint the shed\n- [ ] read that book (unsure)\n")
        self.assertRegex(self.text(self.pool), r"^\d+ fomo: \[work\] a dashboard for queues \(tablet: Paper Ideas\)\n$")
        self.assertEqual(stat.S_IMODE(os.stat(self.personal).st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(os.stat(self.ledger_path).st_mode), 0o600)
        self.assertEqual(len(self.ledger()["pages"]["pageaaaa-1"]), 7)
        self.assertFalse(os.path.exists(folder))

    def test_route_never_writes_personal_text_to_focus_file(self):
        folder = self.claimed()["folder"]
        items = [self.item(folder, "call the plumber", bucket="personal"),
                 self.item(folder, "read that book", kind="note", bucket="unsure"),
                 self.item(folder, "book the dentist", kind="action", bucket="personal")]
        before = self.read(self.focus)
        self.assertEqual(self.route([folder], items)[0], 0)
        self.assertEqual(self.read(self.focus), before)
        self.assertFalse(os.path.exists(self.pool))

    def test_route_keeps_personal_and_unsure_ideas_out_of_the_pool(self):
        self.write(self.pool, "1 fomo: earlier\n")
        folder = self.claimed()["folder"]
        items = [self.item(folder, "paint the shed", kind="idea", bucket="personal"),
                 self.item(folder, "learn the cello", kind="idea", bucket="unsure")]
        self.assertEqual(self.route([folder], items)[0], 0)
        self.assertEqual(self.text(self.pool), "1 fomo: earlier\n")
        self.assertEqual(self.text(self.personal), "## 2026-11-10\n- idea: paint the shed\n- idea: learn the cello (unsure)\n")

    def test_route_without_focus_file_files_work_in_the_personal_file(self):
        folder = self.claimed()["folder"]
        before = self.read(self.focus)
        items = [self.item(folder, "draft the quarterly memo"), self.item(folder, "budget is due", kind="note")]
        code, lines, _ = self.route([folder], items, focus=False)
        self.assertEqual(code, 0)
        self.assertEqual(lines[0]["work"], ["draft the quarterly memo", "budget is due"])
        self.assertEqual(self.text(self.personal), "## 2026-11-10\n- [ ] draft the quarterly memo (work)\n- budget is due (work)\n")
        self.assertEqual(self.read(self.focus), before)

    def test_route_holds_a_folder_whose_pages_were_not_all_read(self):
        a = self.claimed(pages=(("pageaaaa-1", "p00-pageaaaa.png"), ("pagebbbb-2", "p01-pagebbbb.png")))["folder"]
        b = self.claimed(name="Other--bbbbbbbb")["folder"]
        items = [self.item(a, "call the plumber", bucket="personal"), self.item(b, "paint the shed", bucket="personal")]
        for missing_a in (True, False):
            if not os.path.exists(b):
                os.utime(a, None)  # a live lease: this claim takes only the new copy of b
                b = self.claimed(name="Other--bbbbbbbb")["folder"]
                items[1]["folder"] = b
            # pages_read misses a entirely, then lists one of its two pages.
            pages_read = {b: ["pageaaaa-1"]} if missing_a else {a: ["pageaaaa-1"], b: ["pageaaaa-1"]}
            code, lines, _ = self.route([a, b], items, pages_read=pages_read)
            self.assertEqual(code, 0)
            self.assertEqual(lines[0], {"folder": a, "status": "held", "reason": "not fully read"})
            self.assertEqual(lines[1]["status"], "routed")
            self.assertTrue(os.path.isdir(a))
            self.assertEqual(os.stat(a).st_mtime, 0)
            self.assertEqual(self.claims_count(a), "1")
            self.assertNotIn("plumber", self.text(self.personal))
            self.assertNotIn("call the plumber", json.dumps(self.ledger()))

    def test_route_holds_a_folder_with_an_unfiled_new_typed_task(self):
        folder = self.claimed(section="APP_DAILY", name="day_2026_11_10--dddddddd", fmt="daily",
                              todos=[todo("t1", "call the plumber"), todo("t2", "buy stamps")])["folder"]
        items = [self.item(folder, "call the plumber", bucket="personal", todo_id="t1")]
        code, lines, _ = self.route([folder], items)
        self.assertEqual(lines, [{"folder": folder, "status": "held", "reason": "not fully read"}])
        self.assertFalse(os.path.exists(self.personal) or os.path.exists(self.ledger_path))

    def test_route_typed_task_coverage_spans_the_batch(self):
        kw = dict(section="APP_DAILY", fmt="daily", todos=[todo("t1", "call the plumber")],
                  pages=(("pageaaaa-1", "p00-pageaaaa.png"), ("pagebbbb-2", "p01-pagebbbb.png")))
        a = self.claimed(name="day_2026_11_10--aaaaaaaa", **kw)["folder"]
        b = self.claimed(name="day_2026_11_10--bbbbbbbb", **kw)["folder"]
        items = [self.item(b, "call the plumber", bucket="personal", todo_id="t1")]
        code, lines, _ = self.route([a, b], items)
        self.assertEqual([line["status"] for line in lines], ["routed", "routed"])
        self.assertEqual(self.text(self.personal).count("call the plumber"), 1)
        self.assertEqual(self.ledger()["todos"], {"t1": "personal"})
        # B also missing a page: A routes, B is held and still holds the task.
        os.remove(self.personal)
        os.remove(self.ledger_path)
        a = self.claimed(name="day_2026_11_10--aaaaaaaa", **kw)["folder"]
        b = self.claimed(name="day_2026_11_10--bbbbbbbb", **kw)["folder"]
        items = [self.item(b, "call the plumber", bucket="personal", todo_id="t1")]
        code, lines, _ = self.route([a, b], items, pages_read={a: self.page_ids(a), b: ["pageaaaa-1"]})
        self.assertEqual([line["status"] for line in lines], ["routed", "held"])
        self.assertFalse(os.path.exists(a))
        self.assertTrue(os.path.isdir(b))
        self.assertFalse(os.path.exists(self.personal))
        self.assertNotIn("t1", self.ledger()["todos"] if os.path.exists(self.ledger_path) else {})
        self.lapse(b)
        self.assertEqual([t["todo_id"] for t in self.claim()[0]["todos"]], ["t1"])

    def test_route_holds_folder_when_focus_file_missing(self):
        os.remove(self.focus)
        a = self.claimed()["folder"]
        b = self.claimed(name="Other--bbbbbbbb")["folder"]
        items = [self.item(a, "draft the quarterly memo"), self.item(a, "call the plumber", bucket="personal"),
                 self.item(b, "paint the shed", bucket="personal")]
        code, lines, _ = self.route([a, b], items)
        self.assertEqual(code, 0)
        self.assertEqual(lines[0], {"folder": a, "status": "held", "reason": "focus file missing"})
        self.assertEqual(lines[1]["status"], "routed")
        self.assertFalse(os.path.exists(self.focus))
        self.assertNotIn("plumber", self.text(self.personal))
        self.assertNotIn("draft the quarterly memo", json.dumps(self.ledger()))
        self.assertEqual(os.stat(a).st_mtime, 0)

    def test_route_resets_the_claim_count_when_held_for_its_own_reasons(self):
        os.remove(self.focus)
        a = self.claimed()["folder"]
        code, lines, _ = self.route([a], [self.item(a, "draft the quarterly memo")])
        self.assertEqual(lines[0]["reason"], "focus file missing")
        self.assertFalse(os.path.exists(os.path.join(a, ".claims")))
        self.assertEqual(os.stat(a).st_mtime, 0)
        self.write(self.focus, "# Focus\n")
        self.lapse(a)
        self.assertEqual(len(self.claim()), 1)
        self.assertEqual(self.claims_count(a), "1")
        with self.failing_writer(1):
            code, lines, err = self.route([a], [self.item(a, "draft the quarterly memo")])
        # A write failure may last, so it keeps the count: MAX_CLAIMS bounds it.
        self.assertEqual(lines[0]["reason"], "write failed")
        self.assertEqual(self.claims_count(a), "1")
        self.assertEqual(os.stat(a).st_mtime, 0)
        self.assertEqual(err, "tablet: %s: write failed (OSError: injected)\n" % os.path.basename(a))

    def test_route_lasting_write_failure_ends_in_held(self):
        with open(self.focus, "wb") as handle:
            handle.write(b"# Focus\n\xff\xfe not utf-8\n")
        a = self.claimed()["folder"]
        for _ in range(tablet_inbox.MAX_CLAIMS):
            code, lines, err = self.route([a], [self.item(a, "draft the quarterly memo")])
            self.assertEqual((code, lines[0]["reason"]), (0, "write failed"))
            self.assertIn("UnicodeDecodeError", err)
            claimed = self.claim()
        self.assertEqual(claimed, [{"folder": os.path.join(os.path.realpath(self.held), os.path.basename(a)),
                                    "held": "not read"}])

    def test_route_creates_then_extends_the_tablet_section(self):
        a = self.claimed()["folder"]
        self.route([a], [self.item(a, "draft the quarterly memo")])
        self.assertTrue(self.text(self.focus).endswith("\n## From the tablet\n- [ ] draft the quarterly memo\n"))
        self.write(self.focus, "# Focus\n\n## From the tablet\n- [ ] one\n\n## Notes\n- n\n")
        b = self.claimed(name="Other--bbbbbbbb")["folder"]
        self.route([b], [self.item(b, "ping the vendor", kind="action")])
        self.assertEqual(self.text(self.focus),
                         "# Focus\n\n## From the tablet\n- [ ] one\n- [ ] ping the vendor\n\n## Notes\n- n\n")

    def test_route_personal_block_per_day(self):
        a = self.claimed()["folder"]
        self.route([a], [self.item(a, "call the plumber", bucket="personal")], extra=["--today", "2026-11-09"])
        b = self.claimed(name="B--bbbbbbbb")["folder"]
        self.route([b], [self.item(b, "paint the shed", bucket="personal")])
        c = self.claimed(name="C--cccccccc")["folder"]
        self.route([c], [self.item(c, "water the fern", bucket="personal")])
        self.assertEqual(self.text(self.personal), "## 2026-11-09\n- [ ] call the plumber\n\n"
                         "## 2026-11-10\n- [ ] paint the shed\n- [ ] water the fern\n")

    def test_route_other_day_carries_its_date(self):
        a = self.claimed()["folder"]
        self.route([a], [self.item(a, "call the plumber", bucket="personal", date="2026-11-12"),
                         self.item(a, "draft the memo", date="2026-11-12")])
        self.assertIn("- [ ] call the plumber (for Thu 11-12)\n", self.text(self.personal))
        self.assertIn("- [ ] draft the memo (for Thu 11-12)\n", self.text(self.focus))

    def test_route_fomo_line_format(self):
        self.write(self.pool, "1 fomo: earlier")
        a = self.claimed(section="APP_MEETING", name="Standup--aaaaaaaa")["folder"]
        before = int(time.time())
        self.route([a], [self.item(a, "a dashboard  for\nqueues", kind="idea")])
        first, second = self.text(self.pool).splitlines()
        self.assertEqual(first, "1 fomo: earlier")
        epoch, rest = second.split(" ", 1)
        self.assertTrue(before <= int(epoch) <= int(time.time()))
        self.assertEqual(rest, "fomo: [work] a dashboard for queues (tablet: Meeting Standup)")

    def test_route_drops_ledgered_todo_and_known_page_line(self):
        os.makedirs(os.path.dirname(self.ledger_path))
        self.write(self.ledger_path, json.dumps(
            {"version": 1, "todos": {"t1": "work"}, "pages": {"pageaaaa-1": ["Call the plumber!"]}}))
        a = self.claimed(section="APP_DAILY", name="day_2026_11_10--dddddddd", fmt="daily",
                         todos=[todo("t1", "draft the memo")])["folder"]
        items = [self.item(a, "draft the memo", todo_id="t1"),
                 self.item(a, "call the plumber", bucket="personal"),
                 self.item(a, "paint the shed", bucket="personal"),
                 self.item(a, "Paint the shed.", bucket="personal")]
        code, lines, _ = self.route([a], items)
        self.assertEqual(lines[0]["personal"], ["paint the shed"])
        self.assertEqual(lines[0]["work"], [])
        self.assertEqual(self.text(self.personal), "## 2026-11-10\n- [ ] paint the shed\n")
        self.assertNotIn("draft the memo", self.text(self.focus))

    def test_route_is_idempotent(self):
        items = lambda f: [self.item(f, "draft the memo"), self.item(f, "call the plumber", bucket="personal"),
                           self.item(f, "a dashboard", kind="idea")]
        a = self.claimed()["folder"]
        self.route([a], items(a))
        after = self.snapshot()
        b = self.claimed()["folder"]
        code, lines, _ = self.route([b], items(b))
        self.assertEqual(lines[0], {"folder": b, "status": "routed", "work": [], "personal": [], "unsure": [], "ideas": []})
        self.assertEqual(self.snapshot(), after)

    def test_route_retires_a_folder_with_no_items(self):
        a = self.claimed()["folder"]
        code, lines, _ = self.route([a], [])
        self.assertEqual(lines, [{"folder": a, "status": "routed", "work": [], "personal": [], "unsure": [], "ideas": []}])
        self.assertFalse(os.path.exists(a))

    def test_route_rejects_bad_input_and_writes_nothing(self):
        a = self.claimed(section="APP_DAILY", name="day_2026_11_10--dddddddd", fmt="daily",
                         todos=[todo("t1", "draft the memo")])["folder"]
        b = self.claimed(name="Other--bbbbbbbb")["folder"]
        ok = self.item(a, "call the plumber", bucket="personal")
        full = {a: ["pageaaaa-1"], b: ["pageaaaa-1"]}

        def without(key):
            it = dict(ok)
            del it[key]
            return it
        bad_payloads = [
            "not json",
            json.dumps([ok]),
            json.dumps({"pages_read": full}),
            json.dumps({"pages_read": [], "items": []}),
            json.dumps({"pages_read": {"/elsewhere": []}, "items": []}),
            json.dumps({"pages_read": {a: "pageaaaa-1"}, "items": []}),
            json.dumps({"pages_read": {a: [1]}, "items": []}),
        ] + [json.dumps({"pages_read": full, "items": [it]}) for it in (
            without("text"), dict(ok, text="  "), dict(ok, kind="chore"), dict(ok, bucket="family"),
            dict(ok, todo_id="t1"), without("page_id"), dict(without("page_id"), todo_id="t9"),
            dict(without("page_id"), todo_id="t1", folder=b), dict(ok, folder="/elsewhere"),
            dict(ok, date="tomorrow"), "a string")]
        base = ["route", "--work-state-dir", self.work, "--today", TODAY]
        for payload in bad_payloads:
            code, out, err = self.run_main(*(base + [a, b]), stdin=payload)
            self.assertEqual((code, out), (2, ""), payload)
            self.assertTrue(err.startswith("tablet: ") and err.count("\n") == 1, (payload, err))
        good = json.dumps({"pages_read": full, "items": [ok]})
        for argv in (["route", "--today", TODAY], ["route", "--focus-file", self.focus, a, b],
                     base + ["--today", "11/10", a, b]):
            code, out, err = self.run_main(*argv, stdin=good)
            self.assertEqual((code, out), (2, ""), argv)
            self.assertTrue(err.startswith("tablet: ") and err.count("\n") == 1, (argv, err))
        self.assertTrue(os.path.isdir(a) and os.path.isdir(b))
        self.assertFalse(os.path.exists(self.personal) or os.path.exists(self.ledger_path))
        # Positive control: the same call with good input routes.
        code, out, err = self.run_main(*(base + [a, b]), stdin=good)
        self.assertEqual((code, err), (0, ""))

    def test_route_refuses_a_focus_file_inside_the_state_dir(self):
        a = self.claimed()["folder"]
        link = os.path.join(self.work, "link.md")
        os.symlink(os.path.join(self.state, "x.md"), link)
        for focus in (os.path.join(self.state, "x.md"), link):
            argv = ["route", "--work-state-dir", self.work, "--focus-file", focus, a]
            code, out, err = self.run_main(*argv, stdin=json.dumps(
                {"pages_read": {a: ["pageaaaa-1"]}, "items": [self.item(a, "draft the memo")]}))
            self.assertEqual((code, out), (2, ""))
            self.assertTrue(err.startswith("tablet: ") and err.count("\n") == 1)
        self.assertTrue(os.path.isdir(a))
        self.assertEqual(sorted(os.listdir(self.state)), ["aipaper", "inbox"])

    def test_route_refuses_a_state_dir_inside_the_work_state_dir(self):
        a = self.claimed()["folder"]
        inside = os.path.join(self.state, "sub")
        for work in (self.state, self.tmp, inside):
            argv = ["route", "--work-state-dir", work, a]
            code, out, err = self.run_main(*argv, stdin=json.dumps(
                {"pages_read": {a: ["pageaaaa-1"]}, "items": [self.item(a, "call the plumber", bucket="personal")]}))
            self.assertEqual((code, out), (2, ""), work)
            self.assertTrue(err.startswith("tablet: ") and err.count("\n") == 1)
        self.assertTrue(os.path.isdir(a))
        self.assertFalse(os.path.exists(self.personal))

    def test_route_expands_a_tilde_before_the_overlap_checks(self):
        a = self.claimed()["folder"]
        payload = json.dumps({"pages_read": {a: ["pageaaaa-1"]}, "items": [self.item(a, "draft the memo")]})
        with unittest.mock.patch.dict(os.environ, {"HOME": self.tmp}):
            for argv in (["--work-state-dir", "~", "--focus-file", self.focus],
                         ["--work-state-dir", self.work, "--focus-file", "~/state/x.md"]):
                code, out, err = self.run_main(*(["route"] + argv + [a]), stdin=payload)
                self.assertEqual((code, out), (2, ""), argv)
            code, lines, err = self.route([a], [self.item(a, "draft the memo")], focus=False,
                                          extra=["--focus-file", "~/work/focus.md"])
        self.assertEqual((code, err), (0, ""))
        self.assertIn("- [ ] draft the memo\n", self.text(self.focus))

    def test_route_refuses_folder_outside_reading(self):
        a = self.claimed()["folder"]
        outside = os.path.join(self.tmp, "outside")
        os.mkdir(outside)
        link = os.path.join(self.reading, "link")
        os.symlink(outside, link)
        for folder in (os.path.join(self.reading, "..", "..", "inbox"), outside, link, self.reading):
            argv = ["route", "--work-state-dir", self.work, folder]
            code, out, _ = self.run_main(*argv, stdin=json.dumps({"pages_read": {folder: []}, "items": []}))
            self.assertEqual((code, out), (2, ""), folder)
        self.assertTrue(os.path.isdir(outside) and os.path.isdir(a) and os.path.isdir(self.inbox))

    def test_route_reports_a_gone_folder(self):
        a = self.claimed()["folder"]
        b = self.claimed(name="Other--bbbbbbbb")["folder"]
        pages_read = {a: ["pageaaaa-1"], b: ["pageaaaa-1"]}
        shutil.rmtree(a)
        code, lines, _ = self.route([a, b], [self.item(a, "call the plumber", bucket="personal"),
                                              self.item(b, "paint the shed", bucket="personal")], pages_read=pages_read)
        self.assertEqual(lines[0], {"folder": a, "status": "gone"})
        self.assertEqual(lines[1]["status"], "routed")
        self.assertNotIn("plumber", self.text(self.personal))

    def test_route_deletes_folder_only_after_the_ledger_write(self):
        a = self.claimed()["folder"]
        seen = []

        def rmtree(path, *args, **kw):
            seen.append(json.dumps(self.ledger()))
            raise OSError("injected")
        items = [self.item(a, "call the plumber", bucket="personal")]
        with unittest.mock.patch.object(tablet_inbox.shutil, "rmtree", rmtree):
            self.assertEqual(self.route([a], items)[0], 0)
        self.assertIn("call the plumber", seen[0])
        self.assertTrue(os.path.isdir(a))
        code, lines, _ = self.route([a], items)
        self.assertEqual((code, lines[0]["status"], lines[0]["personal"]), (0, "routed", []))
        self.assertFalse(os.path.exists(a))
        self.assertEqual(self.text(self.personal).count("call the plumber"), 1)

    def test_route_failed_write_records_nothing(self):
        a = self.claimed()["folder"]
        before = self.snapshot()
        with self.failing_writer(2):
            code, lines, err = self.route([a], [self.item(a, "draft the memo"),
                                                self.item(a, "call the plumber", bucket="personal")])
        self.assertEqual((code, lines), (0, [{"folder": a, "status": "held", "reason": "write failed"}]))
        self.assertEqual(self.snapshot(), before)
        self.assertTrue(os.path.isdir(a))

    def test_route_ledger_write_failure_restores_every_sink(self):
        self.write(self.pool, "1 fomo: earlier\n")
        a = self.claimed()["folder"]
        items = [self.item(a, "draft the memo"), self.item(a, "call the plumber", bucket="personal"),
                 self.item(a, "a dashboard", kind="idea")]
        before = self.snapshot()
        with self.failing_writer(4):
            code, lines, err = self.route([a], items)
        cause = "tablet: %s: write failed (OSError: injected)\n" % os.path.basename(a)
        self.assertEqual((code, lines[0]["reason"], err), (0, "write failed", cause))
        self.assertEqual(self.snapshot(), before)
        self.assertFalse(os.path.exists(self.personal))
        # A restore that fails too is named on stderr; the folder is still held.
        with self.failing_writer(4, 5):
            code, lines, err = self.route([a], items)
        self.assertEqual((code, lines[0]["reason"]), (0, "write failed"))
        self.assertEqual(err, cause + "tablet: restore failed captures.md\n")
        self.assertTrue(os.path.isdir(a))

    def test_route_unexpected_error_is_held_and_restored(self):
        a = self.claimed()["folder"]
        b = self.claimed(name="Other--bbbbbbbb")["folder"]
        before = self.snapshot()
        with self.failing_writer(2, error=ValueError):
            code, lines, _ = self.route([a, b], [self.item(a, "draft the memo"),
                                                 self.item(a, "call the plumber", bucket="personal"),
                                                 self.item(b, "paint the shed", bucket="personal")])
        self.assertEqual(code, 0)
        self.assertEqual(lines[0], {"folder": a, "status": "held", "reason": "write failed"})
        self.assertEqual(lines[1]["status"], "routed")
        self.assertEqual(self.read(self.focus), before[0])
        self.assertEqual(self.text(self.personal), "## 2026-11-10\n- [ ] paint the shed\n")


class ReleaseTest(Base):
    def test_release_lapses_every_lease(self):
        self.capture()
        self.capture(name="Other--bbbbbbbb")
        folders = [line["folder"] for line in self.claim()]
        self.assertEqual(self.run_main("release"), (0, "", ""))
        for folder in folders:
            self.assertEqual(os.stat(folder).st_mtime, 0)
        self.assertEqual(len(self.claim()), 2)

    def test_five_refused_routes_in_a_row_do_not_hold_the_folder(self):
        folder = self.claimed()["folder"]
        for _ in range(5):
            code, _, _ = self.route([folder], [self.item(folder, "x", kind="chore")])
            self.assertEqual(code, 2)
            self.assertEqual(self.run_main("release"), (0, "", ""))
            lines = self.claim()
            self.assertEqual([line.get("held") for line in lines], [None])
        self.assertTrue(os.path.isdir(folder))
        self.assertFalse(os.path.exists(self.held))


class HardeningTest(Base):
    def setUp(self):
        super().setUp()
        self.write(self.focus, "# Focus\n")

    def test_route_writes_through_symlinked_sinks(self):
        target = os.path.join(self.work, "today.md")
        os.rename(self.focus, target)
        os.symlink(target, self.focus)
        elsewhere = os.path.join(self.tmp, "elsewhere")
        os.mkdir(elsewhere)
        os.symlink(os.path.join(elsewhere, "personal.md"), self.personal)
        a = self.claimed()["folder"]
        code, lines, err = self.route([a], [self.item(a, "draft the memo"),
                                            self.item(a, "call the plumber", bucket="personal")])
        self.assertEqual((code, err, lines[0]["status"]), (0, "", "routed"))
        self.assertTrue(os.path.islink(self.focus) and os.path.islink(self.personal))
        self.assertIn("- [ ] draft the memo\n", self.text(target))
        self.assertEqual(self.text(os.path.join(elsewhere, "personal.md")), "## 2026-11-10\n- [ ] call the plumber\n")

    def test_route_refuses_a_personal_file_linked_into_the_work_state_dir(self):
        os.symlink(os.path.join(self.work, "leak.md"), self.personal)
        a = self.claimed()["folder"]
        code, lines, err = self.route([a], [self.item(a, "call the plumber", bucket="personal")])
        self.assertEqual((code, lines), (2, []))
        self.assertTrue(err.startswith("tablet: ") and err.count("\n") == 1)
        self.assertFalse(os.path.exists(os.path.join(self.work, "leak.md")))

    def test_claim_skips_an_entry_it_cannot_rename(self):
        self.capture(name="L" * 240)
        self.capture(name="Other--bbbbbbbb")
        for _ in range(2):
            code, out, err = self.run_main("claim")
            self.assertEqual(code, 0)
            self.assertTrue(err.startswith("tablet: ") and err.count("\n") == 1, err)
        self.assertEqual(len(out.splitlines()), 0)
        self.assertTrue(os.path.isdir(os.path.join(self.inbox, "APP_PAPER", "L" * 240)))
        self.assertEqual(len(os.listdir(self.reading)), 1)

    def test_an_os_error_is_one_line_and_rc_1(self):
        self.capture()
        os.makedirs(os.path.join(self.state, "aipaper", "lock"))
        code, out, err = self.run_main("claim")
        self.assertEqual((code, out), (1, ""))
        self.assertTrue(err.startswith("tablet: ") and err.count("\n") == 1, err)

    def test_route_goes_on_when_a_hold_cannot_touch_its_folder(self):
        a = self.claimed()["folder"]
        b = self.claimed(name="Other--bbbbbbbb")["folder"]
        real_utime = os.utime

        def utime(path, *args, **kw):
            if path == a:
                raise PermissionError("injected")
            return real_utime(path, *args, **kw)
        with unittest.mock.patch.object(tablet_inbox.os, "utime", utime):
            code, lines, err = self.route([a, b], [self.item(b, "paint the shed", bucket="personal")],
                                          pages_read={b: ["pageaaaa-1"]})
        self.assertEqual(code, 0)
        self.assertEqual(lines[0], {"folder": a, "status": "held", "reason": "not fully read"})
        self.assertEqual(lines[1]["status"], "routed")
        self.assertTrue(err.startswith("tablet: ") and err.count("\n") == 1, err)

    def test_route_files_every_symbol_only_line(self):
        a = self.claimed()["folder"]
        items = [self.item(a, t, bucket="personal") for t in ("→ ★", "?!", "\U0001F642", "?!")]
        code, lines, _ = self.route([a], items)
        self.assertEqual(lines[0]["personal"], ["→ ★", "?!", "\U0001F642"])
        self.assertEqual(self.text(self.personal).count("- [ ] "), 3)

    @unittest.skipUnless(sys.platform == "darwin", "case-insensitive default filesystem")
    def test_route_refuses_a_case_variant_of_the_state_dir(self):
        a = self.claimed()["folder"]
        variant = os.path.join(self.tmp, "STATE")
        for argv in (["--work-state-dir", variant], ["--work-state-dir", self.work, "--focus-file",
                                                     os.path.join(variant, "x.md")]):
            code, out, _ = self.run_main(*(["route"] + argv + [a]), stdin=json.dumps(
                {"pages_read": {a: ["pageaaaa-1"]}, "items": [self.item(a, "draft the memo")]}))
            self.assertEqual((code, out), (2, ""), argv)

    def test_pool_line_stays_one_line_whatever_the_note_name(self):
        a = self.claimed()["folder"]
        meta_path = os.path.join(a, "note.json")
        with open(meta_path) as handle:
            meta = json.load(handle)
        meta["fileName"] = "Ideas\n1 fomo: forged"
        self.write(meta_path, json.dumps(meta))
        self.route([a], [self.item(a, "a dashboard", kind="idea")])
        pool = self.text(self.pool).splitlines()
        self.assertEqual(len(pool), 1)
        self.assertTrue(pool[0].endswith("(tablet: Paper Ideas 1 fomo: forged)"))

    def test_claim_does_not_follow_a_symlinked_entry(self):
        outside = os.path.join(self.tmp, "outside")
        os.makedirs(os.path.join(outside, "Cap--1"))
        self.write(os.path.join(outside, "Cap--1", "note.json"), json.dumps({"fileName": "x", "pages": []}))
        os.makedirs(os.path.join(self.inbox, "APP_PAPER"))
        os.symlink(os.path.join(outside, "Cap--1"), os.path.join(self.inbox, "APP_PAPER", "Link--1"))
        os.symlink(outside, os.path.join(self.inbox, "APP_MEMO"))
        code, out, err = self.run_main("claim")
        self.assertEqual((code, out), (0, ""))
        self.assertEqual(err.count("\n"), 2, err)
        self.assertTrue(os.path.islink(os.path.join(self.inbox, "APP_PAPER", "Link--1")))
        self.assertTrue(os.path.isdir(os.path.join(outside, "Cap--1")))
        self.assertEqual(os.listdir(self.reading), [])

    def test_route_reports_a_gone_folder_with_a_typed_task_item(self):
        a = self.claimed(section="APP_DAILY", name="day_2026_11_10--dddddddd", fmt="daily",
                         todos=[todo("t1", "draft the memo")])["folder"]
        b = self.claimed(name="Other--bbbbbbbb")["folder"]
        shutil.rmtree(a)
        code, lines, err = self.route([a, b], [self.item(a, "draft the memo", todo_id="t1"),
                                               self.item(b, "paint the shed", bucket="personal")],
                                      pages_read={a: ["pageaaaa-1"], b: ["pageaaaa-1"]})
        self.assertEqual((code, err), (0, ""))
        self.assertEqual([line["status"] for line in lines], ["gone", "routed"])

    def test_route_refuses_a_page_id_not_in_its_folder(self):
        a = self.claimed()["folder"]
        code, lines, err = self.route([a], [self.item(a, "call the plumber", bucket="personal", page_id="nope")])
        self.assertEqual((code, lines), (2, []))
        self.assertTrue(err.startswith("tablet: ") and err.count("\n") == 1)
        self.assertTrue(os.path.isdir(a))

    def test_replace_file_leaves_no_tmp_on_failure(self):
        target = os.path.join(self.work, "is-a-dir")
        os.mkdir(target)
        with self.assertRaises(OSError):
            tablet_inbox.replace_file(target, b"x", 0o600)
        self.assertFalse(os.path.exists(target + ".tmp"))


if __name__ == "__main__":
    unittest.main()
