#!/bin/sh
# The heartbeat must carry the engaged gear to the model every turn:
# a valid .clutch/tempo injects 'tempo gear: <gear>', absence or invalid
# content injects nothing, and the sprint clock, spine, and budget lines
# ride unaffected either way. Every run must exit 0 (fail-open contract).
set -u

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
HERE=$(cd "$(dirname "$0")" && pwd)
HB="$HERE/../scripts/heartbeat.sh"

mkdir "$T/repo"
git -C "$T/repo" init -q
mkdir "$T/repo/.clutch"

# valid gear -> tempo line, spine and budget still present
printf 'craft\n' > "$T/repo/.clutch/tempo"
OUT=$(cd "$T/repo" && sh "$HB"); RC=$?
[ "$RC" = 0 ] || { echo "FAIL: heartbeat exited $RC with valid gear"; exit 1; }
echo "$OUT" | grep -q "tempo gear: craft" || { echo "FAIL: valid gear missing tempo line: $OUT"; exit 1; }
echo "$OUT" | grep -q "dispatch spine" || { echo "FAIL: spine missing with tempo file: $OUT"; exit 1; }
echo "$OUT" | grep -q "clutch-budget" || { echo "FAIL: budget line missing with tempo file: $OUT"; exit 1; }

# no tempo file -> no tempo line, spine still present
rm "$T/repo/.clutch/tempo"
OUT=$(cd "$T/repo" && sh "$HB"); RC=$?
[ "$RC" = 0 ] || { echo "FAIL: heartbeat exited $RC with no tempo file"; exit 1; }
echo "$OUT" | grep -q "tempo gear" && { echo "FAIL: tempo line with no file"; exit 1; }
echo "$OUT" | grep -q "dispatch spine" || { echo "FAIL: spine missing without tempo file: $OUT"; exit 1; }

# garbage content -> closed vocabulary collapses it to silence
printf 'rm -rf /\n' > "$T/repo/.clutch/tempo"
OUT=$(cd "$T/repo" && sh "$HB"); RC=$?
[ "$RC" = 0 ] || { echo "FAIL: heartbeat exited $RC on garbage content"; exit 1; }
echo "$OUT" | grep -q "tempo gear" && { echo "FAIL: garbage content produced a tempo line"; exit 1; }

# multi-word content -> treated as absent
printf 'craft plus junk\n' > "$T/repo/.clutch/tempo"
OUT=$(cd "$T/repo" && sh "$HB"); RC=$?
[ "$RC" = 0 ] || { echo "FAIL: heartbeat exited $RC on multi-word content"; exit 1; }
echo "$OUT" | grep -q "tempo gear" && { echo "FAIL: multi-word content produced a tempo line"; exit 1; }

# case variant -> closed vocabulary stays fail-closed
printf 'Craft\n' > "$T/repo/.clutch/tempo"
OUT=$(cd "$T/repo" && sh "$HB"); RC=$?
[ "$RC" = 0 ] || { echo "FAIL: heartbeat exited $RC on case-variant content"; exit 1; }
echo "$OUT" | grep -q "tempo gear" && { echo "FAIL: case-variant content produced a tempo line"; exit 1; }

# valid gear + live sprint -> both lines ride the same turn
printf 'ballmer\n' > "$T/repo/.clutch/tempo"
NOW=$(date +%s)
printf '%s test goal\n' "$((NOW - 300))" > "$T/repo/.clutch/sprint-start"
OUT=$(cd "$T/repo" && sh "$HB"); RC=$?
[ "$RC" = 0 ] || { echo "FAIL: heartbeat exited $RC with tempo + sprint"; exit 1; }
echo "$OUT" | grep -q "tempo gear: ballmer" || { echo "FAIL: tempo line missing beside sprint: $OUT"; exit 1; }
echo "$OUT" | grep -q "min left on 'test goal'" || { echo "FAIL: sprint clock missing beside tempo: $OUT"; exit 1; }
printf '%s\n' "$OUT" | python3 -c 'import sys,json; json.load(sys.stdin)'; RC=$?
[ "$RC" = 0 ] || { echo "FAIL: tempo + sprint output is not valid JSON: $OUT"; exit 1; }

# encoder intact: a single line starting with the hook envelope
LINES=$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')
[ "$LINES" = 1 ] || { echo "FAIL: output is not a single line: $OUT"; exit 1; }
case "$OUT" in '{"hookSpecificOutput"'*) ;; *) echo "FAIL: output does not start with the hook envelope: $OUT"; exit 1 ;; esac

echo PASS
