#!/bin/sh
# Ops beat. B1-B13 cover the stop.sh beat gate: a session whose tag has an
# ops record (~/.clutch/watch/<tag8>.beat) and no "prompt" whose whole value
# is /clutch:beat @<tag8> is blocked once a local day with the arming step;
# "asked <YYYY-MM-DD>" lands in the record before the block prints. The watch
# gate keeps priority (B5). Every failure falls through: no block (B6-B10).
# CLUTCH_BEAT=off skips it (B11). B1-B13 and SW1-SW9 run under
# CLUTCH_POLL=off (the 2.16.2 asks). PB1-PB14 with PB3b, PB9b, PB10b, PB11b,
# PB11c, PB14b-PB14d run the silent-check beat gate (BPOLL, the poller's
# .poll and the young-death drop) in default mode. B-scrub pins the brain
# scrub line.
# H1-H14 cover clutch_beat_window (the untagged open waits, then the newest
# 20 moved: lines after the record's last epoch and at or before now - 120
# whose field 5 is not the tag; "last <now - 120>" appended to an existing
# record before printing; unreadable state is rc 2). H-peek1-H-peek5 cover
# its peek mode (the moved: lines only, nothing appended). R1 runs the
# beat skill's read line, R2 the ops Step 0 record snippet under sh and
# zsh -f (its tag guard against '@', '@../x', '@a/b' and an unguarded
# mutant), R3 the beat skill's moved: text through the constitution snippet.
# C1-C9 cover clutch_ops_record (0 record there, 1 surely gone, 2 cannot
# tell; never writes). R4/R5 run the beat's and the armed sweep's record
# check line under sh and zsh -f.
# prelude.sh and stop.sh are staged into a scratch tree and run from a scratch
# repo or a non-git dir under a scratch HOME. PRELUDE_SH, STOP_SH,
# BEAT_SKILL, OPS_SKILL and CONST_FILE override the targets for replay
# against a historical version. Silent on pass apart from PASS.
set -u
unset CLUTCH_BEAT CLUTCH_WATCH CLUTCH_POLL CLUTCH_POLL_SLEEP CLUTCH_INVESTIGATE CLUTCH_PLAIN CLUTCH_GUESS CLAUDE_PLUGIN_ROOT

HERE=$(cd "$(dirname "$0")" && pwd)
P=${PRELUDE_SH:-$HERE/../scripts/prelude.sh}
S=${STOP_SH:-$HERE/../scripts/stop.sh}
PL=${POLL_SH:-$HERE/../scripts/poll.sh}
BS=${BEAT_SKILL:-$HERE/../skills/beat/SKILL.md}
O=${OPS_SKILL:-$HERE/../skills/ops/SKILL.md}
K=${CONST_FILE:-$HERE/../rules/constitution.md}
for f in "$P" "$S" "$PL" "$O" "$K"; do
  [ -f "$f" ] || { echo "FAIL: missing $f"; exit 1; }
done
# A missing beat skill fails R1 and R3 below, and the rest still runs.
[ -f "$BS" ] || echo "FAIL: missing $BS"

T=$(mktemp -d) || exit 1
trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
HOME=$T/home
export HOME
mkdir -p "$HOME" "$T/scripts" "$T/plain"
cp "$P" "$T/scripts/prelude.sh"
cp "$S" "$T/scripts/stop.sh"
cp "$PL" "$T/scripts/poll.sh"
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

BLOCK='{"decision":"block","reason":"This ops session has no beat. Arm one now with CronCreate, schedule `7 8-20 * * *`, recurring, prompt `/clutch:beat @0123abcd`, then end the turn. If the user said not to arm a beat, just end the turn."}'
WBLOCK='{"decision":"block","reason":"This session holds open wait loops and no watch. Arm one now with CronCreate, schedule `*/10 8-21 * * *`, recurring, prompt `/clutch:watch @0123abcd`, then end the turn. If the user said not to watch them, just end the turn."}'
SBLOCK='{"decision":"block","reason":"This ops session has no sweep. Arm one now with CronCreate, schedule `37 8,12,16 * * *`, recurring, prompt `/clutch:ops re-sweep armed`, then end the turn. If the user said not to arm a sweep, just end the turn."}'
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
# sweepasked <label> <n>: the record holds exactly n "sweep asked <today>" lines.
sweepasked() {
  A_N=$(grep -cx "sweep asked $TODAY" "$BF" 2>/dev/null)
  [ "$A_N" = "$2" ] || { echo "FAIL: $1 -- $A_N 'sweep asked $TODAY' lines, want $2: $(cat "$BF" 2>/dev/null)"; fail=1; }
}
sblocked() {
  [ "$RC" = 0 ] && [ "$OUT" = "$SBLOCK" ] \
    || { echo "FAIL: $1 -- rc $RC stdout [$OUT], want rc 0 and the sweep block line"; fail=1; }
}
# crons <prompt>: the session's crons, <prompt> plus an armed sweep. The beat
# keeps the pre-2.16.0 two-hour schedule on purpose: a live session's older
# beat is matched by its prompt and never asked again.
SWC='{"id":"c2","cron":"37 8,12,16 * * *","prompt":"/clutch:ops re-sweep armed","recurring":true}'
crons() {
  printf '{"session_id":"%s","stop_hook_active":false,"session_crons":[{"id":"c1","cron":"7 8-20/2 * * *","prompt":"%s","recurring":true},%s]}' "$ID" "$1" "$SWC"
}
# bcrons <json crons>: the session's crons exactly as given.
bcrons() { printf '{"session_id":"%s","stop_hook_active":false,"session_crons":[%s]}' "$ID" "$1"; }
docin() {
  printf '{"session_id":"%s","transcript_path":"/t/x.jsonl","cwd":"/c","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"%s","background_tasks":[],"session_crons":%s}' "$ID" "$1" "$2"
}

# B1-B13 and SW1-SW9 test the 2.16.2 beat ask (BOLD): CLUTCH_POLL=off.
# The PB block below runs the silent-check beat gate in default mode.
CLUTCH_POLL=off
export CLUTCH_POLL

# B1: ops record, nothing armed: the block line, valid JSON, asked today
# recorded, and no breadcrumb on this stop.
rec
fresh "$SF"
stp "$T/run" "$IN"
blocked B1
if [ -x /usr/bin/python3 ]; then
  printf '%s' "$OUT" | /usr/bin/python3 -I -c 'import json,sys; d=json.load(sys.stdin); assert d["decision"] == "block"; assert "7 8-20 * * *" in d["reason"]; assert "/clutch:beat @0123abcd" in d["reason"]' 2>/dev/null \
    || { echo "FAIL: B1 -- block line is not the JSON block object"; fail=1; }
fi
asked B1 1
[ ! -e "$T/run/.clutch/breadcrumb" ] || { echo "FAIL: B1 -- a breadcrumb was written on a blocking stop"; fail=1; }

# B4: asked today already: no second beat ask; the next stop asks the
# sweep once, and the one after is quiet.
stp "$T/run" "$IN"
sblocked B4
asked B4 1
stp "$T/run" "$IN"
quiet "B4 third"
asked "B4 third" 1

