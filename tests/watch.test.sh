#!/bin/sh
# Armed watch: the session tag and the owned wait loops. T1-T5 and T4b cover
# clutch_session_tag (the first "session_id" key of the hook input JSON, cut
# to 8 chars of [0-9A-Za-z-], rc 1 with no stdout otherwise). O1-O5 cover
# clutch_owned_loops (the open wait lines whose field 6 equals the tag; rc 1
# with no worklog, rc 2 on an unreadable worklog, a worklog path that cannot
# be stat'ed, an empty HOME or a malformed tag; a wait re-held after a moved:
# line on the same ref is open again). A1-A5 cover the anchor's
# "Session tag: @<tag8>" line (dropped without a session_id or under
# CLUTCH_WATCH=off); K1-K4 pin the constitution's wait: verb, the watch
# tick carve-out, the untagged wait and the one-token baseline. S1-S14 and
# S2b cover the stop.sh watch gate (one block line while the session holds
# owned open waits and no armed /clutch:watch, once per wait set).
# prelude.sh, anchor.sh, stop.sh and the constitution are staged into a
# scratch tree and run from a scratch repo or a non-git dir under a scratch
# HOME. PRELUDE_SH, ANCHOR_SH, STOP_SH and CONST_FILE override the targets
# for replay against a historical version. Silent on pass apart from PASS.
set -u
unset CLUTCH_WATCH CLAUDE_PLUGIN_ROOT

HERE=$(cd "$(dirname "$0")" && pwd)
P=${PRELUDE_SH:-$HERE/../scripts/prelude.sh}
A=${ANCHOR_SH:-$HERE/../scripts/anchor.sh}
K=${CONST_FILE:-$HERE/../rules/constitution.md}
S=${STOP_SH:-$HERE/../scripts/stop.sh}
for f in "$P" "$A" "$K" "$S"; do
  [ -f "$f" ] || { echo "FAIL: missing $f"; exit 1; }
done

T=$(mktemp -d) || exit 1
trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
HOME=$T/home
export HOME
mkdir -p "$HOME" "$T/scripts" "$T/plain" "$T/rules"
cp "$P" "$T/scripts/prelude.sh"
cp "$A" "$T/scripts/anchor.sh"
cp "$S" "$T/scripts/stop.sh"
cp "$K" "$T/rules/constitution.md"
W="$HOME/.clutch/worklog.md"
NOW=$(date +%s)
fail=0

# tag <json>: clutch_session_tag on json; sets OUT and RC.
OUT=""
RC=0
tag() {
  OUT=$(cd "$T/plain" && . "$T/scripts/prelude.sh" && clutch_session_tag "$1" 2>/dev/null); RC=$?
}
# owned <arg>: clutch_owned_loops on arg; sets OUT, RC and ERR (stderr).
ERR=""
owned() {
  OUT=$(cd "$T/plain" && . "$T/scripts/prelude.sh" && clutch_owned_loops "$1" 2>"$T/err"); RC=$?
  ERR=$(cat "$T/err")
}
# is <label> <rc> <stdout>: exact rc and stdout.
is() {
  [ "$RC" = "$2" ] && [ "$OUT" = "$3" ] \
    || { echo "FAIL: $1 -- rc $RC stdout [$OUT], want rc $2 stdout [$3]"; fail=1; }
}
# seed: an empty worklog; add <age> <rest>: append one line aged <age> s.
seed() { rm -rf "$HOME/.clutch"; mkdir -p "$HOME/.clutch" && : > "$W"; }
add() { printf '%s %s\n' "$((NOW - $1))" "$2" >> "$W"; }

