#!/usr/bin/python3
"""Pull changed note pages from a Viwoods AiPaper tablet's LAN Transfer app.

The tablet serves its notes over HTTP on port 8090 while LAN Transfer is in
the foreground. Each run copies the page images of notes that changed since
the last run into <state>/inbox/aipaper/. When the tablet is not serving, the
run ends at once and says nothing. See README.md beside this file.

Standard library only; runs on /usr/bin/python3 (3.9).
"""
import argparse
import fcntl
import hashlib
import http.client
import io
import json
import os
import posixpath
import re
import socket
import sys
import time
import urllib.parse
import zipfile

PORT = 8090
SECTIONS = ("APP_PAPER", "APP_DAILY", "APP_MEETING", "APP_MEMO", "APP_PICKING")
ASSET_FOLDERS = ("PNG Template", "Audio File", "PDF Template")
PROBE_TIMEOUT = 2
TIMEOUT = 30
RETRIES = 2
BACKOFF = 1.0  # seconds, times the attempt number; the tests set it to zero
# The peer is unauthenticated: bound what it can send.
MAX_BODY = 256 * 1024 * 1024
MAX_MEMBER = 64 * 1024 * 1024
MAX_DEPTH = 16
MAX_FAILURES = 3  # consecutive runs a download may fail before the note is skipped


class ConnectionFailed(Exception):
    """A request got no complete answer, retries included."""


class DeviceError(Exception):
    """The device answered with a non-200 code."""


class Unsupported(Exception):
    """The download cannot be pulled; the message is the skip reason."""


class DeviceGone(Exception):
    """The device stopped serving mid-run."""


def warn(message):
    # One message is one line, whatever the device put in it.
    print("aipaper: " + "".join(ch if ch.isprintable() else " " for ch in message), file=sys.stderr)


