#!/bin/sh
# Silent check. L1-L11 cover clutch_poll_alive <@tag> (record
# ~/.clutch/watch/<tag8>.poll, one line "<pid> <start epoch>" with an optional
# third field): 0 alive (kill -0 passes and ps -ww names poll.sh @<tag8> at
# the end), 1 no record (proven absent), 2 cannot tell, 3 ended (dead or
# reused pid, another tag's poller, malformed line). It never writes.
# prelude.sh is staged into a scratch tree and run under a scratch HOME.
# PRELUDE_SH overrides the target for replay. Silent on pass apart from PASS.
set -u
unset CLUTCH_POLL CLUTCH_POLL_SLEEP CLUTCH_POLL_ROUNDS CLUTCH_WATCH CLUTCH_BEAT CLAUDE_PLUGIN_ROOT

HERE=$(cd "$(dirname "$0")" && pwd)
P=${PRELUDE_SH:-$HERE/../scripts/prelude.sh}
[ -f "$P" ] || { echo "FAIL: missing $P"; exit 1; }

T=$(mktemp -d) || exit 1
PIDS=""
trap 'for p in $PIDS; do kill "$p" 2>/dev/null; done; chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
HOME=$T/home
export HOME
mkdir -p "$HOME" "$T/scripts" "$T/plain" "$T/stub" "$T/fakebin"
cp "$P" "$T/scripts/prelude.sh"
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

[ "$fail" -eq 0 ] && echo PASS
exit "$fail"
