#!/bin/sh
# Background-pass models: grep-pin the model each sub-agent launch names, and
# the inherit fallback beside it. Without a named model every pass runs on the
# session model, so a light daydream sweep could cost an Opus turn. Every
# positive pattern here is absent from the pre-pin tree, so a revert turns
# this red. FOMO_SKILL and DAYDREAM_SKILL override the targets for replay.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
F=${FOMO_SKILL:-$HERE/../skills/fomo/SKILL.md}
DD=${DAYDREAM_SKILL:-$HERE/../skills/daydream/SKILL.md}

fail=0
for f in "$F" "$DD"; do
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

pin "$F"  "fomo: judgment pass on sonnet"   'Run it on `sonnet`'
pin "$F"  "fomo: inherit fallback"          'inherit the session'
pin "$F"  "fomo: foreground fallback kept"  'backgrounding is unavailable'
pin "$DD" "daydream: light pass on fable"   'Run it on `fable`'
pin "$DD" "daydream: inherit fallback"      'inherit the session'
pin "$DD" "daydream: foreground fallback"   'backgrounding is'

[ "$fail" -eq 0 ] && echo PASS
exit "$fail"