# B2, B2s: an armed beat, either spacing: quiet, breadcrumb written, no ask.
for c in "$(crons '/clutch:beat @0123abcd')" \
  "{\"session_id\":\"$ID\",\"stop_hook_active\":false,\"session_crons\":[{\"id\":\"c1\",\"prompt\": \"/clutch:beat @0123abcd\",\"recurring\":true},$SWC]}"; do
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
# no ask; the next stop (fingerprint recorded) brings the beat block. Under
# CLUTCH_POLL=off these are the 2.16.2 */10 and BOLD asks; unset, the
# silent-check asks (WPOLL, then BPOLL) take their place.
WPOLL='{"decision":"block","reason":"This session holds open wait loops and no watch. Start `sh '"$T"'/scripts/poll.sh @0123abcd` with the Bash tool'"'"'s run_in_background, then end the turn: it stays silent until a wait moves. If the user said not to watch them, just end the turn."}'
BPOLL='{"decision":"block","reason":"This ops session has no beat. Start `sh '"$T"'/scripts/poll.sh @0123abcd` with the Bash tool'"'"'s run_in_background, then end the turn: it stays silent until another session moves. If the user said not to arm a beat, just end the turn."}'
bpolled() {
  [ "$RC" = 0 ] && [ "$OUT" = "$BPOLL" ] \
    || { echo "FAIL: $1 -- rc $RC stdout [$OUT], want rc 0 and the silent-check beat block line"; fail=1; }
}
for pm in off ''; do
  rec
  : > "$W"
  add 100 'proj wait: gh:o/r#1 b1 @0123abcd pr one'
  fresh "$SF"
  CLUTCH_POLL=$pm
  export CLUTCH_POLL
  if [ "$pm" = off ]; then WANT=$WBLOCK; else WANT=$WPOLL; fi
  stp "$T/run" "$IN"
  [ "$RC" = 0 ] && [ "$OUT" = "$WANT" ] || { echo "FAIL: B5 [$pm] -- first stop rc $RC [$OUT], want the watch block"; fail=1; }
  asked "B5 first [$pm]" 0
  stp "$T/run" "$IN"
  if [ "$pm" = off ]; then blocked "B5 second [$pm]"; else bpolled "B5 second [$pm]"; fi
  asked "B5 second [$pm]" 1
done
CLUTCH_POLL=off
export CLUTCH_POLL

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
FILL=$(i=0; while [ $i -lt 2200 ]; do printf 'lorem \\"session_crons\\":[ \\"prompt\\":\\"/clutch:beat @0123abcd\\" ] \\"prompt\\":\\"/clutch:ops re-sweep\\" ipsum '; i=$((i + 1)); done)
BCRON='{"id":"c9","schedule":"7 8-20/2 * * *","recurring":true,"prompt":"/clutch:beat @0123abcd"}'
SCRON='{"id":"c8","schedule":"37 8,12,16 * * *","recurring":true,"prompt":"/clutch:ops re-sweep armed"}'
for c in '[]' "[$BCRON]" "[$BCRON,$SCRON]"; do
  rec
  fresh "$SF"
  B13_T0=$(date +%s)
  stp "$T/run" "$(docin "$FILL" "$c")"
  B13_DT=$(($(date +%s) - B13_T0))
  [ "$B13_DT" -le 1 ] || { echo "FAIL: B13 [$c] -- ${B13_DT}s for a ${#FILL}-byte message"; fail=1; }
  case $c in
    '[]') blocked "B13 unarmed" ;;
    "[$BCRON]") sblocked "B13 beat only" ;;
    *) quiet "B13 armed" ;;
  esac
done

# --- SW1-SW9: the sweep ask, in the beat gate after the beat. An ops
# session with no "prompt" whose whole value is /clutch:ops re-sweep is
# blocked once a local day with the sweep's arming step; "sweep asked
# <YYYY-MM-DD>" lands in the record before the block prints.
BONLY='{"id":"c1","cron":"7 8-20 * * *","prompt":"/clutch:beat @0123abcd","recurring":true}'

# SW1: ops record, beat armed, no sweep: the sweep block, valid JSON, sweep
# asked today recorded, the beat's asked line untouched, no breadcrumb.
rec
fresh "$SF"
stp "$T/run" "$(bcrons "$BONLY")"
sblocked SW1
if [ -x /usr/bin/python3 ]; then
  printf '%s' "$OUT" | /usr/bin/python3 -I -c 'import json,sys; d=json.load(sys.stdin); assert d["decision"] == "block"; r=d["reason"]; assert "37 8,12,16 * * *" in r; assert "prompt `/clutch:ops re-sweep armed`" in r; assert "recurring" in r; assert r.endswith("If the user said not to arm a sweep, just end the turn.")' 2>/dev/null \
    || { echo "FAIL: SW1 -- block line is not the JSON sweep block object"; fail=1; }
fi
sweepasked SW1 1
asked SW1 0
[ ! -e "$T/run/.clutch/breadcrumb" ] || { echo "FAIL: SW1 -- a breadcrumb was written on a blocking stop"; fail=1; }

# SW2: asked today already: quiet, no second line.
stp "$T/run" "$(bcrons "$BONLY")"
quiet SW2
sweepasked SW2 1

# SW3, SW3s: an armed sweep, either spacing: quiet, breadcrumb, no ask. A
# cron whose whole prompt is the hand-typed /clutch:ops re-sweep also counts,
# so a sweep armed before the armed form is never armed twice.
for sw in "$SWC" '{"id":"c2","prompt": "/clutch:ops re-sweep armed","recurring":true}' \
  '{"id":"c2","prompt":"/clutch:ops re-sweep","recurring":true}' '{"id":"c2","prompt": "/clutch:ops re-sweep","recurring":true}'; do
  rec
  fresh "$SF"
  stp "$T/run" "$(bcrons "$BONLY,$sw")"
  quiet "SW3 [$sw]"
  [ -s "$T/run/.clutch/breadcrumb" ] || { echo "FAIL: SW3 -- no breadcrumb"; fail=1; }
  sweepasked SW3 0
done

# SW4: no ops record: no sweep ask, nothing under ~/.clutch/watch.
seed
fresh "$SF"
stp "$T/run" "$(bcrons "$BONLY")"
quiet SW4
[ ! -e "$HOME/.clutch/watch" ] || { echo "FAIL: SW4 -- ~/.clutch/watch created for a non-ops session"; fail=1; }

# SW5: nothing armed: the beat block first and no sweep ask; once the beat
# is armed, the next stop brings the sweep block.
rec
fresh "$SF"
stp "$T/run" "$IN"
blocked "SW5 first"
sweepasked "SW5 first" 0
stp "$T/run" "$(bcrons "$BONLY")"
sblocked "SW5 second"
sweepasked "SW5 second" 1

# SW6: the beat declined today (asked, not armed): the sweep is still asked.
rec "asked $TODAY"
fresh "$SF"
stp "$T/run" "$IN"
sblocked SW6

# SW7: a mention of the sweep prompt, a /loop prompt naming it, or a
# re-sweep with more after it is not an armed sweep, in either form.
# Built outside $(...): bash 3.2 brace-expands a {a,b} there despite the quotes.
LOOPC='{"id":"c2","prompt":"/loop 4h /clutch:ops re-sweep"}'
MOREC='{"id":"c2","prompt":"/clutch:ops re-sweep now"}'
LOOPA='{"id":"c2","prompt":"/loop 4h /clutch:ops re-sweep armed"}'
MOREA='{"id":"c2","prompt":"/clutch:ops re-sweep armed now"}'
for c in "$(docin 'Armed: \"prompt\":\"/clutch:ops re-sweep\" now' "[$BONLY]")" \
  "$(docin 'Armed: \"prompt\":\"/clutch:ops re-sweep armed\" now' "[$BONLY]")" \
  "$(bcrons "$BONLY,$LOOPC")" "$(bcrons "$BONLY,$MOREC")" \
  "$(bcrons "$BONLY,$LOOPA")" "$(bcrons "$BONLY,$MOREA")"; do
  rec
  fresh "$SF"
  stp "$T/run" "$c"
  sblocked "SW7 [$c]"
done

# SW8: an older sweep asked line only: asked again, today appended.
rec 'sweep asked 2000-01-01'
fresh "$SF"
stp "$T/run" "$(bcrons "$BONLY")"
sblocked SW8
sweepasked SW8 1

# SW9: CLUTCH_BEAT=off: no sweep ask, nothing written. stop_hook_active:
# quiet. Unwritable record: no block.
rec
fresh "$SF"
BEAT=off
stp "$T/run" "$(bcrons "$BONLY")"
BEAT=''
quiet "SW9 off"
sweepasked "SW9 off" 0
rec
fresh "$SF"
stp "$T/run" "{\"session_id\":\"$ID\",\"stop_hook_active\":true,\"session_crons\":[$BONLY]}"
quiet "SW9 active"
sweepasked "SW9 active" 0
if [ "$(id -u)" != 0 ]; then
  rec
  chmod 444 "$BF"
  fresh "$SF"
  stp "$T/run" "$(bcrons "$BONLY")"
  quiet "SW9 unwritable"
  chmod 644 "$BF"
