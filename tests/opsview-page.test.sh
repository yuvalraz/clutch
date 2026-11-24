#!/bin/sh
# The ops view page under templates/: static checks on opsview.html and, on
# macOS, its ops-logic block run under osascript (JXA) against invented
# fixtures. Hermetic: scratch HOME, no network. Silent on success.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE/.." || { echo "FAIL: cannot cd to repo root"; exit 1; }

PYTHONDONTWRITEBYTECODE=1
export PYTHONDONTWRITEBYTECODE

PY=/usr/bin/python3
[ -x "$PY" ] || PY=python3

T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT
HOME=$T
export HOME

fail=0
[ -f templates/opsview.html ] || { echo "FAIL: missing templates/opsview.html"; fail=1; }
out=$("$PY" -B tests/opsview_page_test.py 2>&1) || { echo "FAIL: opsview page tests"; echo "$out"; fail=1; }

exit "$fail"
