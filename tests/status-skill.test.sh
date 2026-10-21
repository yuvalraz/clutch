#!/bin/sh
# Status skill: step 1 runs the script through the documented
# ${CLAUDE_PLUGIN_ROOT} substitution, not a hand-resolved base-directory path,
# and the skill stays model-invocable. Then run the real scripts/status.sh in
# a scratch git repo and in a non-git dir: it must exit 0 both times and say
# which substrate it found. STATUS_SKILL overrides the skill file, so the pins
# can be replayed against any historical version (git show BASE:... > tmp).
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
S=${STATUS_SKILL:-$ROOT/skills/status/SKILL.md}
ST="$ROOT/scripts/status.sh"

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
pin   "skill: keeps the \$0 warning"                  'Never locate it with $0 or $BASH_SOURCE'
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

[ "$fail" -eq 0 ] || exit 1
echo PASS