fi

# --- PB1-PB14: the beat gate with the silent check (default mode, the
# staged scripts dir holds poll.sh). Armed by a /clutch:beat @<tag> cron or a
# live poller whose .poll line carries beat (clutch_poll_alive beat 0); else
# BPOLL once a day through "asked <day>". A dead poller that woke (rc 3, not
# young) has its .poll removed and BPOLL asked even when asked today; one
# that died young (clutch_poll_young 0) is dropped quietly and the gate goes
# on as with no .poll. A live poller without beat (a 2.18.0 poller, rc 4) is
# no beat and keeps its .poll. An unreadable record asks nothing.
unset CLUTCH_POLL
PF="$HOME/.clutch/watch/0123abcd.poll"
WK="$HOME/.clutch/watch/0123abcd.woke"
DD="$HOME/.clutch/watch/0123abcd"
WCRON30='{"decision":"block","reason":"This session holds open wait loops and no watch. Arm one now with CronCreate, schedule `7,37 8-21 * * *`, recurring, prompt `/clutch:watch @0123abcd`, then end the turn. If the user said not to watch them, just end the turn."}'
mkdir -p "$T/stub"
printf 'sleep 120\n' > "$T/stub/poll.sh"
LIVE=$( ( sh "$T/stub/poll.sh" @0123abcd </dev/null >/dev/null 2>&1 & echo $! ) )
DEAD=$( ( true </dev/null >/dev/null 2>&1 & echo $! ) )
trap 'kill "$LIVE" 2>/dev/null; chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
sleep 1
# prec <pid> [start] [third]: .poll holding "<pid> <start>[ <third>]"; the
# start defaults to now (young); OLD is 700 s ago, over one round: not young.
prec() { mkdir -p "$HOME/.clutch/watch"; printf '%s %s%s\n' "$1" "${2:-$(date +%s)}" "${3:+ $3}" > "$PF"; }
OLD=$(($(date +%s) - 700))
nopoll() { [ ! -e "$PF" ] || { echo "FAIL: $1 -- .poll left: $(cat "$PF")"; fail=1; }; }
samepoll() { [ "$(cat "$PF" 2>/dev/null)" = "$2" ] || { echo "FAIL: $1 -- .poll [$(cat "$PF" 2>/dev/null)], want [$2] unchanged"; fail=1; }; }
# ownrec: the owned lines recorded in <file>, read through the staged prelude.
ownrec() { (cd "$T/plain" && . "$T/scripts/prelude.sh" && clutch_owned_loops @0123abcd) > "$1"; }

# PB1: ops record, no cron, no poller: BPOLL, asked today recorded.
rec; fresh "$SF"; stp "$T/run" "$IN"
bpolled PB1; asked PB1 1
# PB2: a live poller whose line carries beat: no beat ask, the sweep follows.
rec; prec "$LIVE" '' beat; fresh "$SF"; stp "$T/run" "$IN"
sblocked PB2; asked PB2 0
# PB3: asked today, a dead .poll started two rounds ago: removed, BPOLL.
rec "asked $TODAY"; prec "$DEAD" "$OLD"; fresh "$SF"; stp "$T/run" "$IN"
bpolled PB3; nopoll PB3; asked PB3 1
# PB3b: the next stop: quiet for the beat, then the sweep as usual.
stp "$T/run" "$IN"
sblocked PB3b; asked PB3b 1
# PB4: an old /clutch:beat @tag cron arms the beat; a stale .poll is not read.
rec; prec "$DEAD" "$OLD"; PB_P=$(cat "$PF"); fresh "$SF"; stp "$T/run" "$(crons '/clutch:beat @0123abcd')"
quiet PB4; asked PB4 0; samepoll PB4 "$PB_P"
# PB5: CLUTCH_POLL=off: BOLD byte for byte; a stale .poll left as it is.
rec; prec "$DEAD" "$OLD"; PB_P=$(cat "$PF"); fresh "$SF"
CLUTCH_POLL=off; export CLUTCH_POLL; stp "$T/run" "$IN"; unset CLUTCH_POLL
blocked PB5; asked PB5 1; samepoll PB5 "$PB_P"
# PB7: an owned gh wait, no poller: the watch gate's WPOLL first, then BPOLL.
rec; add 100 'proj wait: gh:o/r#1 b1 @0123abcd pr one'; fresh "$SF"
stp "$T/run" "$IN"; [ "$RC" = 0 ] && [ "$OUT" = "$WPOLL" ] || { echo "FAIL: PB7 first -- rc $RC [$OUT], want WPOLL"; fail=1; }
stp "$T/run" "$IN"; bpolled "PB7 second"; asked PB7 1
# PB8: no poll.sh beside stop.sh: BOLD.
mkdir -p "$T/nopoll"; cp "$T/scripts/prelude.sh" "$T/scripts/stop.sh" "$T/nopoll/"
rec; fresh "$SF"
OUT=$(cd "$T/run" && printf '%s' "$IN" | GIT_CEILING_DIRECTORIES=$T sh "$T/nopoll/stop.sh" 2>/dev/null); RC=$?
blocked PB8; asked PB8 1
# PB10: gh + slack waits all recorded in <tag8>, asked today, a stale .poll
# that is not young: the watch gate is quiet and leaves .poll; the beat gate
# removes it and asks BPOLL.
rec "asked $TODAY"; add 100 'proj wait: gh:o/r#1 b1 @0123abcd pr one'; add 90 'proj wait: slack:C1/123 b1 @0123abcd thread'
ownrec "$DD"; prec "$DEAD" "$OLD"; fresh "$SF"; stp "$T/run" "$IN"
bpolled PB10; nopoll PB10; asked PB10 1
# PB10b: as PB10 but the slack line is new: stop 1 WCRON30 with .poll and
# the record untouched; stop 2 BPOLL.
rec "asked $TODAY"; add 100 'proj wait: gh:o/r#1 b1 @0123abcd pr one'; ownrec "$DD"
add 90 'proj wait: slack:C1/123 b1 @0123abcd thread'; prec "$DEAD" "$OLD"; PB_P=$(cat "$PF"); PB_R=$(cat "$BF"); fresh "$SF"
stp "$T/run" "$IN"; [ "$RC" = 0 ] && [ "$OUT" = "$WCRON30" ] || { echo "FAIL: PB10b first -- rc $RC [$OUT], want WCRON30"; fail=1; }
samepoll "PB10b first" "$PB_P"; [ "$(cat "$BF")" = "$PB_R" ] || { echo "FAIL: PB10b first -- record changed: $(cat "$BF")"; fail=1; }
stp "$T/run" "$IN"; bpolled "PB10b second"; nopoll "PB10b second"
# PB11: gh-only waits, a stale .poll that is not young, asked today: stop 1
# WPOLL (the watch gate removes .poll); stop 2 with a live poller whose line
# carries beat: no beat ask, the sweep follows.
rec "asked $TODAY"; add 100 'proj wait: gh:o/r#1 b1 @0123abcd pr one'; prec "$DEAD" "$OLD"; fresh "$SF"
stp "$T/run" "$IN"; [ "$RC" = 0 ] && [ "$OUT" = "$WPOLL" ] || { echo "FAIL: PB11 first -- rc $RC [$OUT], want WPOLL"; fail=1; }
nopoll "PB11 first"
prec "$LIVE" '' beat; stp "$T/run" "$IN"; sblocked "PB11 second"; asked PB11 1
# PB11b: as PB11 with no poller started: stop 2 quiet for the beat (the sweep
# follows); the next day's first stop asks BPOLL.
rec "asked $TODAY"; add 100 'proj wait: gh:o/r#1 b1 @0123abcd pr one'; prec "$DEAD" "$OLD"; fresh "$SF"
stp "$T/run" "$IN"; [ "$OUT" = "$WPOLL" ] || { echo "FAIL: PB11b first -- [$OUT], want WPOLL"; fail=1; }
stp "$T/run" "$IN"; sblocked "PB11b second"; asked "PB11b second" 1
printf 'last %s\nasked 2000-01-01\n' "$NOW" > "$BF"
stp "$T/run" "$IN"; bpolled "PB11b next day"; asked "PB11b next day" 1
# PB11c: as PB11b with no asked today: stop 2 BPOLL.
rec; add 100 'proj wait: gh:o/r#1 b1 @0123abcd pr one'; prec "$DEAD" "$OLD"; fresh "$SF"
stp "$T/run" "$IN"; [ "$OUT" = "$WPOLL" ] || { echo "FAIL: PB11c first -- [$OUT], want WPOLL"; fail=1; }
stp "$T/run" "$IN"; bpolled "PB11c second"; asked PB11c 1
# PB12: a live 2.18.0 poller (no beat field), not asked today: BPOLL, asked
# recorded, .poll untouched. PB13: asked today: quiet for the beat.
rec; prec "$LIVE"; PB_P=$(cat "$PF"); fresh "$SF"; stp "$T/run" "$IN"
bpolled PB12; asked PB12 1; samepoll PB12 "$PB_P"
rec "asked $TODAY"; prec "$LIVE"; fresh "$SF"; stp "$T/run" "$IN"
sblocked PB13; asked PB13 1; samepoll PB13 "$PB_P"
# PB14: no owned waits, asked today, a dead .poll started now, empty .woke:
# died young, dropped quietly; the sweep follows.
rec "asked $TODAY"; prec "$DEAD"; : > "$WK"; fresh "$SF"; stp "$T/run" "$IN"
sblocked PB14; nopoll PB14; asked PB14 1
# PB14b: as PB14 but .woke appended after .poll (the poller woke): BPOLL.
rec "asked $TODAY"; prec "$DEAD"; touch -t 200001010000 "$PF"; printf 'beat %s\n' "$NOW" > "$WK"; fresh "$SF"; stp "$T/run" "$IN"
bpolled PB14b; nopoll PB14b; asked PB14b 1
# PB14c: gh-only waits recorded in .polled, asked today, a dead young .poll:
# the watch gate drops it quietly, the beat gate reads rc 1: the sweep follows.
rec "asked $TODAY"; add 100 'proj wait: gh:o/r#1 b1 @0123abcd pr one'; ownrec "$DD.polled"; prec "$DEAD"; fresh "$SF"; stp "$T/run" "$IN"
sblocked PB14c; nopoll PB14c; asked PB14c 1
# PB14d: as PB14 with no asked today: .poll gone, BPOLL, asked recorded.
rec; prec "$DEAD"; : > "$WK"; fresh "$SF"; stp "$T/run" "$IN"
bpolled PB14d; nopoll PB14d; asked PB14d 1
if [ "$(id -u)" = 0 ]; then
  echo "SKIP: PB6 PB9 PB9b (root reads and writes through chmod)"
