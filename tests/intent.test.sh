#!/bin/sh
# Intent as a core feature: grep-pin the intent skill, the constitution
# carve-out, the heartbeat spine mirror (BOTH, so they can never diverge
# silently), the README moment, and the GLOSSARY entry; then run the anchor
# in scratch repos to assert the session-start question's three branches.
# Every pattern here is absent from the pre-intent tree (f608747), so a
# revert turns this red instead of passing vacuously. INTENT_SKILL,
# CONST_FILE, HB_FILE, README_FILE, GLOSSARY_FILE, and ANCHOR_SH override
# the targets, so the pins can be replayed per file against any historical
# version (e.g. git show BASE:... > tmp). Replay note for ANCHOR_SH: the
# anchor sources prelude.sh from its own directory and exits 0 when it is
# absent, so a bare temp copy goes red on the prelude guard, not on behavior.
# This test therefore stages whatever ANCHOR_SH points at into a scratch
# scripts/ dir beside the real prelude.sh before executing it; a historical
# anchor replayed here fails on a question assert, never on the guard.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
S=${INTENT_SKILL:-$HERE/../skills/intent/SKILL.md}
C=${CONST_FILE:-$HERE/../rules/constitution.md}
H=${HB_FILE:-$HERE/../scripts/heartbeat.sh}
R=${README_FILE:-$HERE/../README.md}
G=${GLOSSARY_FILE:-$HERE/../GLOSSARY.md}
A=${ANCHOR_SH:-$HERE/../scripts/anchor.sh}

fail=0
for f in "$S" "$C" "$H" "$R" "$G" "$A"; do
  [ -f "$f" ] || { echo "FAIL: missing $f"; fail=1; }
done
[ "$fail" -eq 0 ] || exit 1

# rc 0 = pin holds, 1 = pattern gone, >=2 = grep itself broke. Only 0 passes;
# everything else fails loudly.
pin() {
  file=$1; label=$2; pat=$3
  grep -q "$pat" "$file"
  rc=$?
  case $rc in
    0) ;;
    1) echo "FAIL: $label -- pattern not found: $pat"; fail=1 ;;
    *) echo "FAIL: $label -- grep error rc=$rc: $pat"; fail=1 ;;
  esac
}

# --- skill pins: three forms, craft marker, posture, handoff, once-only law
pin "$S" "skill: build form"          '/clutch:intent build'
pin "$S" "skill: ideate form"         '/clutch:intent ideate'
pin "$S" "skill: bare form asks"      'ask one question: build or ideate'
pin "$S" "skill: craft marker write"  'printf .%s.n. "craft" 2>/dev/null > "\$ROOT/\.clutch/tempo"'
pin "$S" "skill: marker-fail contract" 'only the re-injection is lost'
pin "$S" "skill: posture verify"      'we verify before we claim'
pin "$S" "skill: posture tests ship"  'the tests ship with the code'
pin "$S" "skill: posture no silent"   'Nothing fails silently'
pin "$S" "skill: posture scope check" 'a scope check, not more polish'
pin "$S" "skill: ideate handoff"      'run /clutch:ideate'
pin "$S" "skill: once-only law"       'never re-asks uninvited'
pin "$S" "skill: session-scoped gear" 'The gear is session-scoped'
pin "$S" "skill: resume inherits"     'resume and compaction inherit'
pin "$S" "skill: unknown arg"         'one line naming the two focuses'
pin "$S" "skill: two focuses fixed"   'no third and no config'
pin "$S" "skill: description trigger" 'answers the session-start intent question'
pin "$S" "skill: invocation scope"    'A stray "build" mid-conversation invokes nothing'
# The answer path: a plain "build" or "ideate" reply must be able to invoke
# the skill, so model invocation stays enabled (negative pin).
if grep -q 'disable-model-invocation: true' "$S"; then
  echo "FAIL: skill still disables model invocation -- the answer path is dead"
  fail=1
fi

