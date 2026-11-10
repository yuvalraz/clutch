"""Claim, route and release tablet captures pulled by tools/aipaper/pull.py.

claim   renames each capture in <state>/inbox/aipaper into <state>/aipaper/reading
        and prints one JSON line per folder to read.
route   files the items read from claimed folders (JSON on stdin) in their sinks,
        records them in the ledger and deletes each folder once filed.
release lapses the lease of every claimed folder, for a sweep that stopped.

Called only through scripts/tablet-inbox.sh. Standard library only; runs on
/usr/bin/python3 (3.9). Every non-zero exit prints one stderr line `tablet: ...`.
"""
import argparse
import datetime
import fcntl
import json
import os
import re
import shutil
import sys
import time

LEASE = 600  # seconds a claimed folder belongs to the sweep that took it
LOCK_WAIT = 10  # seconds to wait for the puller's lock; the tests set it to zero
MAX_CLAIMS = 5  # claims of one folder before it moves to held/
KINDS = ("task", "note", "action", "idea")
BUCKETS = ("work", "personal", "unsure")
TABLET_HEADING = "## From the tablet"
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


class Refused(Exception):
    """Bad usage or input: rc 2, nothing written."""


class Busy(Exception):
    """The lock stayed held: rc 3, nothing written."""


class Unusable(Exception):
    """The ledger cannot be trusted: rc 4, nothing written."""


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise Refused(message)


def warn(message):
    print("tablet: " + " ".join(str(message).split()), file=sys.stderr)


def replace_file(path, data, mode):
    """All of it or the old file: a kill mid-write leaves no half file under the real name."""
    tmp = path + ".tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, mode)
    with os.fdopen(fd, "wb") as handle:
        os.fchmod(handle.fileno(), mode)
        handle.write(data)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(tmp, path)


def norm(text):
    return " ".join(re.sub(r"[^\w\s]", "", text.lower()).split())


def one_line(text):
    return " ".join(text.split())[:300]


def valid_date(text):
    if not isinstance(text, str) or not DATE.match(text):
        return False
    try:
        datetime.date.fromisoformat(text)
    except ValueError:
        return False
    return True


def item_line(item, today, filed_in):
    """The line an item takes in the focus file or the personal file."""
    prefix = {"task": "- [ ] ", "action": "- [ ] ", "note": "- ", "idea": "- idea: "}[item["kind"]]
    line = prefix + one_line(item["text"])
    if filed_in == "personal" and item["bucket"] in ("unsure", "work"):
        line += " (%s)" % item["bucket"]
    date = item.get("date")
    if date and date != today:
        line += " (for %s)" % datetime.date.fromisoformat(date).strftime("%a %m-%d")
    return line


def insert_in_section(text, heading, lines):
    """The text with the lines at the end of the section under heading, made at the end if absent."""
    rows = text.split("\n") if text else []
    if text.endswith("\n"):
        rows.pop()
    if heading not in rows:
        if rows:
            rows.append("")
        return "\n".join(rows + [heading] + lines) + "\n"
    end = rows.index(heading) + 1
    while end < len(rows) and not rows[end].startswith("## "):
        end += 1
    while end > rows.index(heading) + 1 and rows[end - 1].strip() == "":
        end -= 1
    return "\n".join(rows[:end] + lines + rows[end:]) + "\n"


def overlaps(a, b):
    """True when two real paths are the same or one sits inside the other."""
    return os.path.commonpath([a, b]) in (a, b)


def section_name(app):
    return str(app).replace("APP_", "", 1).capitalize()


def read_meta(folder):
    """note.json of a capture folder, or None when it is missing or not an object."""
    try:
        with open(os.path.join(folder, "note.json")) as handle:
            meta = json.load(handle)
    except (OSError, ValueError):
        return None
    return meta if isinstance(meta, dict) else None


def todo_date(todo):
    try:
        return datetime.date(int(todo["year"]), int(todo["month"]), int(todo["day"])).isoformat()
    except (KeyError, TypeError, ValueError):
        return ""


def typed_tasks(meta):
    """The typed tasks of a note that are not deleted."""
    todos = meta.get("todos")
    return [t for t in (todos if isinstance(todos, list) else [])
            if isinstance(t, dict) and "id" in t and t.get("isDelete") is not True]


def view(folder, meta, ledger):
    """(page images, new typed tasks) of a folder: the pages whose file is there, and the
    typed tasks not deleted and not in the ledger. Claim prints them; route checks them."""
    pages = []
    for page in meta.get("pages") if isinstance(meta.get("pages"), list) else []:
        if not isinstance(page, dict):
            continue
        name = str(page.get("file", ""))
        path = os.path.join(folder, name)
        if name and os.path.basename(name) == name and os.path.isfile(path):
            page_id = str(page.get("pageId", ""))
            pages.append({"file": path, "page_id": page_id,
                          "known_lines": ledger["pages"].get(page_id, [])})
    todos = [{"todo_id": str(t["id"]), "content": str(t.get("content", "")), "date": todo_date(t)}
             for t in typed_tasks(meta) if str(t["id"]) not in ledger["todos"]]
    return pages, todos


