#!/bin/sh
# The only entry point skills run for the ops view: it finds python3 and hands
# arguments, stdin, output and the exit status to tools/ops_sync/ops_sync.py.
PY=$(command -v python3) || { echo "ops_sync: python3 not found" >&2; exit 1; }
case $0 in */*) here=${0%/*} ;; *) here=. ;; esac
exec "$PY" -B "$here/../tools/ops_sync/ops_sync.py" "$@"