ID='0123abcd-4567-89ab-cdef-0123456789ab'
tag "{\"session_id\":\"$ID\",\"source\":\"startup\"}"
is T1 0 '@0123abcd'
tag '{"source":"startup"}'
is T2 1 ''
tag '{"session_id":"ab/cd","source":"startup"}'
is "T3 slash" 1 ''
tag '{"session_id":"ab\"c","source":"startup"}'
is "T3 escaped quote" 1 ''
tag "{\"session_id\":\"$ID\",\"last_assistant_message\":\"x \\\"session_id\\\":\\\"ffffffff\\\" y\"}"
is T4 0 '@0123abcd'
tag "{\"session_id\":\"$ID\",\"nested\":{\"session_id\":\"ffffffff\"}}"
is T4b 0 '@0123abcd'
tag '{"session_id":"abc123"}'
is T5 0 '@abc123'

# O1/O4: only the open line whose field 6 is the tag, raw with its epoch.
seed
add 500 'proj wait: gh:o/r#1 b1 @0123abcd mine open'
add 400 'proj wait: gh:o/r#2 b1 untagged wait'
add 300 'proj wait: gh:o/r#3 b1 @ffffffff someone else'
add 200 'proj wait: gh:o/r#4 b1 @0123abcd mine but moved'
add 100 'proj moved: gh:o/r#4 merged'
add 50 'proj wait: gh:o/r#5 b1 note @0123abcd tag as 7th token'
owned '@0123abcd'
is O1 0 "$((NOW - 500)) proj wait: gh:o/r#1 b1 @0123abcd mine open"
owned '@nobody'
is "O4 no match" 0 ''

# O2: no worklog is rc 1 with empty stderr; a directory, or a worklog that
# cannot be stat'ed (no-x parent, dangling symlink, parent is a file, empty
# HOME), is rc 2, never "no worklog".
rm -rf "$HOME/.clutch"
owned '@0123abcd'
is "O2 none" 1 ''
[ -z "$ERR" ] || { echo "FAIL: O2 none -- stderr [$ERR], want empty"; fail=1; }
mkdir -p "$W"
owned '@0123abcd'
is "O2 dir" 2 ''
seed
chmod a-x "$HOME/.clutch"
owned '@0123abcd'
is "O2 no-x parent" 2 ''
chmod u+x "$HOME/.clutch"
rm -f "$W" && ln -s "$T/nowhere" "$W"
owned '@0123abcd'
is "O2 dangling symlink" 2 ''
rm -rf "$HOME/.clutch" && : > "$HOME/.clutch"
owned '@0123abcd'
is "O2 parent is a file" 2 ''
rm -f "$HOME/.clutch"
HOME=''
owned '@0123abcd'
HOME=$T/home
is "O2 empty HOME" 2 ''

# O3: a malformed tag is rc 2, never "no owned waits".
seed
add 100 'proj wait: gh:o/r#1 b1 @0123abcd mine'
for bad in '0123abcd' '' '@' '@a/b'; do
  owned "$bad"
  is "O3 [$bad]" 2 ''
done
# Non-ASCII letters under a UTF-8 locale, where a range class matches them.
LC_ALL=en_US.UTF-8
export LC_ALL
for bad in '@é' '@abü'; do
  owned "$bad"
  is "O3 [$bad]" 2 ''
done
unset LC_ALL

# O5: wait, moved, then the re-held wait on the same ref: only the re-held line.
seed
add 300 'proj wait: gh:o/r#1 b1 @0123abcd pr one'
add 200 'proj moved: gh:o/r#1 approved'
add 100 'proj wait: gh:o/r#1 b2 @0123abcd pr one re-held'
owned '@0123abcd'
is O5 0 "$((NOW - 100)) proj wait: gh:o/r#1 b2 @0123abcd pr one re-held"