def load_ledger(path):
    try:
        with open(path) as handle:
            ledger = json.load(handle)
    except FileNotFoundError:
        return {"version": 1, "todos": {}, "pages": {}}
    except (OSError, ValueError) as exc:
        raise Unusable("cannot use %s (%s); fix or remove it" % (path, exc))
    if (not isinstance(ledger, dict) or ledger.get("version") != 1
            or not isinstance(ledger.get("todos"), dict) or not isinstance(ledger.get("pages"), dict)
            or not all(isinstance(v, list) for v in ledger["pages"].values())):
        raise Unusable("cannot use %s (not a version 1 ledger); fix or remove it" % path)
    return ledger


def lock(state):
    """The puller's own lock, waited for up to LOCK_WAIT seconds. Returns the open file."""
    os.makedirs(os.path.join(state, "aipaper"), exist_ok=True)
    handle = open(os.path.join(state, "aipaper", "lock"), "a")
    deadline = time.monotonic() + LOCK_WAIT
    while True:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return handle
        except BlockingIOError:
            if time.monotonic() >= deadline:
                handle.close()
                raise Busy("the tablet puller or another sweep holds the lock; try again")
            time.sleep(0.1)


def read_claims(folder):
    try:
        with open(os.path.join(folder, ".claims")) as handle:
            return max(int(handle.read().strip()), 0)
    except (OSError, ValueError):
        return 0


def write_claims(folder, count):
    replace_file(os.path.join(folder, ".claims"), b"%d\n" % count, 0o600)


def lapse(folder):
    os.utime(folder, (0, 0))


def emit(value):
    print(json.dumps(value, ensure_ascii=False))


def claim(state):
    inbox = os.path.join(state, "inbox", "aipaper")
    reading = os.path.join(state, "aipaper", "reading")
    held = os.path.join(state, "aipaper", "held")
    if not os.path.isdir(inbox) and not os.path.isdir(reading):
        return 0
    with lock(state):
        ledger = load_ledger(os.path.join(state, "aipaper", "ledger.json"))
        os.makedirs(reading, exist_ok=True)
        now = time.time()
        taken = [os.path.join(reading, name) for name in os.listdir(reading)
                 if os.path.isdir(os.path.join(reading, name))
                 and os.stat(os.path.join(reading, name)).st_mtime <= now - LEASE]
        if os.path.isdir(inbox):
            for section in sorted(os.listdir(inbox)):
                if not os.path.isdir(os.path.join(inbox, section)):
                    continue
                for capture in sorted(os.listdir(os.path.join(inbox, section))):
                    source = os.path.join(inbox, section, capture)
                    if os.path.isdir(source):
                        target = os.path.join(reading, "%s__%s__%d" % (section, capture, time.time_ns()))
                        os.rename(source, target)
                        taken.append(target)
        for folder in sorted(taken, key=os.path.basename):
            count, meta = read_claims(folder), read_meta(folder)
            reason = "not read" if count >= MAX_CLAIMS else "unreadable" if meta is None else None
            if reason:
                os.makedirs(held, exist_ok=True)
                os.rename(folder, os.path.join(held, os.path.basename(folder)))
                emit({"folder": os.path.join(held, os.path.basename(folder)), "held": reason})
                continue
            write_claims(folder, count + 1)
            os.utime(folder, None)
            pages, todos = view(folder, meta, ledger)
            emit({"folder": folder, "section": section_name(meta.get("appType", "")),
                  "note": str(meta.get("fileName", "")), "format": str(meta.get("format", "")),
                  "pages": pages, "todos": todos})
    return 0


def release(state):
    """Lapse every lease. A folder still under a live lease was taken by a claim whose sweep
    stopped before route retired or held it, so that claim does not count toward MAX_CLAIMS."""
    reading = os.path.join(state, "aipaper", "reading")
    if not os.path.isdir(reading):
        return 0
    with lock(state):
        now = time.time()
        for name in os.listdir(reading):
            folder = os.path.join(reading, name)
            if not os.path.isdir(folder):
                continue
            if os.stat(folder).st_mtime > now - LEASE:
                write_claims(folder, max(read_claims(folder) - 1, 0))
            lapse(folder)
    return 0


