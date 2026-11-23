#!/bin/sh
# Silent check. L1-L11 cover clutch_poll_alive <@tag> (record
# ~/.clutch/watch/<tag8>.poll, one line "<pid> <start epoch>" with an optional
# third field): 0 alive (kill -0 passes and ps -ww names poll.sh @<tag8> at
# the end), 1 no record (proven absent), 2 cannot tell, 3 ended (dead or
# reused pid, another tag's poller, malformed line). It never writes.
# L12-L14 cover its beat mode (4 for a live poller whose line has no third
# field beat). Y1-Y9 cover clutch_poll_young <@tag> (0 died young: a
# well-formed .poll started under one round ago, not after now, whose .woke
# is empty, absent or older; 1 otherwise; it never writes).
# M1-M27 with M5b, M11b, M12b, M12c, M20b-M20d, M22b, M24b-M24e and M27b run
# scripts/poll.sh @<tag> (the silent check) against a fake gh that applies the
# real --jq filter to a per-PR GraphQL fixture through /usr/bin/jq, a fake
# date for +%H and +%s and a fake sleep: quiet rounds print nothing, a move
# prints "<ref> <what>" lines and the closing line after appending
# <ref> <stamp> to .woke, 3 gh failures in a row print "<ref> unreadable" once
# per wait line, every other exit prints the ended line, and a failed write
# prints the stopped line, under dash too (M20d); a gh that never answers is
# killed after 60 s and counts as a failure (M27), and no gh returns at once
# under sh and dash (M27b). Bt1-Bt17 with Bt4b, Bt5b,
# Bt6b, Bt8b, Bt10b and Bt13b cover the beat: with the tag's ops record there it peeks the beat window
# from 08:00 to 20:59, wakes on peer moves at most once an hour with
# "Run /clutch:beat @<tag>." after a "beat <epoch>" mark, seeds a record with
# no last line in a beat round (a failed seed retries next round), and
# keeps running with no gh wait while the record is there; the hourly cap
# leaves out a last or beat mark after now (Bt17).
# prelude.sh and poll.sh are staged into a scratch tree and run under a
# scratch HOME. PRELUDE_SH and POLL_SH override the targets for replay or a
# mutant copy. Silent on pass apart from PASS.
set -u
unset CLUTCH_POLL CLUTCH_POLL_SLEEP CLUTCH_POLL_ROUNDS CLUTCH_WATCH CLUTCH_BEAT CLAUDE_PLUGIN_ROOT

HERE=$(cd "$(dirname "$0")" && pwd)
P=${PRELUDE_SH:-$HERE/../scripts/prelude.sh}
PS=${POLL_SH:-$HERE/../scripts/poll.sh}
for f in "$P" "$PS"; do
  [ -f "$f" ] || { echo "FAIL: missing $f"; exit 1; }
done
# The fake gh applies the real filter; without jq the M series proves nothing.
[ -x /usr/bin/jq ] || { echo "FAIL: /usr/bin/jq missing"; exit 1; }

T=$(mktemp -d) || exit 1
PIDS=""
trap 'for p in $PIDS; do kill "$p" 2>/dev/null; done; chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
HOME=$T/home
export HOME
mkdir -p "$HOME" "$T/scripts" "$T/plain" "$T/stub" "$T/fakebin"
cp "$P" "$T/scripts/prelude.sh"
cp "$PS" "$T/scripts/poll.sh"
NOW=$(date +%s)
fail=0

