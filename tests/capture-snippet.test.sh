#!/bin/sh
# The capture snippet may never lose a line silently:
# BANKED + appended line inside a work tree; MISS + nothing written outside one.
# The snippet under test is extracted from SKILL.md itself, so doc and test cannot drift.
# Fomo's snippet mirrors capture's shape by design; the same extraction guards it.
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

# The second door: fomo's snippet, same extraction, same honesty contract.
awk '/```sh/{f++;next} /```/{f=0} f==1' "$HERE/../skills/fomo/SKILL.md" \
  | sed 's/<content and why, one line>/test fomo why/' > "$T/fomo.sh"
grep -q 'rev-parse' "$T/fomo.sh" || { echo "FAIL: fomo snippet extraction came up empty"; exit 1; }

mkdir "$T/repo2"
git -C "$T/repo2" init -q
OUT=$(cd "$T/repo2" && sh "$T/fomo.sh")
[ "$OUT" = "BANKED" ] || { echo "FAIL: fomo in-repo expected BANKED, got: $OUT"; exit 1; }
grep -q 'fomo: test fomo why' "$T/repo2/.clutch/captures.md" || { echo "FAIL: fomo line not appended with marker"; exit 1; }

mkdir "$T/plain2"
OUT=$(cd "$T/plain2" && sh "$T/fomo.sh")
case "$OUT" in
  MISS*) ;;
  *) echo "FAIL: fomo outside repo expected MISS, got: $OUT"; exit 1;;
esac
[ ! -e "$T/plain2/.clutch" ] || { echo "FAIL: fomo created .clutch outside a repo"; exit 1; }

echo PASS
