"""Tests for templates/opsview.html, the ops view page.

Two legs. The static leg reads the page source: the demo-data samples, the
ticket-like tokens, and the purity of the ops-logic block. The JXA leg
extracts <script id="ops-logic">, appends a driver holding the fixtures
below, runs it with `osascript -l JavaScript`, and compares the JSON it
returns with literal expectations. On Darwin a missing osascript fails; on
other systems the JXA leg is skipped.

Run: /usr/bin/python3 -B tests/opsview_page_test.py
Every fixture value is invented; the shapes follow the S0 probe notes.
"""
import json
import os
import platform
import re
import shutil
import subprocess
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
PAGE = os.path.join(HERE, "..", "templates", "opsview.html")
NOW = "2026-11-23T12:00:00Z"
ALLOWED_TOOLS = ("list_projects", "list_issues", "get_initiative")
# The fields argument of each Linear call, per the S0 probe. Without `fields`,
# list_issues omits parentId and the parent edges vanish.
ISSUE_FIELDS = ["id", "title", "url", "status", "statusType", "assignee", "projectId", "parentId", "updatedAt",
                "priority"]
PROJECT_FIELDS = ["id", "uuid", "name", "status", "initiatives", "url", "lead"]
ASSIGNED_FIELDS = ["id", "title", "url", "status", "statusType", "project", "projectId", "parentId", "updatedAt"]


def page_source():
    # A missing page reads as empty, so every check fails on its assertion.
    try:
        with open(PAGE, encoding="utf-8") as handle:
            return handle.read()
    except FileNotFoundError:
        return ""


def script_block(source, attrs):
    match = re.search(r"<script " + re.escape(attrs) + r">(.*?)</script>", source, re.S)
    return match.group(1) if match else None


# ---- Linear fixtures, shaped per the S0 probe -------------------------------

def puid(n):
    return "00000000-0000-4000-8000-%012d" % n


def iuid(n):
    return "10000000-0000-4000-8000-%012d" % n


def project(n, status_type="started", inits=()):
    return {"id": "P-DEMO-%d" % n, "uuid": puid(n), "name": "Demo project %d" % n,
            "status": {"id": "st%d" % n, "name": status_type.title(), "type": status_type},
            "initiatives": [{"id": iuid(i), "name": "Demo initiative %d" % i} for i in inits],
            "url": "https://linear.app/demo/project/demo%d" % n, "lead": "Pat"}


PARENT_FIELD = object()


def issue(n, proj=None, parent=PARENT_FIELD, status_type="started", project_name=None):
    doc = {"id": "DEMO-%d" % n, "title": "Demo ticket %d" % n,
           "url": "https://linear.app/demo/issue/DEMO-%d" % n,
           "status": "In Progress" if status_type == "started" else status_type.title(),
           "statusType": status_type, "assignee": "Pat",
           "projectId": puid(proj) if proj else None,
           "updatedAt": "2026-11-23T09:00:00Z", "priority": 2}
    if parent is not PARENT_FIELD:
        doc["parentId"] = parent
    if project_name is not None:
        doc["project"] = project_name
    return doc


def norm_issue(n, parent=None, status_type="started"):
    return {"id": "DEMO-%d" % n, "title": "Demo ticket %d" % n,
            "state": "In Progress" if status_type == "started" else status_type.title(),
            "open": status_type not in ("completed", "canceled"),
            "url": "https://linear.app/demo/issue/DEMO-%d" % n, "parent": parent}


def norm_project(n, issues):
    return {"id": "P-DEMO-%d" % n, "name": "Demo project %d" % n,
            "url": "https://linear.app/demo/project/demo%d" % n, "issues": issues}


OBJECTIVE = {"id": iuid(9), "name": "Demo objective", "url": "https://linear.app/demo/initiative/objective"}

PROJECTS = {"projects": [project(1, "started", [1]), project(2, "planned", [2]),
                         project(3, "started", []), project(4, "completed", [1]),
                         project(5, "canceled", []), project(6, "backlog", [2, 1])],
            "hasNextPage": False}

L1 = {
    "projects": PROJECTS,
    "assigned": {"issues": [issue(12, 1, parent="DEMO-11", project_name="Demo project 1"),
                            issue(21, 2, parent=None, project_name="Demo project 2"),
                            issue(71, 7, parent=None, project_name="Partner work"),
                            issue(81, None, parent=None)],
                 "hasNextPage": False},
    "issuesByProject": {
        "P-DEMO-1": {"issues": [issue(11, 1, parent=None), issue(12, 1, parent="DEMO-11")], "hasNextPage": False},
        "P-DEMO-3": {"issues": [issue(31, 3)], "hasNextPage": False},
        "P-DEMO-6": {"issues": [issue(61, 6, parent="DEMO-500")], "hasNextPage": False},
    },
    "initiativesById": {
        iuid(1): {"id": "DEMO-901", "uuid": iuid(1), "name": "Demo initiative one",
                  "url": "https://linear.app/demo/initiative/one", "status": "Active",
                  "owner": {"name": "Sam"}, "parentInitiatives": [OBJECTIVE]},
        iuid(2): {"id": "DEMO-902", "uuid": iuid(2), "name": "Demo initiative two",
                  "url": "https://linear.app/demo/initiative/two", "status": "Active",
                  "owner": {"name": "Sam"}, "parentInitiatives": []},
    },
}