def validate(payload, folders, todo_ids):
    """Raise Refused unless the route stdin is well formed. todo_ids: folder -> its typed task ids."""
    if not isinstance(payload, dict) or not isinstance(payload.get("items"), list) \
            or not isinstance(payload.get("pages_read"), dict):
        raise Refused('stdin must be {"pages_read": {...}, "items": [...]}')
    for folder, pages in payload["pages_read"].items():
        if folder not in folders:
            raise Refused("pages_read names a folder that is not an argument")
        if not isinstance(pages, list) or not all(isinstance(p, str) for p in pages):
            raise Refused("pages_read values must be lists of page ids")
    for number, item in enumerate(payload["items"], 1):
        where = "item %d: " % number
        if not isinstance(item, dict):
            raise Refused(where + "not an object")
        if item.get("folder") not in folders:
            raise Refused(where + "folder is not an argument")
        if not isinstance(item.get("text"), str) or not item["text"].strip():
            raise Refused(where + "empty text")
        if item.get("kind") not in KINDS or item.get("bucket") not in BUCKETS:
            raise Refused(where + "unknown kind or bucket")
        if ("page_id" in item) == ("todo_id" in item):
            raise Refused(where + "needs exactly one of page_id and todo_id")
        if not isinstance(item.get("page_id", item.get("todo_id")), str):
            raise Refused(where + "the id must be a string")
        if "todo_id" in item and item["todo_id"] not in todo_ids.get(item["folder"], ()):
            raise Refused(where + "todo_id is not a typed task of its folder")
        if "date" in item and not valid_date(item["date"]):
            raise Refused(where + "date must be YYYY-MM-DD")


def real(path):
    return os.path.realpath(os.path.expanduser(path))


def route(state, args):
    if not args.folders:
        raise Refused("route needs at least one folder")
    if args.focus_file and not args.work_state_dir:
        raise Refused("--focus-file needs --work-state-dir")
    if args.today and not valid_date(args.today):
        raise Refused("--today must be YYYY-MM-DD")
    today = args.today or datetime.date.today().isoformat()
    state_real = os.path.realpath(state)
    if args.work_state_dir and overlaps(state_real, real(args.work_state_dir)):
        raise Refused("the work state dir and the tablet state dir overlap")
    focus = os.path.expanduser(args.focus_file) if args.focus_file else None
    if focus and os.path.commonpath([state_real, real(focus)]) == state_real:
        raise Refused("the focus file sits inside the tablet state dir")
    reading = os.path.realpath(os.path.join(state, "aipaper", "reading"))
    for folder in args.folders:
        if os.path.dirname(os.path.realpath(folder)) != reading:
            raise Refused("a folder argument is outside aipaper/reading")
    metas = {f: read_meta(f) for f in args.folders if os.path.isdir(f)}
    todo_ids = {f: set(str(t["id"]) for t in typed_tasks(m)) for f, m in metas.items() if m is not None}
    try:
        payload = json.loads(sys.stdin.read())
    except ValueError:
        raise Refused("stdin is not JSON")
    validate(payload, args.folders, todo_ids)
    pages_read, items = payload["pages_read"], payload["items"]
    batch_todos = set(item["todo_id"] for item in items if "todo_id" in item)
    paths = {"focus": focus, "personal": os.path.join(state, "personal.md"),
             "pool": os.path.join(state, "captures.md"),
             "ledger": os.path.join(state, "aipaper", "ledger.json")}
    with lock(state):
        ledger = load_ledger(paths["ledger"])
        for folder in args.folders:
            if not os.path.isdir(folder):
                emit({"folder": folder, "status": "gone"})
                continue
            ledger = route_folder(folder, metas.get(folder), [i for i in items if i["folder"] == folder],
                                  pages_read.get(folder), batch_todos, ledger, paths, today)
    return 0


def hold(folder, reason):
    if reason != "not fully read":
        try:
            os.remove(os.path.join(folder, ".claims"))  # before the lapse: a delete moves the mtime
        except FileNotFoundError:
            pass
    lapse(folder)
    emit({"folder": folder, "status": "held", "reason": reason})


