#!/bin/sh
# Ops beat. B1-B13 cover the stop.sh beat gate: a session whose tag has an
# ops record (~/.clutch/watch/<tag8>.beat) and no "prompt" whose whole value
# is /clutch:beat @<tag8> is blocked once a local day with the arming step;
# "asked <YYYY-MM-DD>" lands in the record before the block prints. The watch
# gate keeps priority (B5). Every failure falls through: no block (B6-B10).
# CLUTCH_BEAT=off skips it (B11). B-scrub pins the brain scrub line.
# H1-H14 cover clutch_beat_window (the untagged open waits, then the newest
# 20 moved: lines after the record's last epoch and at or before now - 120
# whose field 5 is not the tag; "last <now - 120>" appended to an existing
# record before printing; unreadable state is rc 2). R1 runs the
# beat skill's read line, R2 the ops Step 0 record snippet under sh and
# zsh -f, R3 the beat skill's moved: text through the constitution snippet.
# prelude.sh and stop.sh are staged into a scratch tree and run from a scratch
# repo or a non-git dir under a scratch HOME. PRELUDE_SH, STOP_SH,
# BEAT_SKILL, OPS_SKILL and CONST_FILE override the targets for replay
# against a historical version. Silent on pass apart from PASS.
set -u
unset CLUTCH_BEAT CLUTCH_WATCH CLUTCH_INVESTIGATE CLUTCH_PLAIN CLUTCH_GUESS CLAUDE_PLUGIN_ROOT

HERE=$(cd "$(dirname "$0")" && pwd)
P=${PRELUDE_SH:-$HERE/../scripts/prelude.sh}
S=${STOP_SH:-$HERE/../scripts/stop.sh}
BS=${BEAT_SKILL:-$HERE/../skills/beat/SKILL.md}
O=${OPS_SKILL:-$HERE/../skills/ops/SKILL.md}
K=${CONST_FILE:-$HERE/../rules/constitution.md}
for f in "$P" "$S" "$O" "$K"; do
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

# B-scrub: brain.test.sh's sibling runs clear CLUTCH_BEAT and BEAT_SKILL.
for v in CLUTCH_BEAT BEAT_SKILL; do
  grep -E '^[[:space:]]*\( unset ' "$HERE/brain.test.sh" | grep -qw "$v" \
    || { echo "FAIL: B-scrub -- $v missing from brain.test.sh's run_scrubbed unset line"; fail=1; }
done

# B-readme: the README beat bullet names both switches that turn the beat off.
awk '/^- An ops session is told at turn end/{f=1} f && /^- / && !/^- An ops/{f=0} f' "$HERE/../README.md" |
  tr '\n' ' ' | grep -q 'CLUTCH_WATCH=off.*beat' \
  || { echo "FAIL: B-readme -- the beat bullet does not say CLUTCH_WATCH=off turns the beat off"; fail=1; }

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
  done
fi

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