# --- Anchor tag line. anc <dir> <json>: the staged anchor run from dir on
# json, with CLUTCH_WATCH set to $WATCH; sets OUT and RC. fix: a fresh repo
# .clutch (breadcrumb only) and a one-line worklog, so each run starts alike.
R=$T/repo
mkdir -p "$R"
git -C "$R" init -q
WATCH=''
anc() {
  OUT=$(cd "$1" && printf '%s' "$2" | CLUTCH_WATCH=$WATCH GIT_CEILING_DIRECTORIES=$T sh "$T/scripts/anchor.sh" 2>/dev/null); RC=$?
}
fix() {
  rm -rf "$R/.clutch" && mkdir -p "$R/.clutch"
  printf 'b; most recent: notes.md\n' > "$R/.clutch/breadcrumb"
  seed
  add 100 'proj moved: gh:o/r#9 merged'
}
# tagged <label>: rc 0 and exactly one Session tag line, @0123abcd.
tagged() {
  [ "$RC" = 0 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^Session tag:')" = 1 ] \
    && printf '%s\n' "$OUT" | grep -qx 'Session tag: @0123abcd' \
    || { echo "FAIL: $1 -- rc $RC, want one 'Session tag: @0123abcd' line in [$OUT]"; fail=1; }
}
# untagged <label>: rc 0 and no Session tag line.
untagged() {
  [ "$RC" = 0 ] && ! printf '%s\n' "$OUT" | grep -q 'Session tag:' \
    || { echo "FAIL: $1 -- rc $RC, want no Session tag line in [$OUT]"; fail=1; }
}
ASKLINE='Intent for this session: build, ideate, ops, or review? /clutch:intent sets the frame.'

# A1: startup in a repo: one tag line, the intent ask still last.
fix
anc "$R" "{\"session_id\":\"$ID\",\"source\":\"startup\"}"
tagged A1
[ "$(printf '%s\n' "$OUT" | tail -n 1)" = "$ASKLINE" ] \
  || { echo "FAIL: A1 -- intent ask is not the last line in [$OUT]"; fail=1; }

# A2: every other source carries the tag too.
for src in resume compact clear fork; do
  fix
  anc "$R" "{\"session_id\":\"$ID\",\"source\":\"$src\"}"
  tagged "A2 $src"
done

# A3: outside git, without and with a worklog; after the Worklog block.
rm -rf "$HOME/.clutch"
anc "$T/plain" "{\"session_id\":\"$ID\",\"source\":\"startup\"}"
tagged "A3 no worklog"
fix
anc "$T/plain" "{\"session_id\":\"$ID\",\"source\":\"startup\"}"
tagged "A3 worklog"
printf '%s\n' "$OUT" | awk '/^Worklog:$/ { w = NR } /^Session tag: / { s = NR } END { exit !(w && s > w) }' \
  || { echo "FAIL: A3 -- tag line not after the Worklog block in [$OUT]"; fail=1; }

# A4: no session_id, or bad JSON: no tag line, rc 0.
for j in '{"source":"startup"}' '{"session_id":' 'not json' '{"session_id":"ab/cd","source":"startup"}'; do
  fix
  anc "$R" "$j"
  untagged "A4 [$j]"
  [ "$j" != '{"source":"startup"}' ] || [ "$(printf '%s\n' "$OUT" | tail -n 1)" = "$ASKLINE" ] \
    || { echo "FAIL: A4 [$j] -- intent ask is not the last line in [$OUT]"; fail=1; }
done

# A5: CLUTCH_WATCH=off with a session_id prints what the same anchor prints
# for the input without one, in a repo and outside git.
for d in "$R" "$T/plain"; do
  fix
  anc "$d" '{"source":"startup"}'
  BASE_OUT=$OUT
  fix
  WATCH=off
  anc "$d" "{\"session_id\":\"$ID\",\"source\":\"startup\"}"
  WATCH=''
  untagged "A5 off [$d]"
  [ "$OUT" = "$BASE_OUT" ] \
    || { echo "FAIL: A5 [$d] -- off output differs from no-session_id output: [$OUT] vs [$BASE_OUT]"; fail=1; }
done

# --- K1-K4: constitution pins, whitespace joined so wrapped prose matches.
J=$(tr -s '[:space:]' ' ' < "$T/rules/constitution.md")
kpin() {
  case "$J" in *"$2"*) ;; *) echo "FAIL: $1 -- constitution lacks: $2"; fail=1 ;; esac
}
kpin "K1 wait verb" "wait: when an outward action leaves you waiting on someone else's move"
kpin "K1 wait text" '<kind>:<ref> <baseline> <session tag> <what you wait for>'
kpin "K2 watch tick invited" "A tick from the session's armed watch is invited output too."
kpin "K3 untagged wait" "No Session tag line: omit the tag, never a peer's."
kpin "K4 one-token baseline" "The baseline is one token: hyphens, no spaces."

