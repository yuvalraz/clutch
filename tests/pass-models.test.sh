#!/bin/sh
# Background-pass models: grep-pin the model fomo's sub-agent launch names,
# and the inherit fallback beside it. daydream deliberately names no model:
# its forked pass inherits the session's, and the absence pins keep a model
# from creeping back in. Every positive pattern here is absent from the
# pre-pin tree, so a revert turns this red; labels starting `guard:` hold
# today. FOMO_SKILL and DAYDREAM_SKILL override the targets for replay.
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
# absent: the same rc discipline inverted. 1 passes, 0 = still present.
absent() {
  file=$1; label=$2; pat=$3
  grep -q "$pat" "$file"
  rc=$?
  case $rc in
    1) ;;
    0) echo "FAIL: $label -- pattern still present: $pat"; fail=1 ;;
    *) echo "FAIL: $label -- grep error rc=$rc"; fail=1 ;;
  esac
}

pin "$F"  "fomo: judgment pass on sonnet"   'Run it on `sonnet`'
pin "$F"  "fomo: inherit fallback"          'inherit the session'
pin "$F"  "fomo: foreground fallback kept"  'backgrounding is unavailable'
pin "$DD" "daydream: foreground fallback"   'backgrounding is'
absent "$DD" "daydream: prose fable pin gone" 'fable'
absent "$DD" "guard: daydream names no model, inherits the session's" '^model:'

[ "$fail" -eq 0 ] && echo PASS
exit "$fail"