NL1 = {
    "initiatives": [
        {"id": iuid(1), "name": "Demo initiative one", "url": "https://linear.app/demo/initiative/one",
         "parent": OBJECTIVE,
         "projects": [norm_project(1, [norm_issue(11), norm_issue(12, "DEMO-11")])]},
        {"id": iuid(2), "name": "Demo initiative two", "url": "https://linear.app/demo/initiative/two",
         "parent": None,
         "projects": [norm_project(2, [norm_issue(21)]), norm_project(6, [norm_issue(61, "DEMO-500")])]},
    ],
    "noInitiative": [norm_project(3, [norm_issue(31)]),
                     {"id": "none", "name": "No project", "url": None, "issues": [norm_issue(81)]}],
    "outside": [{"id": puid(7), "name": "Partner work", "url": None, "issues": [norm_issue(71)]}],
}

EMPTY_LINEAR = {"initiatives": [], "noInitiative": [], "outside": []}
EMPTY_MODEL = {"zones": [], "noInitiative": [], "outside": [], "other": [], "unlinked": [],
               "floor": {"builds": [], "sessions": [], "moves": []}, "waitsList": [], "edges": [],
               "lastChange": None}

# ---- db document fixtures (IF-5 key names) ----------------------------------

MISSING = object()


def build(wf, status, ticket=MISSING, updated_at="2026-11-23T10:00:00Z"):
    doc = {"wf": wf, "type": "BUILD", "repo": "demo", "branch": "feat/demo", "status": status,
           "created_at": "2026-11-23T08:00:00Z", "updated_at": updated_at}
    if ticket is not MISSING:
        doc["ticket"] = ticket
    return doc


def session(tag, repo, ticket, last_at, tickets=None, moves=()):
    return {"kind": "session", "tag": tag, "repo": repo, "on": "demo work", "on_at": last_at,
            "moves": list(moves), "ticket": ticket,
            "tickets": tickets if tickets is not None else ([ticket] if ticket else []),
            "last_at": last_at, "updated_at": last_at}


def wait(ref, tag, ticket, state="open", updated_at="2026-11-23T10:00:00Z"):
    return {"kind": "wait", "ref": ref, "wait_kind": ref.split(":")[0], "tag": tag, "repo": "demo",
            "baseline": "open", "text": "review", "ticket": ticket, "state": state,
            "opened_at": "2026-11-23T08:00:00Z",
            "closed_at": updated_at if state == "closed" else None, "updated_at": updated_at}


def sweep(key, ticket, present=True, updated_at="2026-11-23T09:00:00Z"):
    return {"kind": "sweep", "key": key, "item_kind": "other", "ref": None, "title": "Demo item",
            "state": "open", "waiting_on": "Sam", "ticket": ticket, "present": present,
            "seen_at": updated_at, "updated_at": updated_at}


def model_input(builds=(), sessions=(), waits=(), sweeps=(), linear=None):
    return {"builds": list(builds), "sessions": list(sessions), "waits": list(waits),
            "sweep": list(sweeps), "linear": linear, "now": NOW}


B_RUN = build("wf-a", "running", "DEMO-12")
S_ON = session("@0000000a", "demo", "DEMO-31", "2026-11-23T11:00:00Z")
W_OPEN = wait("gh:demo/repo#1", None, "DEMO-71")
SW_ON = sweep("linear:DEMO-81", "DEMO-81")
PLACED = model_input([B_RUN], [S_ON], [W_OPEN], [SW_ON], NL1)


def item(kind, ident, doc):
    return {"kind": kind, "id": ident, "doc": doc}


def kinds(items):
    return [(i["kind"], i["id"]) for i in items]


def lanes_of(model):
    out = []
    for zone in model["zones"]:
        out.extend(zone["lanes"])
    return out + model["noInitiative"] + model["outside"]


def placed(model):
    """{ticket: [(kind, id)]} for every map node that holds items."""
    return {node["ticket"]: kinds(node["items"])
            for lane in lanes_of(model) for node in lane["nodes"] if node["items"]}


# ---- watchDiff fixtures -----------------------------------------------------

