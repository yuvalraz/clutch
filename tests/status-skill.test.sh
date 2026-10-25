#!/bin/sh
# Status skill: step 1 runs the script through the documented
# ${CLAUDE_PLUGIN_ROOT} substitution, not a hand-resolved base-directory path,
# and the skill stays model-invocable. Then run the real scripts/status.sh in
# a scratch git repo and in a non-git dir: it must exit 0 both times and say
# which substrate it found. Then seed .clutch/session-state four ways and
# assert the stop-hook line: no stop line yet is "not fired yet", a malformed
# stop line is "unreadable". STATUS_SKILL and STATUS_SH override the skill
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
  printf '%b' "$state" > "$T/repo/.clutch/session-state"
  OUT=$(cd "$T/repo" && sh "$ST"); rc=$?
  [ "$rc" = 0 ] || { echo "FAIL: status ($label) exited $rc"; fail=1; }
  printf '%s\n' "$OUT" | grep -qxF "  stop hook: $want" \
    || { echo "FAIL: status ($label) -- want 'stop hook: $want', got:"; printf '%s\n' "$OUT" | grep 'stop hook'; fail=1; }
}
stop_line "fresh start/base"   'start 100\nbase -\n'                    'not fired yet in this state'
stop_line "declined only"      'declined 889814453\n'                    'not fired yet in this state'
stop_line "valid stop"         'start 100\nbase -\nstop 200\n'          'fired in this state (stop events recorded: 1)'
stop_line "malformed stop"     'start 100\nbase -\nstop abc\n'          'state present but unreadable'

[ "$fail" -eq 0 ] || exit 1
echo PASS
