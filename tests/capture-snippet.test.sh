#!/bin/sh
# The capture snippet may never lose a line silently:
# BANKED + appended line inside a work tree; MISS + nothing written outside one.
# The snippet under test is extracted from SKILL.md itself, so doc and test cannot drift.
set -u

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
HERE=$(cd "$(dirname "$0")" && pwd)

awk '/```sh/{f++;next} /```/{f=0} f==1' "$HERE/../skills/capture/SKILL.md" \
  | sed 's/the tangent in one line/test tangent/' > "$T/snippet.sh"
grep -q 'rev-parse' "$T/snippet.sh" || { echo "FAIL: snippet extraction came up empty"; exit 1; }

mkdir "$T/repo"
git -C "$T/repo" init -q
OUT=$(cd "$T/repo" && sh "$T/snippet.sh")
[ "$OUT" = "BANKED" ] || { echo "FAIL: in-repo expected BANKED, got: $OUT"; exit 1; }
grep -q 'test tangent' "$T/repo/.clutch/captures.md" || { echo "FAIL: line not appended"; exit 1; }

mkdir "$T/plain"
OUT=$(cd "$T/plain" && sh "$T/snippet.sh")
case "$OUT" in
  MISS*) ;;
  *) echo "FAIL: outside repo expected MISS, got: $OUT"; exit 1;;
esac
[ ! -e "$T/plain/.clutch" ] || { echo "FAIL: created .clutch outside a repo"; exit 1; }

echo PASS
