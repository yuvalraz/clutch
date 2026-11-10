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
DOMAIN=gui/$(id -u)

# A recording launchctl: it logs its arguments; bootstrap loads the job,
# bootout unloads it, print answers whether it is loaded. The files `refuse`
# and `stuck` beside it make bootstrap fail and bootout leave the job.
mkdir "$T/ctl"
cat > "$T/ctl/launchctl" <<'EOF'
#!/bin/sh
d=$(dirname "$0")
echo "$*" >> "$d/calls"
case $1 in
  bootstrap) [ ! -e "$d/refuse" ] && : > "$d/loaded" ;;
  bootout) [ -e "$d/loaded" ] && [ ! -e "$d/stuck" ] && rm "$d/loaded" ;;
  print) [ -e "$d/loaded" ] ;;
esac
EOF
chmod +x "$T/ctl/launchctl"
CLUTCH_LAUNCHCTL=$T/ctl/launchctl
: > "$T/ctl/calls"

# rc <want> or a FAIL line; stdout and stderr of the script stay out of ours.
run() {
  want=$1; label=$2; shift 2
  sh "$L" "$@" >"$T/out" 2>"$T/err"
  rc=$?
  [ "$rc" -eq "$want" ] || { echo "FAIL: $label -- rc $rc, want $want"; fail=1; }
}
# says <file> <text> <label>: the last run's out or err holds the text.
says() {
  grep -qF -- "$2" "$T/$1" || { echo "FAIL: $3 -- $1 lacks: $2"; fail=1; }
}

# Refusals first, on a HOME with no .clutch: nothing may be written.
mkdir -p "$HOME"
run 2 "install without \$HOME/.clutch" install 192.0.2.10
[ -s "$T/err" ] || { echo "FAIL: missing-.clutch refusal says nothing"; fail=1; }
[ -z "$(ls -A "$HOME")" ] || { echo "FAIL: refused install wrote under HOME"; fail=1; }

mkdir "$HOME/.clutch"
for bad in '' 'a b' 'h;id' 'x<y' '$(id)' '-h' 'a..b' '..' '.' '.-.' '::' '192.0.2.10:8090' 'tablet:8090' 'tablet:'; do
  run 2 "install bad host '$bad'" install "$bad"
  [ "$(wc -l < "$T/err")" -eq 1 ] || { echo "FAIL: bad host '$bad' refusal is not one line"; fail=1; }
done
run 2 "install a host with a port" install 192.0.2.10:8090
says err "without the port" "host:port refusal"
run 2 "install with no host" install
[ -z "$(ls -A "$HOME/.clutch")" ] && [ ! -e "$HOME/Library" ] \
  || { echo "FAIL: refused install wrote something"; fail=1; }
[ ! -s "$T/ctl/calls" ] || { echo "FAIL: a refused install called launchctl"; fail=1; }

# Not installed: uninstall is rc 0, status says so.
run 0 "uninstall when not installed" uninstall
run 0 "status when not installed" status
says out "plist: not installed" "status before install"
says out "loaded: no" "status before install"

# Install writes a valid plist that names the host and this checkout's pull.py.
: > "$T/ctl/calls"
run 0 "install" install 192.0.2.10
[ -f "$PLIST" ] || { echo "FAIL: install wrote no plist"; fail=1; }
[ -d "$HOME/.clutch/aipaper" ] || { echo "FAIL: install did not create the log directory"; fail=1; }
[ "$(cat "$T/ctl/calls")" = "bootout $DOMAIN/$LABEL
bootstrap $DOMAIN $PLIST" ] || { echo "FAIL: install launchctl calls: $(cat "$T/ctl/calls")"; fail=1; }
lint() {
  if command -v plutil >/dev/null 2>&1; then
    plutil -lint "$PLIST" >/dev/null 2>&1 || { echo "FAIL: plist does not lint ($1)"; fail=1; }
  fi
}
lint "install"
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
says out "192.0.2.10" "status host"
says out "loaded: yes" "status after install"
grep -q '^log:' "$T/out" && { echo "FAIL: status prints a log line with no pull.log"; fail=1; }
printf 'first line\naipaper: 1 notes, 2 pages\n' > "$HOME/.clutch/aipaper/pull.log"
run 0 "status with a log" status
says out "log: aipaper: 1 notes, 2 pages" "status last log line"
grep -qF 'first line' "$T/out" && { echo "FAIL: status prints more than the last log line"; fail=1; }

# Reinstall replaces the job; an IPv6 address is a host, not host:port.
run 0 "second install" install 2001:db8::7
has "the new host" "<string>2001:db8::7</string>"
grep -qF '192.0.2.10' "$PLIST" 2>/dev/null && { echo "FAIL: reinstall kept the old host"; fail=1; }

# A failed bootstrap is rc 1 and says the plist stays armed.
: > "$T/ctl/refuse"
run 1 "install with a failing bootstrap" install 192.0.2.10
rm "$T/ctl/refuse"
[ "$(wc -l < "$T/err")" -eq 1 ] || { echo "FAIL: failed bootstrap is not one line"; fail=1; }
says err "next login" "failed bootstrap"
says err "uninstall" "failed bootstrap"
[ -f "$PLIST" ] || { echo "FAIL: failed bootstrap removed the plist"; fail=1; }
run 0 "status after a failed bootstrap" status
says out "loaded: no" "status after a failed bootstrap"

# A checkout path with & is escaped in the plist.
mkdir "$T/a&b"
cp "$L" "$T/a&b/launchd.sh"
KEEP=$L
L=$T/a\&b/launchd.sh
run 0 "install from a path with &" install 192.0.2.10
L=$KEEP
has "the escaped path" "<string>$T/a&amp;b/pull.py</string>"
lint "path with &"

# Uninstall removes the plist; a job that will not stop is rc 1; twice is rc 0.
: > "$T/ctl/stuck"
: > "$T/ctl/calls"
run 1 "uninstall with a job that stays loaded" uninstall
rm "$T/ctl/stuck"
[ "$(wc -l < "$T/err")" -eq 1 ] || { echo "FAIL: stuck uninstall is not one line"; fail=1; }
[ "$(cat "$T/ctl/calls")" = "bootout $DOMAIN/$LABEL
print $DOMAIN/$LABEL" ] || { echo "FAIL: uninstall launchctl calls: $(cat "$T/ctl/calls")"; fail=1; }
run 0 "uninstall" uninstall
[ ! -e "$PLIST" ] || { echo "FAIL: uninstall left the plist"; fail=1; }
run 0 "uninstall twice" uninstall
run 2 "unknown verb" frobnicate

exit "$fail"
