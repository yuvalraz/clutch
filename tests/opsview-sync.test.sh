#!/bin/sh
# The ops view tool under tools/ops_sync: run its unittest suite (scratch
# HOMEs, the real prelude.sh), scan its imports for network modules, then
# drive the sh wrapper under a scratch HOME with PATH set to scratch dirs,
# one with python3 and one without. Hermetic: no real HOME. Silent on success.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE/.." || { echo "FAIL: cannot cd to repo root"; exit 1; }

PYTHONDONTWRITEBYTECODE=1
export PYTHONDONTWRITEBYTECODE

PY=/usr/bin/python3
[ -x "$PY" ] || PY=$(command -v python3)
TOOL=tools/ops_sync/ops_sync.py
W=scripts/opsview-sync.sh

fail=0
for f in "$TOOL" tools/ops_sync/test_ops_sync.py "$W"; do
  [ -f "$f" ] || { echo "FAIL: missing $f"; fail=1; }
done
[ "$fail" = 0 ] || exit 1

out=$("$PY" -B tools/ops_sync/test_ops_sync.py 2>&1) || { echo "FAIL: ops_sync unittest"; echo "$out"; fail=1; }

# Import scan: no network module, at any depth of the module path.
"$PY" -B - "$TOOL" <<'EOF' || { echo "FAIL: ops_sync imports a network module"; fail=1; }
import ast, sys
banned = {"socket", "http", "urllib", "ssl", "ftplib", "smtplib", "requests"}
names = set()
for node in ast.walk(ast.parse(open(sys.argv[1]).read())):
    if isinstance(node, ast.Import):
        names.update(a.name.split(".")[0] for a in node.names)
    elif isinstance(node, ast.ImportFrom):
        names.add((node.module or "").split(".")[0])
sys.exit(1 if not names or names & banned else 0)
EOF

T=$(mktemp -d) || exit 1
trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
HOME=$T/home
export HOME
mkdir -p "$HOME/.clutch"

# $T/py holds sh and python3; $T/nopy holds only sh.
mkdir "$T/py" "$T/nopy"
ln -s /bin/sh "$T/py/sh"
ln -s /bin/sh "$T/nopy/sh"
ln -s "$PY" "$T/py/python3"

# wrap <pathdir> <args...>: run the wrapper; rc in $rc, output in $T/out and $T/err.
wrap() {
  dir=$1; shift
  PATH=$T/$dir /bin/sh "$W" "$@" > "$T/out" 2> "$T/err"
  rc=$?
}

# test_wrapper_passes_through
find "$HOME" | sort > "$T/before"
wrap py
find "$HOME" | sort > "$T/after"
[ "$rc" -eq 0 ] && [ "$(cat "$T/out")" = "OPS: off" ] && [ ! -s "$T/err" ] && cmp -s "$T/before" "$T/after" \
  || { echo "FAIL: test_wrapper_passes_through (off, rc $rc)"; fail=1; }
printf '{"url": "https://claude.ai/artifact/demo-ops-view"}\n' > "$HOME/.clutch/opsview.json"
wrap py --ack 'meta/config=1'
[ "$rc" -eq 2 ] && [ ! -s "$T/out" ] && [ "$(wc -l < "$T/err")" -eq 1 ] && grep -q '^ops_sync: ' "$T/err" \
  || { echo "FAIL: test_wrapper_passes_through (bad --ack, rc $rc)"; fail=1; }

# test_wrapper_no_python
wrap nopy
[ "$rc" -eq 1 ] && [ ! -s "$T/out" ] && [ "$(cat "$T/err")" = "ops_sync: python3 not found" ] \
  || { echo "FAIL: test_wrapper_no_python (rc $rc)"; fail=1; }

# test_wrapper_no_net_words (the README's scripts/ grep) and test_wrapper_no_rm
[ -z "$(grep -E 'curl|wget|/dev/tcp|nc ' "$W")" ] || { echo "FAIL: test_wrapper_no_net_words"; fail=1; }
[ -z "$(grep -E '(^|[^A-Za-z])rm([^A-Za-z]|$)' "$W")" ] || { echo "FAIL: test_wrapper_no_rm"; fail=1; }

exit "$fail"
