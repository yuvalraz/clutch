#!/bin/sh
# The only entry point to tablet_inbox.py. It exists so a machine with no tablet
# inbox never starts Python: the gate below uses builtins only and exits before
# any interpreter lookup. Usage: tablet-inbox.sh [--state-dir DIR] claim|route|release|fold ...
# An explicit --state-dir skips the inbox gate: the helper judges it (a missing one is rc 2).
# fold starts Python only when the --work-state-dir's tablet.md holds something.
case ${1:-} in
  --state-dir) verb=${3:-} ;;
  --state-dir=*) verb=${2:-} ;;
  *) verb=${1:-}; [ "$verb" = fold ] || [ -d "${HOME:-}/.clutch/inbox/aipaper" ] \
       || [ -d "${HOME:-}/.clutch/aipaper/reading" ] || exit 0 ;;
esac
if [ "$verb" = fold ]; then
  work= prev=
  for arg in "$@"; do
    [ "$prev" = --work-state-dir ] && work=$arg
    case $arg in --work-state-dir=*) work=${arg#*=} ;; esac
    prev=$arg
  done
  [ -n "$work" ] && [ -s "$work/tablet.md" ] || exit 0
fi
PY=$(command -v python3) || { echo "tablet: python3 not found" >&2; exit 5; }
case $0 in */*) here=${0%/*} ;; *) here=. ;; esac
exec "$PY" -B "$here/tablet_inbox.py" "$@"
