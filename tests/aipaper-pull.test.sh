#!/bin/sh
# The tablet puller under tools/aipaper: run its offline unittest suite (an
# in-process fake device on 127.0.0.1, temp state dirs), then drive
# launchd.sh under a scratch HOME with a stubbed launchctl. Hermetic: no
# device, no real HOME, no real launchctl. Silent on success.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE/.." || { echo "FAIL: cannot cd to repo root"; exit 1; }

unset CLUTCH_AIPAPER_HOST
CLUTCH_LAUNCHCTL=true
PYTHONDONTWRITEBYTECODE=1
export CLUTCH_LAUNCHCTL PYTHONDONTWRITEBYTECODE

PY=/usr/bin/python3
[ -x "$PY" ] || PY=python3
L=tools/aipaper/launchd.sh
LABEL=com.clutch.aipaper-pull

fail=0
for f in tools/aipaper/pull.py tools/aipaper/test_pull.py "$L" tools/aipaper/README.md; do
  [ -f "$f" ] || { echo "FAIL: missing $f"; fail=1; }
done

out=$("$PY" tools/aipaper/test_pull.py 2>&1) || { echo "FAIL: unittest suite"; echo "$out"; fail=1; }

T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT
HOME=$T/home
export HOME
PLIST=$HOME/Library/LaunchAgents/$LABEL.plist
PULL=$(pwd)/tools/aipaper/pull.py

# rc <want> or a FAIL line; stdout and stderr of the script stay out of ours.
run() {
  want=$1; label=$2; shift 2
  sh "$L" "$@" >"$T/out" 2>"$T/err"
  rc=$?
  [ "$rc" -eq "$want" ] || { echo "FAIL: $label -- rc $rc, want $want"; fail=1; }
}

# Refusals first, on a HOME with no .clutch: nothing may be written.
mkdir -p "$HOME"
run 2 "install without \$HOME/.clutch" install 192.0.2.10
[ -s "$T/err" ] || { echo "FAIL: missing-.clutch refusal says nothing"; fail=1; }
[ -z "$(ls -A "$HOME")" ] || { echo "FAIL: refused install wrote under HOME"; fail=1; }

mkdir "$HOME/.clutch"
for bad in '' 'a b' 'h;id' 'x<y' '$(id)' '-h'; do
  run 2 "install bad host '$bad'" install "$bad"
  [ -s "$T/err" ] || { echo "FAIL: bad host '$bad' refusal says nothing"; fail=1; }
done
run 2 "install with no host" install
[ -z "$(ls -A "$HOME/.clutch")" ] && [ ! -e "$HOME/Library" ] \
  || { echo "FAIL: refused install wrote something"; fail=1; }

# Not installed: uninstall is rc 0.
run 0 "uninstall when not installed" uninstall

# Install writes a valid plist that names the host and this checkout's pull.py.
run 0 "install" install 192.0.2.10
[ -f "$PLIST" ] || { echo "FAIL: install wrote no plist"; fail=1; }
[ -d "$HOME/.clutch/aipaper" ] || { echo "FAIL: install did not create the log directory"; fail=1; }
if command -v plutil >/dev/null 2>&1; then
  plutil -lint "$PLIST" >/dev/null 2>&1 || { echo "FAIL: plist does not lint"; fail=1; }
fi
has() {
  grep -qF -- "$2" "$PLIST" 2>/dev/null || { echo "FAIL: plist lacks $1: $2"; fail=1; }
}
has "the label" "<string>$LABEL</string>"
has "the interpreter" "<string>/usr/bin/python3</string>"
has "the pull.py path" "<string>$PULL</string>"
has "the host flag" "<string>--host</string>"
has "the host" "<string>192.0.2.10</string>"
has "the log path" "<string>$HOME/.clutch/aipaper/pull.log</string>"
[ "$(grep -cF "$HOME/.clutch/aipaper/pull.log" "$PLIST" 2>/dev/null)" = 2 ] \
  || { echo "FAIL: plist should send stdout and stderr to pull.log"; fail=1; }
grep -A1 -F '<key>StartInterval</key>' "$PLIST" 2>/dev/null | grep -qF '<integer>60</integer>' \
  || { echo "FAIL: StartInterval is not 60"; fail=1; }

run 0 "status" status
grep -qF '192.0.2.10' "$T/out" || { echo "FAIL: status does not print the host"; fail=1; }

# Reinstall replaces the job; a failed bootstrap is rc 1.
run 0 "second install" install 198.51.100.7
has "the new host" "<string>198.51.100.7</string>"
grep -qF '192.0.2.10' "$PLIST" 2>/dev/null && { echo "FAIL: reinstall kept the old host"; fail=1; }
CLUTCH_LAUNCHCTL=false
run 1 "install with a failing launchctl" install 192.0.2.10
CLUTCH_LAUNCHCTL=true
[ -s "$T/err" ] || { echo "FAIL: failed bootstrap says nothing"; fail=1; }

# Uninstall removes the plist; twice is rc 0.
run 0 "uninstall" uninstall
[ ! -e "$PLIST" ] || { echo "FAIL: uninstall left the plist"; fail=1; }
run 0 "uninstall twice" uninstall
run 2 "unknown verb" frobnicate

exit "$fail"