def route_folder(folder, meta, items, pages_read, batch_todos, ledger, paths, today):
    """File one folder's items; returns the ledger as it now is on disk."""
    if meta is None or pages_read is None:
        hold(folder, "not fully read")
        return ledger
    pages, todos = view(folder, meta, ledger)
    if not set(p["page_id"] for p in pages) <= set(pages_read) \
            or any(t["todo_id"] not in batch_todos for t in todos):
        hold(folder, "not fully read")
        return ledger
    kept, seen = [], set()
    for item in items:
        text = one_line(item["text"])
        if "todo_id" in item:
            key = ("todo", item["todo_id"])
            known = item["todo_id"] in ledger["todos"]
        else:
            key = ("page", item["page_id"], norm(text))
            known = norm(text) in [norm(line) for line in ledger["pages"].get(item["page_id"], [])]
        if not known and key not in seen:
            seen.add(key)
            kept.append(dict(item, text=text))
    focus_items = [i for i in kept if i["bucket"] == "work" and i["kind"] != "idea"] if paths["focus"] else []
    if focus_items and not os.path.isfile(paths["focus"]):
        hold(folder, "focus file missing")
        return ledger
    pool_items = [i for i in kept if i["bucket"] == "work" and i["kind"] == "idea"]
    personal_items = [i for i in kept if i not in focus_items and i not in pool_items]
    new_ledger = json.loads(json.dumps(ledger))
    for item in kept:
        if "todo_id" in item:
            new_ledger["todos"][item["todo_id"]] = item["bucket"]
        else:
            new_ledger["pages"].setdefault(item["page_id"], []).append(item["text"])
    done = []
    try:
        changes = []
        if focus_items:
            changes.append(("focus", lambda old: insert_in_section(
                old, TABLET_HEADING, [item_line(i, today, "focus") for i in focus_items])))
        if personal_items:
            changes.append(("personal", lambda old: insert_in_section(
                old, "## " + today, [item_line(i, today, "personal") for i in personal_items])))
        if pool_items:
            # shortcut: a fomo append to captures.md in the same instant as this replace can be
            # lost; switch to append plus truncate-on-failure if that ever bites.
            tag = " (tablet: %s %s)" % (section_name(meta.get("appType", "")), meta.get("fileName", ""))
            stamp = int(time.time())
            changes.append(("pool", lambda old: old + ("" if old.endswith("\n") or not old else "\n") + "".join(
                "%d fomo: [work] %s%s\n" % (stamp, i["text"], tag) for i in pool_items)))
        if kept:
            # shortcut: the ledger grows without bound; prune by age when it passes about 1 MB.
            changes.append(("ledger", lambda old: json.dumps(new_ledger, indent=1, sort_keys=True) + "\n"))
        prepared = []
        for name, change in changes:
            path = paths[name]
            try:
                with open(path, "rb") as handle:
                    old = handle.read()
                mode = os.stat(path).st_mode & 0o777
            except FileNotFoundError:
                old, mode = None, 0o600
            new = change(old.decode("utf-8") if old is not None else "").encode("utf-8")
            prepared.append((path, old, mode, new))
        for path, old, mode, new in prepared:
            replace_file(path, new, mode)
            done.append((path, old, mode))
    except Exception:
        for path, old, mode in reversed(done):
            try:
                if old is None:
                    os.remove(path)
                else:
                    replace_file(path, old, mode)
            except Exception:
                warn("restore failed %s" % os.path.basename(path))
        hold(folder, "write failed")
        return ledger
    try:
        shutil.rmtree(folder)
    except OSError as exc:  # every item is ledgered: the next route files nothing and deletes it
        warn("could not delete %s (%s); the next sweep retires it" % (os.path.basename(folder), exc))
        lapse(folder)
    emit({"folder": folder, "status": "routed",
          "work": [i["text"] for i in kept if i["bucket"] == "work" and i["kind"] != "idea"],
          "personal": [i["text"] for i in kept if i["bucket"] == "personal"],
          "unsure": [i["text"] for i in kept if i["bucket"] == "unsure"],
          "ideas": [i["text"] for i in pool_items]})
    return new_ledger


def main(argv=None):
    parser = Parser(prog="tablet-inbox.sh", description=__doc__.splitlines()[0])
    parser.add_argument("--state-dir", help="replaces $HOME/.clutch; must already exist")
    verbs = parser.add_subparsers(dest="verb")
    verbs.add_parser("claim")
    verbs.add_parser("release")
    routing = verbs.add_parser("route")
    routing.add_argument("--work-state-dir")
    routing.add_argument("--focus-file")
    routing.add_argument("--today")
    routing.add_argument("folders", nargs="*")
    try:
        args = parser.parse_args(argv)
        if args.verb is None:
            raise Refused("claim, route or release")
        state = args.state_dir or os.path.join(os.path.expanduser("~"), ".clutch")
        if not os.path.isdir(state):  # never created here: its existence switches clutch's brain mode on
            if args.state_dir is None and args.verb != "route":
                return 0
            raise Refused("%s is missing; not creating it" % state)
        state = os.path.realpath(state)
        if args.verb == "claim":
            return claim(state)
        if args.verb == "release":
            return release(state)
        return route(state, args)
    except Refused as exc:
        warn(exc)
        return 2
    except Busy as exc:
        warn(exc)
        return 3
    except Unusable as exc:
        warn(exc)
        return 4


if __name__ == "__main__":
    sys.exit(main())
