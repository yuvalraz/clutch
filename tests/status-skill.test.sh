#!/bin/sh
# Status skill: step 1 runs the script through the documented
# ${CLAUDE_PLUGIN_ROOT} substitution, not a hand-resolved base-directory path,
# and the skill stays model-invocable. Then run the real scripts/status.sh in
# a scratch git repo and in a non-git dir: it must exit 0 both times and say
# which substrate it found. Then seed .clutch/session-state four ways and
# assert the stop-hook line: no stop line yet is "not fired yet", a malformed
# stop line is "unreadable". Then two permission cases (skipped as root): a
# chmod 000 file is "unreadable" with no garbled bell line, a chmod 444 file
# is "not writable" rather than "not fired yet". Then four .clutch directory
# cases: mode 000 is "not readable" with no bell or sprint line; mode 555,
# with or without a state file, is "not writable" (the temp-file-plus-mv
# rewriters and the anchor's create cannot record), never "fired" and never
# "no session state yet"; mode 300 (searchable, not listable) is "not
# readable". Then four shape cases: .clutch as a regular file or a dangling
# symlink is "not a directory", never the plugin-enablement line; a
# session-state directory, alone or inside a 555 .clutch (non-root only; pins
# the shape check above the not-writable check), and a dangling session-state
# symlink are "not a file", never "no session state yet".
# STATUS_SKILL and STATUS_SH override the skill
# file and the script, so both can be replayed against any historical version
# (git show BASE:... > tmp).
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
S=${STATUS_SKILL:-$ROOT/skills/status/SKILL.md}
ST=${STATUS_SH:-$ROOT/scripts/status.sh}

fail=0
for f in "$S" "$ST"; do
  [ -f "$f" ] || { echo "FAIL: missing $f"; fail=1; }
done
[ "$fail" -eq 0 ] || exit 1

# pin: rc 0 passes; 1 = pattern gone, >=2 = grep broke.
pin() {
  label=$1; pat=$2
  grep -qF -- "$pat" "$S"
  rc=$?
  case $rc in
    0) ;;
    1) echo "FAIL: $label -- pattern not found: $pat"; fail=1 ;;
    *) echo "FAIL: $label -- grep error rc=$rc: $pat"; fail=1 ;;
  esac
}
# unpin: rc 1 passes; 0 = pattern present, >=2 = grep broke.
unpin() {
  label=$1; pat=$2
  grep -qF -- "$pat" "$S"
  rc=$?
  case $rc in
    1) ;;
    0) echo "FAIL: $label -- pattern present: $pat"; fail=1 ;;
    *) echo "FAIL: $label -- grep error rc=$rc: $pat"; fail=1 ;;
  esac
}

# --- skill pins (the positive pin keeps the negatives from passing vacuously)
pin   "skill: runs the script via CLAUDE_PLUGIN_ROOT" 'sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"'
pin   "skill: keeps the \$0 warning, escaped"         'Never locate it with \$0 or $BASH_SOURCE'
unpin "skill: no bare \$0 (argument shorthand)"       'Never locate it with $0'
pin   "skill: unresolved path stops"                  'path did not resolve (`/scripts/status.sh` not found)'
pin   "skill: says clutch is not loaded"              'clutch is not loaded as a plugin in this session'
pin   "skill: no search for the script"               'do not search for the script'
unpin "skill: no hand-resolved path"                  '<base-directory>'
unpin "skill: stays model-invocable"                  'disable-model-invocation: true'
pin   "skill: fix for a .clutch hooks cannot use"     'chmod u+rwx .clutch'
# One pin per Step 3 fix line: the status phrase plus its fix verb.
pin   "skill: fix line, .clutch dir"      '`.clutch present but not readable` or `.clutch not writable`: `chmod u+rwx .clutch`'
pin   "skill: fix line, state file mode"  '`state present but not writable`, or `unreadable` when the file'"'"'s mode blocks reading: `chmod u+rw .clutch/session-state`'
pin   "skill: fix line, .clutch shape"    '`.clutch present but not a directory`: moving that `.clutch` file or link aside'
pin   "skill: fix line, state shape"      '`session-state present but not a file`: moving `.clutch/session-state` aside'

T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT

# --- (iv) scratch git repo: rc 0, first line "clutch status"
mkdir "$T/repo"
git -C "$T/repo" init -q
OUT=$(cd "$T/repo" && sh "$ST"); rc=$?
[ "$rc" = 0 ] || { echo "FAIL: status in git repo exited $rc"; fail=1; }
FIRST=$(printf '%s\n' "$OUT" | head -n 1)
[ "$FIRST" = "clutch status" ] || { echo "FAIL: status in git repo -- first line: $FIRST"; fail=1; }