def number(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def safe(text):
    """A device-supplied name as one path component that cannot leave its directory."""
    text = re.sub(r"[^A-Za-z0-9._-]", "_", str(text))[:80]
    return "_" + text[1:] if text.startswith(".") else text


def write_file(path, data):
    """All of it or the old file: a kill mid-write leaves no half file under the real name."""
    tmp = path + ".tmp"
    with open(tmp, "wb") as handle:
        handle.write(data)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(tmp, path)


def write_json(path, value):
    write_file(path, json.dumps(value, indent=1, sort_keys=True).encode())


def skipped(previous, stamp, reason):
    """The journal entry of a note that was not pulled. It keeps the page hashes and the
    comparison base of the last good state, so the next good pull still delivers every page
    edited since then."""
    entry = {"updateTime": stamp, "skipped": reason, "since": 0}
    if previous is not None:
        entry["since"] = previous.get("since", previous.get("updateTime"))
        if "pages" in previous:
            entry["pages"] = previous["pages"]
    return entry


def load_journal(path):
    """The journal, or a fresh one when the file is missing. ValueError when it cannot be trusted."""
    try:
        with open(path) as handle:
            journal = json.load(handle)
    except FileNotFoundError:
        return {"version": 1, "baseline_complete": False, "notes": {}}
    if not isinstance(journal, dict) or journal.get("version") != 1:
        raise ValueError("not a version 1 journal")
    notes = journal.setdefault("notes", {})
    if not isinstance(notes, dict) or not all(isinstance(entry, dict) for entry in notes.values()):
        raise ValueError("malformed notes")
    journal["baseline_complete"] = journal.get("baseline_complete") is True
    return journal


def parse_archive(blob):
    """(format, pages, todos) of a packaged note. Detected by member names, not by section."""
    try:
        archive = zipfile.ZipFile(io.BytesIO(blob))
    except zipfile.BadZipFile:
        raise Unsupported("not a ZIP")
    names = archive.namelist()

    def member(suffix):
        return next((name for name in names if name.endswith(suffix)), None)

    def read(name):
        if archive.getinfo(name).file_size > MAX_MEMBER:
            raise ValueError("a member over the size bound")
        return archive.read(name)

    pages, todos = [], None
    page_list = member("_PageListFileInfo.json")
    note_list = member("_NoteList.json")
    if page_list:
        kind, records = "notebook", json.loads(read(page_list))
        for record in records:
            image = "screenshotBmp_%s.png" % record["id"]
            if image in names:  # a blank page has no image
                pages.append({"pageId": str(record["id"]), "order": int(record["order"]),
                              "lastModifiedTime": int(record["lastModifiedTime"]),
                              "data": read(image)})
    elif note_list:
        kind, records = "daily", json.loads(read(note_list))
        for record in records:
            try:
                image = posixpath.basename(record["pageFilePath"])
                page = {"pageId": str(record["id"]), "order": int(record["pageOrder"]),
                        "lastModifiedTime": int(record["lastModifiedTime"]), "isNote": record["isNote"]}
            except (KeyError, TypeError, ValueError, AttributeError):
                continue
            if image in names:
                page["data"] = read(image)
                pages.append(page)
        todo_list = member("_TodoList.json")
        if todo_list:
            todos = json.loads(read(todo_list))
    else:
        raise Unsupported("unsupported")
    if records and not pages:  # a format change must be loud, never "pulled, nothing new"
        raise Unsupported("no page images")
    return kind, pages, todos


def probe(host, port):
    try:
        socket.create_connection((host, port), timeout=PROBE_TIMEOUT).close()
        return True
    except (OSError, ValueError):  # ValueError: a host that cannot be a name, such as a..b
        return False


class Puller:
    def __init__(self, host, port, state):
        self.host, self.port = host, port
        self.journal_path = os.path.join(state, "aipaper", "journal.json")
        self.inbox = os.path.join(state, "inbox", "aipaper")
        self.complete = True  # no listing failed
        self.pulled_notes = self.pulled_pages = 0

    def get(self, path, params):
        """(status, body). A new connection per request, never `Connection: close`: the device
        truncates the body. Every value is percent-encoded; the device resets on `+` for a space."""
        query = "&".join("%s=%s" % (key, urllib.parse.quote(str(value), safe="")) for key, value in params)
        error = None
        for attempt in range(RETRIES + 1):
            time.sleep(BACKOFF * attempt)
            conn = http.client.HTTPConnection(self.host, self.port, timeout=TIMEOUT)
            try:
                conn.request("GET", "/%s?%s" % (path, query))
                response = conn.getresponse()
                body = response.read(MAX_BODY + 1)
                if len(body) > MAX_BODY:
                    raise DeviceError("a response over %d bytes" % MAX_BODY)
                return response.status, body
            except (OSError, http.client.HTTPException) as exc:
                error = exc
            finally:
                conn.close()
        raise ConnectionFailed(str(error) or type(error).__name__)

    def api(self, path, params):
        status, body = self.get(path, params)
        try:
            reply = json.loads(body)
            code = reply["code"]
        except (ValueError, KeyError, TypeError):
            raise DeviceError("HTTP %s, not a JSON reply" % status)
        if code != 200:
            raise DeviceError("code %s" % safe(code))
        return reply.get("data")

    def gone_or_up(self):
        """After a connection failure: raise when the device left, return when it still serves."""
        if not probe(self.host, self.port):
            raise DeviceGone()

    def walk(self, app, folder_id, folders, visited):
        """Yield (folder names, item) for every note under one folder of a section."""
        where = "/".join([app] + [safe(name) for name in folders])
        try:
            if len(folders) > MAX_DEPTH:
                raise DeviceError("more than %d folders deep" % MAX_DEPTH)
            items = self.api("getChildFolderList", [("appType", app), ("folderId", folder_id), ("language", "en")])
            if items is None:  # an empty folder
                items = []
            if not isinstance(items, list):
                raise DeviceError("the listing is not a list")
        except (DeviceError, ConnectionFailed) as exc:
            if isinstance(exc, ConnectionFailed):
                self.gone_or_up()
            warn("listing %s failed: %s" % (where, exc))
            self.complete = False
            return
        for item in items:
            # An unknown appType makes the device answer with the root list, whose items have no noteId.
            if not isinstance(item, dict) or not item.get("noteId"):
                continue
            note_id = str(item["noteId"])
            if not item.get("isFolder"):
                yield folders, item
            elif note_id not in ASSET_FOLDERS and note_id not in visited:
                visited.add(note_id)
                for found in self.walk(app, note_id, folders + [str(item.get("fileName", ""))], visited):
                    yield found

    def pull_note(self, app, folders, item, previous, stamp):
        """Package, download and parse one note; write its changed pages. Returns its journal entry."""
        name = str(item.get("fileName", ""))
        label = "%s/%s" % (app, safe(name))
        try:
            path = self.api("packageFile", [
                ("appType", app), ("fileUrl", item["noteId"]), ("folderId", item.get("notePId") or ""),
                ("isFolder", "false"), ("fileName", name + ".note"),
                ("fileFormat", "note"), ("childFileFormat", "note")])
            status, blob = self.get("download", [("filePath", path)])
            if status != 200:
                raise DeviceError("download HTTP %s" % status)
            kind, pages, todos = parse_archive(blob)
            reason = None
        except ConnectionFailed:
            self.gone_or_up()
            # The device is up but this note failed: try it again next run, edit or no edit.
            entry = dict(previous) if previous is not None else {"updateTime": -1, "since": 0}
            entry["failures"] = number(entry.get("failures")) + 1
            if entry["failures"] < MAX_FAILURES:
                warn("%s: download failed, trying again next run" % label)
                return entry
            reason = "download failed"
        except DeviceError as exc:
            reason = "device error: %s" % exc
        except Unsupported as exc:
            reason = str(exc)
        except Exception:  # whatever an archive can raise: one skip, not the same crash every minute
            reason = "bad archive"
        if reason:
            warn("skipped %s: %s" % (label, reason))
            return skipped(previous, stamp, reason)

        known = previous.get("pages", {}) if previous else {}
        hashes, changed = {}, []
        for page in pages:
            digest = hashlib.sha256(page["data"]).hexdigest()
            hashes[page["pageId"]] = digest
            if page["pageId"] in known:
                new = known[page["pageId"]] != digest
            else:  # no hash: every page of a new note, else only pages touched since the last good state
                new = previous is None or page["lastModifiedTime"] > number(
                    previous.get("since", previous.get("updateTime")))
            if new:
                changed.append(page)
        if changed:
            self.write_note(app, folders, item, name, stamp, kind, changed, todos)
            self.pulled_notes += 1
            self.pulled_pages += len(changed)
        return {"updateTime": stamp, "pages": hashes}

    def write_note(self, app, folders, item, name, stamp, kind, changed, todos):
        # `app` is the section the walk asked for, never the value the device echoed.
        directory = os.path.join(self.inbox, app, "%s--%s" % (safe(name), safe(str(item["noteId"])[:8])))
        os.makedirs(directory, exist_ok=True)
        records = []
        for page in changed:
            filename = "p%02d-%s.png" % (page["order"], safe(page["pageId"][:8]))
            write_file(os.path.join(directory, filename), page["data"])
            record = {"file": filename, "pageId": page["pageId"], "order": page["order"],
                      "lastModifiedTime": page["lastModifiedTime"]}
            if "isNote" in page:
                record["isNote"] = page["isNote"]
            records.append(record)
        meta_path = os.path.join(directory, "note.json")
        try:
            with open(meta_path) as handle:
                earlier = json.load(handle)["pages"]
        except (OSError, ValueError, KeyError, TypeError):
            earlier = []
        written = set(record["file"] for record in records)
        present = set(os.listdir(directory)) - written
        records += [r for r in earlier if isinstance(r, dict) and r.get("file") in present]
        meta = {"appType": app, "noteId": item["noteId"], "fileName": name, "folder": folders,
                "updateTime": stamp, "pulledAt": int(time.time() * 1000), "format": kind,
                "pages": sorted(records, key=lambda r: (number(r.get("order")), str(r.get("file"))))}
        if todos is not None:
            meta["todos"] = todos
        write_json(meta_path, meta)

    def run(self):
        try:
            journal = load_journal(self.journal_path)
        except (OSError, ValueError) as exc:
            warn("cannot use %s (%s); fix or remove it" % (self.journal_path, exc))
            return 4
        notes = journal["notes"]
        baseline = not journal["baseline_complete"]
        listed, empty = set(), set()
        gone = False
        try:
            for app in SECTIONS:
                before = len(listed)
                for folders, item in self.walk(app, "", [], set()):
                    key = "%s/%s" % (app, item["noteId"])
                    listed.add(key)
                    stamp = number(item.get("updateTime"))
                    previous = notes.get(key)
                    if baseline:
                        # A note an earlier, cut-short baseline recorded keeps its first stamp,
                        # so an edit made while the baseline is stuck is pulled once it completes.
                        entry = {"updateTime": stamp}
                        if item.get("encryption"):
                            entry["skipped"] = "encrypted"
                        notes.setdefault(key, entry)
                        continue
                    if previous is not None and previous.get("updateTime") == stamp:
                        continue
                    if item.get("encryption"):
                        warn("skipped %s/%s: encrypted" % (app, safe(item.get("fileName", ""))))
                        notes[key] = skipped(previous, stamp, "encrypted")
                    else:
                        notes[key] = self.pull_note(app, folders, item, previous, stamp)
                    write_json(self.journal_path, journal)  # a kill keeps what was done
                if len(listed) == before:
                    empty.add(app)
            if self.complete:  # never prune, or call a baseline done, after a partial walk
                stale = set(notes) - listed
                # An empty answer is not proof of deletion: pruning would make every note look new.
                for app in sorted(set(key.split("/")[0] for key in stale) & empty):
                    warn("%s lists no notes; keeping its journal entries" % app)
                for key in stale:
                    if key.split("/")[0] not in empty:
                        del notes[key]
                journal["baseline_complete"] = True
        except DeviceGone:
            gone = True
        finally:
            write_json(self.journal_path, journal)
        if baseline and journal["baseline_complete"]:
            print("aipaper: baseline recorded for %d notes" % len(listed))
        if self.pulled_pages:
            print("aipaper: %d notes, %d pages -> %s" % (self.pulled_notes, self.pulled_pages, self.inbox))
        if gone:
            warn("the device went away mid-run; the journal keeps what was done")
            return 3
        if baseline and not journal["baseline_complete"]:
            warn("the baseline is still incomplete; nothing is pulled until one walk lists every section")
        return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--host", help="the tablet's address (else env CLUTCH_AIPAPER_HOST)")
    parser.add_argument("--port", type=int, default=PORT, help=argparse.SUPPRESS)
    parser.add_argument("--state-dir", help="replaces $HOME/.clutch; must already exist")
    args = parser.parse_args(argv)
    host = args.host or os.environ.get("CLUTCH_AIPAPER_HOST")
    if not host:
        warn("no host: pass --host or set CLUTCH_AIPAPER_HOST")
        return 2
    state = args.state_dir or os.path.join(os.path.expanduser("~"), ".clutch")
    if not os.path.isdir(state):  # never created here: its existence switches other tools on
        warn("%s is missing; not creating it" % state)
        return 2
    if not probe(host, args.port):
        return 0  # the tablet is not serving: the normal state
    try:
        os.makedirs(os.path.join(state, "aipaper"), exist_ok=True)
        with open(os.path.join(state, "aipaper", "lock"), "a") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                return 0  # another run holds it
            return Puller(host, args.port, state).run()
    except OSError as exc:  # a lock or write error: one line, not a traceback
        warn("cannot use %s: %s" % (state, exc))
        return 1


if __name__ == "__main__":
    sys.exit(main())