def pkey(n):
    return "project:P-DEMO-%d" % n


def ikey(n):
    return "initiative:" + iuid(n)


def padd(n):
    return {"key": pkey(n), "tool": "list_issues",
            "input": {"project": "P-DEMO-%d" % n, "fields": ISSUE_FIELDS, "limit": 100}}


def iadd(n):
    return {"key": ikey(n), "tool": "get_initiative", "input": {"query": iuid(n)}}


def without(*numbers):
    return {"projects": [p for p in PROJECTS["projects"] if p["id"] not in ["P-DEMO-%d" % n for n in numbers]]}


P_KEYS = [pkey(1), pkey(3), pkey(2), pkey(6), ikey(1), ikey(2)]
P_PLUS7 = {"projects": PROJECTS["projects"] + [project(7, "started", [1])]}
P_CAPS = {"projects": [project(n, "planned", [n]) for n in range(1, 6)]
          + [project(n, "started", [n] if n <= 25 else []) for n in range(6, 46)]}
P_SECOND = {"projects": [project(1, "started", [1, 3])]}
NOOP = {"drop": [], "add": []}

# ---- the JXA leg ------------------------------------------------------------

DRIVER = r"""
(function () {
  var FNS = {
    normalizeLinear: typeof normalizeLinear === "function" ? normalizeLinear : null,
    watchDiff: typeof watchDiff === "function" ? watchDiff : null,
    opsModel: typeof opsModel === "function" ? opsModel : null
  };
  // The page's watch-table loop: drop first, then add; the table is rebuilt as a new object.
  function replay(payloads) {
    var table = {}, steps = [], registered = [], dupes = [], maxLive = 0;
    payloads.forEach(function (p) {
      var d = FNS.watchDiff(Object.keys(table), p), next = {};
      Object.keys(table).forEach(function (k) { if (d.drop.indexOf(k) < 0) next[k] = 1; });
      d.add.forEach(function (a) {
        if (Object.prototype.hasOwnProperty.call(next, a.key)) dupes.push(a.key);
        next[a.key] = 1;
        registered.push(a.key);
      });
      table = next;
      maxLive = Math.max(maxLive, Object.keys(table).length);
      steps.push([d.drop.length, d.add.length]);
    });
    return {steps: steps, registered: registered, dupes: dupes, maxLive: maxLive, keys: Object.keys(table)};
  }
  // Every property the logic reads off a Linear issue or project, through proxies.
  function reads(payloads) {
    var seen = {issue: {}, assigned: {}, project: {}};
    function spy(obj, kind) {
      return new Proxy(obj, {get: function (t, k) {
        if (typeof k === "string") seen[kind][k] = 1;
        return t[k];
      }});
    }
    function issues(list, kind) {
      return {issues: list.issues.map(function (i) { return spy(i, kind); }), hasNextPage: list.hasNextPage};
    }
    var byProject = {};
    Object.keys(payloads.issuesByProject).forEach(function (k) {
      byProject[k] = issues(payloads.issuesByProject[k], "issue");
    });
    var projects = {projects: payloads.projects.projects.map(function (p) { return spy(p, "project"); })};
    FNS.normalizeLinear({projects: projects, assigned: issues(payloads.assigned, "assigned"),
                         issuesByProject: byProject, initiativesById: payloads.initiativesById});
    FNS.watchDiff([], projects);
    return {issue: Object.keys(seen.issue).sort(), assigned: Object.keys(seen.assigned).sort(),
            project: Object.keys(seen.project).sort(),
            constants: {issue: typeof OPS_ISSUE_FIELDS === "undefined" ? null : OPS_ISSUE_FIELDS,
                        assigned: typeof OPS_ASSIGNED_FIELDS === "undefined" ? null : OPS_ASSIGNED_FIELDS,
                        project: typeof OPS_PROJECT_FIELDS === "undefined" ? null : OPS_PROJECT_FIELDS}};
  }
  var out = {};
  __CALLS__.forEach(function (c) {
    try {
      if (c.fn === "replay") {
        if (!FNS.watchDiff) throw new Error("watchDiff is not a function");
        out[c.name] = {ok: replay(c.args[0])};
      } else if (c.fn === "reads") {
        out[c.name] = {ok: reads(c.args[0])};
      } else {
        if (!FNS[c.fn]) throw new Error(c.fn + " is not a function");
        out[c.name] = {ok: FNS[c.fn].apply(null, c.args)};
      }
    } catch (e) {
      out[c.name] = {error: String(e)};
    }
  });
  return JSON.stringify(out);
})();
"""