# --- constitution carve-out AND heartbeat mirror: pin BOTH with the same
# phrases so the table and the spine can never diverge silently.
for f in "$C" "$H"; do
  pin "$f" "carve-out named ($f)"     'the session-start intent ask'
  pin "$f" "carve-out gear bound ($f)" 'only when no gear is declared'
  pin "$f" "carve-out not counted ($f)" 'never counted against the budget'
  pin "$f" "carve-out ignore legal ($f)" 'ignoring it is a legal answer'
done

# --- README eleventh moment + GLOSSARY entry
pin "$R" "README: intent moment"      'build or ideate?'
pin "$R" "README: never asks twice"   'it never asks twice'
pin "$G" "GLOSSARY: Intent entry"     '### Intent'
pin "$G" "GLOSSARY: set via command"  'set via /clutch:intent'
pin "$G" "GLOSSARY: cites PoP entry"  'see "Point of performance"'

[ "$fail" -eq 0 ] || exit 1

# --- anchor behavior: the question line rides only the no-gear branch, and
# only at a true session boundary (startup|resume|clear, never compact).
Q='build or ideate?'
T=$(mktemp -d)
trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
# Stage the anchor under test beside the real prelude.sh (see the replay note
# in the header) and execute the staged copy everywhere below.
mkdir "$T/scripts"
cp "$A" "$T/scripts/anchor.sh"
cp "$HERE/../scripts/prelude.sh" "$T/scripts/prelude.sh"
RUN="$T/scripts/anchor.sh"
mkdir "$T/repo"
git -C "$T/repo" init -q
git -C "$T/repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m seed
JSON='{"source":"startup"}'

# no gear declared -> greeting ends with the intent question
OUT_ABSENT=$(cd "$T/repo" && printf '%s' "$JSON" | sh "$RUN"); RC=$?
[ "$RC" = 0 ] || { echo "FAIL: anchor exited $RC with no gear"; exit 1; }
printf '%s\n' "$OUT_ABSENT" | tail -n 1 | grep -qF "$Q" \
  || { echo "FAIL: no-gear branch missing the intent question as final line"; exit 1; }

# compact, no gear -> a compaction is the same session continuing: the
# greeting still lands, the question does not
OUT_COMPACT=$(cd "$T/repo" && printf '%s' '{"source":"compact"}' | sh "$RUN"); RC=$?
[ "$RC" = 0 ] || { echo "FAIL: anchor exited $RC on compact"; exit 1; }
printf '%s\n' "$OUT_COMPACT" | grep -qF "$Q" \
  && { echo "FAIL: compact still asks the intent question"; exit 1; }
printf '%s\n' "$OUT_COMPACT" | grep -q 'Smallest legal move' \
  || { echo "FAIL: compact greeting lost its move line"; exit 1; }

# empty tempo file -> not a declaration -> question fires
mkdir -p "$T/repo/.clutch"
: > "$T/repo/.clutch/tempo"
OUT_EMPTY=$(cd "$T/repo" && printf '%s' "$JSON" | sh "$RUN"); RC=$?
[ "$RC" = 0 ] || { echo "FAIL: anchor exited $RC with empty tempo"; exit 1; }
printf '%s\n' "$OUT_EMPTY" | grep -qF "$Q" \
  || { echo "FAIL: empty tempo treated as a declared gear (no question)"; exit 1; }

# invalid tempo content -> not a declaration -> question fires
printf 'junk\n' > "$T/repo/.clutch/tempo"
OUT_JUNK=$(cd "$T/repo" && printf '%s' "$JSON" | sh "$RUN"); RC=$?
[ "$RC" = 0 ] || { echo "FAIL: anchor exited $RC with junk tempo"; exit 1; }
printf '%s\n' "$OUT_JUNK" | grep -qF "$Q" \
  || { echo "FAIL: junk tempo treated as a declared gear (no question)"; exit 1; }

