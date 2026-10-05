#!/bin/sh
# Ops as the third focus: grep-pin the ops skill (espresso marker, the
# rituals config home and its error contracts, the read-only sweep, the
# one-loop guardrails, the human checkpoint on outward actions, the no-count
# law), the intent handoff, the tempo and GLOSSARY mentions; then run the
# heartbeat and the anchor in a scratch repo to assert that a declared
# espresso gear rides every turn and silences the session-start ask on
# resume. Same rc-discipline as siblings; the F/G wording gates are mirrored
# locally because de-private.test.sh applies them only to the divergent set.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
O=${OPS_SKILL:-$HERE/../skills/ops/SKILL.md}
I=${INTENT_SKILL:-$HERE/../skills/intent/SKILL.md}
TP=${TEMPO_SKILL:-$HERE/../skills/tempo/SKILL.md}
G=${GLOSSARY_FILE:-$HERE/../GLOSSARY.md}
R=${README_FILE:-$HERE/../README.md}
HB=${HB_FILE:-$HERE/../scripts/heartbeat.sh}
A=${ANCHOR_SH:-$HERE/../scripts/anchor.sh}

fail=0
for f in "$O" "$I" "$TP" "$G" "$R" "$HB" "$A"; do
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

# --- ops skill: gear, config home, error contracts
pin "$O" "ops: espresso marker write"   'printf .%s.n. "espresso" 2>/dev/null > "\$ROOT/\.clutch/tempo"'
pin "$O" "ops: marker-fail contract"    'only the re-injection is lost'
pin "$O" "ops: hopping is the gait"     'Hopping between loops is the gait'
pin "$O" "ops: config home"             '\.clutch/rituals\.md'
pin "$O" "ops: handoff to setup"        '/clutch:rituals'
pin "$O" "ops: never-scaffold contract" 'Never scaffold a default config'
pin "$O" "ops: state-dir contract"      'offer to continue without state'
pin "$O" "ops: integration-skip"        'say so and skip'
pin "$O" "ops: reachable only"          'only if it is reachable'
pin "$O" "ops: unset-key persist"       'offer to persist the answer'

# --- ops skill: the sweep is one read-only divergent pulse
pin "$O" "ops: sweep reads only"        'The sweep reads; it never writes'
pin "$O" "ops: horizon bound"           'nothing past the next workday'
pin "$O" "ops: sweep runs once"         'reads each reachable tool once'
pin "$O" "ops: not a dashboard"         'not a dashboard'
pin "$O" "ops: lives in the turn"       'lives in the turn'
pin "$O" "ops: situation line cap"      'at most seven lines'

# --- ops skill: guardrails
pin "$O" "ops: one loop at a time"      'One loop at a time'
pin "$O" "ops: never two open"          'Never two loops open at once'
pin "$O" "ops: human checkpoint"        'send on a yes'
pin "$O" "ops: reading is free"         'Reading is free'
pin "$O" "ops: tangent banks"           '/clutch:fomo'
pin "$O" "ops: build leaves ops"        '/clutch:intent build'
pin "$O" "ops: no counts"               'No counts'
pin "$O" "ops: no overdue framing"      'never as overdue'
pin "$O" "ops: re-sweep on request"     'Re-sweep on request only'
pin "$O" "ops: one smallest move"       'one loop that closes in one sitting'
pin "$O" "ops: fires when fired"        'Nothing here runs on its own'
pin "$O" "ops: eod owns the close"      '/clutch:eod'
pin "$O" "ops: description trigger"     'hands off after an "ops" answer'
# The handoff path: /clutch:intent ops must be able to invoke the skill, so
# model invocation stays enabled (negative pin).
if grep -q 'disable-model-invocation: true' "$O"; then
  echo "FAIL: ops skill disables model invocation -- the handoff path is dead"
  fail=1
fi

# --- intent: the third form and its handoff
pin "$I" "intent: ops form"            '/clutch:intent ops'
pin "$I" "intent: ops handoff"         'run /clutch:ops'
pin "$I" "intent: three focuses"       'Three focuses exist'

# --- tempo, GLOSSARY, README: ops is named where the gears are
pin "$TP" "tempo: ops drives espresso" 'ops drives espresso'
pin "$TP" "tempo: ops names its gear"  '/clutch:ops. engages espresso'
pin "$G"  "GLOSSARY: ops in Intent"    'Ops engages espresso'
pin "$R"  "README: ops command"        '/clutch:ops'
pin "$R"  "README: three-way ask"      'build, ideate, or ops?'