CALLS = {
    # normalizeLinear
    "nl-full": ("normalizeLinear", [L1]),
    "nl-no-initiative-payloads": ("normalizeLinear", [dict(L1, initiativesById=None)]),
    "nl-parent-field-absent": ("normalizeLinear", [dict(L1, initiativesById={
        iuid(1): {"id": "DEMO-901", "uuid": iuid(1), "name": "Demo initiative one", "url": "https://linear.app/demo/initiative/one"},
    })]),
    "nl-empty": ("normalizeLinear", [{}]),
    "nl-null": ("normalizeLinear", [None]),
    "nl-null-parts": ("normalizeLinear", [{"projects": None, "assigned": None, "issuesByProject": None,
                                           "initiativesById": None}]),
    "nl-projects-array": ("normalizeLinear", [{"projects": PROJECTS["projects"]}]),
    "nl-truncated": ("normalizeLinear", [dict(L1, issuesByProject=dict(
        L1["issuesByProject"], **{"P-DEMO-1": dict(L1["issuesByProject"]["P-DEMO-1"], hasNextPage=True),
                                  "P-DEMO-3": json.dumps(dict(L1["issuesByProject"]["P-DEMO-3"], hasNextPage=True))}))]),
    "reads": ("reads", [L1]),
    # opsModel
    "m-linear": ("opsModel", [model_input(linear=NL1)]),
    "m-truncated": ("opsModel", [model_input(linear=dict(NL1, noInitiative=[dict(NL1["noInitiative"][0], truncated=True),
                                                                             NL1["noInitiative"][1]]))]),
    "m-placed": ("opsModel", [PLACED]),
    "m-other": ("opsModel", [model_input([build("wf-b", "completed", "DEMO-99")], [],
                                         [wait("slack:C1/1.2", "@0000000b", "DEMO-98")],
                                         [sweep("pr:demo#2", "DEMO-99")], NL1)]),
    "m-unlinked": ("opsModel", [model_input([], [], [wait("cal:demo", None, None)],
                                            [sweep("other:demo", None)], NL1)]),
    "m-build-no-ticket": ("opsModel", [model_input([build("wf-old", "running")], linear=NL1)]),
    "m-untagged": ("opsModel", [model_input([], [session(None, "demo-repo", None, "2026-11-23T11:00:00Z")],
                                            linear=NL1)]),
    "m-linear-null": ("opsModel", [dict(PLACED, linear=None)]),
    "m-floor": ("opsModel", [model_input(
        [build("wf-r", "running", None), build("wf-w", "waiting", None),
         build("wf-c", "completed", None), build("wf-f", "failed", None)],
        [session("@00000003", "three", None, "2026-11-23T09:00:00Z",
                 moves=[{"text": "three-%d" % i, "at": "2026-11-23T08:%02d:00Z" % (59 - i * 2)} for i in range(6)]),
         session("@00000005", "five", None, "2026-11-23T07:00:00Z",
                 moves=[{"text": "five-%d" % i, "at": "2026-11-23T08:%02d:00Z" % (58 - i * 2)} for i in range(6)]),
         session("@0000001e", "old", "DEMO-12", "2026-11-22T06:00:00Z",
                 moves=[{"text": "old-0", "at": "2026-11-23T08:59:30Z"}])],
        linear=NL1)]),
    "m-waits": ("opsModel", [model_input(
        [], [],
        [wait("gh:demo/repo#3", None, None, "open", "2026-11-23T10:00:00Z"),
         wait("gh:demo/repo#4", None, "DEMO-12", "closed", "2026-11-23T11:00:00Z")],
        [sweep("pr:demo#5", None, True, "2026-11-23T09:00:00Z"),
         sweep("pr:demo#6", "DEMO-31", False, "2026-11-23T11:30:00Z")],
        NL1)]),
    "m-waits-tagged": ("opsModel", [model_input([], [], [wait("gh:demo/repo#3", "@0000000c", None)], [], NL1)]),
    "m-edges": ("opsModel", [model_input(
        [], [session("@0000000d", "demo", "DEMO-31", "2026-11-23T11:00:00Z", ["DEMO-31", "DEMO-61", "DEMO-99"]),
             session("@0000000e", "demo", "DEMO-61", "2026-11-23T11:00:00Z", ["DEMO-61", "DEMO-31"]),
             session("@0000000f", "demo", "DEMO-11", "2026-11-21T11:00:00Z", ["DEMO-11", "DEMO-81"])],
        [], [], NL1)]),
    "m-empty": ("opsModel", [{}]),
    "m-empty-lists": ("opsModel", [model_input()]),
    "m-last-change": ("opsModel", [model_input(
        [build("wf-x", "completed", None, "2026-11-23T10:00:00Z"), build("wf-y", "running", None, None)],
        [session("@00000010", "old", None, "2026-11-21T10:00:00Z")],
        [wait("gh:demo/repo#7", None, None, "closed", "2026-11-23T11:45:00Z")],
        [sweep("pr:demo#8", None, False, "2026-11-23T11:30:00Z")])]),
    # watchDiff
    "wd-first": ("watchDiff", [[], PROJECTS]),
    "wd-repeat": ("watchDiff", [P_KEYS, PROJECTS]),
    "wd-project-gone": ("watchDiff", [P_KEYS, without(3)]),
    "wd-sole-initiative-gone": ("watchDiff", [P_KEYS, without(2, 6)]),
    "wd-shared-initiative-kept": ("watchDiff", [P_KEYS, without(2)]),
    "wd-new-project": ("watchDiff", [P_KEYS, P_PLUS7]),
    "wd-caps": ("watchDiff", [[], P_CAPS]),
    "wd-first-initiative-only": ("watchDiff", [[], P_SECOND]),
    "wd-null": ("watchDiff", [P_KEYS, None]),
    "wd-garbage": ("watchDiff", [P_KEYS, "not json"]),
    "wd-no-list": ("watchDiff", [P_KEYS, {}]),
    "wd-bad-list": ("watchDiff", [P_KEYS, {"projects": "x"}]),
    "wd-all-gone": ("watchDiff", [[pkey(1)], {"projects": []}]),
    "wd-json-text": ("watchDiff", [[], json.dumps(PROJECTS)]),
    "wd-call-result": ("watchDiff", [[], {"content": [{"type": "text", "text": "x"}], "payload": PROJECTS}]),
    "wd-replay": ("replay", [[PROJECTS, PROJECTS, PROJECTS, without(3), P_PLUS7, P_PLUS7, None,
                              "not json", P_CAPS, P_CAPS]]),
}