# The gear is session-scoped. startup with a declared gear -> the anchor
# wipes the gear before the ask evaluation: the file goes, the question fires.
printf 'craft\n' > "$T/repo/.clutch/tempo"
OUT_PRESENT=$(cd "$T/repo" && printf '%s' "$JSON" | sh "$RUN"); RC=$?
[ "$RC" = 0 ] || { echo "FAIL: anchor exited $RC with gear declared on startup"; exit 1; }
printf '%s\n' "$OUT_PRESENT" | grep -qF "$Q" \
  || { echo "FAIL: startup with a declared gear kept the gear (no question)"; exit 1; }
[ ! -e "$T/repo/.clutch/tempo" ] \
  || { echo "FAIL: startup left .clutch/tempo in place"; exit 1; }

# clear with a declared gear -> same wipe, same question
printf 'craft\n' > "$T/repo/.clutch/tempo"
OUT_CLEAR=$(cd "$T/repo" && printf '%s' '{"source":"clear"}' | sh "$RUN"); RC=$?
[ "$RC" = 0 ] || { echo "FAIL: anchor exited $RC with gear declared on clear"; exit 1; }
printf '%s\n' "$OUT_CLEAR" | grep -qF "$Q" \
  || { echo "FAIL: clear with a declared gear kept the gear (no question)"; exit 1; }
[ ! -e "$T/repo/.clutch/tempo" ] \
  || { echo "FAIL: clear left .clutch/tempo in place"; exit 1; }

# resume with a declared gear -> a continued conversation inherits its gear:
# no question, file intact, and the output is byte-identical to the no-gear
# output minus its one question line (the question is the only delta)
printf 'craft\n' > "$T/repo/.clutch/tempo"
OUT_RESUME=$(cd "$T/repo" && printf '%s' '{"source":"resume"}' | sh "$RUN"); RC=$?
[ "$RC" = 0 ] || { echo "FAIL: anchor exited $RC with gear declared on resume"; exit 1; }
printf '%s\n' "$OUT_RESUME" | grep -qF "$Q" \
  && { echo "FAIL: resume with a declared gear still asks the intent question"; exit 1; }
grep -q '^craft$' "$T/repo/.clutch/tempo" \
  || { echo "FAIL: resume wiped or mangled .clutch/tempo"; exit 1; }
EXPECT=$(printf '%s\n' "$OUT_ABSENT" | grep -vF "$Q")
[ "$OUT_RESUME" = "$EXPECT" ] \
  || { echo "FAIL: resume gear-declared output differs beyond the question line"; exit 1; }

# compact with a declared gear -> same session continuing: no question, file intact
OUT_CGEAR=$(cd "$T/repo" && printf '%s' '{"source":"compact"}' | sh "$RUN"); RC=$?
[ "$RC" = 0 ] || { echo "FAIL: anchor exited $RC with gear declared on compact"; exit 1; }
printf '%s\n' "$OUT_CGEAR" | grep -qF "$Q" \
  && { echo "FAIL: compact with a declared gear asks the intent question"; exit 1; }
grep -q '^craft$' "$T/repo/.clutch/tempo" \
  || { echo "FAIL: compact wiped or mangled .clutch/tempo"; exit 1; }

# unreadable .clutch -> fail-open: no question, rc=0, and a silent stderr
# (no mask here: a leak from the anchor's own redirects must stay visible)
chmod 000 "$T/repo/.clutch"
OUT_UNREAD=$(cd "$T/repo" && printf '%s' "$JSON" | sh "$RUN" 2>"$T/err"); RC=$?
chmod 700 "$T/repo/.clutch"
[ "$RC" = 0 ] || { echo "FAIL: anchor exited $RC on unreadable .clutch"; exit 1; }
printf '%s\n' "$OUT_UNREAD" | grep -qF "$Q" \
  && { echo "FAIL: unreadable .clutch still asks the intent question"; exit 1; }
if [ -s "$T/err" ]; then
  echo "FAIL: anchor leaked stderr on unreadable .clutch:"
  head -5 "$T/err"
  exit 1
fi

echo PASS
