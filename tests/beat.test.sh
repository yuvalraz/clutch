#!/bin/sh
# Ops beat. B1-B13 cover the stop.sh beat gate: a session whose tag has an
# ops record (~/.clutch/watch/<tag8>.beat) and no "prompt" whose whole value
# is /clutch:beat @<tag8> is blocked once a local day with the arming step;
# "asked <YYYY-MM-DD>" lands in the record before the block prints. The watch
# gate keeps priority (B5). Every failure falls through: no block (B6-B10).
# CLUTCH_BEAT=off skips it (B11). B-scrub pins the brain scrub line.
# prelude.sh and stop.sh are staged into a scratch tree and run from a scratch
# repo or a non-git dir under a scratch HOME. PRELUDE_SH and STOP_SH override
# the targets for replay against a historical version. Silent on pass apart
# from PASS.
set -u
unset CLUTCH_BEAT CLUTCH_WATCH CLUTCH_INVESTIGATE CLUTCH_PLAIN CLUTCH_GUESS CLAUDE_PLUGIN_ROOT

HERE=$(cd "$(dirname "$0")" && pwd)
P=${PRELUDE_SH:-$HERE/../scripts/prelude.sh}
S=${STOP_SH:-$HERE/../scripts/stop.sh}
for f in "$P" "$S"; do
  [ -f "$f" ] || { echo "FAIL: missing $f"; exit 1; }
done

T=$(mktemp -d) || exit 1
trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
HOME=$T/home
export HOME
mkdir -p "$HOME" "$T/scripts" "$T/plain"
cp "$P" "$T/scripts/prelude.sh"
cp "$S" "$T/scripts/stop.sh"
W="$HOME/.clutch/worklog.md"
NOW=$(date +%s)
TODAY=$(date +%Y-%m-%d)
fail=0