_RESULTS = None


def jxa_results():
    global _RESULTS
    if _RESULTS is None:
        logic = script_block(page_source(), 'id="ops-logic"') or ""
        calls = [{"name": name, "fn": fn, "args": args} for name, (fn, args) in CALLS.items()]
        program = logic + "\n" + DRIVER.replace("__CALLS__", json.dumps(calls))
        tmp = tempfile.mkdtemp()
        try:
            path = os.path.join(tmp, "driver.js")
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(program)
            proc = subprocess.run([OSASCRIPT, "-l", "JavaScript", path],
                                  capture_output=True, text=True, timeout=60)
        finally:
            shutil.rmtree(tmp)
        if proc.returncode != 0:
            raise AssertionError("osascript rc %d: %s" % (proc.returncode, proc.stderr.strip()[-500:]))
        _RESULTS = json.loads(proc.stdout)
    return _RESULTS


OSASCRIPT = shutil.which("osascript") or ("/usr/bin/osascript" if os.path.exists("/usr/bin/osascript") else None)
ON_DARWIN = platform.system() == "Darwin"


@unittest.skipUnless(ON_DARWIN, "JXA leg runs on macOS only")
class JxaLogic(unittest.TestCase):
    def call(self, name):
        self.assertIsNotNone(OSASCRIPT, "osascript is missing on Darwin")
        result = jxa_results()[name]
        self.assertNotIn("error", result, "%s: %s" % (name, result.get("error")))
        return result["ok"]

    # -- normalizeLinear: scope, levels, the flagged zone, outside --

    def test_scope_member(self):
        got = self.call("nl-full")
        self.assertEqual(got, NL1)
        ids = [p["id"] for z in got["initiatives"] for p in z["projects"]] + [p["id"] for p in got["noInitiative"]]
        self.assertNotIn("P-DEMO-4", ids)  # completed
        self.assertNotIn("P-DEMO-5", ids)  # canceled
        self.assertEqual(self.call("nl-projects-array")["initiatives"][0]["projects"][0]["id"], "P-DEMO-1")

    def test_no_initiative(self):
        model = self.call("m-linear")
        self.assertEqual([lane["id"] for lane in model["noInitiative"]], ["P-DEMO-3", "none"])
        self.assertEqual(model["noInitiative"][1]["name"], "No project")
        self.assertEqual([n["ticket"] for n in model["noInitiative"][1]["nodes"]], ["DEMO-81"])
        zone_lanes = [lane["id"] for zone in model["zones"] for lane in zone["lanes"]]
        self.assertNotIn("P-DEMO-3", zone_lanes)
        self.assertNotIn("none", zone_lanes)

    def test_outside(self):
        got = self.call("nl-full")
        self.assertEqual(got["outside"], NL1["outside"])
        self.assertNotIn(puid(7), [p["id"] for p in got["noInitiative"]])
        model = self.call("m-linear")
        self.assertEqual([(lane["id"], lane["name"]) for lane in model["outside"]], [(puid(7), "Partner work")])
        self.assertEqual([n["ticket"] for n in model["outside"][0]["nodes"]], ["DEMO-71"])

    def test_parent_level(self):
        got = self.call("nl-full")
        self.assertEqual([z["parent"] for z in got["initiatives"]], [OBJECTIVE, None])
        bare = self.call("nl-no-initiative-payloads")["initiatives"]
        self.assertEqual([(z["id"], z["name"], z["url"], z["parent"]) for z in bare],
                         [(iuid(1), "Demo initiative 1", None, None), (iuid(2), "Demo initiative 2", None, None)])
        absent = self.call("nl-parent-field-absent")["initiatives"]
        self.assertEqual([(z["name"], z["parent"]) for z in absent],
                         [("Demo initiative one", None), ("Demo initiative 2", None)])
        model = self.call("m-linear")
        self.assertEqual([(z["id"], z["parent"]) for z in model["zones"]], [(iuid(1), OBJECTIVE), (iuid(2), None)])

    def test_two_initiatives(self):
        got = self.call("nl-full")
        self.assertEqual([p["id"] for p in got["initiatives"][1]["projects"]], ["P-DEMO-2", "P-DEMO-6"])
        everywhere = [p["id"] for z in got["initiatives"] for p in z["projects"]]
        self.assertEqual(everywhere.count("P-DEMO-6"), 1)

    def test_truncated_lane(self):
        got = self.call("nl-truncated")
        flags = [(p["id"], p.get("truncated")) for z in got["initiatives"] for p in z["projects"]]
        flags += [(p["id"], p.get("truncated")) for p in got["noInitiative"] + got["outside"]]
        self.assertEqual(flags, [("P-DEMO-1", True), ("P-DEMO-2", None), ("P-DEMO-6", None),
                                 ("P-DEMO-3", True), ("none", None), (puid(7), None)])
        self.assertNotIn("truncated", str(self.call("nl-full")))
        model = self.call("m-truncated")
        self.assertEqual([(lane["id"], lane.get("truncated")) for lane in model["noInitiative"]],
                         [("P-DEMO-3", True), ("none", None)])

    def test_fields_cover_reads(self):
        got = self.call("reads")
        self.assertEqual(got["constants"], {"issue": ISSUE_FIELDS, "assigned": ASSIGNED_FIELDS,
                                            "project": PROJECT_FIELDS})
        self.assertTrue(got["issue"] and got["assigned"] and got["project"])
        self.assertLessEqual(set(got["issue"]), set(ISSUE_FIELDS))
        self.assertLessEqual(set(got["assigned"]), set(ASSIGNED_FIELDS))
        self.assertLessEqual(set(got["project"]), set(PROJECT_FIELDS))
        self.assertIn("parentId", got["issue"])

    # -- opsModel: placement and the zones items land in --

    def test_placement(self):
        model = self.call("m-placed")
        self.assertEqual(placed(model), {"DEMO-12": [("build", "wf-a")], "DEMO-31": [("session", "@0000000a")],
                                         "DEMO-71": [("wait", "gh:demo/repo#1")],
                                         "DEMO-81": [("sweep", "linear:DEMO-81")]})
        self.assertEqual(model["zones"][0]["lanes"][0]["nodes"][1],
                         {"ticket": "DEMO-12", "title": "Demo ticket 12", "state": "In Progress",
                          "url": "https://linear.app/demo/issue/DEMO-12", "items": [item("build", "wf-a", B_RUN)]})
        self.assertEqual((model["other"], model["unlinked"]), ([], []))

    def test_other_zone(self):
        model = self.call("m-other")
        self.assertEqual([(o["ticket"], kinds(o["items"])) for o in model["other"]],
                         [("DEMO-99", [("build", "wf-b"), ("sweep", "pr:demo#2")]),
                          ("DEMO-98", [("wait", "slack:C1/1.2 @0000000b")])])
        self.assertEqual(placed(model), {})

    def test_unlinked(self):
        model = self.call("m-unlinked")
        self.assertEqual(kinds(model["unlinked"]), [("wait", "cal:demo"), ("sweep", "other:demo")])
        self.assertEqual((placed(model), model["other"]), ({}, []))

    def test_build_without_ticket(self):
        model = self.call("m-build-no-ticket")
        self.assertEqual(kinds(model["unlinked"]), [("build", "wf-old")])
        self.assertEqual(kinds(model["floor"]["builds"]), [("build", "wf-old")])

    def test_untagged_session(self):
        model = self.call("m-untagged")
        self.assertEqual(kinds(model["floor"]["sessions"]), [("session", "repo:demo-repo")])
        self.assertEqual(kinds(model["unlinked"]), [("session", "repo:demo-repo")])

    def test_linear_null(self):
        model = self.call("m-linear-null")
        self.assertEqual((model["zones"], model["noInitiative"], model["outside"]), ([], [], []))
        self.assertEqual([(o["ticket"], kinds(o["items"])) for o in model["other"]],
                         [("DEMO-12", [("build", "wf-a")]), ("DEMO-31", [("session", "@0000000a")]),
                          ("DEMO-71", [("wait", "gh:demo/repo#1")]), ("DEMO-81", [("sweep", "linear:DEMO-81")])])
        self.assertEqual(model["unlinked"], [])

    def test_floor(self):
        model = self.call("m-floor")
        self.assertEqual(kinds(model["floor"]["builds"]), [("build", "wf-r"), ("build", "wf-w")])
        self.assertEqual(kinds(model["floor"]["sessions"]), [("session", "@00000003")])
        self.assertEqual([(m["text"], m["session"]) for m in model["floor"]["moves"]],
                         [("three-0", "@00000003"), ("five-0", "@00000005"), ("three-1", "@00000003"),
                          ("five-1", "@00000005"), ("three-2", "@00000003"), ("five-2", "@00000005"),
                          ("three-3", "@00000003"), ("five-3", "@00000005"), ("three-4", "@00000003"),
                          ("five-4", "@00000005")])
        self.assertEqual(model["floor"]["moves"][0], {"text": "three-0", "at": "2026-11-23T08:59:00Z",
                                                      "session": "@00000003"})
        # The session older than 24 h is not shown anywhere.
        self.assertEqual(placed(model), {})

    def test_waits_list(self):
        model = self.call("m-waits")
        self.assertEqual(kinds(model["waitsList"]), [("wait", "gh:demo/repo#3"), ("sweep", "pr:demo#5")])
        self.assertEqual(kinds(model["unlinked"]), [("wait", "gh:demo/repo#3"), ("sweep", "pr:demo#5")])
        self.assertEqual(placed(model), {})
        self.assertEqual(kinds(self.call("m-waits-tagged")["waitsList"]), [("wait", "gh:demo/repo#3 @0000000c")])

    def test_edges(self):
        model = self.call("m-edges")
        self.assertEqual(model["edges"], [{"from": "DEMO-11", "to": "DEMO-12", "kind": "parent"},
                                          {"from": "DEMO-31", "to": "DEMO-61", "kind": "session"}])

    def test_empty(self):
        self.assertEqual(self.call("m-empty"), EMPTY_MODEL)
        self.assertEqual(self.call("m-empty-lists"), EMPTY_MODEL)
        for name in ("nl-empty", "nl-null", "nl-null-parts"):
            self.assertEqual(self.call(name), EMPTY_LINEAR, name)

    def test_last_change(self):
        self.assertEqual(self.call("m-last-change")["lastChange"], "2026-11-23T11:45:00Z")
        self.assertEqual(self.call("m-placed")["lastChange"], "2026-11-23T11:00:00Z")

    # -- watchDiff (PP12) --

    def test_watch_diff(self):
        self.assertEqual(self.call("wd-first"), {"drop": [], "add": [padd(1), padd(3), padd(2), padd(6),
                                                                      iadd(1), iadd(2)]})
        self.assertEqual(self.call("wd-repeat"), NOOP)
        self.assertEqual(self.call("wd-project-gone"), {"drop": [pkey(3)], "add": []})
        self.assertEqual(self.call("wd-sole-initiative-gone"), {"drop": [pkey(2), pkey(6), ikey(2)], "add": []})
        self.assertEqual(self.call("wd-shared-initiative-kept"), {"drop": [pkey(2)], "add": []})
        self.assertEqual(self.call("wd-new-project"), {"drop": [], "add": [padd(7)]})
        caps = self.call("wd-caps")
        self.assertEqual(caps["drop"], [])
        self.assertEqual(caps["add"], [padd(n) for n in range(6, 46)] + [iadd(n) for n in range(6, 21)])
        # Only initiatives[0] is watched: normalizeLinear places a project under its first initiative only.
        self.assertEqual(self.call("wd-first-initiative-only"), {"drop": [], "add": [padd(1), iadd(1)]})
        for name in ("wd-null", "wd-garbage", "wd-no-list", "wd-bad-list"):
            self.assertEqual(self.call(name), NOOP, name)
        self.assertEqual(self.call("wd-all-gone"), {"drop": [pkey(1)], "add": []})
        self.assertEqual(self.call("wd-json-text"), self.call("wd-first"))
        self.assertEqual(self.call("wd-call-result"), self.call("wd-first"))

    def test_watch_diff_replay(self):
        got = self.call("wd-replay")
        self.assertEqual(got["steps"], [[0, 6], [0, 0], [0, 0], [1, 0], [0, 2], [0, 0], [0, 0], [0, 0],
                                        [5, 53], [0, 0]])
        self.assertEqual(got["dupes"], [])
        self.assertLessEqual(got["maxLive"], 55)  # + the two list watches = 57, under 64
        self.assertEqual(len(got["keys"]), 55)
        # P_CAPS keeps P-DEMO-6 and P-DEMO-7, so the switch drops five keys and adds 53.
        self.assertEqual(len(got["registered"]), 6 + 2 + 53)
        self.assertEqual(sorted(got["registered"][:8]), sorted(P_KEYS + [pkey(3), pkey(7)]))