else
  # PB6: liveness cannot tell (.poll unreadable): no beat ask, the sweep follows.
  rec; prec "$LIVE" '' beat; chmod 000 "$PF"; fresh "$SF"; stp "$T/run" "$IN"
  chmod 644 "$PF"; sblocked PB6; asked PB6 0
  # PB9: the .poll of a poller that woke cannot be removed (~/.clutch/watch
  # 555): no beat ask; the record stays writable, so the sweep asks.
  rec; prec "$DEAD" "$OLD"; chmod 555 "$HOME/.clutch/watch"; fresh "$SF"; stp "$T/run" "$IN"
  chmod 755 "$HOME/.clutch/watch"; sblocked PB9; asked PB9 0
  [ -e "$PF" ] || { echo "FAIL: PB9 -- .poll removed"; fail=1; }
  # PB9b: the record unreadable (grep rc 2) with a stale .poll: no beat ask,
  # .poll bytes unchanged, no sweep ask.
  rec; prec "$DEAD" "$OLD"; PB_P=$(cat "$PF"); chmod 000 "$BF"; fresh "$SF"; stp "$T/run" "$IN"
  chmod 644 "$BF"; quiet PB9b; asked PB9b 0; samepoll PB9b "$PB_P"
fi
kill "$LIVE" 2>/dev/null

# B-scrub: brain.test.sh's sibling runs clear CLUTCH_BEAT and BEAT_SKILL, and
# the silent check's CLUTCH_POLL* switches and POLL_SH override.
for v in CLUTCH_BEAT BEAT_SKILL CLUTCH_POLL CLUTCH_POLL_SLEEP CLUTCH_POLL_ROUNDS POLL_SH; do
  grep -E '^[[:space:]]*\( unset ' "$HERE/brain.test.sh" | grep -qw "$v" \
    || { echo "FAIL: B-scrub -- $v missing from brain.test.sh's run_scrubbed unset line"; fail=1; }
done

# B-readme: the README beat bullet names both switches that turn the beat off.
awk '/^- An ops session is told at turn end/{f=1} f && /^- / && !/^- An ops/{f=0} f' "$HERE/../README.md" |
  tr -s '[:space:]' ' ' | grep -q 'CLUTCH_WATCH=off. also turns off both the beat and sweep asks\.' \
  || { echo "FAIL: B-readme -- the beat bullet does not say CLUTCH_WATCH=off turns off both the beat and sweep asks"; fail=1; }

# B-readme-sweep: the README beat bullet names the armed sweep, its times and the switch.
awk '/^- An ops session is told at turn end/{f=1} f && /^- / && !/^- An ops/{f=0} f' "$HERE/../README.md" |
  tr -s '[:space:]' ' ' | grep -q '`/clutch:ops re-sweep armed` at 08:37, 12:37 and 16:37.*CLUTCH_BEAT=off. turns off both asks' \
  || { echo "FAIL: B-readme-sweep -- the beat bullet does not name the armed sweep and its switch"; fail=1; }

# B-readme-stop: the beat bullet and the network paragraph say the beat and
# the armed sweep stop themselves once the session's ops record is gone.
awk '/^- An ops session is told at turn end/{f=1} f && /^- / && !/^- An ops/{f=0} f' "$HERE/../README.md" |
  tr -s '[:space:]' ' ' | grep -q 'The beat and the armed sweep stop themselves once the session.s ops record is gone' \
  || { echo "FAIL: B-readme-stop -- the beat bullet does not say the beat and sweep stop once the ops record is gone"; fail=1; }
tr -s '[:space:]' ' ' < "$HERE/../README.md" |
  grep -q 'and only reads, until the session.s ops record is gone' \
  || { echo "FAIL: B-readme-stop -- the armed sweep line does not say it runs until the ops record is gone"; fail=1; }

# --- H1-H10: clutch_beat_window. bw <tag>: the helper sourced from the
# staged prelude in a plain dir; sets OUT, RC and ERR. mkrec <line>...: a
# record holding exactly those lines.
ERR=""
bw() {
  OUT=$(cd "$T/plain" && . "$T/scripts/prelude.sh" && clutch_beat_window "$1" 2>"$T/err"); RC=$?
  ERR=$(cat "$T/err")
}
mkrec() { mkdir -p "$HOME/.clutch/watch" && printf '%s\n' "$@" > "$BF"; }
# wl <age> <rest>: the exact line add writes.
wl() { printf '%s %s' "$((NOW - $1))" "$2"; }
lastn() { grep -c '^last [0-9][0-9]*$' "$BF" 2>/dev/null; }

# H1/H1b: only untagged waits (an @handle is text, not a tag).
seed
add 500 'proj wait: gh:o/r#1 b1 untagged one'
add 400 'proj wait: gh:o/r#2 b1 @0123abcd mine'
add 300 'proj wait: gh:o/r#3 b1 @ffffffff peer'
add 200 'proj wait: gh:o/r#4 b1 @Dan handle text'
mkrec "last $((NOW - 1000))"
bw '@0123abcd'
is H1 0 "$(wl 500 'proj wait: gh:o/r#1 b1 untagged one')
$(wl 200 'proj wait: gh:o/r#4 b1 @Dan handle text')"