OUT=""
RC=0
# is <label> <rc> <stdout>: exact rc and stdout.
is() {
  [ "$RC" = "$2" ] && [ "$OUT" = "$3" ] \
    || { echo "FAIL: $1 -- rc $RC stdout [$OUT], want rc $2 stdout [$3]"; fail=1; }
}
# seed: an empty worklog; add <age> <rest>: append one line aged <age> s.
seed() { rm -rf "$HOME/.clutch"; mkdir -p "$HOME/.clutch" && : > "$W"; }
add() { printf '%s %s\n' "$((NOW - $1))" "$2" >> "$W"; }
ID='0123abcd-4567-89ab-cdef-0123456789ab'
BF="$HOME/.clutch/watch/0123abcd.beat"
# rec [extra line]: a fresh ~/.clutch holding only the ops record.
rec() {
  rm -rf "$HOME/.clutch"
  mkdir -p "$HOME/.clutch/watch"
  printf 'last %s\n' "$((NOW - 600))" > "$BF"
  [ $# = 0 ] || printf '%s\n' "$1" >> "$BF"
}

# --- B1-B13: the stop.sh beat gate. stp <dir> <json>: the staged stop.sh run
# from dir on json, CLUTCH_BEAT unset unless $BEAT is set; sets OUT and RC.
# fresh <fixture>: a fresh copy at $T/run, because stop.sh writes the
# breadcrumb and state.
unset XDG_CONFIG_HOME
GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_NOSYSTEM
BEAT=''
stp() {
  if [ -n "$BEAT" ]; then
    OUT=$(cd "$1" && printf '%s' "$2" | CLUTCH_BEAT=$BEAT GIT_CEILING_DIRECTORIES=$T sh "$T/scripts/stop.sh" 2>/dev/null); RC=$?
  else
    OUT=$(cd "$1" && printf '%s' "$2" | GIT_CEILING_DIRECTORIES=$T sh "$T/scripts/stop.sh" 2>/dev/null); RC=$?
  fi
}
fresh() { rm -rf "$T/run" && cp -R "$1" "$T/run"; }
mkrepo() {
  mkdir -p "$1" && git -C "$1" init -q &&
    git -C "$1" config user.email s@s && git -C "$1" config user.name s &&
    git -C "$1" commit -q --allow-empty -m "seed"
}
SF=$T/sfix
mkrepo "$SF" || exit 1

BLOCK='{"decision":"block","reason":"This ops session has no beat. Arm one now with CronCreate, schedule `7 8-20/2 * * *`, recurring, prompt `/clutch:beat @0123abcd`, then end the turn. If the user said not to arm a beat, just end the turn."}'
WBLOCK='{"decision":"block","reason":"This session holds open wait loops and no watch. Arm one now with CronCreate, schedule `*/15 8-21 * * *`, recurring, prompt `/clutch:watch @0123abcd`, then end the turn. If the user said not to watch them, just end the turn."}'
IN="{\"session_id\":\"$ID\",\"stop_hook_active\":false,\"session_crons\":[]}"
blocked() {
  [ "$RC" = 0 ] && [ "$OUT" = "$BLOCK" ] \
    || { echo "FAIL: $1 -- rc $RC stdout [$OUT], want rc 0 and the beat block line"; fail=1; }
}
quiet() { is "$1" 0 ''; }
# asked <label> <n>: the record holds exactly n "asked <today>" lines.
asked() {
  A_N=$(grep -cx "asked $TODAY" "$BF" 2>/dev/null)
  [ "$A_N" = "$2" ] || { echo "FAIL: $1 -- $A_N 'asked $TODAY' lines, want $2: $(cat "$BF" 2>/dev/null)"; fail=1; }
}
crons() {
  printf '{"session_id":"%s","stop_hook_active":false,"session_crons":[{"id":"c1","cron":"7 8-20/2 * * *","prompt":"%s","recurring":true}]}' "$ID" "$1"
}
docin() {
  printf '{"session_id":"%s","transcript_path":"/t/x.jsonl","cwd":"/c","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"%s","background_tasks":[],"session_crons":%s}' "$ID" "$1" "$2"
}

# B1: ops record, nothing armed: the block line, valid JSON, asked today
# recorded, and no breadcrumb on this stop.
rec
fresh "$SF"
stp "$T/run" "$IN"
blocked B1
if [ -x /usr/bin/python3 ]; then
  printf '%s' "$OUT" | /usr/bin/python3 -I -c 'import json,sys; d=json.load(sys.stdin); assert d["decision"] == "block"; assert "7 8-20/2 * * *" in d["reason"]; assert "/clutch:beat @0123abcd" in d["reason"]' 2>/dev/null \
    || { echo "FAIL: B1 -- block line is not the JSON block object"; fail=1; }
fi
asked B1 1
[ ! -e "$T/run/.clutch/breadcrumb" ] || { echo "FAIL: B1 -- a breadcrumb was written on a blocking stop"; fail=1; }

# B4: asked today already: quiet, no second asked line.
stp "$T/run" "$IN"
quiet B4
asked B4 1

# B2, B2s: an armed beat, either spacing: quiet, breadcrumb written, no ask.
for c in "$(crons '/clutch:beat @0123abcd')" \
  "{\"session_id\":\"$ID\",\"stop_hook_active\":false,\"session_crons\":[{\"id\":\"c1\",\"prompt\": \"/clutch:beat @0123abcd\",\"recurring\":true}]}"; do
  rec
  fresh "$SF"
  stp "$T/run" "$c"
  quiet "B2 [$c]"
  [ -s "$T/run/.clutch/breadcrumb" ] || { echo "FAIL: B2 -- no breadcrumb"; fail=1; }
  asked B2 0
done

# B2b: a longer tag or another session's beat is not this session's.
for pr in '/clutch:beat @0123abcd9' '/clutch:beat @ffffffff'; do
  rec
  fresh "$SF"
  stp "$T/run" "$(crons "$pr")"
  blocked "B2b [$pr]"
done

# B2c: a message that mentions the beat prompt is not an armed beat.
rec
fresh "$SF"
stp "$T/run" "$(docin 'Armed: \"prompt\":\"/clutch:beat @0123abcd\" now' '[]')"
blocked B2c

# B2d: a /loop prompt that only mentions the beat is not the beat.
rec
fresh "$SF"
stp "$T/run" "$(crons '/loop 2h /clutch:beat @0123abcd')"
blocked B2d

# B3: no ops record: quiet, nothing under ~/.clutch/watch.
seed
fresh "$SF"
stp "$T/run" "$IN"
quiet B3
[ ! -e "$HOME/.clutch/watch" ] || { echo "FAIL: B3 -- ~/.clutch/watch created for a non-ops session"; fail=1; }

# B4b: only an older asked line: blocked again, today appended.
rec 'asked 2000-01-01'
fresh "$SF"
stp "$T/run" "$IN"
blocked B4b
asked B4b 1

# B5: an owned wait with no watch and an ops record: the watch block first,
# no ask; the next stop (fingerprint recorded) brings the beat block.
rec
: > "$W"
add 100 'proj wait: gh:o/r#1 b1 @0123abcd pr one'
fresh "$SF"
stp "$T/run" "$IN"
[ "$RC" = 0 ] && [ "$OUT" = "$WBLOCK" ] || { echo "FAIL: B5 -- first stop rc $RC [$OUT], want the watch block"; fail=1; }
asked "B5 first" 0
stp "$T/run" "$IN"
blocked "B5 second"
asked "B5 second" 1

# B6: stop_hook_active true, either spacing: quiet, record unchanged.
for a in '"stop_hook_active":true' '"stop_hook_active": true'; do
  rec
  fresh "$SF"
  B6_BEFORE=$(cat "$BF")
  stp "$T/run" "{\"session_id\":\"$ID\",$a,\"session_crons\":[]}"
  quiet "B6 [$a]"
  [ "$(cat "$BF")" = "$B6_BEFORE" ] || { echo "FAIL: B6 [$a] -- record changed"; fail=1; }
done

# B7: no session_crons key (registry unreachable): quiet.
rec
fresh "$SF"
stp "$T/run" "{\"session_id\":\"$ID\",\"stop_hook_active\":false}"
quiet B7
asked B7 0

# B8: no session_id: quiet.
rec
fresh "$SF"
stp "$T/run" '{"stop_hook_active":false,"session_crons":[]}'
quiet B8
asked B8 0

# B9: the record cannot be written: no block, rc 0. B9b: it cannot be read
# (grep rc 2): no block, no append. Root reads and writes through modes.
if [ "$(id -u)" = 0 ]; then
  echo "SKIP: B9 B9b (root writes through chmod)"
else
  rec
  chmod 444 "$BF"
  fresh "$SF"
  stp "$T/run" "$IN"
  quiet B9
  chmod 644 "$BF"
  asked B9 0
  rec
  chmod 222 "$BF"
  fresh "$SF"
  stp "$T/run" "$IN"
  quiet B9b
  chmod 644 "$BF"
  asked B9b 0
fi
# B9c: ~/.clutch/watch is a regular file: no block.
rm -rf "$HOME/.clutch"
mkdir -p "$HOME/.clutch"
: > "$HOME/.clutch/watch"
fresh "$SF"
stp "$T/run" "$IN"
quiet B9c

# B10: empty, non-JSON and truncated stdin: no block, rc 0.
for j in '' 'not json' "{\"session_id\":\"0123abcd-45" "{\"session_id\":\"$ID\",\"session_cr"; do
  rec
  fresh "$SF"
  stp "$T/run" "$j"
  quiet "B10 [$j]"
done

# B11: CLUTCH_BEAT=off: quiet, nothing written. B11b: on is the same as unset.
rec
fresh "$SF"
BEAT=off
stp "$T/run" "$IN"
BEAT=''
quiet B11
asked B11 0
rec
fresh "$SF"
BEAT=on
stp "$T/run" "$IN"
BEAT=''
blocked B11b

# B12: outside git the gate still blocks.
rec
stp "$T/plain" "$IN"
blocked B12

# B13: a ~160 KB last_assistant_message full of escaped mentions finishes
# well inside the hook timeout (whole seconds: a diff of 1 or less is < 2 s).
FILL=$(i=0; while [ $i -lt 2200 ]; do printf 'lorem \\"session_crons\\":[ \\"prompt\\":\\"/clutch:beat @0123abcd\\" ] ipsum '; i=$((i + 1)); done)
BCRON='{"id":"c9","schedule":"7 8-20/2 * * *","recurring":true,"prompt":"/clutch:beat @0123abcd"}'
for c in '[]' "[$BCRON]"; do
  rec
  fresh "$SF"
  B13_T0=$(date +%s)
  stp "$T/run" "$(docin "$FILL" "$c")"
  B13_DT=$(($(date +%s) - B13_T0))
  [ "$B13_DT" -le 1 ] || { echo "FAIL: B13 [$c] -- ${B13_DT}s for a ${#FILL}-byte message"; fail=1; }
  if [ "$c" = '[]' ]; then blocked "B13 unarmed"; else quiet "B13 armed"; fi
done

# B-scrub: brain.test.sh's sibling runs clear CLUTCH_BEAT.
grep -E '^[[:space:]]*\( unset ' "$HERE/brain.test.sh" | grep -qw CLUTCH_BEAT \
  || { echo "FAIL: B-scrub -- CLUTCH_BEAT missing from brain.test.sh's run_scrubbed unset line"; fail=1; }

[ "$fail" -eq 0 ] || exit 1
echo PASS
