#!/bin/sh
# Brain resolution for dream and interview: grep-pin the three-step lookup
# (override, the session's own memory path, the derived per-project default)
# and negative-pin the old override-only refusal. Claude Code's auto memory
# works without `autoMemoryDirectory`, so an override-only lookup reported
# "no brain" on a machine that had one. Every positive pattern here is absent
# from the pre-fix tree, so a revert turns this red instead of passing
# vacuously. DREAM_SKILL and INTERVIEW_SKILL override the targets for replay.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
D=${DREAM_SKILL:-$HERE/../skills/dream/SKILL.md}
I=${INTERVIEW_SKILL:-$HERE/../skills/interview/SKILL.md}

fail=0
for f in "$D" "$I"; do
  [ -f "$f" ] || { echo "FAIL: missing $f"; fail=1; }
done
[ "$fail" -eq 0 ] || exit 1

# rc 0 = pin holds, 1 = pattern gone, >=2 = grep itself broke. Only 0 passes.
pin() {
  file=$1; label=$2; pat=$3
  grep -q "$pat" "$file"
  rc=$?
  case $rc in
    0) ;;
    1) echo "FAIL: $label -- pattern not found: $pat"; fail=1 ;;
    *) echo "FAIL: $label -- grep error rc=$rc"; fail=1 ;;
  esac
}

# The pattern must be ABSENT. rc 1 passes; a hit or a grep error fails.
neg() {
  file=$1; label=$2; pat=$3
  grep -q "$pat" "$file"
  rc=$?
  case $rc in
    1) ;;
    0) echo "FAIL: $label -- forbidden pattern present: $pat"; fail=1 ;;
    *) echo "FAIL: $label -- grep error rc=$rc"; fail=1 ;;
  esac
}

for pair in "dream:$D" "interview:$I"; do
  n=${pair%%:*}; f=${pair#*:}
  pin "$f" "$n: override first"          'autoMemoryDirectory'
  pin "$f" "$n: session memory path"     'memory instructions'
  pin "$f" "$n: derived default"         'the .memory. folder inside .~/.claude/projects/<project-key>.'
  pin "$f" "$n: project-key rule"        'every `/` replaced by `-`'
  pin "$f" "$n: existence check"         'Confirm the'
  neg "$f" "$n: override-only refusal"   'If the key is absent'
  neg "$f" "$n: override-only refusal"   'no `autoMemoryDirectory`, no'
done

[ "$fail" -eq 0 ] && echo PASS
exit "$fail"