# --- local mirror of the private-vocab, intent, F and G wording gates.
# Same regex strings as de-private.test.sh; rc 1 = clean, 0 = leak,
# >=2 = loud grep failure.
PAT_A='javos|knowledge-ops|aipaper|daylog|MEMORY\.md|trust ledger|trust-ledger|\.claude/tempo|config/intents'
PAT_C='/intent\b|intent default'
PAT_E='fuel'
PAT_F='daemon|launchd|cron|nightly|overnight|schedul|auto-trigger'
PAT_T='HH:MM'

check_empty() {
  label=$1; shift
  hits=$(grep "$@" 2>&1)
  rc=$?
  case $rc in
    1) ;;
    0) echo "FAIL: $label"
       printf '%s\n' "$hits" | head -5
       fail=1 ;;
    *) echo "FAIL: $label -- grep error rc=$rc"
       printf '%s\n' "$hits" | head -5
       fail=1 ;;
  esac
}
check_empty "A private-vocab (ops)" -niE "$PAT_A" "$O"
check_empty "C intent (ops)"        -nE  "$PAT_C" "$O"
check_empty "E fuel (ops)"          -niE "$PAT_E" "$O"
check_empty "F daemon (ops)"        -niE "$PAT_F" "$O"
check_empty "G template (ops)"      -nF  "$PAT_T" "$O"

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
printf 'a javos /intent fuel daemon at HH:MM\n' > "$T/probe"
grep -iE "$PAT_A" "$T/probe" >/dev/null 2>&1 || { echo "FAIL: self-check missed probe for A"; fail=1; }
grep -E  "$PAT_C" "$T/probe" >/dev/null 2>&1 || { echo "FAIL: self-check missed probe for C"; fail=1; }
grep -iE "$PAT_E" "$T/probe" >/dev/null 2>&1 || { echo "FAIL: self-check missed probe for E"; fail=1; }
grep -iE "$PAT_F" "$T/probe" >/dev/null 2>&1 || { echo "FAIL: self-check missed probe for F"; fail=1; }
grep -F  "$PAT_T" "$T/probe" >/dev/null 2>&1 || { echo "FAIL: self-check missed probe for G"; fail=1; }

[ "$fail" -eq 0 ] || exit 1

# --- behavior: a declared espresso gear rides every turn and counts as a
# declaration at the session boundary.
mkdir "$T/scripts"
cp "$A" "$T/scripts/anchor.sh"
cp "$HERE/../scripts/prelude.sh" "$T/scripts/prelude.sh"
RUN="$T/scripts/anchor.sh"
mkdir "$T/repo"
git -C "$T/repo" init -q
git -C "$T/repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m seed
mkdir -p "$T/repo/.clutch"
Q='build, ideate, or ops?'

# heartbeat: espresso -> tempo line names the gear and its shape
printf 'espresso\n' > "$T/repo/.clutch/tempo"
OUT=$(cd "$T/repo" && sh "$HB"); RC=$?
[ "$RC" = 0 ] || { echo "FAIL: heartbeat exited $RC with espresso"; exit 1; }
printf '%s\n' "$OUT" | grep -q 'tempo gear: espresso (tight convergence, one divergent pulse)' \
  || { echo "FAIL: heartbeat missing the espresso tempo line: $OUT"; exit 1; }

# anchor on resume with espresso declared -> no question, file intact
OUT=$(cd "$T/repo" && printf '%s' '{"source":"resume"}' | sh "$RUN"); RC=$?
[ "$RC" = 0 ] || { echo "FAIL: anchor exited $RC on resume with espresso"; exit 1; }
printf '%s\n' "$OUT" | grep -qF "$Q" \
  && { echo "FAIL: resume with espresso declared still asks the intent question"; exit 1; }
grep -q '^espresso$' "$T/repo/.clutch/tempo" \
  || { echo "FAIL: resume wiped or mangled an espresso tempo"; exit 1; }

# anchor on startup -> the ask names all three focuses as its final line
OUT=$(cd "$T/repo" && printf '%s' '{"source":"startup"}' | sh "$RUN"); RC=$?
[ "$RC" = 0 ] || { echo "FAIL: anchor exited $RC on startup"; exit 1; }
printf '%s\n' "$OUT" | tail -n 1 | grep -qF "$Q" \
  || { echo "FAIL: startup ask does not name the three focuses as its final line"; exit 1; }

echo PASS