# bwat <now> <tag>: bw with date +%s pinned to <now> by a PATH shim.
mkdir -p "$T/bin"
printf '#!/bin/sh\n[ -n "${FAKE_NOW:-}" ] && [ "$*" = "+%%s" ] && { echo "$FAKE_NOW"; exit 0; }\nexec /bin/date "$@"\n' > "$T/bin/date"
chmod +x "$T/bin/date"
bwat() {
  OUT=$(cd "$T/plain" && PATH="$T/bin:$PATH" && FAKE_NOW=$1 && export PATH FAKE_NOW &&
    . "$T/scripts/prelude.sh" && clutch_beat_window "$2" 2>"$T/err"); RC=$?
  ERR=$(cat "$T/err")
}

# H2: moves after last and at or before now - 120 only (not before, not
# equal, not inside the grace, not future), never this tag's field 5, never
# on: lines; waits first; last records now - 120.
seed
add 900 'proj wait: gh:o/r#9 b1 plain'
add 700 'proj moved: before'
add 600 'proj moved: equal'
add 400 'proj moved: gh:o/r#1 @0123abcd own'
add 350 'proj moved: gh:o/r#2 @ffffffff other'
add 300 'proj on: claim'
add 290 "proj moved: landed 'x'"
add 60 'proj moved: in grace'
add -1000 'proj moved: future'
mkrec "last $((NOW - 600))"
bwat "$NOW" '@0123abcd'
is H2 0 "$(wl 900 'proj wait: gh:o/r#9 b1 plain')
$(wl 350 'proj moved: gh:o/r#2 @ffffffff other')
$(wl 290 "proj moved: landed 'x'")"
[ "$(lastn)" = 2 ] || { echo "FAIL: H2 -- want 2 last lines: $(cat "$BF")"; fail=1; }
[ "$(tail -n 1 "$BF")" = "last $((NOW - 120))" ] || { echo "FAIL: H2 -- last is not now - 120: $(tail -n 1 "$BF")"; fail=1; }

# H3: a second read straight after prints the waits only.
bw '@0123abcd'
is H3 0 "$(wl 900 'proj wait: gh:o/r#9 b1 plain')"
[ "$(lastn)" = 3 ] || { echo "FAIL: H3 -- want 3 last lines: $(cat "$BF")"; fail=1; }

# H4: no record: waits only, nothing created.
seed
add 500 'proj wait: gh:o/r#9 b1 plain'
add 100 'proj moved: peer move'
bw '@0123abcd'
is H4 0 "$(wl 500 'proj wait: gh:o/r#9 b1 plain')"
[ ! -e "$HOME/.clutch/watch" ] || { echo "FAIL: H4 -- ~/.clutch/watch created"; fail=1; }

# H4b: a record with no last line: no moves, last appended.
mkrec 'asked 2000-01-01'
bw '@0123abcd'
is H4b 0 "$(wl 500 'proj wait: gh:o/r#9 b1 plain')"
[ "$(lastn)" = 1 ] || { echo "FAIL: H4b -- want 1 last line: $(cat "$BF")"; fail=1; }

# H5: no worklog: rc 1, empty, the record untouched, nothing created.
rm -rf "$HOME/.clutch"
bw '@0123abcd'
is "H5 none" 1 ''
[ ! -e "$HOME/.clutch" ] || { echo "FAIL: H5 -- ~/.clutch created"; fail=1; }
mkrec "last $((NOW - 1000))"
bw '@0123abcd'
is "H5 record" 1 ''
[ "$(lastn)" = 1 ] || { echo "FAIL: H5 -- record changed: $(cat "$BF")"; fail=1; }

# H6: an unreadable worklog: rc 2, empty, no last appended.
if [ "$(id -u)" = 0 ]; then
  echo "SKIP: H6 H8 (root reads and writes through chmod)"
else
  seed
  add 500 'proj wait: gh:o/r#9 b1 plain'
  mkrec "last $((NOW - 1000))"
  chmod 000 "$W"
  bw '@0123abcd'
  chmod 644 "$W"
  is H6 2 ''
  [ "$(lastn)" = 1 ] || { echo "FAIL: H6 -- last appended: $(cat "$BF")"; fail=1; }
  # H8: the record cannot be written: rc 2, nothing printed.
  chmod 444 "$BF"
  bw '@0123abcd'
  chmod 644 "$BF"
  is H8 2 ''
fi

# H7: malformed tags: rc 2, nothing written.
seed
add 500 'proj wait: gh:o/r#9 b1 plain'
mkrec "last $((NOW - 1000))"
for g in '@' '@0123abc' '@0123abcd9' '0123abcd' '@0123/bcd' ''; do
  bw "$g"
  is "H7 [$g]" 2 ''
done
[ "$(lastn)" = 1 ] && [ "$(ls "$HOME/.clutch/watch")" = 0123abcd.beat ] \
  || { echo "FAIL: H7 -- something written: $(ls "$HOME/.clutch/watch") / $(cat "$BF")"; fail=1; }

# H9: a moved line ending in one invalid UTF-8 byte hides no later line.
seed
printf '%s proj moved: caf\303\n%s proj moved: after\n' "$((NOW - 300))" "$((NOW - 250))" >> "$W"
mkrec "last $((NOW - 1000))"
OUT=$(cd "$T/plain" && . "$T/scripts/prelude.sh" && LC_ALL=en_US.UTF-8 && export LC_ALL && clutch_beat_window '@0123abcd' 2>/dev/null); RC=$?
[ "$RC" = 0 ] && printf '%s\n' "$OUT" | grep -qF ' proj moved: after' \
  || { echo "FAIL: H9 -- rc $RC, later line lost under UTF-8: $OUT"; fail=1; }

# H10: 25 moves after last: the newest 20, oldest first.
seed
i=1
H10_WANT=""
while [ "$i" -le 25 ]; do
  add $((500 - i * 10)) "proj moved: m$i"
  if [ "$i" -gt 5 ]; then
    H10_WANT="$H10_WANT${H10_WANT:+
}$(wl $((500 - i * 10)) "proj moved: m$i")"
  fi
  i=$((i + 1))
done
mkrec "last $((NOW - 1000))"
bw '@0123abcd'
is H10 0 "$H10_WANT"

# H11: a line stamped before a read but appended after it (stop.sh stamps
# then appends), and a same-second line, land in the next beat past the
# grace, exactly once; no beat repeats a move.
seed
add 900 'proj wait: gh:o/r#9 b1 plain'
add 500 'proj moved: early'
mkrec "last $((NOW - 1000))"
H11_W=$(wl 900 'proj wait: gh:o/r#9 b1 plain')
bwat "$NOW" '@0123abcd'
is "H11 first" 0 "$H11_W
$(wl 500 'proj moved: early')"
add 30 'proj moved: late append'
add 0 'proj moved: same second'
bwat "$NOW" '@0123abcd'
is "H11 inside grace" 0 "$H11_W"
bwat "$((NOW + 200))" '@0123abcd'
is "H11 next" 0 "$H11_W
$(wl 30 'proj moved: late append')
$(wl 0 'proj moved: same second')"
bwat "$((NOW + 400))" '@0123abcd'
is "H11 after" 0 "$H11_W"

# H12: a record armed just now (last <now>) is never moved back by the grace.
seed
add 10 'proj moved: before arming'
mkrec "last $NOW"
bwat "$NOW" '@0123abcd'
is "H12 now" 0 ''
[ "$(tail -n 1 "$BF")" = "last $NOW" ] || { echo "FAIL: H12 -- last moved back: $(cat "$BF")"; fail=1; }
bwat "$((NOW + 200))" '@0123abcd'
is "H12 next" 0 ''

# H13: state that cannot be read is rc 2, not "no worklog": an empty HOME,
# a dangling worklog symlink, an unsearchable ~/.clutch, a record that
# exists but cannot be read (nothing appended).
OUT=$(cd "$T/plain" && HOME='' && . "$T/scripts/prelude.sh" && clutch_beat_window '@0123abcd' 2>/dev/null); RC=$?
is "H13 empty HOME" 2 ''
rm -rf "$HOME/.clutch"
mkdir -p "$HOME/.clutch"
ln -s "$T/nowhere" "$W"
bw '@0123abcd'
is "H13 dangling" 2 ''
if [ "$(id -u)" = 0 ]; then
  echo "SKIP: H13 modes (root reads through chmod)"
