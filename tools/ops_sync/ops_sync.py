from __future__ import annotations

"""Turn the clutch worklog into ops view documents (sessions, waits).

Skills never run this file: they run scripts/opsview-sync.sh. Stdlib only, no
network; the model sends the documents. Writes only under ~/.clutch/opsview/
and never deletes. Interface: docs/plans/2026-11-23-ops-view-plan.md IF-1..IF-5.
"""

import hashlib
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COLLECTIONS = ("sessions", "waits", "sweep")
BATCH = 50
MAX_AGE = 432000
TAG_RE = re.compile(r"^@[0-9a-f]{8}$")
URL_RE = re.compile(r"https://[\x21-\x7e]+")
ACK_RE = re.compile(r"^(sessions|waits|sweep)/([A-Za-z0-9_.~:@+-]{1,200})=([0-9]{1,15})$")
CTRL_RE = re.compile(r"[\x00-\x1f\x7f-\x9f]")
ID_KEEP = frozenset(b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.:-")

SLUG_RE = re.compile(r"(?<![A-Za-z0-9])([A-Za-z]{2,6})-([0-9]{1,6})(?![A-Za-z0-9])")
TEXT_RE = re.compile(r"(?<![A-Za-z0-9-])([A-Z]{2,6})-([0-9]{1,6})(?![A-Za-z0-9])")
NOT_TICKETS = ("CVE", "GPT", "HTTP", "ISO", "PEP", "RFC", "SHA", "UTF", "OD", "IF", "RP")
# Schema fields that hold null rather than "" when the people guard blanks them.
NULLABLE = frozenset(("tag", "on", "on_at", "ticket", "closed_at"))


class Fail(Exception):
    """One stderr line and an exit status; the reason never holds an input value."""

    def __init__(self, reason, code=1):
        super().__init__(reason)
        self.code = code


def enc_doc_id(key: str) -> str:
    """IF-2: a db-safe, injective id for a non-empty key."""
    out = "".join(chr(b) if b in ID_KEEP else "~%02X" % b for b in key.encode("utf-8"))
    if out in (".", ".."):
        out = out.replace(".", "~2E")
    if len(out) > 200:
        out = "~h" + hashlib.sha256(key.encode("utf-8")).hexdigest()[:40]
    return out


def ticket_of(slugs: list, texts: list) -> str | None:
    """IF-3: the first ticket id in the slugs, then in the texts."""
    for pattern, values in ((SLUG_RE, slugs), (TEXT_RE, texts)):
        for value in values:
            if not isinstance(value, str):
                continue
            for match in pattern.finditer(value):
                prefix = match.group(1).upper()
                if prefix not in NOT_TICKETS:
                    return "%s-%s" % (prefix, match.group(2))
    return None


def guard_hit(value: str, guard_lines: list) -> bool:
    """True when `value` holds a guard line or sits inside one."""
    folded = value.casefold()
    return any(g.casefold() in folded or (len(value) >= 16 and folded in g.casefold()) for g in guard_lines)


def people_guard(doc: dict, guard_lines: list) -> int:
    """Blank every string in `doc` that holds a guard line or sits inside one; returns the count."""

    def walk(node):
        count = 0
        items = node.items() if isinstance(node, dict) else enumerate(node)
        for key, value in list(items):
            if isinstance(value, str) and guard_hit(value, guard_lines):
                node[key] = None if key in NULLABLE else ""
                count += 1
            elif isinstance(value, (dict, list)):
                count += walk(value)
        return count

    return walk(doc) if guard_lines else 0


def iso(epoch: int) -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(epoch))


