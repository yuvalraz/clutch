#!/bin/sh
# Retrace reads the pool: grep-pin the coupling contract in SKILL.md.
# Every pattern here is absent from the pre-coupling file (e353958), so a
# revert of the coupling turns this red instead of passing vacuously.
# RETRACE_SKILL and README_FILE override the target files, so the pins can
# be replayed per file against any historical version
# (e.g. git show BASE:... > tmp).
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
F=${RETRACE_SKILL:-$HERE/../skills/retrace/SKILL.md}
R=${README_FILE:-$HERE/../README.md}

[ -f "$F" ] || { echo "FAIL: missing $F"; exit 1; }
[ -f "$R" ] || { echo "FAIL: missing $R"; exit 1; }

fail=0
pin() {
  label=$1; pat=$2
  grep -q "$pat" "$F" \
    || { echo "FAIL: $label -- pattern not found: $pat"; fail=1; }
}
pinr() {
  label=$1; pat=$2
  grep -q "$pat" "$R" \
    || { echo "FAIL: $label -- pattern not found: $pat"; fail=1; }
}

pin "captures.md is read"          'captures\.md'
pin "Pulled at you group exists"   '\*\*Pulled at you\*\*'
pin "fomo door covered"            'omo lines keep'
pin "silent absence / fail-open"   'group is absent and nothing is said'
pin "out-of-window count-only"     'captures stay a count only'
pin "malformed line rule"          'no epoch prefix'
pin "narrower-window tiebreak"     'prefer the narrower window'
pin "dream-sparks entry heading"   'entry heading in dream-sparks'
pin "entry-level omit over guess"  'omit rather than guess'
pin "per-file skip"                'skips silently on its own'

pinr "retrace moment reads pool"   'git and the capture pool'
pinr "pulled-at-you in moment"     'what pulled at you'
pinr "capture moment mirror"       'hands back the ones from its window'

[ "$fail" -eq 0 ] || exit 1
echo PASS