else
  seed
  chmod 000 "$HOME/.clutch"
  bw '@0123abcd'
  chmod 755 "$HOME/.clutch"
  is "H13 unsearchable" 2 ''
  seed
  add 500 'proj wait: gh:o/r#9 b1 plain'
  add 300 'proj moved: peer'
  mkrec "last $((NOW - 1000))"
  chmod 222 "$BF"
  bw '@0123abcd'
  chmod 644 "$BF"
  is "H13 unreadable record" 2 ''
  [ "$(cat "$BF")" = "last $((NOW - 1000))" ] || { echo "FAIL: H13 -- record changed: $(cat "$BF")"; fail=1; }
fi

# H14: the worklog tail read failing is rc 2, not "no moves". A tail shim
# fails the second tail -n 2000 (the first is clutch_open_loops').
printf '#!/bin/sh\nif [ "$1 $2" = "-n 2000" ]; then n=$(cat "%s/tailn" 2>/dev/null || echo 0); n=$((n + 1)); echo $n > "%s/tailn"; [ $n -ge 2 ] && exit 1; fi\nexec /usr/bin/tail "$@"\n' "$T" "$T" > "$T/bin/tail"
chmod +x "$T/bin/tail"
seed
add 500 'proj wait: gh:o/r#9 b1 plain'
add 300 'proj moved: peer'
mkrec "last $((NOW - 1000))"
rm -f "$T/tailn"
OUT=$(cd "$T/plain" && PATH="$T/bin:$PATH" && export PATH && . "$T/scripts/prelude.sh" && clutch_beat_window '@0123abcd' 2>/dev/null); RC=$?
rm -f "$T/bin/tail"
is H14 2 ''

# --- H-peek1-H-peek5: clutch_beat_window <@tag> peek prints only the
# window's moved: lines, never the waits, and never appends last; same rc.
bwp() {
  OUT=$(cd "$T/plain" && . "$T/scripts/prelude.sh" && clutch_beat_window "$1" peek 2>"$T/err"); RC=$?
  ERR=$(cat "$T/err")
}
seed
add 900 'proj wait: gh:o/r#9 b1 plain'
add 500 'proj moved: gh:o/r#1 @0123abcd own'
add 400 'proj moved: gh:o/r#2 @ffffffff other'
mkrec "last $((NOW - 1000))"
RB=$(cat "$BF")
bwp '@0123abcd'
is H-peek1 0 "$(wl 400 'proj moved: gh:o/r#2 @ffffffff other')"
[ "$(cat "$BF")" = "$RB" ] || { echo "FAIL: H-peek1 -- record changed: $(cat "$BF")"; fail=1; }
bwp '@0123abcd'
is "H-peek1 again" 0 "$(wl 400 'proj moved: gh:o/r#2 @ffffffff other')"
seed
add 900 'proj wait: gh:o/r#9 b1 plain'
add 500 'proj moved: gh:o/r#1 @0123abcd own'
mkrec "last $((NOW - 1000))"
bwp '@0123abcd'
is H-peek2 0 ''
seed
add 400 'proj moved: gh:o/r#2 @ffffffff other'
mkrec 'asked 2000-01-01'
bwp '@0123abcd'
is H-peek3 0 ''
[ "$(cat "$BF")" = 'asked 2000-01-01' ] || { echo "FAIL: H-peek3 -- record changed: $(cat "$BF")"; fail=1; }
if [ "$(id -u)" != 0 ]; then
  seed
  add 400 'proj moved: gh:o/r#2 @ffffffff other'
  mkrec "last $((NOW - 1000))"
  chmod 000 "$W"; bwp '@0123abcd'; chmod 644 "$W"
  is "H-peek4 unreadable worklog" 2 ''
  chmod 222 "$BF"; bwp '@0123abcd'; chmod 644 "$BF"
  is "H-peek4 unreadable record" 2 ''
  [ "$(cat "$BF")" = "last $((NOW - 1000))" ] || { echo "FAIL: H-peek4 -- record changed: $(cat "$BF")"; fail=1; }
  # A read-only record peeks fine: peek never writes.
  chmod 444 "$BF"; bwp '@0123abcd'; chmod 644 "$BF"
  is "H-peek4 read-only record" 0 "$(wl 400 'proj moved: gh:o/r#2 @ffffffff other')"
fi
rm -rf "$HOME/.clutch"
bwp '@0123abcd'
is "H-peek5 none" 1 ''
mkrec "last $((NOW - 1000))"
bwp '@0123abcd'
is "H-peek5 record" 1 ''
[ "$(lastn)" = 1 ] || { echo "FAIL: H-peek5 -- record changed: $(cat "$BF")"; fail=1; }

# --- R1: the beat skill's one read line, the plugin root replaced by the
# staged tree and @<tag> filled, prints what the helper prints and passes
# its rc through.
# rl1 <string> <from> <to>: the first <from> replaced by <to>, literally.
rl1() {
  printf '%s\n' "$1" | RA=$2 RB=$3 awk '{ i = index($0, ENVIRON["RA"])
    if (i) $0 = substr($0, 1, i - 1) ENVIRON["RB"] substr($0, i + length(ENVIRON["RA"]))
    print }'
}
RLINE=$(grep -F 'sh -c' "$BS" 2>/dev/null | grep -F 'clutch_beat_window')
if [ "$(printf '%s\n' "$RLINE" | grep -c .)" != 1 ]; then
  echo "FAIL: R1 wants exactly one sh -c line reading clutch_beat_window, got: $RLINE"; fail=1
else
  RBAD=$(rl1 "$RLINE" '${CLAUDE_PLUGIN_ROOT}' "$T")
  RCMD=$(rl1 "$RBAD" '@<tag>' '@0123abcd')
  [ "$RCMD" != "$RBAD" ] || { echo "FAIL: R1 -- no @<tag> to fill in: $RLINE"; fail=1; }
  r1fx() {
    seed
    add 500 'proj wait: gh:o/r#9 b1 plain'
    add 100 'proj moved: peer move'
    mkrec "last $((NOW - 1000))"
  }
  r1fx
  R1_OUT=$(cd "$T/plain" && sh -c "$RCMD" 2>&1); R1_RC=$?
  r1fx
  bw '@0123abcd'
  [ "$R1_RC" = "$RC" ] && [ "$R1_OUT" = "$OUT" ] && [ -n "$OUT" ] \
    || { echo "FAIL: R1 -- line rc $R1_RC [$R1_OUT], helper rc $RC [$OUT]"; fail=1; }
  rm -rf "$HOME/.clutch"
  R1_OUT=$(cd "$T/plain" && sh -c "$RCMD" 2>&1); R1_RC=$?
  [ "$R1_RC" = 1 ] && [ -z "$R1_OUT" ] || { echo "FAIL: R1 none -- want rc 1, silent; rc $R1_RC: $R1_OUT"; fail=1; }
  r1fx
  R1_OUT=$(cd "$T/plain" && sh -c "$RBAD" 2>/dev/null); R1_RC=$?
  [ "$R1_RC" = 2 ] && [ -z "$R1_OUT" ] || { echo "FAIL: R1 bad -- want rc 2, empty; rc $R1_RC: $R1_OUT"; fail=1; }
fi

