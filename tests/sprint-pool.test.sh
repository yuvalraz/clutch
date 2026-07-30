#!/bin/sh
# Sprint feeds the pool: grep-pin the deflection-banking contract in SKILL.md.
# Every pattern here is absent from the pre-coupling file (139b3e6), so a
# revert of the coupling turns this red instead of passing vacuously.
# SPRINT_SKILL and README_FILE override the target files, so the pins can
# be replayed per file against any historical version
# (e.g. git show BASE:... > tmp).
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
F=${SPRINT_SKILL:-$HERE/../skills/sprint/SKILL.md}
R=${README_FILE:-$HERE/../README.md}

[ -f "$F" ] || { echo "FAIL: missing $F"; exit 1; }
[ -f "$R" ] || { echo "FAIL: missing $R"; exit 1; }

fail=0
# rc 0 = pin holds, 1 = pattern gone, >=2 = grep itself broke. Only 0 passes;
# everything else fails loudly.
pin() {
  label=$1; pat=$2
  grep -q "$pat" "$F"
  rc=$?
  case $rc in
    0) ;;
    1) echo "FAIL: $label -- pattern not found: $pat"; fail=1 ;;
    *) echo "FAIL: $label -- grep error rc=$rc: $pat"; fail=1 ;;
  esac
}
pinr() {
  label=$1; pat=$2
  grep -q "$pat" "$R"
  rc=$?
  case $rc in
    0) ;;
    1) echo "FAIL: $label -- pattern not found: $pat"; fail=1 ;;
    *) echo "FAIL: $label -- grep error rc=$rc: $pat"; fail=1 ;;
  esac
}

pin "deflection appends to captures.md" 'captures\.md'
pin "epoch-prefixed deflection line"    'date +%s)" "the deflected idea'
pin "MISS branch: no work tree"         'echo MISS no-work-tree'
pin "MISS honesty: idea repeated back"  'repeat the idea back'
pin "same-turn return to shippable"     'return to the shippable in the same turn'
pin "no new uninvited speech"           'the deflection line is the whole utterance'
pin "why: divergent skills draw later"  'the divergent skills draw'

pinr "README: deflected ideas bank"     'deflected ideas bank'
pinr "README: same capture door"        'through the same door'

[ "$fail" -eq 0 ] || exit 1
echo PASS