# --- (v) non-git dir: rc 0, substrate reported absent
mkdir "$T/plain"
OUT=$(cd "$T/plain" && GIT_CEILING_DIRECTORIES="$T" sh "$ST"); rc=$?
[ "$rc" = 0 ] || { echo "FAIL: status in non-git dir exited $rc"; fail=1; }
case "$OUT" in *'git substrate: absent'*) ;; *) echo "FAIL: status in non-git dir -- no 'git substrate: absent' line"; fail=1 ;; esac

# --- (vi) the stop-hook line across session-state shapes, in the scratch repo
mkdir -p "$T/repo/.clutch"
stop_line() {
  label=$1; state=$2; want=$3
  printf '%b' "$state" > "$T/repo/.clutch/session-state" \
    || { echo "FAIL: status ($label) -- fixture write failed"; fail=1; return; }
  OUT=$(cd "$T/repo" && sh "$ST"); rc=$?
  [ "$rc" = 0 ] || { echo "FAIL: status ($label) exited $rc"; fail=1; }
  printf '%s\n' "$OUT" | grep -qxF "  stop hook: $want" \
    || { echo "FAIL: status ($label) -- want 'stop hook: $want', got:"; printf '%s\n' "$OUT" | grep 'stop hook'; fail=1; }
}
stop_line "fresh start/base"   'start 100\nbase -\n'                    'not fired yet in this state'
stop_line "declined only"      'declined 889814453\n'                    'not fired yet in this state'
stop_line "valid stop"         'start 100\nbase -\nstop 200\n'          'fired in this state (stop events recorded: 1)'
stop_line "malformed stop"     'start 100\nbase -\nstop abc\n'          'state present but unreadable'

# --- (vii) permissions: root reads and writes through chmod, so skip there.
# Permissions are restored after each case so the trap's rm -rf works.
SS="$T/repo/.clutch/session-state"
CD="$T/repo/.clutch"
trap 'chmod 755 "$CD" 2>/dev/null; chmod 644 "$SS" 2>/dev/null; rm -rf "$T"' EXIT
if [ "$(id -u)" = 0 ]; then
  echo "SKIP: permission cases (running as root)"
else
  printf 'start 100\nbase -\nstop 200\n' > "$SS" \
    || { echo "FAIL: unreadable fixture write failed"; fail=1; }
  chmod 000 "$SS" || { echo "FAIL: chmod 000 failed"; fail=1; }
  OUT=$(cd "$T/repo" && sh "$ST"); rc=$?
  chmod 644 "$SS"
  [ "$rc" = 0 ] || { echo "FAIL: status (unreadable) exited $rc"; fail=1; }
  printf '%s\n' "$OUT" | grep -qxF '  stop hook: state present but unreadable' \
    || { echo "FAIL: status (unreadable) -- got:"; printf '%s\n' "$OUT" | grep 'stop hook'; fail=1; }
  printf '%s\n' "$OUT" | grep -qxF '  bell: unknown while the state is unreadable' \
    || { echo "FAIL: status (unreadable) -- bell line, got:"; printf '%s\n' "$OUT" | grep 'bell'; fail=1; }

  printf 'start 100\nbase -\n' > "$SS" \
    || { echo "FAIL: not-writable fixture write failed"; fail=1; }
  chmod 444 "$SS" || { echo "FAIL: chmod 444 failed"; fail=1; }
  OUT=$(cd "$T/repo" && sh "$ST"); rc=$?
  chmod 644 "$SS"
  [ "$rc" = 0 ] || { echo "FAIL: status (not writable) exited $rc"; fail=1; }
  printf '%s\n' "$OUT" | grep -qxF '  stop hook: state present but not writable; hooks cannot record' \
    || { echo "FAIL: status (not writable) -- got:"; printf '%s\n' "$OUT" | grep 'stop hook'; fail=1; }

  # .clutch the script cannot search: the files inside are invisible to [ -f ].
  printf 'start 100\nbase -\nstop 200\n' > "$SS" \
    || { echo "FAIL: dir-unreadable fixture write failed"; fail=1; }
  chmod 000 "$CD" || { echo "FAIL: chmod 000 dir failed"; fail=1; }
  OUT=$(cd "$T/repo" && sh "$ST"); rc=$?
  chmod 755 "$CD"
  [ "$rc" = 0 ] || { echo "FAIL: status (dir unreadable) exited $rc"; fail=1; }
  printf '%s\n' "$OUT" | grep -qxF '  stop hook: .clutch present but not readable' \
    || { echo "FAIL: status (dir unreadable) -- got:"; printf '%s\n' "$OUT" | grep 'stop hook'; fail=1; }
  printf '%s\n' "$OUT" | grep -qE '^  (bell|sprint):' \
    && { echo "FAIL: status (dir unreadable) -- bell or sprint line printed:"; printf '%s\n' "$OUT" | grep -E '^  (bell|sprint):'; fail=1; }

  # .clutch the hooks cannot write: a writable file does not help a rewriter
  # whose temp file lands in the dir.
  chmod 555 "$CD" || { echo "FAIL: chmod 555 dir failed"; fail=1; }
  OUT=$(cd "$T/repo" && sh "$ST"); rc=$?
  chmod 755 "$CD"
  [ "$rc" = 0 ] || { echo "FAIL: status (dir not writable) exited $rc"; fail=1; }
  printf '%s\n' "$OUT" | grep -qxF '  stop hook: .clutch not writable; some hooks cannot record' \
    || { echo "FAIL: status (dir not writable) -- got:"; printf '%s\n' "$OUT" | grep 'stop hook'; fail=1; }

  rm -f "$SS" || { echo "FAIL: rm session-state failed"; fail=1; }
  chmod 555 "$CD" || { echo "FAIL: chmod 555 dir failed"; fail=1; }
  OUT=$(cd "$T/repo" && sh "$ST"); rc=$?
  chmod 755 "$CD"
  [ "$rc" = 0 ] || { echo "FAIL: status (dir not writable, no state) exited $rc"; fail=1; }
  printf '%s\n' "$OUT" | grep -qxF '  stop hook: .clutch not writable; hooks cannot record' \
    || { echo "FAIL: status (dir not writable, no state) -- got:"; printf '%s\n' "$OUT" | grep 'stop hook'; fail=1; }

  # Mode 300 searches but cannot list: the -r half of the not-readable guard.
  printf 'start 100\nbase -\nstop 200\n' > "$SS" \
    || { echo "FAIL: dir-300 fixture write failed"; fail=1; }
  chmod 300 "$CD" || { echo "FAIL: chmod 300 dir failed"; fail=1; }
  OUT=$(cd "$T/repo" && sh "$ST"); rc=$?
  chmod 755 "$CD"
  [ "$rc" = 0 ] || { echo "FAIL: status (dir 300) exited $rc"; fail=1; }
  printf '%s\n' "$OUT" | grep -qxF '  stop hook: .clutch present but not readable' \
    || { echo "FAIL: status (dir 300) -- got:"; printf '%s\n' "$OUT" | grep 'stop hook'; fail=1; }