# --- B-OV0-B-OV2: the ops view tail on the read line. OLD_BT5 is the 2.18.1
# line; the beat's line is it plus the tail. Off (no ~/.clutch/opsview.json,
# or a directory there), the two lines print, exit and leave the same tree; on,
# the new line adds one last line `OPS VIEW: on` after a read that exits 0,
# and keeps the rc. Each run gets a fresh fixture and date +%s pinned to NOW,
# so the record's `last` append matches.
OLD_BT5='sh -c '"'"'. "${CLAUDE_PLUGIN_ROOT}/scripts/prelude.sh" && L=$(clutch_beat_window "@<tag>") || exit; [ -z "$L" ] || printf "%s\n" "$L" | LC_ALL=C cut -c1-300'"'"
OV_TAIL='; R=$?; [ ! -f "$HOME/.clutch/opsview.json" ] || echo "OPS VIEW: on"; exit $R'
[ "$RLINE" = "${OLD_BT5%?}$OV_TAIL'" ] || { echo "FAIL: B-OV tail -- the read line is not the 2.18.1 line plus the tail: $RLINE"; fail=1; }
# ovrun <cmd> <moves|quiet|none|unread> [on|dir]: sets OUT, RC and TREE.
ovrun() {
  rm -rf "$HOME/.clutch"
  case $2 in
    moves) r1fx ;;
    quiet) seed; mkrec "last $((NOW - 1000))" ;;
    none) mkdir -p "$HOME/.clutch" ;;
    unread) r1fx; chmod 000 "$W" ;;
  esac
  case ${3:-} in on) : > "$HOME/.clutch/opsview.json" ;; dir) mkdir "$HOME/.clutch/opsview.json" ;; esac
  OUT=$(cd "$T/plain" && PATH="$T/bin:$PATH" && FAKE_NOW=$NOW && export PATH FAKE_NOW && sh -c "$1" 2>&1); RC=$?
  TREE=$(cd "$HOME" && find . | LC_ALL=C sort && find . -type f | LC_ALL=C sort | while IFS= read -r f; do cat "$f" 2>/dev/null; done)
  chmod 644 "$W" 2>/dev/null
}
if [ -n "${RCMD:-}" ]; then
  OLD_CMD=$(rl1 "$(rl1 "$OLD_BT5" '${CLAUDE_PLUGIN_ROOT}' "$T")" '@<tag>' '@0123abcd')
  ovk='moves quiet none'
  if [ "$(id -u)" = 0 ]; then echo "SKIP: B-OV unread (root reads through chmod)"; else ovk="$ovk unread"; fi
  for k in $ovk; do
    ovrun "$OLD_CMD" "$k"; o_out=$OUT; o_rc=$RC; o_tree=$TREE
    case "$k:$o_rc:${o_out:+set}" in moves:0:set|quiet:0:|none:1:|unread:2:) ;;
      *) echo "FAIL: B-OV0 [$k] -- fixture gives rc $o_rc [$o_out]"; fail=1 ;; esac
    ovrun "$RCMD" "$k"
    [ "$RC" = "$o_rc" ] && [ "$OUT" = "$o_out" ] \
      || { echo "FAIL: B-OV0 [$k] off -- rc $RC [$OUT], 2.18.1 rc $o_rc [$o_out]"; fail=1; }
    [ "$TREE" = "$o_tree" ] || { echo "FAIL: B-OV2 [$k] -- the off run left another tree"; fail=1; }
    for m in on dir; do
      ovrun "$OLD_CMD" "$k" "$m"; o_out=$OUT; o_rc=$RC
      want=$o_out
      if [ "$m" = on ] && [ "$o_rc" = 0 ]; then
        if [ -n "$o_out" ]; then want="$o_out
OPS VIEW: on"; else want='OPS VIEW: on'; fi
      fi
      ovrun "$RCMD" "$k" "$m"
      [ "$RC" = "$o_rc" ] && [ "$OUT" = "$want" ] \
        || { echo "FAIL: B-OV1 [$k $m] -- rc $RC [$OUT], want rc $o_rc [$want]"; fail=1; }
    done
  done
fi