def parse_worklog(lines: list, now: int) -> list:
    """Worklog on:/moved:/wait: lines no older than 5 days and not in the future, oldest first.

    Each entry: at, repo, verb, tag (or None), text (the tokens after the verb, tag removed),
    tokens (the tokens after the verb, tag kept). A wait's tag is its third token (prelude.sh
    owns a wait by field 6); any other line's tag is the first of its first three tokens.
    """
    entries = []
    for line in lines:
        fields = line.split()
        if len(fields) < 4 or not fields[0].isdigit() or not fields[0].isascii():
            continue
        at = int(fields[0])
        if at > now or now - at > MAX_AGE or fields[2] not in ("on:", "moved:", "wait:"):
            continue
        tokens = fields[3:]
        spots = [2] if fields[2] == "wait:" else [0, 1, 2]
        tag_at = next((i for i in spots if i < len(tokens) and TAG_RE.match(tokens[i])), None)
        text = tokens if tag_at is None else tokens[:tag_at] + tokens[tag_at + 1:]
        entries.append({"at": at, "repo": fields[1], "verb": fields[2],
                        "tag": None if tag_at is None else tokens[tag_at],
                        "text": " ".join(text), "tokens": tokens})
    return entries


def session_docs(entries: list, ident=enc_doc_id) -> dict:
    groups = {}
    for e in entries:
        # A tag (@ + 8 hex) is shorter than any guard line, so it never holds people text.
        key = ("sessions", e["tag"] or ident("repo:" + e["repo"]))
        groups.setdefault(key, []).append(e)
    docs = {}
    for key, group in groups.items():
        newest = group[::-1]
        ons = [e for e in newest if e["verb"] == "on:"]
        moves = [e for e in newest if e["verb"] == "moved:"]
        repo = newest[0]["repo"]
        tickets = []
        for e in newest:
            t = ticket_of([e["repo"]], [e["text"]])
            if t and t not in tickets:
                tickets.append(t)
        docs[key] = {
            "kind": "session", "tag": newest[0]["tag"], "repo": repo,
            "on": ons[0]["text"][:200] if ons else None,
            "on_at": iso(ons[0]["at"]) if ons else None,
            "moves": [{"text": e["text"][:200], "at": iso(e["at"])} for e in moves[:5]],
            "ticket": ticket_of([repo], ([ons[0]["text"]] if ons else []) + [e["text"] for e in moves]),
            "tickets": tickets[:5],
            "last_at": iso(newest[0]["at"]), "updated_at": iso(newest[0]["at"]),
        }
    return docs


def wait_docs(open_wait_lines: list, previous_docs: dict, now: int, ident=enc_doc_id) -> dict:
    docs = {}
    for line in open_wait_lines:
        fields = line.split()
        if len(fields) < 5 or not fields[0].isdigit() or fields[2] != "wait:":
            continue
        ref = fields[3].rstrip(",;:.\r")
        tag = fields[5] if len(fields) > 5 and TAG_RE.match(fields[5]) else None
        text = " ".join(fields[6:] if tag else fields[5:])[:200]
        opened = iso(int(fields[0]))
        doc_id = ident(ref + " " + tag if tag else ref)
        docs[("waits", doc_id)] = {
            "kind": "wait", "ref": ref, "wait_kind": ref.split(":", 1)[0], "tag": tag,
            "repo": fields[1], "baseline": fields[4], "text": text,
            "ticket": ticket_of([fields[1]], [text]), "state": "open",
            "opened_at": opened, "closed_at": None, "updated_at": opened,
        }
    for key, doc in previous_docs.items():
        if key[0] == "waits" and key not in docs and isinstance(doc, dict) and doc.get("state") == "open":
            closed = dict(doc, state="closed", closed_at=iso(now), updated_at=iso(now))
            docs[key] = closed
    return docs


def build_docs(worklog_lines: list, open_wait_lines: list, sweep_record, previous_docs: dict, now: int,
               ident=enc_doc_id) -> dict:
    """{(collection, doc_id): document} for every session and wait to (re)write.

    `sweep_record` is the IF-6 record (S1b); unused until the sweep documents land.
    `ident` maps a document's key to its id; sync passes one that hashes keys holding people text.
    """
    docs = session_docs(parse_worklog(worklog_lines, now), ident)
    docs.update(wait_docs(open_wait_lines, previous_docs, now, ident))
    return docs


# --- the impure shell ------------------------------------------------------


def dump(obj) -> bytes:
    return (json.dumps(obj, sort_keys=True, ensure_ascii=False, indent=1) + "\n").encode("utf-8")


def write_atomic(path: Path, data: bytes):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.parent / ("." + path.name + ".tmp")
    with open(tmp, "wb") as handle:
        handle.write(data)
    os.replace(tmp, path)


