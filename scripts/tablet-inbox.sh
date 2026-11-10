#!/bin/sh
# The only entry point to tablet_inbox.py. It exists so a machine with no tablet
# inbox never starts Python: the gate below uses builtins only and exits before
# any interpreter lookup. Usage: tablet-inbox.sh [--state-dir DIR] claim|route|release ...
state=${HOME:-}/.clutch
[ "${1:-}" = --state-dir ] && state=${2:-}
[ -d "$state/inbox/aipaper" ] || [ -d "$state/aipaper/reading" ] || exit 0
PY=$(command -v python3) || { echo "tablet: python3 not found" >&2; exit 5; }
case $0 in */*) here=${0%/*} ;; *) here=. ;; esac
exec "$PY" -B "$here/tablet_inbox.py" "$@"