# ---- the static leg ---------------------------------------------------------

SLUG_RE = re.compile(r"(?<![A-Za-z0-9])([A-Za-z]{1,6})-([0-9]{1,6})(?![A-Za-z0-9])")
NOT_TICKETS = ("CVE", "GPT", "HTTP", "ISO", "PEP", "RFC", "SHA", "UTF")
PP8_BANNED = (".set(", ".update(", ".delete(", ".add(", "innerHTML", "outerHTML", "insertAdjacentHTML",
              "document.write")
LOGIC_BANNED = ("document", "window", "claude", "fetch(", "XMLHttpRequest", "new Set", "new Map", "delete ",
                "localStorage")


def demo():
    block = script_block(page_source(), 'type="application/json" id="demo-data"')
    return json.loads(block) if block is not None else None


class Static(unittest.TestCase):
    def test_demo_data_parses(self):
        data = demo()
        self.assertIsInstance(data, dict, "demo-data block missing or not an object")
        self.assertEqual(sorted(data), ["builds", "linear", "now", "sessions", "sweep", "waits"])
        self.assertEqual(sorted(data["linear"]), ["assigned", "initiativesById", "issuesByProject", "projects"])

    def test_demo_data_levels(self):
        data = demo()
        self.assertIsNotNone(data, "demo-data block missing")
        linear = data["linear"]
        members = [p for p in linear["projects"]["projects"]
                   if p["status"]["type"] not in ("completed", "canceled")]
        zone_ids = []
        for p in members:
            if p["initiatives"] and p["initiatives"][0]["id"] not in zone_ids:
                zone_ids.append(p["initiatives"][0]["id"])
        parents = [(linear["initiativesById"].get(i) or {}).get("parentInitiatives") or [] for i in zone_ids]
        self.assertEqual(len({ps[0]["id"] for ps in parents if ps}), 1, "one objective band")
        self.assertEqual(len([ps for ps in parents if not ps]), 1, "one zone without a parent")
        self.assertEqual(len([p for p in members if not p["initiatives"]]), 1, "one noInitiative project")
        member_uuids = {p["uuid"] for p in linear["projects"]["projects"]}
        outside = {i["projectId"] for i in linear["assigned"]["issues"]
                   if i.get("projectId") and i["projectId"] not in member_uuids}
        self.assertEqual(len(outside), 1, "one outside project")

    def test_demo_names_are_fake(self):
        data = demo()
        self.assertIsNotNone(data, "demo-data block missing")
        linear = data["linear"]
        people = {p.get("lead") for p in linear["projects"]["projects"]}
        people |= {i.get("assignee") for p in linear["issuesByProject"].values() for i in p["issues"]}
        people |= {i.get("assignee") for i in linear["assigned"]["issues"]}
        people |= {(i.get("owner") or {}).get("name") for i in linear["initiativesById"].values()}
        people.discard(None)
        self.assertTrue(people, "demo-data names no person")
        self.assertLessEqual(people, {"Pat", "Sam"})

    def test_demo_tokens_only(self):
        source = page_source()
        self.assertTrue(source, "templates/opsview.html missing")
        self.assertTrue(SLUG_RE.search("see X-7 next"), "one-letter ids are ticket-like")
        tokens = {m.group(0) for m in SLUG_RE.finditer(source) if m.group(1).upper() not in NOT_TICKETS}
        self.assertTrue(tokens, "no DEMO- ticket in the page")
        self.assertEqual(sorted(t for t in tokens if not re.fullmatch(r"DEMO-[0-9]+", t)), [])

    def test_logic_block_pure(self):
        source = page_source()
        logic = script_block(source, 'id="ops-logic"')
        self.assertIsNotNone(logic, "ops-logic block missing")
        for name in ("function normalizeLinear(", "function watchDiff(", "function opsModel("):
            self.assertIn(name, logic)
        for text in LOGIC_BANNED:
            self.assertNotIn(text, logic)
        for text in PP8_BANNED:
            self.assertNotIn(text, source)
        tools = re.findall(r'tool: "([^"]*)"', logic)
        self.assertTrue(tools)
        self.assertLessEqual(set(tools), set(ALLOWED_TOOLS))


if __name__ == "__main__":
    unittest.main()