def load_state(base: Path) -> dict:
    try:
        raw = (base / "state.json").read_bytes()
    except FileNotFoundError:
        return {"versions": {}, "acked": {}}
    except OSError:
        raw = b""
    try:
        state = json.loads(raw.decode("utf-8"))
        if not isinstance(state, dict):
            raise ValueError
        state.setdefault("versions", {})
        state.setdefault("acked", {})
        if not isinstance(state["versions"], dict) or not isinstance(state["acked"], dict):
            raise ValueError
        return state
    except ValueError:
        print("ops_sync: state reset", file=sys.stderr)
        return {"versions": {}, "acked": {}}


def read_config(home: str) -> str:
    try:
        raw = (Path(home) / ".clutch" / "opsview.json").read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        raise Fail("~/.clutch/opsview.json: cannot be read")
    try:
        config = json.loads(raw)
    except ValueError:
        raise Fail("~/.clutch/opsview.json: not valid JSON")
    if not isinstance(config, dict):
        raise Fail("~/.clutch/opsview.json: not a JSON object")
    url = config.get("url")
    if not isinstance(url, str) or len(url) > 2048 or not URL_RE.fullmatch(url):
        raise Fail("~/.clutch/opsview.json: url must be an https URL of at most 2048 characters")
    return url


def read_guard(home: str) -> list:
    path = Path(home) / ".clutch" / "people.md"
    if not os.path.lexists(path):
        return []
    try:
        text = path.read_bytes().decode("utf-8", "replace")
    except OSError:
        raise Fail("~/.clutch/people.md cannot be read")
    stripped = (line.strip().lstrip("-*#> \t").strip() for line in text.splitlines())
    return [line for line in stripped if len(line) >= 16]