OUT=""
RC=0
# is <label> <rc> <stdout>: exact rc and stdout.
is() {
  [ "$RC" = "$2" ] && [ "$OUT" = "$3" ] \
    || { echo "FAIL: $1 -- rc $RC stdout [$OUT], want rc $2 stdout [$3]"; fail=1; }
}
# snap: the ~/.clutch tree with modes and contents, to prove a reader wrote nothing.
snap() { ls -lRa "$HOME" 2>/dev/null | grep -v '^total'; cat "$HOME"/.clutch/watch/* 2>/dev/null; }

# --- L1-L11: clutch_poll_alive
PF="$HOME/.clutch/watch/0123abcd.poll"
# A stub poller: a live process whose command line ends with poll.sh @<tag>.
printf 'sleep 30\n' > "$T/stub/poll.sh"
# bg <cmd...>: start it detached from this shell's jobs (no "Terminated"
# notice at exit) and print its pid.
bg() { ( "$@" </dev/null >/dev/null 2>&1 & echo $! ); }
LIVE=$(bg sh "$T/stub/poll.sh" @0123abcd)
OTHER=$(bg sh "$T/stub/poll.sh" @ffffffff)
NOTPOLL=$(bg sleep 30)
LONG="$T/stub/a-very-long-plugin-cache-directory-name-that-goes-on/and-on-past-eighty-columns/0.0.0-long-version-string/scripts"
mkdir -p "$LONG"; cp "$T/stub/poll.sh" "$LONG/poll.sh"
LONGP=$(bg sh "$LONG/poll.sh" @0123abcd)
DEAD=$(bg true)
PIDS="$LIVE $OTHER $NOTPOLL $LONGP"
sleep 1

pa() { OUT=$(cd "$T/plain" && . "$T/scripts/prelude.sh" && clutch_poll_alive "$1" 2>&1); RC=$?; }
# rec <line>: a fresh ~/.clutch/watch holding .poll with that content.
rec() { rm -rf "$HOME/.clutch"; mkdir -p "$HOME/.clutch/watch"; printf '%s' "$1" > "$PF"; }
# chk <label> <tag> <rc>: the call's rc, empty stdout, and an unchanged tree.
chk() {
  B=$(snap); pa "$2"; is "$1" "$3" ''
  [ "$(snap)" = "$B" ] || { echo "FAIL: $1 -- the reader changed ~/.clutch"; fail=1; }
}

rec "$LIVE $NOW
"; chk "L1 live poller" '@0123abcd' 0
rec ''; rm -f "$PF"; chk "L2 no .poll" '@0123abcd' 1
rm -rf "$HOME/.clutch/watch"; chk "L2b no watch dir" '@0123abcd' 1
[ ! -e "$HOME/.clutch/watch" ] || { echo "FAIL: L2b -- watch dir created"; fail=1; }
rm -rf "$HOME/.clutch"; chk "L2b no ~/.clutch" '@0123abcd' 1
[ ! -e "$HOME/.clutch" ] || { echo "FAIL: L2b -- ~/.clutch created"; fail=1; }
rec "$DEAD $NOW
"; chk "L3 dead pid" '@0123abcd' 3
rec "$NOTPOLL $NOW
"; chk "L4 live non-poller" '@0123abcd' 3
rec "$OTHER $NOW
"; chk "L5 other tag's poller" '@0123abcd' 3
for c in '' 'abc 1
' "$LIVE" "
$LIVE $NOW
" "$LIVE $NOW beat extra
" "0 $NOW
" "$LIVE x
"; do
  rec "$c"; chk "L6 malformed [$c]" '@0123abcd' 3
done
rec "$LIVE $NOW"; chk "L6b no trailing newline" '@0123abcd' 0
rec "$LIVE $NOW
"
for tg in '' '@' '0123abcd' '@a/b' '@0123abc' '@0123abcd ' '@0123abcd-4567' '@../0123ab'; do
  chk "L7 bad tag [$tg]" "$tg" 2
done
OUT=$(cd "$T/plain" && LC_ALL=en_US.UTF-8 && export LC_ALL && . "$T/scripts/prelude.sh" && clutch_poll_alive '@0123abcé' 2>&1); RC=$?
is "L7 bad tag UTF-8" 2 ''
if [ "$(id -u)" = 0 ]; then
  echo "SKIP: L8 modes (root reads through chmod)"
else
  rec "$LIVE $NOW
"; chmod 000 "$PF"; chk "L8 unreadable .poll" '@0123abcd' 2; chmod 644 "$PF"
  chmod 666 "$HOME/.clutch/watch"; chk "L8 unsearchable watch" '@0123abcd' 2; chmod 755 "$HOME/.clutch/watch"
  rm -f "$PF"; chmod 666 "$HOME/.clutch/watch"; chk "L8 unsearchable watch, no .poll" '@0123abcd' 2; chmod 755 "$HOME/.clutch/watch"
fi
OUT=$(cd "$T/plain" && HOME='' && . "$T/scripts/prelude.sh" && clutch_poll_alive '@0123abcd' 2>&1); RC=$?
is "L8 empty HOME" 2 ''
rec "$LIVE $NOW
"
printf '#!/bin/sh\nexit 1\n' > "$T/fakebin/ps"; chmod 755 "$T/fakebin/ps"
OUT=$(cd "$T/plain" && PATH="$T/fakebin:$PATH" && . "$T/scripts/prelude.sh" && clutch_poll_alive '@0123abcd' 2>&1); RC=$?
is "L9 ps fails" 2 ''
rec "$LONGP $NOW
"; chk "L10 long path" '@0123abcd' 0
rec "$LIVE $NOW beat
"; chk "L11 2.17.1 line" '@0123abcd' 0

# --- L12-L14: clutch_poll_alive <@tag> beat: 0 only when the live poller's
# line carries the third field beat, 4 for a live poller without it.
pab() { OUT=$(cd "$T/plain" && . "$T/scripts/prelude.sh" && clutch_poll_alive "$1" beat 2>&1); RC=$?; }
chkb() {
  B=$(snap); pab "$2"; is "$1" "$3" ''
  [ "$(snap)" = "$B" ] || { echo "FAIL: $1 -- the reader changed ~/.clutch"; fail=1; }
}
rec "$LIVE $NOW beat
"; chkb "L12 beat mode, beat line" '@0123abcd' 0
rec "$LIVE $NOW
"; chkb "L13 beat mode, 2.18.0 line" '@0123abcd' 4
rec "$LIVE $NOW other
"; chkb "L13 beat mode, another third field" '@0123abcd' 4
rec "$DEAD $NOW beat
"; chkb "L14 beat mode, dead pid" '@0123abcd' 3
rm -f "$PF"; chkb "L14 beat mode, no .poll" '@0123abcd' 1
if [ "$(id -u)" != 0 ]; then
  rec "$LIVE $NOW beat
"; chmod 000 "$PF"; chkb "L14 beat mode, unreadable .poll" '@0123abcd' 2; chmod 644 "$PF"
fi

# --- Y1-Y9: clutch_poll_young <@tag>: 0 when .poll names a poller that died
# young (well-formed line, start under one round ago by the CLUTCH_POLL_SLEEP
# clamp, .woke empty or absent or older than .poll), 1 otherwise. Every case
# checks the ~/.clutch tree is unchanged (Y9: it writes nothing).
WY="$HOME/.clutch/watch/0123abcd.woke"
mkdir -p "$T/ybin"
printf '#!/bin/sh\nexit 1\n' > "$T/ybin/date"; chmod 755 "$T/ybin/date"
# py <tag>: the helper, CLUTCH_POLL_SLEEP=$YSLEEP when set, date from $YPATH.
py() {
  OUT=$(cd "$T/plain" && if [ -n "${YSLEEP:-}" ]; then CLUTCH_POLL_SLEEP=$YSLEEP; export CLUTCH_POLL_SLEEP; fi &&
    PATH="${YPATH:-}$PATH" && . "$T/scripts/prelude.sh" && clutch_poll_young "$1" 2>&1); RC=$?
}
ychk() {
  B=$(snap); py "$2"; is "$1" "$3" ''
  [ "$(snap)" = "$B" ] || { echo "FAIL: $1 Y9 -- the helper changed ~/.clutch"; fail=1; }
}
YN=$(date +%s)
rec "$DEAD $YN
"; ychk "Y1 no .woke" '@0123abcd' 0
: > "$WY"; ychk "Y1 empty .woke" '@0123abcd' 0
printf 'gh:o/r#1 x\n' > "$WY"; touch -t 200001010000 "$WY"; ychk "Y2 .woke older" '@0123abcd' 0
rec "$DEAD $YN
"; printf 'gh:o/r#1 x\n' > "$WY"; touch -t 200001010000 "$PF"; ychk "Y3 .woke newer" '@0123abcd' 1
touch -t 200001010000 "$WY"; ychk "Y4 equal mtimes" '@0123abcd' 1
rec "$DEAD $((YN - 600))
"; ychk "Y5 600 s old, default round" '@0123abcd' 1
rec "$DEAD $((YN - 20))
"; YSLEEP=30; ychk "Y5 20 s old, round 30" '@0123abcd' 0
rec "$DEAD $((YN - 40))
"; ychk "Y5 40 s old, round 30" '@0123abcd' 1
rec "$DEAD $((YN - 300))
"; YSLEEP=abc; ychk "Y5 300 s old, round abc clamped to 600" '@0123abcd' 0
unset YSLEEP
rec "$DEAD $((YN + 1000))
"; ychk "Y5 future start" '@0123abcd' 1
for c in '' "$DEAD" "$DEAD $YN x y" "0 $YN" "$DEAD 1234567890123" 'abc 1' "$DEAD 0$YN"; do
  rec "$c
"; ychk "Y6 malformed [$c]" '@0123abcd' 1
done
rec "$DEAD $YN beat
"; ychk "Y7 third field" '@0123abcd' 0
rm -f "$PF"; ychk "Y8 no .poll" '@0123abcd' 1
rec "$DEAD $YN
"
for tg in '@a/b' '' '@0123abc'; do
  ychk "Y8 bad tag [$tg]" "$tg" 1
done
YPATH="$T/ybin:"; ychk "Y8 date fails" '@0123abcd' 1; unset YPATH
OUT=$(cd "$T/plain" && HOME='' && . "$T/scripts/prelude.sh" && clutch_poll_young '@0123abcd' 2>&1); RC=$?
is "Y8 empty HOME" 1 ''
if [ "$(id -u)" != 0 ]; then
  chmod 000 "$PF"; ychk "Y8 unreadable .poll" '@0123abcd' 1; chmod 644 "$PF"
fi

# --- M1-M25: scripts/poll.sh @<tag>
FIX=$T/fix
mkdir -p "$FIX" "$T/mbin"
W="$HOME/.clutch/worklog.md"
WF="$HOME/.clutch/watch/0123abcd.woke"
# Fake gh: logs each call, runs the hooks the test drops in $FIX, then
# applies the poller's own --jq filter to $FIX/<owner>_<repo>_<n>.json.
cat > "$T/mbin/gh" <<'EOF'
#!/bin/sh
F=$HOME/../fix
echo call >> "$F/log"
# hang: a gh that never answers, as its own pid (exec), for that many seconds.
[ -f "$F/hang" ] && { echo $$ > "$F/hangpid"; exec /bin/sleep "$(cat "$F/hang")"; }
[ -f "$F/pollcopy.on" ] && cp "$HOME/.clutch/watch/0123abcd.poll" "$F/pollcopy"
[ -f "$F/chmodwoke" ] && { rm -f "$F/chmodwoke"; chmod 400 "$HOME/.clutch/watch/0123abcd.woke"; }
[ -f "$F/wokewo" ] && { rm -f "$F/wokewo"; chmod 200 "$HOME/.clutch/watch/0123abcd.woke"; }
[ -f "$F/chmodwl" ] && { rm -f "$F/chmodwl"; chmod 000 "$HOME/.clutch/worklog.md"; }
[ -f "$F/repoll" ] && { rm -f "$F/repoll"; printf '1 1\n' > "$HOME/.clutch/watch/0123abcd.poll"; }
[ -f "$F/fail1" ] && { rm -f "$F/fail1"; echo 'HTTP 502' >&2; exit 1; }
# fseq: one line per call, 1 = fail this call, 0 = answer.
if [ -s "$F/fseq" ]; then
  s=$(head -n 1 "$F/fseq"); sed 1d "$F/fseq" > "$F/fseq.t"; mv "$F/fseq.t" "$F/fseq"
  [ "$s" = 1 ] && exit 1
fi
o='' r='' n='' q=''
while [ $# -gt 0 ]; do
  case $1 in
    --jq) q=$2; shift ;;
    -f | -F) case $2 in o=*) o=${2#o=} ;; r=*) r=${2#r=} ;; n=*) n=${2#n=} ;; esac; shift ;;
  esac
  shift
done
[ -f "$F/${o}_${r}_${n}.json" ] || exit 1
/usr/bin/jq -r "$q" "$F/${o}_${r}_${n}.json"
EOF
# Fake date: +%H pops the first line of $FIX/hseq when it holds one, else
# reads $FIX/hour (default 12, inside the window).
cat > "$T/mbin/date" <<'EOF'
#!/bin/sh
F=$HOME/../fix
if [ "$*" = '+%H' ]; then
  # hmode: chmod .woke to that mode on the first +%H call (after the start check).
  [ -f "$F/hmode" ] && { chmod "$(cat "$F/hmode")" "$HOME/.clutch/watch/0123abcd.woke"; rm -f "$F/hmode"; }
  if [ -s "$F/hseq" ]; then head -n 1 "$F/hseq"; sed 1d "$F/hseq" > "$F/hseq.t"; mv "$F/hseq.t" "$F/hseq"; exit 0; fi
  cat "$F/hour" 2>/dev/null || echo 12; exit 0
fi
[ "$*" = '+%s' ] && [ -f "$HOME/../fix/datefail" ] && exit 1
# skew: seconds added to +%s (the fake sleep sets it, to step the clock).
[ "$*" = '+%s' ] && [ -f "$F/skew" ] && { echo $(($(/bin/date +%s) + $(cat "$F/skew"))); exit 0; }
exec /bin/date "$@"
EOF
# Fake sleep: counts calls, keeps its last argument; call N restores the
# worklog when $FIX/sleepfix.N exists, the ops record when $FIX/sleepbf.N
# exists, and appends $FIX/sleepadd.N to the worklog; it waits while
# $FIX/sleephold exists; $FIX/skew.N becomes the fake date's clock skew.
cat > "$T/mbin/sleep" <<'EOF'
#!/bin/sh
F=$HOME/../fix
c=$(cat "$F/sleeps" 2>/dev/null || echo 0); c=$((c + 1)); echo "$c" > "$F/sleeps"; echo "$1" > "$F/sleeparg"
[ -f "$F/sleepfix.$c" ] && chmod 644 "$HOME/.clutch/worklog.md"
[ -f "$F/sleepbf.$c" ] && chmod 644 "$HOME/.clutch/watch/0123abcd.beat"
[ -f "$F/sleepadd.$c" ] && cat "$F/sleepadd.$c" >> "$HOME/.clutch/worklog.md"
[ -f "$F/skew.$c" ] && cp "$F/skew.$c" "$F/skew"
while [ -f "$F/sleephold" ]; do /bin/sleep 0.1; done
exit 0
EOF
chmod 755 "$T/mbin/gh" "$T/mbin/date" "$T/mbin/sleep"

iso() { date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }
B0=$(iso $((NOW - 1000)))
NEW=$(iso $((NOW - 500)))
OLD=$(iso $((NOW - 2000)))
ENDED='The silent check for @0123abcd ended; end the turn.'
STOP='The silent check for @0123abcd cannot write ~/.clutch/watch; it stopped.'
CLOSE='Run /clutch:watch @0123abcd for the moved waits.'
nl() { printf '%s\n' "$@"; }

# mseed: a fresh ~/.clutch with an empty worklog and no fixtures or hooks.
mseed() {
  chmod -R u+rwx "$HOME/.clutch" 2>/dev/null; rm -rf "$HOME/.clutch" "$FIX"
  mkdir -p "$HOME/.clutch" "$FIX" && : > "$W"
}
madd() { printf '%s %s\n' "$((NOW - $1))" "$2" >> "$W"; }
# fx <o_r_n> <state> <updatedAt> <comment nodes> <review nodes>: a GraphQL fixture.
fx() {
  printf '{"data":{"viewer":{"login":"me"},"repository":{"pullRequest":{"state":"%s","updatedAt":"%s","comments":{"nodes":[%s]},"reviews":{"nodes":[%s]}}}}}\n' \
    "$2" "$3" "$4" "$5" > "$FIX/$1.json"
}
cm() { printf '{"createdAt":"%s","author":{"__typename":"%s","login":"%s"}}' "$1" "$2" "$3"; }
rv() { printf '{"state":"%s","submittedAt":"%s","author":{"__typename":"%s","login":"%s"}}' "$1" "$2" "$3" "$4"; }
# pr <rounds> <tag>: run the poller; OUT, RC, ERR, NGH (gh calls). PBEAT
# sets CLUTCH_BEAT, PSCRIPT another staged poll.sh, PSH the shell (sh), PBIN
# the fake bin dir ($T/mbin).
pr() {
  : > "$FIX/log"
  OUT=$(cd "$T/plain" && PATH="${PBIN:-$T/mbin}:$PATH" CLUTCH_BEAT=${PBEAT:-} CLUTCH_POLL_SLEEP=${PSLEEP:-0} CLUTCH_POLL_ROUNDS=$1 "${PSH:-sh}" "${PSCRIPT:-$T/scripts/poll.sh}" "$2" 2>"$T/err")
  RC=$?
  ERR=$(cat "$T/err")
  NGH=$(grep -c '' "$FIX/log")
}
# ok <label> <rc> <stdout> <gh calls>: is, plus empty stderr and the gh count.
ok() {
  is "$1" "$2" "$3"
  [ -z "$ERR" ] || { echo "FAIL: $1 -- stderr [$ERR]"; fail=1; }
  [ "$NGH" = "$4" ] || { echo "FAIL: $1 -- gh called $NGH times, want $4"; fail=1; }
}
own1() { mseed; madd 100 "proj wait: gh:o/r#1 $B0 @0123abcd pr one"; }

own1; fx o_r_1 OPEN "$B0" '' ''
pr 3 @0123abcd; ok "M1 unchanged" 0 "$ENDED" 3
own1; fx o_r_1 MERGED "$NEW" '' ''
WB=$(cksum < "$W")
pr 3 @0123abcd; ok "M2 merged" 0 "$(nl 'gh:o/r#1 merged' "$CLOSE")" 1
[ "$(cat "$WF" 2>/dev/null)" = "gh:o/r#1 $NEW" ] || { echo "FAIL: M2 -- .woke [$(cat "$WF" 2>/dev/null)], want [gh:o/r#1 $NEW]"; fail=1; }
[ "$(cksum < "$W")" = "$WB" ] || { echo "FAIL: M2 PP5 -- the poller changed the worklog"; fail=1; }
# M12 (PP1): the same evidence never wakes twice.
pr 2 @0123abcd; ok "M12 wake mark" 0 "$ENDED" 2
own1; fx o_r_1 CLOSED "$NEW" '' ''
pr 1 @0123abcd; ok "M3 closed" 0 "$(nl 'gh:o/r#1 closed' "$CLOSE")" 1
own1; fx o_r_1 OPEN "$NEW" '' "$(rv APPROVED "$NEW" User al)"
pr 1 @0123abcd; ok "M4 review" 0 "$(nl 'gh:o/r#1 review APPROVED' "$CLOSE")" 1
own1; fx o_r_1 OPEN "$NEW" "$(cm "$NEW" User al)" ''
pr 1 @0123abcd; ok "M5 comment" 0 "$(nl 'gh:o/r#1 comment' "$CLOSE")" 1
own1; fx o_r_1 OPEN "$NEW" "{\"createdAt\":\"$NEW\",\"author\":null}" ''
pr 1 @0123abcd; ok "M5b ghost comment" 0 "$(nl 'gh:o/r#1 comment' "$CLOSE")" 1
own1; fx o_r_1 OPEN "$NEW" "$(cm "$NEW" User me)" "$(rv APPROVED "$NEW" User me)"
pr 1 @0123abcd; ok "M6 the viewer" 0 "$ENDED" 1
own1; fx o_r_1 OPEN "$NEW" "$(cm "$NEW" Bot qodo-merge)" "$(rv COMMENTED "$NEW" Bot copilot-pull-request-reviewer)"
pr 1 @0123abcd; ok "M7 a bot" 0 "$ENDED" 1
own1; fx o_r_1 OPEN "$NEW" '' "$(rv CHANGES_REQUESTED "$NEW" Bot copilot-pull-request-reviewer)"
pr 1 @0123abcd; ok "M8 bot changes requested" 0 "$(nl 'gh:o/r#1 review CHANGES_REQUESTED' "$CLOSE")" 1
own1; fx o_r_1 OPEN "$NEW" '' "$(rv CHANGES_REQUESTED "$NEW" User me)"
pr 1 @0123abcd; ok "M9 viewer changes requested" 0 "$ENDED" 1
# M10: older than or equal to the baseline never moves.
own1; fx o_r_1 MERGED "$B0" "$(cm "$B0" User al)" "$(rv APPROVED "$OLD" User al),$(rv CHANGES_REQUESTED "$B0" User al)"
pr 1 @0123abcd; ok "M10 not newer" 0 "$ENDED" 1
# M11: a non-ISO baseline falls back to the wait's epoch (NOW - 1000 = B0).
mseed; madd 1000 'proj wait: gh:o/r#1 b1 @0123abcd pr one'; fx o_r_1 OPEN "$NEW" "$(cm "$NEW" User al)" ''
pr 1 @0123abcd; ok "M11 epoch baseline" 0 "$(nl 'gh:o/r#1 comment' "$CLOSE")" 1
mseed; madd 1000 'proj wait: gh:o/r#1 b1 @0123abcd pr one'; fx o_r_1 OPEN "$OLD" "$(cm "$OLD" User al)" ''
pr 1 @0123abcd; ok "M11 epoch baseline, older" 0 "$ENDED" 1
# M11b: a baseline with hyphens in the time reads as ISO (OLD < B < NEW).
HB=$(printf '%s' "$B0" | sed 's/T\(..\):\(..\):/T\1-\2-/')
mseed; madd 3000 "proj wait: gh:o/r#1 $HB @0123abcd pr one"; fx o_r_1 OPEN "$OLD" "$(cm "$OLD" User al)" ''
pr 1 @0123abcd; ok "M11b hyphen-time baseline, older" 0 "$ENDED" 1
mseed; madd 3000 "proj wait: gh:o/r#1 $HB @0123abcd pr one"; fx o_r_1 OPEN "$NEW" "$(cm "$NEW" User al)" ''
pr 1 @0123abcd; ok "M11b hyphen-time baseline, newer" 0 "$(nl 'gh:o/r#1 comment' "$CLOSE")" 1
# M13: a failing gh skips the round; the next round wakes.
own1; fx o_r_1 MERGED "$NEW" '' ''; : > "$FIX/fail1"
pr 3 @0123abcd; ok "M13 gh fails once" 0 "$(nl 'gh:o/r#1 merged' "$CLOSE")" 2
own1; fx o_r_1 MERGED "$NEW" '' ''; echo 03 > "$FIX/hour"
pr 2 @0123abcd; ok "M14 outside the window" 0 "$ENDED" 0
for h in 07 22; do
  own1; fx o_r_1 MERGED "$NEW" '' ''; echo "$h" > "$FIX/hour"
  pr 2 @0123abcd; ok "M14 hour $h" 0 "$ENDED" 0
done
for h in 08 21; do
  own1; fx o_r_1 MERGED "$NEW" '' ''; echo "$h" > "$FIX/hour"
  pr 2 @0123abcd; ok "M14 hour $h" 0 "$(nl 'gh:o/r#1 merged' "$CLOSE")" 1
done
# M24: a gh failure that never clears wakes once as unreadable after 3
# failed rounds, marking .woke first; a restart does not wake it again, and
# the mark never holds back a later real move.
own1
pr 4 @0123abcd; ok "M24 gh always fails" 0 "$(nl 'gh:o/r#1 unreadable' "$CLOSE")" 3
grep -q '^unreadable gh:o/r#1 [0-9][0-9]*$' "$WF" 2>/dev/null || { echo "FAIL: M24 -- .woke [$(cat "$WF" 2>/dev/null)], want an unreadable mark"; fail=1; }
pr 4 @0123abcd; ok "M24 restart stays quiet" 0 "$ENDED" 4
fx o_r_1 MERGED "$NEW" '' ''
pr 1 @0123abcd; ok "M24 later move still wakes" 0 "$(nl 'gh:o/r#1 merged' "$CLOSE")" 1
# M24b: failures must be consecutive; an answer resets the count.
own1; fx o_r_1 OPEN "$B0" '' ''; nl 1 1 0 1 1 > "$FIX/fseq"
pr 5 @0123abcd; ok "M24b fails twice, answers, fails twice" 0 "$ENDED" 5
own1; fx o_r_1 MERGED "$NEW" '' ''; nl 1 1 > "$FIX/fseq"
pr 4 @0123abcd; ok "M24b fails twice then moves" 0 "$(nl 'gh:o/r#1 merged' "$CLOSE")" 3
# M24c: the count is per ref: o/r#2 answering never resets o/r#1's failures.
own1; madd 50 "proj wait: gh:o/r#2 $B0 @0123abcd pr two"; fx o_r_2 OPEN "$B0" '' ''
pr 4 @0123abcd; ok "M24c one ref fails, the other answers" 0 "$(nl 'gh:o/r#1 unreadable' "$CLOSE")" 6
# M24d: an unreadable mark holds back only its own wait line; a new wait line
# on the same ref (another epoch) wakes unreadable again.
own1; mkdir -p "$HOME/.clutch/watch"; printf 'unreadable gh:o/r#1 %s\n' "$((NOW - 5000))" > "$WF"
pr 4 @0123abcd; ok "M24d new wait line wakes unreadable again" 0 "$(nl 'gh:o/r#1 unreadable' "$CLOSE")" 3
grep -qx "unreadable gh:o/r#1 $((NOW - 100))" "$WF" || { echo "FAIL: M24d -- no mark for the new wait line: [$(cat "$WF")]"; fail=1; }
# M24e: a round outside the window neither counts a failure nor resets the
# count: hours 12 12 03 12 wake unreadable in round 4 after 3 gh calls.
own1; nl 12 12 03 12 > "$FIX/hseq"
pr 4 @0123abcd; ok "M24e outside-window round neither counts nor resets" 0 "$(nl 'gh:o/r#1 unreadable' "$CLOSE")" 3
own1; fx o_r_1 OPEN "$B0" '' ''; : > "$FIX/repoll"
pr 3 @0123abcd; ok "M15 superseded" 0 "$ENDED" 1
own1; fx o_r_1 MERGED "$NEW" '' ''; : > "$FIX/log"
OUT=$(cd "$T/plain" && PATH="$T/mbin:$PATH" CLUTCH_WATCH=off CLUTCH_POLL_SLEEP=0 CLUTCH_POLL_ROUNDS=2 sh "$T/scripts/poll.sh" @0123abcd 2>"$T/err"); RC=$?
ERR=$(cat "$T/err"); NGH=$(grep -c '' "$FIX/log" 2>/dev/null)
ok "M16 CLUTCH_WATCH=off" 0 "$ENDED" 0
[ ! -e "$HOME/.clutch/watch/0123abcd.poll" ] || { echo "FAIL: M16 -- .poll written"; fail=1; }
mseed; madd 100 'proj wait: slack:C1/123 b1 @0123abcd thread'; fx o_r_1 MERGED "$NEW" '' ''
pr 3 @0123abcd; ok "M17 only non-gh waits" 0 "$ENDED" 0
mseed; madd 300 "proj wait: gh:bad#x $B0 @0123abcd a"; madd 200 "proj wait: gh:o/r# $B0 @0123abcd b"
madd 100 "proj wait: gh:o/r#1, $B0 @0123abcd c"; fx o_r_1 MERGED "$NEW" '' ''
pr 1 @0123abcd; ok "M18 refs" 0 "$(nl 'gh:o/r#1 merged' "$CLOSE")" 1
own1
for tg in '@a/b' '' '@' '0123abcd' '@0123abcd '; do
  pr 1 "$tg"
  [ "$RC" = 2 ] && [ -z "$OUT" ] && [ "$ERR" = 'poll.sh: bad tag' ] && [ "$NGH" = 0 ] \
    || { echo "FAIL: M19 bad tag [$tg] -- rc $RC stdout [$OUT] stderr [$ERR] gh $NGH"; fail=1; }
done
own1; fx o_r_1 MERGED "$NEW" '' ''; : > "$FIX/chmodwl"; : > "$FIX/fail1"; : > "$FIX/sleepfix.2"
if [ "$(id -u)" = 0 ]; then
  echo "SKIP: M21, M20, M20b, M12b modes (root reads through chmod)"
else
  # M21: an unreadable worklog (rc 2) retries; it does not end the check.
  pr 3 @0123abcd; ok "M21 worklog unreadable" 0 "$(nl 'gh:o/r#1 merged' "$CLOSE")" 2
  own1; fx o_r_1 MERGED "$NEW" '' ''; mkdir -p "$HOME/.clutch/watch"; chmod 555 "$HOME/.clutch/watch"
  pr 1 @0123abcd; chmod 755 "$HOME/.clutch/watch"; ok "M20 watch dir not writable" 0 "$STOP" 0
  own1; fx o_r_1 MERGED "$NEW" '' ''; mkdir -p "$HOME/.clutch/watch"; : > "$WF"; chmod 555 "$HOME/.clutch/watch"
  pr 1 @0123abcd; chmod 755 "$HOME/.clutch/watch"; ok "M20 watch dir not writable, .woke there" 0 "$STOP" 0
  [ ! -e "$HOME/.clutch/watch/0123abcd.poll" ] || { echo "FAIL: M20 -- .poll written"; fail=1; }
  for m in 000 200; do
    own1; fx o_r_1 MERGED "$NEW" '' ''; mkdir -p "$HOME/.clutch/watch"; : > "$WF"; chmod "$m" "$WF"
    pr 1 @0123abcd; chmod 644 "$WF"; ok "M20b .woke mode $m" 0 "$STOP" 0
    [ ! -e "$HOME/.clutch/watch/0123abcd.poll" ] || { echo "FAIL: M20b $m -- .poll written"; fail=1; }
  done
  # M12b: the mark append fails mid-run: the stopped line only, .poll left.
  # Mode 400 (readable, not writable): the marks read, the append fails.
  own1; fx o_r_1 MERGED "$NEW" '' ''; : > "$FIX/chmodwoke"
  pr 1 @0123abcd; ok "M12b mark append fails" 0 "$STOP" 1
  [ -s "$HOME/.clutch/watch/0123abcd.poll" ] || { echo "FAIL: M12b -- .poll gone"; fail=1; }
  # M12c: M12's second run with .woke made unreadable (mode 200) on the first
  # gh call: round 2 skips the wait, never reading it as "no marks".
  own1; fx o_r_1 MERGED "$NEW" '' ''
  pr 1 @0123abcd; ok "M12c first run wakes" 0 "$(nl 'gh:o/r#1 merged' "$CLOSE")" 1
  WK=$(cat "$WF"); : > "$FIX/wokewo"
  pr 2 @0123abcd; chmod 644 "$WF"; ok "M12c .woke unreadable mid-run" 0 "$ENDED" 1
  [ "$(cat "$WF")" = "$WK" ] || { echo "FAIL: M12c -- .woke changed"; fail=1; }
fi
chmod -R u+rwx "$HOME/.clutch" 2>/dev/null; rm -rf "$HOME/.clutch"; rm -rf "$FIX"; mkdir -p "$FIX"
pr 1 @0123abcd; ok "M20c no ~/.clutch" 0 "$STOP" 0
[ ! -e "$HOME/.clutch" ] || { echo "FAIL: M20c -- ~/.clutch created"; fail=1; }
# M20d: M20, M20b and M20c under dash, where a failed redirect on a special
# builtin ends the shell: still the stopped line, never silence.
if ! command -v dash >/dev/null 2>&1; then
  echo "SKIP: M20d (no dash)"
else
  PSH=dash
  if [ "$(id -u)" != 0 ]; then
    own1; fx o_r_1 MERGED "$NEW" '' ''; mkdir -p "$HOME/.clutch/watch"; chmod 555 "$HOME/.clutch/watch"
    pr 1 @0123abcd; chmod 755 "$HOME/.clutch/watch"; ok "M20d dash, watch dir not writable" 0 "$STOP" 0
    for m in 000 200; do
      own1; fx o_r_1 MERGED "$NEW" '' ''; mkdir -p "$HOME/.clutch/watch"; : > "$WF"; chmod "$m" "$WF"
      pr 1 @0123abcd; chmod 644 "$WF"; ok "M20d dash, .woke mode $m" 0 "$STOP" 0
    done
  fi
  chmod -R u+rwx "$HOME/.clutch" 2>/dev/null; rm -rf "$HOME/.clutch" "$FIX"; mkdir -p "$FIX"
  pr 1 @0123abcd; ok "M20d dash, no ~/.clutch" 0 "$STOP" 0
  unset PSH
fi
own1; madd 50 "proj wait: gh:o/r#2 $B0 @0123abcd pr two"; madd 40 "proj wait: gh:o/r#3 $B0 @0123abcd pr three"
fx o_r_1 MERGED "$NEW" '' ''; fx o_r_2 OPEN "$NEW" "$(cm "$NEW" User al)" ''; fx o_r_3 OPEN "$B0" '' ''
pr 1 @0123abcd; ok "M22 two moved" 0 "$(nl 'gh:o/r#1 merged' 'gh:o/r#2 comment' "$CLOSE")" 3
# M22b: a newer mark for o/r#1 and a beat line never hold back o/r#2.
own1; madd 50 "proj wait: gh:o/r#2 $B0 @0123abcd pr two"; mkdir -p "$HOME/.clutch/watch"
nl "gh:o/r#1 $(iso $((NOW - 100)))" "beat $((NOW - 100))" > "$WF"
fx o_r_1 OPEN "$B0" '' ''; fx o_r_2 OPEN "$NEW" "$(cm "$NEW" User al)" ''
pr 1 @0123abcd; ok "M22b marks match their ref" 0 "$(nl 'gh:o/r#2 comment' "$CLOSE")" 2
# M25: a failed date +%s ends the check; it does not blame ~/.clutch/watch.
own1; fx o_r_1 MERGED "$NEW" '' ''; : > "$FIX/datefail"
pr 1 @0123abcd; ok "M25 date fails" 0 "$ENDED" 0
# M26: CLUTCH_POLL_SLEEP that is not 1-5 digits >= 1 sleeps 600 s, as
# stop.sh reads a round; a valid one is kept.
for nap in 0 00 abc 999999 100000 30 99999; do
  own1; fx o_r_1 OPEN "$B0" '' ''; rm -f "$FIX/sleeparg"
  PSLEEP=$nap; pr 2 @0123abcd; unset PSLEEP
  want=600; case $nap in 30 | 99999) want=$nap ;; esac
  [ "$(cat "$FIX/sleeparg" 2>/dev/null)" = "$want" ] || { echo "FAIL: M26 [$nap] -- slept [$(cat "$FIX/sleeparg" 2>/dev/null)], want $want"; fail=1; }
done
# M27: a gh that never answers is killed after the watchdog (60 s; 1 s in a
# staged copy), its own pid only, and counts as one gh failure: 3 in a row
# wake unreadable.
mkdir -p "$T/sgh"; cp "$T/scripts/prelude.sh" "$T/sgh/prelude.sh"
sed 's|"$n" -lt 60 ]|"$n" -lt 1 ]|' "$T/scripts/poll.sh" > "$T/sgh/poll.sh"
[ "$(grep -c '"$n" -lt 1 ]' "$T/sgh/poll.sh")" = 1 ] || { echo "FAIL: M27 -- the staged copy has no 1 s watchdog"; fail=1; }
own1; fx o_r_1 MERGED "$NEW" '' ''; echo 5 > "$FIX/hang"
M27S=$(date +%s)
PSCRIPT="$T/sgh/poll.sh"; pr 4 @0123abcd; unset PSCRIPT
M27E=$(($(date +%s) - M27S))
rm -f "$FIX/hang"
ok "M27 hung gh times out" 0 "$(nl 'gh:o/r#1 unreadable' "$CLOSE")" 3
[ "$M27E" -lt 12 ] || { echo "FAIL: M27 -- took ${M27E}s, want the 1 s watchdog per call"; fail=1; }
! kill -0 "$(cat "$FIX/hangpid" 2>/dev/null)" 2>/dev/null || { echo "FAIL: M27 -- the hung gh is still running"; fail=1; }
# M27b: no gh on PATH (rc 127 at once, the race window widest) returns at
# once on every call, under sh and dash: the watchdog's kill never waits out
# its sleep, and no watchdog sleep outlives its call by more than 1 s. The
# staged copy marks the watchdog's sleep (.00427), counted by that marker and
# never killed.
mkdir -p "$T/sgq" "$T/nogh"; cp "$T/scripts/prelude.sh" "$T/sgq/prelude.sh"
cp "$T/mbin/date" "$T/mbin/sleep" "$T/nogh/"
sed 's|/bin/sleep \([0-9][0-9]*\)\([ ;]\)|/bin/sleep \1.00427\2|' "$T/scripts/poll.sh" > "$T/sgq/poll.sh"
[ "$(grep -c '/bin/sleep [0-9]*\.00427' "$T/sgq/poll.sh")" = 1 ] || { echo "FAIL: M27b -- the staged copy has no marked watchdog sleep"; fail=1; }
M27P=$PATH
for sh27 in /bin/sh /bin/dash; do
  [ -x "$sh27" ] || { echo "SKIP: M27b $sh27 (not installed)"; continue; }
  M27S=$(date +%s)
  i=0
  while [ "$i" -lt 10 ]; do
    own1
    PATH=/usr/bin:/bin:/usr/sbin:/sbin PSH=$sh27 PSCRIPT="$T/sgq/poll.sh" PBIN="$T/nogh"
    pr 3 @0123abcd
    PATH=$M27P; unset PSH PSCRIPT PBIN
    ok "M27b $sh27 no gh [$i]" 0 "$(nl 'gh:o/r#1 unreadable' "$CLOSE")" 0
    i=$((i + 1))
  done
  M27E=$(($(date +%s) - M27S))
  [ "$M27E" -lt 20 ] || { echo "FAIL: M27b $sh27 -- 30 gh calls with no gh took ${M27E}s"; fail=1; }
done
/bin/sleep 2
M27L=$(ps -A -o args= | grep -c '^/bin/sleep [0-9]*\.00427$')
[ "$M27L" = 0 ] || { echo "FAIL: M27b -- $M27L watchdog sleeps outlived their call by 2 s"; fail=1; }
# M23: .poll is one line "<pid> <epoch> beat", pid the poller's own (the
# suite unsets CLUTCH_BEAT, so the beat check is on; Bt12 owns the content).
own1; fx o_r_1 OPEN "$B0" '' ''; : > "$FIX/pollcopy.on"
(cd "$T/plain" && PATH="$T/mbin:$PATH" CLUTCH_POLL_SLEEP=0 CLUTCH_POLL_ROUNDS=1 exec sh "$T/scripts/poll.sh" @0123abcd >/dev/null 2>&1) &
MP=$!
wait "$MP"
PC=$(cat "$FIX/pollcopy" 2>/dev/null)
case $PC in
  "$MP "[0-9]*" beat") E=${PC#"$MP "}; E=${E% beat}; case $E in *[!0-9]*) echo "FAIL: M23 -- .poll [$PC]"; fail=1 ;; esac
    [ "$E" -ge "$NOW" ] || { echo "FAIL: M23 -- epoch $E before the run"; fail=1; } ;;
  *) echo "FAIL: M23 -- .poll [$PC], want [$MP <epoch> beat]"; fail=1 ;;
esac
[ "$(grep -c '' "$FIX/pollcopy" 2>/dev/null)" = 1 ] || { echo "FAIL: M23 -- .poll is not one line"; fail=1; }

# --- Bt1-Bt16: the poller beats while the tag's ops record is there: from
# 08:00 to 20:59 it peeks the beat window (clutch_beat_window peek) and wakes
# with "Run /clutch:beat @<tag>." on peer moves, at most once an hour (the
# newer of the record's newest last and the newest .woke beat mark), after
# appending "beat <now - 120>" to .woke.
BFR="$HOME/.clutch/watch/0123abcd.beat"
BEATL='Run /clutch:beat @0123abcd.'
opsrec() { mkdir -p "$HOME/.clutch/watch"; printf '%s\n' "$@" > "$BFR"; }
peer() { madd "$1" 'proj moved: gh:o/r#7 @ffffffff peer'; }
own() { madd "$1" 'proj moved: gh:o/r#8 @0123abcd own'; }
slack1() { madd 100 'proj wait: slack:C1/123 b1 @0123abcd thread'; }
beats() { grep -c '^beat [0-9][0-9]*$' "$WF" 2>/dev/null; }
sleeps() { cat "$FIX/sleeps" 2>/dev/null || echo 0; }

mseed; opsrec "last $((NOW - 7200))"; peer 600
pr 3 @0123abcd; ok "Bt1 beat-only wake" 0 "$BEATL" 0
[ "$(beats)" = 1 ] || { echo "FAIL: Bt1 -- .woke [$(cat "$WF" 2>/dev/null)], want one beat mark"; fail=1; }
BM=$(sed -n 's/^beat \([0-9][0-9]*\)$/\1/p' "$WF" 2>/dev/null)
[ "${BM:-0}" -ge $((NOW - 120)) ] || { echo "FAIL: Bt1 -- beat mark [$BM] is not now - 120"; fail=1; }
# Bt13: a restart (no last appended) in the same hour does not wake the beat again.
pr 3 @0123abcd; ok "Bt13 restart, mark under an hour old" 0 "$ENDED" 0
[ "$(beats)" = 1 ] || { echo "FAIL: Bt13 -- .woke [$(cat "$WF")], want one beat mark"; fail=1; }
mseed; opsrec "last $((NOW - 7200))"; peer 600; mkdir -p "$HOME/.clutch/watch"; printf 'beat %s\n' "$((NOW - 7200))" > "$WF"
pr 3 @0123abcd; ok "Bt13b beat mark 2 h old" 0 "$BEATL" 0
mseed; opsrec "last $((NOW - 1200))"; peer 600
pr 2 @0123abcd; ok "Bt2 last 20 min ago" 0 "$ENDED" 0
mseed; opsrec "last $((NOW - 7200))"
pr 2 @0123abcd; ok "Bt3 no peer move" 0 "$ENDED" 0
mseed; opsrec 'asked 2000-01-01'; peer 600
pr 2 @0123abcd; ok "Bt4 no last: seeded, no wake" 0 "$ENDED" 0
[ "$(grep -c '^last [0-9][0-9]*$' "$BFR")" = 1 ] || { echo "FAIL: Bt4 -- record [$(cat "$BFR")], want one last line"; fail=1; }
# Bt4b: the seed fails in round 1 (no worklog, rc 1) and retries: round 2
# seeds (no wake in its seeding round), round 3, an hour later by the clock,
# wakes once on the peer move logged after the seed.
mseed; rm -f "$W"; opsrec 'asked 2000-01-01'
printf '%s proj moved: gh:o/r#7 @ffffffff peer\n' "$((NOW + 3600))" > "$FIX/sleepadd.1"; echo 7200 > "$FIX/skew.2"
pr 3 @0123abcd; ok "Bt4b failed seed retried, then a wake" 0 "$BEATL" 0
[ "$(grep -c '^last [0-9][0-9]*$' "$BFR")" = 1 ] || { echo "FAIL: Bt4b -- record [$(cat "$BFR")], want one last line"; fail=1; }
[ "$(sleeps)" = 2 ] || { echo "FAIL: Bt4b -- slept $(sleeps) times, want 2 (woke in round 3)"; fail=1; }
own1; fx o_r_1 OPEN "$B0" '' ''; opsrec "last $((NOW - 7200))"; peer 600; RB=$(cat "$BFR"); : > "$FIX/pollcopy.on"
PBEAT=off; pr 2 @0123abcd; unset PBEAT; ok "Bt5 CLUTCH_BEAT=off" 0 "$ENDED" 2
[ "$(cat "$BFR")" = "$RB" ] || { echo "FAIL: Bt5 -- record changed: $(cat "$BFR")"; fail=1; }
case $(cat "$FIX/pollcopy" 2>/dev/null) in
  *[!0-9\ ]* | *' '*' '* | '') echo "FAIL: Bt5 -- .poll [$(cat "$FIX/pollcopy" 2>/dev/null)], want the two-field line"; fail=1 ;;
esac
own1; fx o_r_1 OPEN "$B0" '' ''; opsrec 'asked 2000-01-01'
PBEAT=off; pr 1 @0123abcd; unset PBEAT; ok "Bt5 CLUTCH_BEAT=off, no last" 0 "$ENDED" 1
[ "$(cat "$BFR")" = 'asked 2000-01-01' ] || { echo "FAIL: Bt5 -- record seeded under off: $(cat "$BFR")"; fail=1; }
mseed; slack1; opsrec "last $((NOW - 7200))"; peer 600
PBEAT=off; pr 3 @0123abcd; unset PBEAT; ok "Bt5b CLUTCH_BEAT=off, no gh waits" 0 "$ENDED" 0
[ "$(sleeps)" = 0 ] || { echo "FAIL: Bt5b -- ran $(sleeps) more rounds, want the ended line in round 1"; fail=1; }
mseed; slack1; peer 600
pr 3 @0123abcd; ok "Bt6 no record, no gh waits" 0 "$ENDED" 0
[ "$(sleeps)" = 0 ] || { echo "FAIL: Bt6 -- ran $(sleeps) more rounds, want the ended line in round 1"; fail=1; }
# Bt6b: clutch_ops_record cannot tell (rc 2): a staged prelude whose helper says so.
mkdir -p "$T/s6b"; cp "$T/scripts/poll.sh" "$T/s6b/poll.sh"
{ cat "$T/scripts/prelude.sh"; echo 'clutch_ops_record() { return 2; }'; } > "$T/s6b/prelude.sh"
mseed; slack1
PSCRIPT="$T/s6b/poll.sh"; pr 3 @0123abcd; unset PSCRIPT; ok "Bt6b record cannot tell" 0 "$ENDED" 0
[ "$(sleeps)" = 2 ] || { echo "FAIL: Bt6b -- slept $(sleeps) times, want 2 (ran to the cap)"; fail=1; }
own1; fx o_r_1 OPEN "$B0" '' ''; opsrec "last $((NOW - 7200))"; peer 600; echo 21 > "$FIX/hour"
pr 2 @0123abcd; ok "Bt7 hour 21: gh check, no beat" 0 "$ENDED" 2
for h in 07 20; do
  mseed; opsrec "last $((NOW - 7200))"; peer 600; echo "$h" > "$FIX/hour"
  want=$ENDED; [ "$h" != 20 ] || want=$BEATL
  pr 1 @0123abcd; ok "Bt7 hour $h" 0 "$want" 0
done
own1; fx o_r_1 MERGED "$NEW" '' ''; opsrec "last $((NOW - 7200))"; peer 600
pr 1 @0123abcd; ok "Bt8 gh move and beat move" 0 "$(nl 'gh:o/r#1 merged' "$CLOSE" "$BEATL")" 1
own1; opsrec "last $((NOW - 7200))"; printf '%s proj moved: gh:o/r#7 @ffffffff late peer\n' "$((NOW - 300))" > "$FIX/sleepadd.2"
pr 4 @0123abcd; ok "Bt8b unreadable and beat" 0 "$(nl 'gh:o/r#1 unreadable' "$CLOSE" "$BEATL")" 3
{ grep -q '^unreadable gh:o/r#1 [0-9][0-9]*$' "$WF" && [ "$(beats)" = 1 ]; } || { echo "FAIL: Bt8b -- .woke [$(cat "$WF")], want the unreadable and beat marks"; fail=1; }
mseed; slack1; opsrec "last $((NOW - 7200))"; own 600
pr 2 @0123abcd; ok "Bt9 only own-tag moves" 0 "$ENDED" 0
mseed; slack1; opsrec "last $((NOW - 7200))"
pr 3 @0123abcd; ok "Bt10 only a slack wait, record there" 0 "$ENDED" 0
[ "$(sleeps)" = 2 ] || { echo "FAIL: Bt10 -- slept $(sleeps) times, want 2 (ran to the cap)"; fail=1; }
mseed; rm -f "$W"; opsrec "last $((NOW - 7200))"
pr 3 @0123abcd; ok "Bt10b no worklog, record there" 0 "$ENDED" 0
[ "$(sleeps)" = 2 ] || { echo "FAIL: Bt10b -- slept $(sleeps) times, want 2 (ran to the cap)"; fail=1; }
# Bt12: a running poller's .poll is "<pid> <epoch> beat"; A1's reader (no beat) reads it alive.
mseed; slack1; opsrec "last $((NOW - 7200))"; : > "$FIX/sleephold"
(cd "$T/plain" && PATH="$T/mbin:$PATH" CLUTCH_POLL_SLEEP=0 CLUTCH_POLL_ROUNDS=2 exec sh "$T/scripts/poll.sh" @0123abcd >/dev/null 2>&1) &
MP=$!
PIDS="$PIDS $MP"
i=0; while [ ! -f "$FIX/sleeps" ] && [ "$i" -lt 100 ]; do /bin/sleep 0.1; i=$((i + 1)); done
case $(cat "$PF" 2>/dev/null) in
  "$MP "[1-9]*" beat") ;;
  *) echo "FAIL: Bt12 -- .poll [$(cat "$PF" 2>/dev/null)], want [$MP <epoch> beat]"; fail=1 ;;
esac
pa '@0123abcd'; is "Bt12 A1 reader" 0 ''
pab '@0123abcd'; is "Bt12 beat reader" 0 ''
rm -f "$FIX/sleephold"; wait "$MP"
# Bt14: beat marks in .woke change neither 2.18.0 reader (M2, M12, M24).
own1; fx o_r_1 MERGED "$NEW" '' ''; mkdir -p "$HOME/.clutch/watch"; printf 'beat %s\n' "$((NOW - 100))" > "$WF"
pr 3 @0123abcd; ok "Bt14 M2" 0 "$(nl 'gh:o/r#1 merged' "$CLOSE")" 1
pr 2 @0123abcd; ok "Bt14 M12" 0 "$ENDED" 2
own1; mkdir -p "$HOME/.clutch/watch"; printf 'beat %s\n' "$((NOW - 100))" > "$WF"
pr 4 @0123abcd; ok "Bt14 M24" 0 "$(nl 'gh:o/r#1 unreadable' "$CLOSE")" 3
pr 4 @0123abcd; ok "Bt14 M24 restart" 0 "$ENDED" 4
# Bt17: a last line or beat mark newer than now (the clock stepped back) is
# left out of the cap: the peer move since the newest last still wakes.
mseed; opsrec "last $((NOW + 7200))" "last $((NOW - 7200))"; peer 600
pr 1 @0123abcd; ok "Bt17 future last" 0 "$BEATL" 0
mseed; opsrec "last $((NOW - 7200))"; peer 600; mkdir -p "$HOME/.clutch/watch"; printf 'beat %s\n' "$((NOW + 7200))" > "$WF"
pr 1 @0123abcd; ok "Bt17 future beat mark" 0 "$BEATL" 0
if [ "$(id -u)" = 0 ]; then
  echo "SKIP: Bt11, Bt15, Bt16 modes (root reads through chmod)"
else
  mseed; opsrec "last $((NOW - 7200))"; peer 600; chmod 222 "$BFR"; : > "$FIX/sleepbf.1"
  pr 3 @0123abcd; ok "Bt11 peek rc 2, retried" 0 "$BEATL" 0
  [ "$(sleeps)" = 1 ] || { echo "FAIL: Bt11 -- slept $(sleeps) times, want 1 (woke in round 2)"; fail=1; }
  mseed; opsrec "last $((NOW - 7200))"; peer 600; echo 400 > "$FIX/hmode"
  pr 1 @0123abcd; chmod 644 "$WF"; ok "Bt15 beat mark append fails" 0 "$STOP" 0
  mseed; opsrec "last $((NOW - 7200))"; peer 600; echo 200 > "$FIX/hmode"
  pr 2 @0123abcd; chmod 644 "$WF"; ok "Bt16 .woke unreadable" 0 "$ENDED" 0
fi

[ "$fail" -eq 0 ] && echo PASS
exit "$fail"