# --- S1-S14, S2b: the stop.sh watch gate. stp <dir> <json>: the staged
# stop.sh run from dir on json, with CLUTCH_WATCH set to $WATCH; sets OUT and
# RC. fresh <fixture>: a fresh copy at $T/run, because stop.sh writes the
# breadcrumb and state. Scratch repos carry a repo-local identity only.
unset XDG_CONFIG_HOME
GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_NOSYSTEM
stp() {
  OUT=$(cd "$1" && printf '%s' "$2" | CLUTCH_WATCH=$WATCH GIT_CEILING_DIRECTORIES=$T sh "$T/scripts/stop.sh" 2>/dev/null); RC=$?
}
fresh() { rm -rf "$T/run" && cp -R "$1" "$T/run"; }
mkrepo() {
  mkdir -p "$1" && git -C "$1" init -q &&
    git -C "$1" config user.email s@s && git -C "$1" config user.name s &&
    git -C "$1" commit -q --allow-empty -m "seed"
}
SF=$T/sfix
mkrepo "$SF" || exit 1
# Bell-ready: first stop 2000 s ago, base one authored commit behind HEAD.
BF=$T/bfix
mkrepo "$BF" || exit 1
mkdir -p "$BF/.clutch"
printf 'stop %s\nbase %s\n' "$((NOW - 2000))" "$(git -C "$BF" rev-parse HEAD)" > "$BF/.clutch/session-state"
git -C "$BF" commit -q --allow-empty -m "feat bell"

BLOCK='{"decision":"block","reason":"This session holds open wait loops and no watch. Arm one now with CronCreate, schedule `*/15 8-21 * * *`, recurring, prompt `/clutch:watch @0123abcd`, then end the turn. If the user said not to watch them, just end the turn."}'
IN="{\"session_id\":\"$ID\",\"stop_hook_active\":false,\"session_crons\":[]}"
FP="$HOME/.clutch/watch/0123abcd"
# blocked <label>: rc 0 and stdout exactly the block line.
blocked() {
  [ "$RC" = 0 ] && [ "$OUT" = "$BLOCK" ] \
    || { echo "FAIL: $1 -- rc $RC stdout [$OUT], want rc 0 and the block line"; fail=1; }
}
# quiet <label>: rc 0 and no stdout.
quiet() { is "$1" 0 ''; }
# owned1: a fresh worklog holding one owned open wait.
owned1() { seed; add 100 'proj wait: gh:o/r#1 b1 @0123abcd pr one'; }
crons() {
  printf '{"session_id":"%s","stop_hook_active":false,"session_crons":[{"id":"c1","cron":"*/15 8-21 * * *","prompt":"%s","recurring":true}]}' "$ID" "$1"
}

# S1: owned open wait, no watch: one valid JSON block line; fingerprint written.
owned1
fresh "$SF"
stp "$T/run" "$IN"
blocked S1
if [ -x /usr/bin/python3 ]; then
  printf '%s' "$OUT" | /usr/bin/python3 -I -c 'import json,sys; d=json.load(sys.stdin); assert d["decision"] == "block"; assert "*/15 8-21 * * *" in d["reason"]; assert "/clutch:watch @0123abcd" in d["reason"]' 2>/dev/null \
    || { echo "FAIL: S1 -- block line is not the JSON block object"; fail=1; }