# --- R2: the ops Step 0 record snippet, @<tag> filled, under sh and zsh -f.
nrb=$(awk '/^[ \t]*```sh/{n++; f=1; b[n] = ""; next} /^[ \t]*```/{f=0} f{b[n] = b[n] $0 "\n"}
  END {k = 0; for (i = 1; i <= n; i++) if (index(b[i], ".beat")) {k++; s = b[i]}
       printf "%s", s > out; print k}' out="$T/rsnip.raw" "$O")
if [ "$nrb" != 1 ]; then
  echo "FAIL: R2 wants exactly one ops sh block naming .beat, got $nrb"; fail=1
else
  rl1 "$(cat "$T/rsnip.raw")" '@<tag>' '@0123abcd' > "$T/rsnip.sh"
  cmp -s "$T/rsnip.raw" "$T/rsnip.sh" && { echo "FAIL: R2 -- no @<tag> to fill in"; fail=1; }
  SHELLS="sh"
  if command -v zsh >/dev/null 2>&1; then SHELLS="sh zsh"; else echo "SKIP: R2 zsh (no zsh)"; fi
  for sh in $SHELLS; do
    [ "$sh" = zsh ] && run="zsh -f" || run=sh
    # rs [VAR=val]: the snippet from a plain dir; sets OUT (stdout+stderr), RC.
    rs() { OUT=$(cd "$T/plain" && env "$@" $run "$T/rsnip.sh" 2>&1); RC=$?; }
    # (a) ~/.clutch exists: one last line in 0123abcd.beat.
    rm -rf "$HOME/.clutch"; mkdir -p "$HOME/.clutch"
    rs HOME="$HOME"
    [ -z "$OUT" ] && [ "$(ls "$HOME/.clutch/watch" 2>/dev/null)" = 0123abcd.beat ] \
      && [ "$(grep -c . "$BF")" = 1 ] && grep -qx 'last [0-9][0-9]*' "$BF" \
      || { echo "FAIL: R2 $sh (a) -- out [$OUT], watch [$(ls "$HOME/.clutch/watch" 2>/dev/null)], record [$(cat "$BF" 2>/dev/null)]"; fail=1; }
    # (b) no ~/.clutch: nothing created.
    rm -rf "$HOME/.clutch"
    rs HOME="$HOME"
    [ -z "$OUT" ] && [ ! -e "$HOME/.clutch" ] || { echo "FAIL: R2 $sh (b) -- out [$OUT] or ~/.clutch created"; fail=1; }
    # (c) CLUTCH_BEAT=off: nothing created.
    mkdir -p "$HOME/.clutch"
    rs HOME="$HOME" CLUTCH_BEAT=off
    [ -z "$OUT" ] && [ ! -e "$HOME/.clutch/watch" ] || { echo "FAIL: R2 $sh (c) -- out [$OUT] or record written under off"; fail=1; }
    # (d) an existing record is left unchanged.
    mkrec 'last 1' "asked $TODAY"
    R2_B=$(cat "$BF")
    rs HOME="$HOME"
    [ -z "$OUT" ] && [ "$(cat "$BF")" = "$R2_B" ] || { echo "FAIL: R2 $sh (d) -- out [$OUT] or record changed: $(cat "$BF")"; fail=1; }
    # (e) the case guard: an empty, dot or slash tag writes nothing outside
    # ~/.clutch/watch/<one name>.beat. A mutant without the guard must go red.
    sed 's/case \$T in .* \*) \(.*\) ;; esac$/\1/' "$T/rsnip.raw" > "$T/rsnip-mut.raw"
    cmp -s "$T/rsnip.raw" "$T/rsnip-mut.raw" && { echo "FAIL: R2 $sh (e) -- guard mutant did not change the snippet"; fail=1; }
    for v in snip mut; do
      [ "$v" = snip ] && src="$T/rsnip.raw" || src="$T/rsnip-mut.raw"
      made=
      for tg in '@' '@../x' '@a/b'; do
        rm -rf "$HOME/.clutch"; mkdir -p "$HOME/.clutch/watch/a"
        rl1 "$(cat "$src")" '@<tag>' "$tg" > "$T/rsnip-g.sh"
        (cd "$T/plain" && $run "$T/rsnip-g.sh" >/dev/null 2>&1)
        for s in "$HOME/.clutch/x.beat" "$HOME/.clutch/watch/.beat" "$HOME/.clutch/watch/a/b.beat"; do [ ! -e "$s" ] || made="$made $tg:$s"; done
      done
      rm -rf "$HOME/.clutch"
      if [ "$v" = snip ]; then
        [ -z "$made" ] || { echo "FAIL: R2 $sh (e) -- the guard let a bad tag write:$made"; fail=1; }
      else
        [ -n "$made" ] || { echo "FAIL: R2 $sh (e) -- the guard check is vacuous: the unguarded mutant wrote nothing"; fail=1; }
      fi
    done
  done
fi

# --- C1-C9: clutch_ops_record <@tag>: 0 the record is there, 1 it surely is
# not, 2 cannot tell. It never creates or changes anything.
cr() { OUT=$(cd "$T/plain" && . "$T/scripts/prelude.sh" && clutch_ops_record "$1" 2>&1); RC=$?; }
rec; R_B=$(cat "$BF")
cr '@0123abcd'; is "C1 present" 0 ''
[ "$(cat "$BF")" = "$R_B" ] || { echo "FAIL: C1 -- record changed: $(cat "$BF")"; fail=1; }
cr '@89abcdef'; is "C2 peer only" 1 ''
rm -rf "$HOME/.clutch"
cr '@0123abcd'; is "C3 no ~/.clutch" 1 ''
[ ! -e "$HOME/.clutch" ] || { echo "FAIL: C3 -- ~/.clutch created"; fail=1; }
mkdir -p "$HOME/.clutch"
cr '@0123abcd'; is "C4 no watch dir" 1 ''
[ ! -e "$HOME/.clutch/watch" ] || { echo "FAIL: C4 -- watch dir created"; fail=1; }
rec
# The record 0123abcd.beat is there, so a wrong 1 on a near-miss tag shows.
for tg in '' '@' '@../0123abcd' '@a/b' '0123abcd' '@<tag>' '@0123abc' '@0123abcd ' '@0123abcd-4567'; do
  cr "$tg"; is "C5 bad tag [$tg]" 2 ''
done
OUT=$(cd "$T/plain" && HOME='' && . "$T/scripts/prelude.sh" && clutch_ops_record '@0123abcd' 2>&1); RC=$?
is "C6 empty HOME" 2 ''
OUT=$(cd "$T/plain" && HOME="$T/nohome" && . "$T/scripts/prelude.sh" && clutch_ops_record '@0123abcd' 2>&1); RC=$?
is "C6 missing HOME" 2 ''
if [ "$(id -u)" = 0 ]; then
  echo "SKIP: C6 unsearchable HOME parent (root reads through chmod)"
else
  # The EXIT trap restores the mode if this run dies before the chmod back.
  mkdir -p "$T/lk/home"; chmod 000 "$T/lk"
  OUT=$(cd "$T/plain" && HOME="$T/lk/home" && . "$T/scripts/prelude.sh" && clutch_ops_record '@0123abcd' 2>&1); RC=$?
  chmod 755 "$T/lk"
  is "C6 unsearchable HOME parent" 2 ''
fi
if [ "$(id -u)" = 0 ]; then
  echo "SKIP: C7 modes (root reads through chmod)"
else
  rec; chmod 000 "$HOME/.clutch/watch"; cr '@0123abcd'; chmod 755 "$HOME/.clutch/watch"; is "C7 unsearchable watch" 2 ''
  rec; chmod 000 "$HOME/.clutch"; cr '@0123abcd'; chmod 755 "$HOME/.clutch"; is "C7 unsearchable ~/.clutch" 2 ''
fi
rm -rf "$HOME/.clutch"; mkdir -p "$HOME/.clutch"; : > "$HOME/.clutch/watch"
cr '@0123abcd'; is "C7 watch not a dir" 2 ''
# C8 a dangling record symlink still counts as there; C9 a dangling
# ~/.clutch symlink cannot be told apart from a broken mount.
rec; rm -f "$BF"; ln -s "$T/nowhere" "$BF"
cr '@0123abcd'; is "C8 dangling record symlink" 0 ''
rm -rf "$HOME/.clutch"; ln -s "$T/nowhere" "$HOME/.clutch"
cr '@0123abcd'; is "C9 dangling ~/.clutch symlink" 2 ''
rm -f "$HOME/.clutch"

# --- R4/R5: the beat skill's and the armed sweep's record check line, the
# plugin root replaced by the staged tree and @<tag> filled, under sh and
# zsh -f: record there, rc 0 and silent (the beat and sweep go on as before);
# record gone, rc 1 and silent (the stop path); nothing created either way.
for pair in "R4:$BS" "R5:$O"; do
  rid=${pair%%:*}; rf=${pair#*:}
  CL=$(grep -F 'sh -c' "$rf" 2>/dev/null | grep -F 'clutch_ops_record')
  if [ "$(printf '%s\n' "$CL" | grep -c .)" != 1 ]; then
    echo "FAIL: $rid wants exactly one sh -c line reading clutch_ops_record in $rf, got: $CL"; fail=1; continue
  fi
  CBAD=$(rl1 "$CL" '${CLAUDE_PLUGIN_ROOT}' "$T")
  CCMD=$(rl1 "$CBAD" '@<tag>' '@0123abcd')
  [ "$CCMD" != "$CBAD" ] || { echo "FAIL: $rid -- no @<tag> to fill in: $CL"; fail=1; }
  SHELLS="sh"
  if command -v zsh >/dev/null 2>&1; then SHELLS="sh zsh"; else echo "SKIP: $rid zsh (no zsh)"; fi
  for sh in $SHELLS; do
    [ "$sh" = zsh ] && run="zsh -f" || run=sh
    rec; R_B=$(cat "$BF")
    OUT=$(cd "$T/plain" && $run -c "$CCMD" 2>&1); RC=$?
    is "$rid $sh present" 0 ''
    [ "$(cat "$BF")" = "$R_B" ] || { echo "FAIL: $rid $sh -- record changed: $(cat "$BF")"; fail=1; }
    rm -f "$BF"
    OUT=$(cd "$T/plain" && $run -c "$CCMD" 2>&1); RC=$?
    is "$rid $sh gone" 1 ''
    [ "$(ls -A "$HOME/.clutch/watch")" = '' ] || { echo "FAIL: $rid $sh -- the check wrote: $(ls -A "$HOME/.clutch/watch")"; fail=1; }
    rm -rf "$HOME/.clutch"
    OUT=$(cd "$T/plain" && $run -c "$CCMD" 2>&1); RC=$?
    is "$rid $sh no ~/.clutch" 1 ''
    [ ! -e "$HOME/.clutch" ] || { echo "FAIL: $rid $sh -- ~/.clutch created"; fail=1; }
  done
done

# --- R3: the beat skill's moved: text, filled and written with the
# constitution's snippet, closes the untagged wait on its ref; a tagged form
# would not (DD7).
# csnip <verb> <text> <out>: the constitution's snippet filled.
csnip() {
  awk '/```sh/{n++; f=1; next} /```/{f=0} f && n == 1' "$K" | CV=$1 CX=$2 awk '
    function rl(s, a, b,   i) { i = index(s, a); return i ? substr(s, 1, i - 1) b substr(s, i + length(a)) : s }
    { $0 = rl($0, "<moved:|on:>", ENVIRON["CV"]); print rl($0, "<one line>", ENVIRON["CX"]) }' > "$3"
}
# open9: clutch_open_loops lists the gh:o/r#9 wait.
open9() { (cd "$T/plain" && . "$T/scripts/prelude.sh" && clutch_open_loops) | grep -qF ' gh:o/r#9 '; }
MT=$(sed -n 's/.*verb `moved:` and text `\([^`]*\)`.*/\1/p' "$BS" 2>/dev/null | head -n 1)
if [ -z "$MT" ]; then
  echo "FAIL: R3 -- no moved: text template in the beat skill"; fail=1
else
  FILLED=$(rl1 "$(rl1 "$(rl1 "$MT" '<kind>:<ref>' 'gh:o/r#9')" '<what moved>' 'merged')" '@<tag>' '@0123abcd')
  seed
  add 500 'proj wait: gh:o/r#9 b1 pr nine'
  open9 || { echo "FAIL: R3 -- the wait is not open before the move"; fail=1; }
  csnip 'moved:' 'gh:o/r#9 @0123abcd merged' "$T/r3tag.sh"
  (cd "$T/plain" && sh "$T/r3tag.sh" >/dev/null 2>&1)
  open9 || { echo "FAIL: R3 -- a tagged moved: line closed the untagged wait"; fail=1; }
  csnip 'moved:' "$FILLED" "$T/r3.sh"
  (cd "$T/plain" && sh "$T/r3.sh" >/dev/null 2>&1)
  open9 && { echo "FAIL: R3 -- the beat's moved: text [$FILLED] left the untagged wait open"; fail=1; }
fi

[ "$fail" -eq 0 ] || exit 1
echo PASS
