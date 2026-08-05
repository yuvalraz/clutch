#!/bin/sh
# The fomo bank snippet may never lose a line silently:
# BANKED + appended line inside a work tree; MISS + nothing written outside one.
# The snippet under test is extracted from SKILL.md itself, so doc and test cannot drift.
# Fomo carries two sh blocks: the first is the bank snippet tested here, the
# second is the absorb door, executed live by brain.test.sh.
set -u

T=$(mktemp -d)
trap 'chmod -R u+w "$T" 2>/dev/null; rm -rf "$T"' EXIT
HERE=$(cd "$(dirname "$0")" && pwd)
FOMO=${FOMO_SKILL:-$HERE/../skills/fomo/SKILL.md}

[ -f "$FOMO" ] || { echo "FAIL: missing $FOMO"; exit 1; }

# n counts sh blocks and never resets; f tracks "inside a block". The older
# single-var form reset on every fence, so it could not tell two blocks apart.
awk '/```sh/{n++;f=1;next} /```/{f=0} f && n==1' "$FOMO" \
  | sed 's/<the thing and why, one line>/test fomo why/' > "$T/snippet.sh"
grep -q 'rev-parse' "$T/snippet.sh" || { echo "FAIL: snippet extraction came up empty"; exit 1; }
# Block-order guard: block 1 is the bank snippet, never the absorb door.
grep -q 'SKIP no-brain' "$T/snippet.sh" \
  && { echo "FAIL: block 1 is the absorb door, not the bank snippet"; exit 1; }
grep -q 'captures\.md' "$T/snippet.sh" \
  || { echo "FAIL: bank snippet does not target captures.md"; exit 1; }

mkdir "$T/repo"
git -C "$T/repo" init -q
OUT=$(cd "$T/repo" && sh "$T/snippet.sh")
[ "$OUT" = "BANKED" ] || { echo "FAIL: in-repo expected BANKED, got: $OUT"; exit 1; }
grep -q 'fomo: test fomo why' "$T/repo/.clutch/captures.md" \
  || { echo "FAIL: line not appended with marker"; exit 1; }

mkdir "$T/plain"
OUT=$(cd "$T/plain" && sh "$T/snippet.sh")
case "$OUT" in
  MISS*) ;;
  *) echo "FAIL: outside repo expected MISS, got: $OUT"; exit 1;;
esac
[ ! -e "$T/plain/.clutch" ] || { echo "FAIL: created .clutch outside a repo"; exit 1; }

# The two write-failure legs. Without these the suite only ever exercises the
# happy path and the no-work-tree path -- so a snippet that echoes BANKED on a
# failed append (the precise "vanishing behind an ack" bug) ships green.

# mkdir leg: work tree present, repo root unwritable, so .clutch cannot be made.
mkdir "$T/repo3"
git -C "$T/repo3" init -q
chmod 555 "$T/repo3"
OUT=$(cd "$T/repo3" && sh "$T/snippet.sh")
chmod 755 "$T/repo3"
[ "$OUT" = "MISS no-write" ] \
  || { echo "FAIL: unwritable repo root expected MISS no-write, got: $OUT"; exit 1; }
[ ! -e "$T/repo3/.clutch" ] || { echo "FAIL: created .clutch under an unwritable root"; exit 1; }

# append leg: .clutch exists but is unwritable, so the printf >> fails.
mkdir "$T/repo4"
git -C "$T/repo4" init -q
mkdir "$T/repo4/.clutch"
chmod 555 "$T/repo4/.clutch"
# stderr is the shell's own "Permission denied" for the redirect, which is
# expected here and would otherwise pollute the suite output. The contract
# under test is the MISS token on stdout.
OUT=$(cd "$T/repo4" && sh "$T/snippet.sh" 2>/dev/null)
chmod 755 "$T/repo4/.clutch"
[ "$OUT" = "MISS no-write" ] \
  || { echo "FAIL: unwritable .clutch expected MISS no-write, got: $OUT"; exit 1; }
[ ! -s "$T/repo4/.clutch/captures.md" ] \
  || { echo "FAIL: reported MISS but wrote content anyway"; exit 1; }

# --brain destination: <brain> filled with yes banks to $HOME, not the repo.
sed 's/<brain>/yes/' "$T/snippet.sh" > "$T/brain.sh"
mkdir "$T/repo5"
git -C "$T/repo5" init -q
mkdir -p "$T/h5"
OUT=$(cd "$T/repo5" && HOME="$T/h5" sh "$T/brain.sh")
[ "$OUT" = "BANKED" ] || { echo "FAIL: --brain expected BANKED, got: $OUT"; exit 1; }
grep -q 'fomo: test fomo why' "$T/h5/.clutch/captures.md" \
  || { echo "FAIL: --brain did not bank into the brain"; exit 1; }
[ ! -e "$T/repo5/.clutch" ] \
  || { echo "FAIL: --brain also wrote the repo pool"; exit 1; }

# --brain works with no work tree at all; plain fomo there still MISSes.
mkdir "$T/plain5"
mkdir -p "$T/h6"
OUT=$(cd "$T/plain5" && HOME="$T/h6" sh "$T/brain.sh")
[ "$OUT" = "BANKED" ] || { echo "FAIL: --brain outside a repo expected BANKED, got: $OUT"; exit 1; }
OUT=$(cd "$T/plain5" && HOME="$T/h6" sh "$T/snippet.sh")
[ "$OUT" = "MISS no-work-tree" ] \
  || { echo "FAIL: plain fomo outside a repo must not fall back to the brain, got: $OUT"; exit 1; }

echo PASS
