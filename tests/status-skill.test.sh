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
# symlink are "not a file", never "no session state yet". Then the worklog
# line under the scratch HOME: missing (with and without ~/.clutch, creating
# nothing), writable, and unwritable (file 444; ~/.clutch 555; ~/.clutch 644
# with the file present; non-root only).
# STATUS_SKILL and STATUS_SH override the skill
# file and the script, so both can be replayed against any historical version
# (git show BASE:... > tmp).
# ST1-ST3 (2.15.0): status.sh @<tag8> reads this session's
# .clutch/s/<tag8>/ when it exists (no symlink at either level, neither
# CLUTCH_PER_SESSION=off nor CLUTCH_WATCH=off); anything else, and no
# argument, is fbb2aa8's report byte for byte.
set -u
unset CLUTCH_PER_SESSION CLUTCH_WATCH

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
pin   "skill: fix line, .clutch dir"      '`.clutch present but not readable` or `.clutch not writable`: `chmod u+rwx .clutch` lets the hooks back in; on a report run with this session'"'"'s tag whose `.clutch/s/<tag8>` folder exists, `.clutch not writable` means that folder: `chmod u+rwx .clutch/s/<tag8>`.'
pin   "skill: passes the session tag"     'sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh" '"'"'@<tag>'"'"''
pin   "skill: fix line, state file mode"  '`state present but not writable`, or `unreadable` when the file'"'"'s mode blocks reading: `chmod u+rw .clutch/session-state`'
pin   "skill: fix line, .clutch shape"    '`.clutch present but not a directory`: moving that `.clutch` file or link aside'
pin   "skill: fix line, state shape"      '`session-state present but not a file`: moving `.clutch/session-state` aside'
pin   "skill: worklog missing, first write" 'the first write makes it'
pin   "skill: worklog missing, brain"       'which also starts a brain'
pin   "skill: worklog unwritable, dir fix"  'chmod u+rwx ~/.clutch'

T=$(mktemp -d) || exit 1
HOME=$T/home; export HOME
mkdir -p "$HOME"
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

# --- (ix) the worklog line, from a plain dir under the scratch HOME. Readers
# never create anything: the no-~/.clutch leg leaves HOME empty.
WD="$HOME/.clutch"
WF="$WD/worklog.md"
trap 'chmod 755 "$CD" "$C2" "$WD" 2>/dev/null; chmod 644 "$SS" "$WF" 2>/dev/null; rm -rf "$T"' EXIT
worklog_line() {
  label=$1; want=$2
  OUT=$(cd "$T/plain" && GIT_CEILING_DIRECTORIES="$T" sh "$ST"); rc=$?
  [ "$rc" = 0 ] || { echo "FAIL: status ($label) exited $rc"; fail=1; }
  printf '%s\n' "$OUT" | grep -qxF "$want" \
    || { echo "FAIL: status ($label) -- want '$want', got:"; printf '%s\n' "$OUT" | grep worklog; fail=1; }
}
worklog_line "worklog, no ~/.clutch" '  worklog: missing; the first write makes it and ~/.clutch, which starts a brain'
[ -z "$(ls -A "$HOME")" ] || { echo "FAIL: status (worklog, no ~/.clutch) created: $(ls -A "$HOME")"; fail=1; }
mkdir -p "$WD" || { echo "FAIL: mkdir ~/.clutch failed"; fail=1; }
worklog_line "worklog, ~/.clutch, no file" '  worklog: missing; the first write makes it'
: > "$WF" || { echo "FAIL: worklog fixture write failed"; fail=1; }
worklog_line "worklog, file present" "  worklog: writable ($WF)"
if [ "$(id -u)" = 0 ]; then
  echo "SKIP: worklog permission cases (running as root)"
else
  chmod 444 "$WF" || { echo "FAIL: chmod 444 worklog failed"; fail=1; }
  worklog_line "worklog, file 444" "  worklog: unwritable ($WF)"
  chmod 644 "$WF"
  rm -f "$WF" || { echo "FAIL: rm worklog failed"; fail=1; }
  chmod 555 "$WD" || { echo "FAIL: chmod 555 ~/.clutch failed"; fail=1; }
  worklog_line "worklog, ~/.clutch 555, no file" "  worklog: unwritable ($WF)"
  chmod 755 "$WD"
  # Write without search: the file cannot be seen or written, so not "missing".
  : > "$WF" || { echo "FAIL: worklog fixture write failed"; fail=1; }
  chmod 644 "$WD" || { echo "FAIL: chmod 644 ~/.clutch failed"; fail=1; }
  worklog_line "worklog, ~/.clutch 644, file present" "  worklog: unwritable ($WF)"
  chmod 755 "$WD"
fi

# --- ST: the session's own folder, read on a tagged run.
BASE=fbb2aa8
mkdir -p "$T/base/scripts" "$T/base/rules"
cp "$ROOT/rules/constitution.md" "$T/base/rules/"
git -C "$ROOT" show "$BASE:scripts/status.sh" > "$T/base/scripts/status.sh" 2>/dev/null \
  || { echo "FAIL: parity base $BASE not reachable from $ROOT"; exit 1; }