fi
[ -s "$FP" ] || { echo "FAIL: S1 -- no fingerprint at $FP"; fail=1; }

# S5: a second stop on the same owned set stays quiet.
stp "$T/run" "$IN"
quiet S5
# S6: a new owned wait blocks again.
add 50 'proj wait: gh:o/r#2 b1 @0123abcd pr two'
stp "$T/run" "$IN"
blocked S6

# S2: an armed watch: no block, breadcrumb still written.
owned1
fresh "$SF"
stp "$T/run" "$(crons '/clutch:watch @0123abcd')"
quiet S2
[ -s "$T/run/.clutch/breadcrumb" ] || { echo "FAIL: S2 -- no breadcrumb"; fail=1; }

# S2b: a longer tag or another session's watch is not this session's.
for pr in '/clutch:watch @0123abcd9' '/clutch:watch @ffffffff'; do
  owned1
  fresh "$SF"
  stp "$T/run" "$(crons "$pr")"
  blocked "S2b [$pr]"
done

# S3: stop_hook_active true, either spacing.
for a in '"stop_hook_active":true' '"stop_hook_active": true'; do
  owned1
  fresh "$SF"
  stp "$T/run" "{\"session_id\":\"$ID\",$a,\"session_crons\":[]}"
  quiet "S3 [$a]"
done

# S4: only untagged and peer-tagged waits never block.
seed
add 100 'proj wait: gh:o/r#1 b1 untagged wait'
add 90 'proj wait: gh:o/r#2 b1 @ffffffff peer wait'
fresh "$SF"
stp "$T/run" "$IN"
quiet S4

# S7: CLUTCH_WATCH=off with a session_id gives the same stdout and rc as the
# same stop.sh fed the input without session_id, bell-ready fixture.
owned1
fresh "$BF"
stp "$T/run" '{"stop_hook_active":false,"session_crons":[]}'
BASE_OUT=$OUT BASE_RC=$RC
[ -n "$BASE_OUT" ] || { echo "FAIL: S7 -- bell fixture printed nothing (vacuous)"; fail=1; }
owned1
fresh "$BF"
WATCH=off
stp "$T/run" "$IN"
WATCH=''
[ "$OUT" = "$BASE_OUT" ] && [ "$RC" = "$BASE_RC" ] \
  || { echo "FAIL: S7 -- off rc $RC [$OUT] vs no-session_id rc $BASE_RC [$BASE_OUT]"; fail=1; }
# S12 (S7 control): watch on, same input: only the block line, no bell.
owned1
fresh "$BF"
stp "$T/run" "$IN"
blocked S12
grep -q '^emit' "$T/run/.clutch/session-state" && { echo "FAIL: S12 -- bell recorded an emit"; fail=1; }

# S8: empty, non-JSON and truncated stdin: no block, rc 0.
for j in '' 'not json' "{\"session_id\":\"0123abcd-45" "{\"session_id\":\"$ID\",\"session_cr"; do
  owned1
  fresh "$SF"
  stp "$T/run" "$j"
  quiet "S8 [$j]"
done

# S9: outside git the gate still blocks.
owned1
stp "$T/plain" "$IN"
blocked S9

# S10: no session_crons key (registry unreachable): no block.
owned1
fresh "$SF"
stp "$T/run" "{\"session_id\":\"$ID\",\"stop_hook_active\":false}"
quiet S10

# S11: the fingerprint cannot be written: no block, rc 0.
owned1
: > "$HOME/.clutch/watch"
fresh "$SF"
stp "$T/run" "$IN"
quiet S11

# S13: no session_id: no block.
owned1
fresh "$SF"
stp "$T/run" '{"stop_hook_active":false,"session_crons":[]}'
quiet S13

# S14: an owned wait closed by moved: on its ref: no block.
owned1
add 50 'proj moved: gh:o/r#1 merged'
fresh "$SF"
stp "$T/run" "$IN"
quiet S14

[ "$fail" -eq 0 ] || exit 1
echo PASS
