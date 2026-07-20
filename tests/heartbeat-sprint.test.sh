#!/bin/sh
# The heartbeat must carry the sprint clock to the model every turn:
# a live marker injects 'N min left', an expired marker injects the close
# instruction, no marker injects no sprint line at all.
set -u

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
HERE=$(cd "$(dirname "$0")" && pwd)
HB="$HERE/../scripts/heartbeat.sh"

mkdir "$T/repo"
git -C "$T/repo" init -q
mkdir "$T/repo/.clutch"
NOW=$(date +%s)

# live sprint, started 5 min ago -> clock line, no close instruction
printf '%s test goal\n' "$((NOW - 300))" > "$T/repo/.clutch/sprint-start"
OUT=$(cd "$T/repo" && sh "$HB")
echo "$OUT" | grep -q "min left on 'test goal'" || { echo "FAIL: live marker missing clock line: $OUT"; exit 1; }
echo "$OUT" | grep -q "time is up" && { echo "FAIL: live marker got the close instruction"; exit 1; }

# expired sprint, started 25 min ago -> close instruction
printf '%s test goal\n' "$((NOW - 1500))" > "$T/repo/.clutch/sprint-start"
OUT=$(cd "$T/repo" && sh "$HB")
echo "$OUT" | grep -q "time is up on 'test goal'" || { echo "FAIL: expired marker missing close: $OUT"; exit 1; }

# malformed marker -> no sprint line, spine still present
printf 'not-an-epoch test goal\n' > "$T/repo/.clutch/sprint-start"
OUT=$(cd "$T/repo" && sh "$HB")
echo "$OUT" | grep -q "sprint clock" && { echo "FAIL: malformed marker produced a clock line"; exit 1; }

# no marker -> no sprint line, spine still present
rm "$T/repo/.clutch/sprint-start"
OUT=$(cd "$T/repo" && sh "$HB")
echo "$OUT" | grep -q "dispatch spine" || { echo "FAIL: spine missing without marker: $OUT"; exit 1; }
echo "$OUT" | grep -q "sprint clock" && { echo "FAIL: clock line with no marker"; exit 1; }

echo PASS
