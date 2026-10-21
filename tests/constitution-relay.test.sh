#!/bin/sh
# Constitution relay rule: a forked pass the user invoked (daydream,
# dream-spark) is invited output, so its reply, or a notice that it failed
# before replying, is relayed as it is and sits outside the two-line cap; the
# rule licenses nothing uninvited. Every pin is absent from the pre-rule tree,
# so a revert turns this red. CONST_FILE overrides the target for replay.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
C=${CONST_FILE:-$HERE/../rules/constitution.md}

[ -f "$C" ] || { echo "FAIL: missing $C"; exit 1; }

fail=0
# rc 0 = pin holds, 1 = pattern gone, >=2 = grep itself broke. Only 0 passes.
pin() {
  label=$1; pat=$2
  grep -qF -- "$pat" "$C"
  rc=$?
  case $rc in
    0) ;;
    1) echo "FAIL: $label -- pattern not found: $pat"; fail=1 ;;
    *) echo "FAIL: $label -- grep error rc=$rc: $pat"; fail=1 ;;
  esac
}

pin "invoked fork is invited"      'A forked pass the user invoked (daydream,'
pin "reply is relayed"             'is invited output: relay its reply'
pin "failure notice relayed as is" 'failed before replying, as it is, outside the two-line cap'
pin "licenses nothing uninvited"   'licenses nothing uninvited'

[ "$fail" -eq 0 ] || exit 1
echo PASS
