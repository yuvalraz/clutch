#!/bin/sh
# The only entry point to tablet_inbox.py. It exists so a machine with no tablet
# inbox never starts Python: the gate below uses builtins only and exits before
# any interpreter lookup. Usage: tablet-inbox.sh [--state-dir DIR] claim|route|release ...
# An explicit --state-dir skips the gate: the helper judges it (a missing one is rc 2).
case ${1:-} in
  --state-dir|--state-dir=*) ;;
  *) [ -d "${HOME:-}/.clutch/inbox/aipaper" ] || [ -d "${HOME:-}/.clutch/aipaper/reading" ] || exit 0 ;;
esac
PY=$(command -v python3) || { echo "tablet: python3 not found" >&2; exit 5; }
case $0 in */*) here=${0%/*} ;; *) here=. ;; esac
exec "$PY" -B "$here/tablet_inbox.py" "$@"
