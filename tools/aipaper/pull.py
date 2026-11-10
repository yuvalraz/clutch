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
import zlib

PORT = 8090
SECTIONS = ("APP_PAPER", "APP_DAILY", "APP_MEETING", "APP_MEMO", "APP_PICKING")
ASSET_FOLDERS = ("PNG Template", "Audio File", "PDF Template")
PROBE_TIMEOUT = 2
TIMEOUT = 30
RETRIES = 2
BACKOFF = 1.0  # seconds, times the attempt number; the tests set it to zero


class ConnectionFailed(Exception):
    """A request got no complete answer, retries included."""


class DeviceError(Exception):
    """The device answered with a non-200 code."""


class Unsupported(Exception):
    """The download is not a ZIP, or is neither a notebook nor a Daily archive."""


class DeviceGone(Exception):
    """The device stopped serving mid-run."""


def warn(message):
    print("aipaper: " + message, file=sys.stderr)


def number(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def safe(text):
    """A device-supplied name as one path component that cannot leave its directory."""
    text = re.sub(r"[^A-Za-z0-9._-]", "_", str(text))[:80]
    return "_" + text[1:] if text.startswith(".") else text


def write_json(path, value):
    tmp = path + ".tmp"
    with open(tmp, "w") as handle:
        json.dump(value, handle, indent=1, sort_keys=True)
    os.replace(tmp, path)


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
        raise Unsupported()
    names = archive.namelist()

    def member(suffix):
        return next((name for name in names if name.endswith(suffix)), None)

    pages = []
    page_list = member("_PageListFileInfo.json")
    if page_list:
        for record in json.loads(archive.read(page_list)):
            image = "screenshotBmp_%s.png" % record["id"]
            if image in names:  # a blank page has no image
                pages.append({"pageId": str(record["id"]), "order": int(record["order"]),
                              "lastModifiedTime": int(record["lastModifiedTime"]),
                              "data": archive.read(image)})
        return "notebook", pages, None
    note_list = member("_NoteList.json")
    if note_list:
        for record in json.loads(archive.read(note_list)):
            try:
                image = posixpath.basename(record["pageFilePath"])
                page = {"pageId": str(record["id"]), "order": int(record["pageOrder"]),
                        "lastModifiedTime": int(record["lastModifiedTime"]), "isNote": record["isNote"]}
            except (KeyError, TypeError, ValueError, AttributeError):
                continue
            if image in names:
                page["data"] = archive.read(image)
                pages.append(page)
        todo_list = member("_TodoList.json")
        return "daily", pages, json.loads(archive.read(todo_list)) if todo_list else None
    raise Unsupported()


def probe(host, port):
    try:
        socket.create_connection((host, port), timeout=PROBE_TIMEOUT).close()
        return True
    except OSError:
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
                return response.status, response.read()
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
            raise DeviceError("code %s" % code)
        return reply.get("data")

    def gone_or_up(self):
        """After a connection failure: raise when the device left, return when it still serves."""
        if not probe(self.host, self.port):
            raise DeviceGone()

    def walk(self, app, folder_id, folders, visited):
        """Yield (folder names, item) for every note under one folder of a section."""
        try:
            items = self.api("getChildFolderList", [("appType", app), ("folderId", folder_id), ("language", "en")])
            if not isinstance(items, list):
                raise DeviceError("the listing is not a list")
        except (DeviceError, ConnectionFailed) as exc:
            if isinstance(exc, ConnectionFailed):
                self.gone_or_up()
            warn("listing %s failed: %s" % ("/".join([app] + folders), exc))
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
            reason = "download failed"
        except DeviceError as exc:
            reason = "package failed: %s" % exc
        except Unsupported:
            reason = "unsupported"
        except (zipfile.BadZipFile, zlib.error, ValueError, KeyError, TypeError, AttributeError):
            reason = "bad archive"
        if reason:
            warn("skipped %s/%s: %s" % (app, name, reason))
            return {"updateTime": stamp, "skipped": reason}

        known = previous.get("pages", {}) if previous else {}
        hashes, changed = {}, []
        for page in pages:
            digest = hashlib.sha256(page["data"]).hexdigest()
            hashes[page["pageId"]] = digest
            if page["pageId"] in known:
                new = known[page["pageId"]] != digest
            elif previous is not None:  # baselined: only pages touched since the last look
                new = page["lastModifiedTime"] > number(previous.get("updateTime"))
            else:
                new = True
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
            with open(os.path.join(directory, filename), "wb") as handle:
                handle.write(page["data"])
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
        listed = set()
        gone = False
        try:
            for app in SECTIONS:
                for folders, item in self.walk(app, "", [], set()):
                    key = "%s/%s" % (app, item["noteId"])
                    listed.add(key)
                    stamp = number(item.get("updateTime"))
                    previous = notes.get(key)
                    if item.get("encryption"):
                        notes[key] = {"updateTime": stamp, "skipped": "encrypted"}
                    elif baseline:
                        notes[key] = {"updateTime": stamp}
                    elif previous is None or previous.get("updateTime") != stamp:
                        notes[key] = self.pull_note(app, folders, item, previous, stamp)
            if self.complete:  # never prune, or call a baseline done, after a partial walk
                for key in set(notes) - listed:
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
    os.makedirs(os.path.join(state, "aipaper"), exist_ok=True)
    with open(os.path.join(state, "aipaper", "lock"), "a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            return 0  # another run holds it
        return Puller(host, args.port, state).run()


if __name__ == "__main__":
    sys.exit(main())