R3="$T/repo3"
C3="$R3/.clutch"
A=0123abcd
trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
st() { (cd "$R3" && env "$@" sh "$ST_SH" ${ST_ARG:+"$ST_ARG"}); }
sfx() {
  chmod -R u+rwx "$R3" "$T/else" 2>/dev/null
  rm -rf "$R3" "$T/else"
  mkdir -p "$C3/s/$A"
  git -C "$R3" init -q
  printf 'start 1\nbase -\nstop 2\n' > "$C3/session-state"
  printf '1700000000 theirs\n' > "$C3/sprint-start"
  printf 'start 1\nbase -\nstop 2\nstop 3\nstop 4\nemit 5\n' > "$C3/s/$A/session-state"
  printf '1700000000 mine\n' > "$C3/s/$A/sprint-start"
}
has() { printf '%s\n' "$OUT" | grep -qxF "$2" || { echo "FAIL: $1 -- want '$2', got:"; printf '%s\n' "$OUT" | grep -E 'stop hook|bell|sprint'; fail=1; }; }
ST_SH=$ST
# ST1: the tagged run reads this session's folder.
sfx; ST_ARG="@$A"; OUT=$(st)
has "ST1 tagged" '  stop hook: fired in this state (stop events recorded: 3)'
has "ST1 tagged" '  bell: 1 of 2 emissions used this state'
has "ST1 tagged" "  sprint: active ('mine')"
if [ "$(id -u)" != 0 ]; then
  sfx; chmod 555 "$C3/s/$A"; OUT=$(st); chmod 755 "$C3/s/$A"
  has "ST1 read-only folder" '  stop hook: .clutch not writable; some hooks cannot record'
fi
sfx; rm -f "$C3/s/$A/session-state"; OUT=$(st)
has "ST1 no state" '  stop hook: no session state in this repo yet'
sfx; rm -f "$C3/s/$A/session-state"; mkdir "$C3/s/$A/session-state"; OUT=$(st)
has "ST1 dir state" '  stop hook: session-state present but not a file'
# ST2: anything else is the folder-wide report.
sfx; ST_ARG=""; NOARG=$(st)
printf '%s\n' "$NOARG" | grep -qxF '  stop hook: fired in this state (stop events recorded: 1)' || { echo "FAIL: ST2 control -- no-arg run is not folder-wide"; fail=1; }
for arg in '@fedc9876' '@<tag>' '@../x' '@' '@123456789'; do
  sfx; mkdir -p "$C3/s/123456789"; cp "$C3/s/$A/session-state" "$C3/s/123456789/"
  ST_ARG=$arg; OUT=$(st)
  [ "$OUT" = "$NOARG" ] || { echo "FAIL: ST2 [$arg] -- not the folder-wide report"; fail=1; }
done
for sw in CLUTCH_PER_SESSION=off CLUTCH_WATCH=off; do
  sfx; ST_ARG="@$A"; OUT=$(st "$sw")
  [ "$OUT" = "$NOARG" ] || { echo "FAIL: ST2 $sw -- not the folder-wide report"; fail=1; }
done
sfx; mv "$C3/s" "$T/else"; ln -s "$T/else" "$C3/s"; ST_ARG="@$A"; OUT=$(st)
[ "$OUT" = "$NOARG" ] || { echo "FAIL: ST2 symlinked .clutch/s -- read through the link"; fail=1; }
sfx; mv "$C3/s/$A" "$T/else"; ln -s "$T/else" "$C3/s/$A"; ST_ARG="@$A"; OUT=$(st)
[ "$OUT" = "$NOARG" ] || { echo "FAIL: ST2 symlinked .clutch/s/$A -- read through the link"; fail=1; }
# ST3: no argument equals fbb2aa8 on these fixtures and the earlier ones.
ST_ARG=""
for v in plainfx s000 snostate; do
  sfx
  case $v in s000) chmod 000 "$C3/s" ;; snostate) rm -f "$C3/session-state" ;; esac
  ST_SH=$ST; N=$(st); ST_SH=$T/base/scripts/status.sh; B=$(st); ST_SH=$ST
  chmod 755 "$C3/s"
  [ "$N" = "$B" ] || { echo "FAIL: ST3 $v -- no-arg report differs from $BASE"; fail=1; }
done
for d in "$T/repo" "$T/repo2" "$T/plain"; do
  N=$(cd "$d" && GIT_CEILING_DIRECTORIES="$T" sh "$ST"); B=$(cd "$d" && GIT_CEILING_DIRECTORIES="$T" sh "$T/base/scripts/status.sh")
  [ "$N" = "$B" ] || { echo "FAIL: ST3 $d -- no-arg report differs from $BASE"; fail=1; }
done

[ "$fail" -eq 0 ] || exit 1
echo PASS