fi

# --- (viii) shapes: .clutch or session-state present as the wrong kind of
# thing is reported, never mistaken for an absent install or a fresh state.
mkdir "$T/repo2" || { echo "FAIL: mkdir repo2 failed"; fail=1; }
git -C "$T/repo2" init -q || { echo "FAIL: git init repo2 failed"; fail=1; }
C2="$T/repo2/.clutch"
shape_line() {
  label=$1; want=$2; nowant=$3
  OUT=$(cd "$T/repo2" && sh "$ST"); rc=$?
  [ "$rc" = 0 ] || { echo "FAIL: status ($label) exited $rc"; fail=1; }
  printf '%s\n' "$OUT" | grep -qxF "  stop hook: $want" \
    || { echo "FAIL: status ($label) -- want 'stop hook: $want', got:"; printf '%s\n' "$OUT"; fail=1; }
  printf '%s\n' "$OUT" | grep -qF "$nowant" \
    && { echo "FAIL: status ($label) -- printed '$nowant'"; fail=1; }
}
printf 'x\n' > "$C2" || { echo "FAIL: .clutch file fixture write failed"; fail=1; }
shape_line ".clutch is a file" '.clutch present but not a directory' 'no .clutch state here'
rm -f "$C2" || { echo "FAIL: rm .clutch file failed"; fail=1; }
ln -s "$T/nowhere" "$C2" || { echo "FAIL: dangling symlink fixture failed"; fail=1; }
shape_line ".clutch is a dangling symlink" '.clutch present but not a directory' 'no .clutch state here'
rm -f "$C2" || { echo "FAIL: rm .clutch symlink failed"; fail=1; }
mkdir -p "$C2/session-state" || { echo "FAIL: session-state dir fixture failed"; fail=1; }
shape_line "session-state is a dir" 'session-state present but not a file' 'no session state'
trap 'chmod 755 "$CD" "$C2" 2>/dev/null; chmod 644 "$SS" 2>/dev/null; rm -rf "$T"' EXIT
if [ "$(id -u)" = 0 ]; then
  echo "SKIP: session-state dir in a 555 .clutch (running as root)"
else
  chmod 555 "$C2" || { echo "FAIL: chmod 555 repo2 .clutch failed"; fail=1; }
  shape_line "session-state is a dir, .clutch 555" 'session-state present but not a file' 'not writable'
  chmod 755 "$C2"
fi
rmdir "$C2/session-state" || { echo "FAIL: rmdir session-state failed"; fail=1; }
ln -s "$T/missing/state" "$C2/session-state" || { echo "FAIL: dangling session-state link fixture failed"; fail=1; }
shape_line "session-state is a dangling symlink" 'session-state present but not a file' 'no session state'

[ "$fail" -eq 0 ] || exit 1
echo PASS
