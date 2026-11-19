#!/bin/sh
# Silent check. L1-L11 cover clutch_poll_alive <@tag> (record
# ~/.clutch/watch/<tag8>.poll, one line "<pid> <start epoch>" with an optional
# third field): 0 alive (kill -0 passes and ps -ww names poll.sh @<tag8> at
# the end), 1 no record (proven absent), 2 cannot tell, 3 ended (dead or
# reused pid, another tag's poller, malformed line). It never writes.
# M1-M23 with M5b, M12b, M12c, M20b and M20c run scripts/poll.sh @<tag> (the
# silent check) against a fake gh that applies the real --jq filter to a
# per-PR GraphQL fixture through /usr/bin/jq, a fake date for +%H and a fake
# sleep: quiet rounds print nothing, a move prints "<ref> <what>" lines and
# the closing line after appending <ref> <stamp> to .woke, every other exit
# prints the ended line, and a failed write prints the stopped line.
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

# --- M1-M23: scripts/poll.sh @<tag>
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
[ -f "$F/pollcopy.on" ] && cp "$HOME/.clutch/watch/0123abcd.poll" "$F/pollcopy"
[ -f "$F/chmodwoke" ] && { rm -f "$F/chmodwoke"; chmod 400 "$HOME/.clutch/watch/0123abcd.woke"; }
[ -f "$F/wokewo" ] && { rm -f "$F/wokewo"; chmod 200 "$HOME/.clutch/watch/0123abcd.woke"; }
[ -f "$F/chmodwl" ] && { rm -f "$F/chmodwl"; chmod 000 "$HOME/.clutch/worklog.md"; }
[ -f "$F/repoll" ] && { rm -f "$F/repoll"; printf '1 1\n' > "$HOME/.clutch/watch/0123abcd.poll"; }
[ -f "$F/fail1" ] && { rm -f "$F/fail1"; echo 'HTTP 502' >&2; exit 1; }
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
# Fake date: +%H reads $FIX/hour (default 12, inside the window).
cat > "$T/mbin/date" <<'EOF'
#!/bin/sh
if [ "$*" = '+%H' ]; then cat "$HOME/../fix/hour" 2>/dev/null || echo 12; exit 0; fi
exec /bin/date "$@"
EOF
# Fake sleep: counts calls; call N restores the worklog when $FIX/sleepfix.N exists.
cat > "$T/mbin/sleep" <<'EOF'
#!/bin/sh
F=$HOME/../fix
c=$(cat "$F/sleeps" 2>/dev/null || echo 0); c=$((c + 1)); echo "$c" > "$F/sleeps"
[ -f "$F/sleepfix.$c" ] && chmod 644 "$HOME/.clutch/worklog.md"
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
# pr <rounds> <tag>: run the poller; OUT, RC, ERR, NGH (gh calls).
pr() {
  : > "$FIX/log"
  OUT=$(cd "$T/plain" && PATH="$T/mbin:$PATH" CLUTCH_POLL_SLEEP=0 CLUTCH_POLL_ROUNDS=$1 sh "$T/scripts/poll.sh" "$2" 2>"$T/err")
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
# M13: a failing gh skips the round; the next round wakes.
own1; fx o_r_1 MERGED "$NEW" '' ''; : > "$FIX/fail1"
pr 3 @0123abcd; ok "M13 gh fails once" 0 "$(nl 'gh:o/r#1 merged' "$CLOSE")" 2
own1; fx o_r_1 MERGED "$NEW" '' ''; echo 03 > "$FIX/hour"
pr 2 @0123abcd; ok "M14 outside the window" 0 "$ENDED" 0
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
own1; madd 50 "proj wait: gh:o/r#2 $B0 @0123abcd pr two"; madd 40 "proj wait: gh:o/r#3 $B0 @0123abcd pr three"
fx o_r_1 MERGED "$NEW" '' ''; fx o_r_2 OPEN "$NEW" "$(cm "$NEW" User al)" ''; fx o_r_3 OPEN "$B0" '' ''
pr 1 @0123abcd; ok "M22 two moved" 0 "$(nl 'gh:o/r#1 merged' 'gh:o/r#2 comment' "$CLOSE")" 3
# M23: .poll is one line "<pid> <epoch>", pid the poller's own.
own1; fx o_r_1 OPEN "$B0" '' ''; : > "$FIX/pollcopy.on"
(cd "$T/plain" && PATH="$T/mbin:$PATH" CLUTCH_POLL_SLEEP=0 CLUTCH_POLL_ROUNDS=1 exec sh "$T/scripts/poll.sh" @0123abcd >/dev/null 2>&1) &
MP=$!
wait "$MP"
PC=$(cat "$FIX/pollcopy" 2>/dev/null)
case $PC in
  "$MP "[0-9]*) E=${PC#"$MP "}; case $E in *[!0-9]*) echo "FAIL: M23 -- .poll [$PC]"; fail=1 ;; esac
    [ "$E" -ge "$NOW" ] || { echo "FAIL: M23 -- epoch $E before the run"; fail=1; } ;;
  *) echo "FAIL: M23 -- .poll [$PC], want [$MP <epoch>]"; fail=1 ;;
esac
[ "$(grep -c '' "$FIX/pollcopy" 2>/dev/null)" = 1 ] || { echo "FAIL: M23 -- .poll is not one line"; fail=1; }

[ "$fail" -eq 0 ] && echo PASS
exit "$fail"
