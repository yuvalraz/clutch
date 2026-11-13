#!/bin/sh
# Armed watch: the session tag and the owned wait loops. T1-T5 and T4b cover
# clutch_session_tag (the first "session_id" key of the hook input JSON, cut
# to 8 chars of [0-9A-Za-z-], rc 1 with no stdout otherwise). O1-O5 cover
# clutch_owned_loops (the open wait lines whose field 6 equals the tag; rc 1
# with no worklog, rc 2 on an unreadable worklog, a worklog path that cannot
# be stat'ed, an empty HOME or a malformed tag; a wait re-held after a moved:
# line on the same ref is open again).
# prelude.sh is staged into a scratch tree and sourced from a non-git dir
# under a scratch HOME. PRELUDE_SH overrides the target for replay against a
# historical version. Silent on pass apart from PASS.
set -u
unset CLUTCH_WATCH CLAUDE_PLUGIN_ROOT

HERE=$(cd "$(dirname "$0")" && pwd)
P=${PRELUDE_SH:-$HERE/../scripts/prelude.sh}
[ -f "$P" ] || { echo "FAIL: missing $P"; exit 1; }

T=$(mktemp -d) || exit 1
trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
HOME=$T/home
export HOME
mkdir -p "$HOME" "$T/scripts" "$T/plain"
cp "$P" "$T/scripts/prelude.sh"
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

[ "$fail" -eq 0 ] || exit 1
echo PASS