def read_worklog(home: str) -> tuple:
    """(last 2000 worklog lines, open wait lines) or Fail when the worklog is unreadable."""
    try:
        proc = subprocess.run(["sh", "-c", '. "$1/scripts/prelude.sh" && clutch_open_loops', "sh", str(ROOT)],
                              cwd=home, timeout=20, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    except (OSError, subprocess.SubprocessError):
        raise Fail("worklog unreadable")
    worklog = Path(home) / ".clutch" / "worklog.md"
    # rc 1 also covers a dangling link; only a worklog that is truly absent means "none".
    if proc.returncode == 1 and not os.path.lexists(worklog):
        return [], []
    if proc.returncode != 0:
        raise Fail("worklog unreadable")
    try:
        raw = worklog.read_bytes()
    except OSError:
        if os.path.lexists(worklog):
            raise Fail("worklog unreadable")
        return [], []
    lines = raw.decode("utf-8", "replace").splitlines()[-2000:]
    return lines, proc.stdout.decode("utf-8", "replace").splitlines()


def read_docs(docs_dir: Path) -> dict:
    found = {}
    for collection in COLLECTIONS:
        folder = docs_dir / collection
        if not folder.is_dir():
            continue
        for path in folder.glob("*.json"):
            try:
                found[(collection, path.name[:-5])] = json.loads(path.read_bytes().decode("utf-8"))
            except (OSError, ValueError):
                found[(collection, path.name[:-5])] = None
    return found


def sync(home: str) -> int:
    if not os.path.isfile(Path(home) / ".clutch" / "opsview.json"):
        print("OPS: off")
        return 0
    url = read_config(home)
    base = Path(home) / ".clutch" / "opsview"
    docs_dir = base / "docs"
    if re.search(r"\s", str(docs_dir)):
        raise Fail("document path contains whitespace")
    guard = read_guard(home)
    worklog_lines, open_lines = read_worklog(home)
    now = int(time.time())
    state = load_state(base)
    previous = read_docs(docs_dir)
    hashed = []

    def ident(key):
        if guard_hit(key, guard):
            hashed.append(key)
            return "~h" + hashlib.sha256(key.encode("utf-8")).hexdigest()[:40]
        return enc_doc_id(key)

    docs = build_docs(worklog_lines, open_lines, None, previous, now, ident)
    blanked = len(hashed) + sum(people_guard(doc, guard) for doc in docs.values())
    if blanked:
        print("ops_sync: people-file text kept out of %d fields" % blanked, file=sys.stderr)
    try:
        for (collection, doc_id), doc in docs.items():
            data = dump(doc)
            path = docs_dir / collection / (doc_id + ".json")
            if previous.get((collection, doc_id)) is None or dump(previous[(collection, doc_id)]) != data:
                write_atomic(path, data)
    except OSError:
        raise Fail("cannot write documents")
    changed = []
    for (collection, doc_id), doc in read_docs(docs_dir).items():
        path = docs_dir / collection / (doc_id + ".json")
        try:
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
        except OSError:
            continue
        key = collection + "/" + doc_id
        if digest != state["acked"].get(key):
            stamp = doc.get("updated_at") if isinstance(doc, dict) else None
            changed.append((stamp if isinstance(stamp, str) else "", key, collection, doc_id, path))
    changed.sort(reverse=True)
    lines = ["OPS: " + url]
    for _, key, collection, doc_id, path in changed[:BATCH]:
        version = state["versions"].get(key)
        tail = " if_version=%d" % version if type(version) is int and version >= 0 else ""
        lines.append("OPS_DOC: %s %s %s%s" % (collection, doc_id, path, tail))
    if not changed:
        lines.append("OPS: unchanged")
        # Nothing to send is a push that succeeded: it clears a failure mark, said or not.
        if "failed" in state or "failed_said" in state:
            state.pop("failed", None)
            state.pop("failed_said", None)
            try:
                write_atomic(base / "state.json", dump(state))
            except OSError:
                pass
    print("\n".join(lines))
    return 0


def ack(home: str, args: list) -> int:
    if not args:
        raise Fail("ack: no argument", 2)
    if not home:
        raise Fail("ack: no HOME", 2)
    base = Path(home) / ".clutch" / "opsview"
    recorded = []
    for index, arg in enumerate(args, 1):
        match = ACK_RE.match(arg)
        if not match or match.group(2) in (".", ".."):
            raise Fail("ack: argument %d is malformed" % index, 2)
        path = base / "docs" / match.group(1) / (match.group(2) + ".json")
        try:
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
        except OSError:
            raise Fail("ack: argument %d names no document" % index, 2)
        recorded.append((match.group(1) + "/" + match.group(2), int(match.group(3)), digest))
    state = load_state(base)
    for key, version, digest in recorded:
        state["versions"][key] = version
        state["acked"][key] = digest
    state.pop("failed", None)
    state.pop("failed_said", None)
    try:
        write_atomic(base / "state.json", dump(state))
    except OSError:
        raise Fail("ack: cannot write state")
    print("OPS: acked")
    return 0


def failed(home: str, speak: bool, reason: str) -> int:
    """Record a failed push. A beat (no --speak) always hears quiet; a sweep hears say once."""
    try:
        if not home:
            raise OSError
        base = Path(home) / ".clutch" / "opsview"
        state = load_state(base)
        if "failed" not in state:
            state["failed_said"] = False
        state["failed"] = CTRL_RE.sub("", reason)[:200]
        say = state.get("failed_said") is not True
        if speak and say:
            state["failed_said"] = True
        write_atomic(base / "state.json", dump(state))
    except OSError:
        say = True  # unrecorded, so a sweep says it every time
    print("OPS: say" if speak and say else "OPS: quiet")
    return 0


def main(argv: list | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    home = os.environ.get("HOME", "")
    try:
        if not argv:
            if not home:
                print("OPS: off")
                return 0
            return sync(home)
        if argv[0] == "--ack":
            return ack(home, argv[1:])
        if argv[0] == "--failed":
            speak = argv[1:2] == ["--speak"]
            return failed(home, speak, " ".join(argv[2:] if speak else argv[1:]))
        raise Fail("usage: ops_sync [--ack <collection>/<doc_id>=<version> ...] [--failed [--speak] <reason>]", 2)
    except Fail as err:
        print("ops_sync: %s" % err, file=sys.stderr)
        return err.code


if __name__ == "__main__":
    sys.exit(main())
