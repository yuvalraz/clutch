"""Offline tests for pull.py against an in-process fake device on 127.0.0.1.

Run: /usr/bin/python3 tools/aipaper/test_pull.py
"""
import collections
import contextlib
import fcntl
import http.server
import io
import json
import os
import socket
import sys
import tempfile
import threading
import unittest
import urllib.parse
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pull  # noqa: E402

pull.BACKOFF = 0


def note(app, note_id, name, stamp, pid="DIR_1", **extra):
    item = {"appType": app, "fileName": name, "isFolder": False, "noteId": note_id,
            "notePId": pid, "updateTime": stamp}
    item.update(extra)
    return item


def folder(app, folder_id, name):
    return {"appType": app, "fileName": name, "isFolder": True, "noteId": folder_id,
            "notePId": "DIR_1", "updateTime": 0}


def build_zip(members):
    blob = io.BytesIO()
    with zipfile.ZipFile(blob, "w") as archive:
        for name, data in members.items():
            archive.writestr(name, data if isinstance(data, bytes) else json.dumps(data))
    return blob.getvalue()


def notebook(name, pages):
    """pages: (page id, order, lastModifiedTime, image bytes or None for a blank page)."""
    members = {name + "_PageListFileInfo.json": [
        {"id": pid, "order": order, "lastModifiedTime": modified} for pid, order, modified, _ in pages]}
    for pid, _, _, image in pages:
        if image is not None:
            members["screenshotBmp_%s.png" % pid] = image
    return build_zip(members)


class Fake:
    """The three LAN Transfer endpoints, served from an in-memory tree."""

    def __init__(self):
        self.tree = {}                 # (appType, folderId) -> [items]
        self.archives = {}             # noteId -> bytes that /download returns
        self.package_code = {}         # noteId -> error code from /packageFile
        self.fail_listing = set()      # appTypes whose listing answers code 500
        self.reset_download = set()    # noteIds whose download drops the connection
        self.die_at_download = None    # from this download on (1-based) the device is gone
        self.paths = {}
        self.server = None
        self.reset_counts()

    def reset_counts(self):
        self.counts = collections.Counter()
        self.lines = []
        self.headers = []
        self.queries = []
        self.downloads = 0

    def start(self):
        self.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.server.fake = self
        threading.Thread(target=self.server.serve_forever, kwargs={"poll_interval": 0.01},
                         daemon=True).start()
        return self.server.server_address[1]

    def stop(self):
        if self.server:
            server, self.server = self.server, None
            server.shutdown()
            server.server_close()

    def listed(self):
        return [(q["appType"], q["folderId"]) for path, q in self.queries if path == "/getChildFolderList"]

    def packaged(self):
        return [q for path, q in self.queries if path == "/packageFile"]


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass

    def reply(self, body, kind="application/json"):
        if not isinstance(body, bytes):
            body = json.dumps(body).encode()
        self.send_response(200)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        fake = self.server.fake
        url = urllib.parse.urlsplit(self.path)
        query = dict(urllib.parse.parse_qsl(url.query, keep_blank_values=True))
        fake.counts[url.path] += 1
        fake.lines.append(self.requestline)
        fake.headers.append({k.lower(): v.lower() for k, v in self.headers.items()})
        fake.queries.append((url.path, query))
        if url.path == "/getChildFolderList":
            if query["appType"] in fake.fail_listing:
                return self.reply({"code": 500, "msg": "boom", "reguestId": ""})
            return self.reply({"code": 200, "msg": "",
                               "data": fake.tree.get((query["appType"], query["folderId"]), [])})
        if url.path == "/packageFile":
            note_id = query["fileUrl"]
            if note_id in fake.package_code:
                return self.reply({"code": fake.package_code[note_id], "msg": "no", "reguestId": ""})
            path = "/sd/down load/%d/%s" % (len(fake.paths), query["fileName"])
            fake.paths[path] = note_id
            return self.reply({"code": 200, "data": path, "msg": ""})
        if url.path == "/download":
            fake.downloads += 1
            note_id = fake.paths[query["filePath"]]
            if fake.die_at_download and fake.downloads >= fake.die_at_download:
                fake.stop()  # the listening port closes before this connection drops
                self.close_connection = True
                return None
            if note_id in fake.reset_download:
                self.close_connection = True
                return None
            return self.reply(fake.archives[note_id], "application/octet-stream")
        return self.reply({"code": 404, "msg": "unknown route"})


class PullTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = tmp.name
        self.state = os.path.join(self.root, "state")
        os.mkdir(self.state)
        self.inbox = os.path.join(self.state, "inbox", "aipaper")
        self.journal_path = os.path.join(self.state, "aipaper", "journal.json")
        self.fake = Fake()
        self.addCleanup(self.fake.stop)
        self.port = self.fake.start()
        env = dict(os.environ)
        self.addCleanup(lambda: (os.environ.clear(), os.environ.update(env)))
        os.environ.pop("CLUTCH_AIPAPER_HOST", None)

    def run_pull(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = pull.main(list(argv))
        return code, out.getvalue(), err.getvalue()

    def pull(self, expect=0):
        self.fake.reset_counts()
        code, out, err = self.run_pull("--host", "127.0.0.1", "--port", str(self.port),
                                       "--state-dir", self.state)
        self.assertEqual(code, expect, err)
        return out, err

    def journal(self):
        with open(self.journal_path) as handle:
            return json.load(handle)

    def note_dir(self, app, name):
        return os.path.join(self.inbox, app, name)

    def files(self, app, name):
        return sorted(os.listdir(self.note_dir(app, name)))

    def note_json(self, app, name):
        with open(os.path.join(self.note_dir(app, name), "note.json")) as handle:
            return json.load(handle)

    def read(self, app, name, filename):
        with open(os.path.join(self.note_dir(app, name), filename), "rb") as handle:
            return handle.read()

    def closed_port(self):
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            return sock.getsockname()[1]

    def two_pages(self, stamp=1000, second=(950, b"B1")):
        """One Paper note, two pages, inside the user folder Work."""
        self.fake.tree[("APP_PAPER", "")] = [folder("APP_PAPER", "f-work", "Work")]
        self.fake.tree[("APP_PAPER", "f-work")] = [
            note("APP_PAPER", "aaaaaaaa-1111", "Plan", stamp, pid="f-work")]
        self.fake.archives["aaaaaaaa-1111"] = notebook("Plan", [
            ("pageaaaa-1", 0, 900, b"A1"), ("pagebbbb-2", 1, second[0], second[1])])

    def add_new(self, app, note_id, name, stamp=5000, image=b"IMG", **extra):
        """A one-page notebook note that was not there at baseline."""
        self.fake.tree.setdefault((app, ""), []).append(note(app, note_id, name, stamp, **extra))
        self.fake.archives[note_id] = notebook(name, [("p-" + note_id, 0, stamp, image)])

    # 1
    def test_baseline_journals_every_note_and_downloads_nothing(self):
        self.fake.tree[("APP_PAPER", "")] = [
            folder("APP_PAPER", "PNG Template", "Image templates"),
            folder("APP_PAPER", "f-user", "Work"),
            note("APP_PAPER", "n-root", "Root note", 100)]
        self.fake.tree[("APP_PAPER", "PNG Template")] = [note("APP_PAPER", "n-asset", "Grid", 1)]
        self.fake.tree[("APP_PAPER", "f-user")] = [note("APP_PAPER", "n-inner", "Inner", 200, pid="f-user")]
        self.fake.tree[("APP_MEETING", "")] = [
            folder("APP_MEETING", "Audio File", "Audio files"), note("APP_MEETING", "n-meet", "Sync", 300)]
        self.fake.tree[("APP_MEETING", "Audio File")] = [note("APP_MEETING", "n-audio", "Rec", 1)]
        self.fake.tree[("APP_DAILY", "")] = [note("APP_DAILY", "n-day", "2026-11-10", 400, pid="")]
        self.fake.tree[("APP_LEARNING", "")] = [note("APP_LEARNING", "n-book", "Book", 1)]
        out, err = self.pull()
        self.assertEqual(out, "aipaper: baseline recorded for 4 notes\n")
        self.assertEqual(err, "")
        self.assertEqual(self.fake.counts["/packageFile"], 0)
        self.assertEqual(self.fake.counts["/download"], 0)
        journal = self.journal()
        self.assertEqual(journal["version"], 1)
        self.assertIs(journal["baseline_complete"], True)
        self.assertEqual({key: entry["updateTime"] for key, entry in journal["notes"].items()},
                         {"APP_PAPER/n-root": 100, "APP_PAPER/n-inner": 200,
                          "APP_MEETING/n-meet": 300, "APP_DAILY/n-day": 400})
        self.assertEqual(sorted(self.fake.listed()), sorted(
            [(app, "") for app in ("APP_PAPER", "APP_DAILY", "APP_MEETING", "APP_MEMO", "APP_PICKING")]
            + [("APP_PAPER", "f-user")]))
        self.assertFalse(os.path.exists(os.path.join(self.state, "inbox")))

    # 2
    def test_unchanged_second_run_requests_no_package(self):
        self.two_pages()
        self.pull()
        out, err = self.pull()
        self.assertEqual((out, err), ("", ""))
        self.assertEqual(self.fake.counts["/packageFile"], 0)
        self.assertGreater(self.fake.counts["/getChildFolderList"], 0)
        self.assertFalse(os.path.exists(os.path.join(self.state, "inbox")))

    # 3
    def test_moved_notebook_writes_only_the_newer_page(self):
        self.two_pages()
        self.pull()
        self.two_pages(stamp=2000, second=(1500, b"B2"))
        out, err = self.pull()
        self.assertEqual(out, "aipaper: 1 notes, 1 pages -> %s\n" % self.inbox)
        self.assertEqual(err, "")
        self.assertEqual(self.files("APP_PAPER", "Plan--aaaaaaaa"), ["note.json", "p01-pagebbbb.png"])
        self.assertEqual(self.read("APP_PAPER", "Plan--aaaaaaaa", "p01-pagebbbb.png"), b"B2")
        meta = self.note_json("APP_PAPER", "Plan--aaaaaaaa")
        self.assertIsInstance(meta.pop("pulledAt"), int)
        self.assertEqual(meta, {
            "appType": "APP_PAPER", "noteId": "aaaaaaaa-1111", "fileName": "Plan", "folder": ["Work"],
            "updateTime": 2000, "format": "notebook",
            "pages": [{"file": "p01-pagebbbb.png", "pageId": "pagebbbb-2", "order": 1,
                       "lastModifiedTime": 1500}]})
        self.assertEqual(self.fake.packaged()[0]["folderId"], "f-work")
        entry = self.journal()["notes"]["APP_PAPER/aaaaaaaa-1111"]
        self.assertEqual(entry["updateTime"], 2000)
        self.assertEqual(sorted(entry["pages"]), ["pageaaaa-1", "pagebbbb-2"])

    # 4
    def test_new_notebook_writes_every_page_with_an_image(self):
        self.pull()
        self.fake.tree[("APP_MEETING", "")] = [note("APP_MEETING", "cccccccc-9", "Sync", 700)]
        self.fake.archives["cccccccc-9"] = notebook("Sync", [
            ("p1111111-x", 0, 10, b"one"), ("p2222222-x", 1, 20, None), ("p3333333-x", 2, 30, b"three")])
        out, _ = self.pull()
        self.assertEqual(out, "aipaper: 1 notes, 2 pages -> %s\n" % self.inbox)
        self.assertEqual(self.files("APP_MEETING", "Sync--cccccccc"),
                         ["note.json", "p00-p1111111.png", "p02-p3333333.png"])
        self.assertEqual([p["order"] for p in self.note_json("APP_MEETING", "Sync--cccccccc")["pages"]], [0, 2])

    # 5
    def test_daily_note_page_and_todos(self):
        self.pull()
        note_id = "dddddddd-daily-id"
        self.fake.tree[("APP_DAILY", "")] = [note("APP_DAILY", note_id, "2026-11-10", 800, pid="")]
        self.fake.archives[note_id] = build_zip({
            note_id + "_HeaderInfo.json": {"appVersion": "1"},
            note_id + "_NoteList.json": [
                {"id": "eeeeeeee-page", "pageOrder": 0, "isNote": 1, "lastModifiedTime": 790,
                 "pageFilePath": "/storage/emulated/0/daily/eeeeeeee-img.png"},
                {"id": "no-keys"},
                {"id": "ffffffff-page", "pageOrder": 1, "isNote": 1, "lastModifiedTime": 791,
                 "pageFilePath": "/storage/emulated/0/daily/absent.png"}],
            note_id + "_TodoList.json": [{"text": "buy ink", "done": False}],
            "eeeeeeee-img.png": b"DAILY"})
        out, err = self.pull()
        self.assertEqual(err, "")
        self.assertEqual(self.files("APP_DAILY", "2026-11-10--dddddddd"), ["note.json", "p00-eeeeeeee.png"])
        self.assertEqual(self.read("APP_DAILY", "2026-11-10--dddddddd", "p00-eeeeeeee.png"), b"DAILY")
        meta = self.note_json("APP_DAILY", "2026-11-10--dddddddd")
        self.assertEqual(meta["format"], "daily")
        self.assertEqual(meta["todos"], [{"text": "buy ink", "done": False}])
        self.assertEqual(meta["pages"], [{"file": "p00-eeeeeeee.png", "pageId": "eeeeeeee-page", "order": 0,
                                          "lastModifiedTime": 790, "isNote": 1}])
        package = self.fake.packaged()[0]
        self.assertEqual((package["folderId"], package["fileUrl"], package["fileName"]),
                         ("", note_id, "2026-11-10.note"))
        self.assertTrue(any("/packageFile?" in line and "&folderId=&" in line for line in self.fake.lines))

    # 6
    def test_second_change_skips_the_page_whose_hash_matches(self):
        self.pull()
        self.two_pages(stamp=2000)
        self.pull()
        name = "Plan--aaaaaaaa"
        self.assertEqual(self.files("APP_PAPER", name), ["note.json", "p00-pageaaaa.png", "p01-pagebbbb.png"])
        with open(os.path.join(self.note_dir("APP_PAPER", name), "p00-pageaaaa.png"), "wb") as handle:
            handle.write(b"UNTOUCHED")
        # Page B's bytes change while its lastModifiedTime stays old: the hash decides.
        self.two_pages(stamp=3000, second=(950, b"B-second"))
        out, _ = self.pull()
        self.assertEqual(out, "aipaper: 1 notes, 1 pages -> %s\n" % self.inbox)
        self.assertEqual(self.read("APP_PAPER", name, "p00-pageaaaa.png"), b"UNTOUCHED")
        self.assertEqual(self.read("APP_PAPER", name, "p01-pagebbbb.png"), b"B-second")
        self.assertEqual([p["file"] for p in self.note_json("APP_PAPER", name)["pages"]],
                         ["p00-pageaaaa.png", "p01-pagebbbb.png"])
        os.remove(os.path.join(self.note_dir("APP_PAPER", name), "p00-pageaaaa.png"))
        self.two_pages(stamp=4000, second=(950, b"B-third"))
        self.pull()
        self.assertEqual([p["file"] for p in self.note_json("APP_PAPER", name)["pages"]], ["p01-pagebbbb.png"])

    # 7
    def test_bad_archive_and_package_error_are_skipped_once(self):
        self.pull()
        self.add_new("APP_PAPER", "11111111-bad", "Not zip")
        self.fake.archives["11111111-bad"] = b"this is not a zip"
        self.add_new("APP_PAPER", "22222222-404", "Refused")
        self.fake.package_code["22222222-404"] = 404
        self.add_new("APP_PAPER", "33333333-odd", "No marker")
        self.fake.archives["33333333-odd"] = build_zip({"readme.txt": b"hi"})
        self.add_new("APP_PAPER", "44444444-ok", "Good")
        out, err = self.pull()
        self.assertEqual(out, "aipaper: 1 notes, 1 pages -> %s\n" % self.inbox)
        lines = err.splitlines()
        self.assertEqual(len(lines), 3, err)
        for line, name in zip(lines, ("Not zip", "Refused", "No marker")):
            self.assertIn("APP_PAPER", line)
            self.assertIn(name, line)
        notes = self.journal()["notes"]
        self.assertEqual(notes["APP_PAPER/11111111-bad"], {"updateTime": 5000, "skipped": "unsupported"})
        self.assertEqual(notes["APP_PAPER/33333333-odd"], {"updateTime": 5000, "skipped": "unsupported"})
        self.assertEqual(notes["APP_PAPER/22222222-404"]["updateTime"], 5000)
        self.assertIn("404", notes["APP_PAPER/22222222-404"]["skipped"])
        self.assertEqual(os.listdir(os.path.join(self.inbox, "APP_PAPER")), ["Good--44444444"])
        out, err = self.pull()
        self.assertEqual((out, err), ("", ""))
        self.assertEqual(self.fake.counts["/packageFile"], 0)

    # 8
    def test_device_dying_mid_run_keeps_what_was_done(self):
        self.pull()
        for note_id, name in (("11111111-a", "One"), ("22222222-b", "Two"), ("33333333-c", "Three")):
            self.add_new("APP_PAPER", note_id, name)
        self.fake.die_at_download = 2
        out, err = self.pull(expect=3)
        self.assertEqual(len(err.splitlines()), 1, err)
        self.assertEqual(os.listdir(os.path.join(self.inbox, "APP_PAPER")), ["One--11111111"])
        notes = self.journal()["notes"]  # the journal parses
        self.assertEqual(sorted(notes), ["APP_PAPER/11111111-a"])
        self.assertIn("p-11111111-a", notes["APP_PAPER/11111111-a"]["pages"])
        self.fake.die_at_download = None
        self.port = self.fake.start()
        out, err = self.pull()
        self.assertEqual(out, "aipaper: 2 notes, 2 pages -> %s\n" % self.inbox)
        self.assertEqual(self.fake.counts["/packageFile"], 2)
        self.assertEqual(sorted(os.listdir(os.path.join(self.inbox, "APP_PAPER"))),
                         ["One--11111111", "Three--33333333", "Two--22222222"])

    # 9
    def test_closed_probe_is_silent_and_creates_nothing(self):
        code, out, err = self.run_pull("--host", "127.0.0.1", "--port", str(self.closed_port()),
                                       "--state-dir", self.state)
        self.assertEqual((code, out, err), (0, "", ""))
        self.assertEqual(os.listdir(self.state), [])

    # 10
    def test_missing_state_dir_is_refused_and_not_created(self):
        missing = os.path.join(self.root, "absent")
        code, out, err = self.run_pull("--host", "127.0.0.1", "--port", str(self.port), "--state-dir", missing)
        self.assertEqual((code, out), (2, ""))
        self.assertEqual(len(err.splitlines()), 1, err)
        self.assertFalse(os.path.exists(missing))
        self.assertEqual(sum(self.fake.counts.values()), 0)

    # 11
    def test_host_comes_from_flag_or_env_and_is_required(self):
        code, out, err = self.run_pull("--port", str(self.port), "--state-dir", self.state)
        self.assertEqual((code, out), (2, ""))
        self.assertEqual(len(err.splitlines()), 1, err)
        self.assertEqual(os.listdir(self.state), [])
        os.environ["CLUTCH_AIPAPER_HOST"] = "127.0.0.1"
        code, out, _ = self.run_pull("--port", str(self.port), "--state-dir", self.state)
        self.assertEqual((code, out), (0, "aipaper: baseline recorded for 0 notes\n"))
        # --host wins over the env: the env now names a host that does not resolve.
        os.environ["CLUTCH_AIPAPER_HOST"] = "host.invalid"
        self.fake.reset_counts()
        code, _, _ = self.run_pull("--host", "127.0.0.1", "--port", str(self.port), "--state-dir", self.state)
        self.assertEqual(code, 0)
        self.assertEqual(self.fake.counts["/getChildFolderList"], 5)

    # 12
    def test_vanished_note_is_pruned_only_after_a_full_walk(self):
        self.fake.tree[("APP_PAPER", "")] = [note("APP_PAPER", "n-keep", "Keep", 1),
                                             note("APP_PAPER", "n-gone", "Gone", 2)]
        self.fake.tree[("APP_MEETING", "")] = [note("APP_MEETING", "n-meet", "Sync", 3)]
        self.pull()
        self.assertEqual(len(self.journal()["notes"]), 3)
        del self.fake.tree[("APP_PAPER", "")][1]
        self.fake.fail_listing = {"APP_MEETING"}
        _, err = self.pull()
        self.assertEqual(len(err.splitlines()), 1, err)
        self.assertEqual(len(self.journal()["notes"]), 3)
        self.fake.fail_listing = set()
        self.pull()
        self.assertEqual(sorted(self.journal()["notes"]), ["APP_MEETING/n-meet", "APP_PAPER/n-keep"])

    # 13
    def test_query_values_are_percent_encoded_and_connection_is_kept(self):
        self.pull()
        self.add_new("APP_PAPER", "55555555-sp", "Paper One+Two")
        self.pull()
        self.assertEqual(self.files("APP_PAPER", "Paper_One_Two--55555555"), ["note.json", "p00-p-555555.png"])
        package = [line for line in self.fake.lines if "/packageFile?" in line]
        self.assertEqual(len(package), 1)
        self.assertIn("fileName=Paper%20One%2BTwo.note&", package[0])
        download = [line for line in self.fake.lines if "/download?" in line]
        self.assertIn("filePath=%2Fsd%2Fdown%20load%2F", download[0])
        for line in self.fake.lines:
            self.assertNotIn("+", line)
            self.assertTrue(line.endswith(" HTTP/1.1"), line)
        self.assertGreater(len(self.fake.headers), 5)
        for headers in self.fake.headers:
            self.assertNotEqual(headers.get("connection"), "close")

    # 14
    def test_lock_held_elsewhere_ends_the_run_quietly(self):
        os.mkdir(os.path.join(self.state, "aipaper"))
        with open(os.path.join(self.state, "aipaper", "lock"), "w") as held:
            fcntl.flock(held, fcntl.LOCK_EX)
            out, err = self.pull()
        self.assertEqual((out, err), ("", ""))
        self.assertEqual(sum(self.fake.counts.values()), 0)
        self.assertFalse(os.path.exists(self.journal_path))
        # Positive control: with the lock free the same run does list.
        self.pull()
        self.assertEqual(self.fake.counts["/getChildFolderList"], 5)

    # 15
    def test_interrupted_baseline_baselines_again(self):
        self.two_pages()
        self.fake.tree[("APP_DAILY", "")] = [note("APP_DAILY", "n-day", "Day", 10, pid="")]
        self.fake.tree[("APP_MEMO", "")] = [note("APP_MEMO", "n-memo", "Memo", 20)]
        self.fake.fail_listing = {"APP_MEETING"}  # the third section walked
        out, err = self.pull()
        self.assertEqual(out, "")
        self.assertEqual(len(err.splitlines()), 1, err)
        journal = self.journal()
        self.assertIs(journal["baseline_complete"], False)
        self.assertEqual(sorted(journal["notes"]),
                         ["APP_DAILY/n-day", "APP_MEMO/n-memo", "APP_PAPER/aaaaaaaa-1111"])
        self.fake.fail_listing = set()
        self.fake.tree[("APP_MEETING", "")] = [note("APP_MEETING", "n-meet", "Sync", 30)]
        self.two_pages(stamp=2000, second=(1500, b"B2"))
        out, _ = self.pull()
        self.assertEqual(out, "aipaper: baseline recorded for 4 notes\n")
        self.assertEqual(self.fake.counts["/packageFile"], 0)
        journal = self.journal()
        self.assertIs(journal["baseline_complete"], True)
        self.assertEqual(len(journal["notes"]), 4)
        self.assertEqual(journal["notes"]["APP_PAPER/aaaaaaaa-1111"]["updateTime"], 2000)
        self.two_pages(stamp=3000, second=(2500, b"B3"))
        out, _ = self.pull()
        self.assertEqual(out, "aipaper: 1 notes, 1 pages -> %s\n" % self.inbox)
        self.assertEqual(self.fake.counts["/packageFile"], 1)

    # 16
    def test_one_note_that_always_resets_does_not_starve_the_rest(self):
        self.pull()
        for note_id, name in (("11111111-a", "One"), ("22222222-b", "Two"), ("33333333-c", "Three")):
            self.add_new("APP_PAPER", note_id, name)
        self.fake.reset_download = {"22222222-b"}
        out, err = self.pull()
        self.assertEqual(out, "aipaper: 2 notes, 2 pages -> %s\n" % self.inbox)
        self.assertEqual(len(err.splitlines()), 1, err)
        self.assertIn("Two", err)
        self.assertEqual(self.fake.counts["/download"], 5)  # 1 + (1 try + 2 retries) + 1
        self.assertEqual(self.journal()["notes"]["APP_PAPER/22222222-b"],
                         {"updateTime": 5000, "skipped": "download failed"})
        self.assertEqual(sorted(os.listdir(os.path.join(self.inbox, "APP_PAPER"))),
                         ["One--11111111", "Three--33333333"])

    # 17
    def test_encrypted_item_is_journaled_and_idless_item_ignored(self):
        self.pull()
        self.add_new("APP_PAPER", "66666666-lock", "Locked", encryption=True)
        self.fake.tree[("APP_PAPER", "")].append({"appType": "APP_PAPER", "fileName": "Paper", "isFolder": True})
        self.fake.tree[("APP_PAPER", "")].append({"appType": "APP_PAPER", "fileName": "Loose", "updateTime": 9})
        out, err = self.pull()
        self.assertEqual((out, err), ("", ""))
        self.assertEqual(self.fake.counts["/packageFile"], 0)
        self.assertEqual(self.journal()["notes"],
                         {"APP_PAPER/66666666-lock": {"updateTime": 5000, "skipped": "encrypted"}})
        self.assertEqual(self.fake.listed().count(("APP_PAPER", "")), 1)

    # 18
    def test_unreadable_journal_stops_the_run_untouched(self):
        self.add_new("APP_PAPER", "11111111-a", "One")
        os.mkdir(os.path.join(self.state, "aipaper"))
        for content in (b"{not json", json.dumps({"version": 2, "baseline_complete": True, "notes": {}}).encode(),
                        b"[]"):
            with open(self.journal_path, "wb") as handle:
                handle.write(content)
            out, err = self.pull(expect=4)
            self.assertEqual(out, "")
            self.assertEqual(len(err.splitlines()), 1, err)
            with open(self.journal_path, "rb") as handle:
                self.assertEqual(handle.read(), content)
            self.assertEqual(sum(self.fake.counts.values()), 0)
        self.assertFalse(os.path.exists(os.path.join(self.state, "inbox")))

    # 19
    def test_device_names_cannot_escape_the_inbox(self):
        self.pull()
        evil = note("../../evil-app", "../../../x/y", "../../evil name", 5000)
        self.fake.tree[("APP_PAPER", "")] = [evil, note("APP_PAPER", "..", "..", 5000)]
        self.fake.archives["../../../x/y"] = notebook("e", [("../../../page", 0, 1, b"EVIL")])
        self.fake.archives[".."] = build_zip({
            "d_NoteList.json": [{"id": "../..", "pageOrder": 0, "isNote": 1, "lastModifiedTime": 1,
                                 "pageFilePath": "/a/../../img.png"}],
            "img.png": b"EVIL2"})
        out, err = self.pull()
        self.assertEqual(out, "aipaper: 2 notes, 2 pages -> %s\n" % self.inbox)
        self.assertEqual(os.listdir(self.root), ["state"])
        self.assertEqual(sorted(os.listdir(self.state)), ["aipaper", "inbox"])
        self.assertEqual(os.listdir(os.path.join(self.state, "inbox")), ["aipaper"])
        self.assertEqual(os.listdir(self.inbox), ["APP_PAPER"])
        section = os.path.join(self.inbox, "APP_PAPER")
        self.assertEqual(sorted(os.listdir(section)), ["_.--_.", "_._.._evil_name--_._.._.."])
        found = []
        for base, dirs, names in os.walk(section):
            self.assertEqual(os.path.realpath(base)[:len(os.path.realpath(section))], os.path.realpath(section))
            found += names
        self.assertEqual(sorted(found), ["note.json", "note.json", "p00-_._...png", "p00-_._.._...png"])


if __name__ == "__main__":
    unittest.main()
