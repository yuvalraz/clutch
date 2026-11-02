#!/bin/sh
# Worklog: the cross-session log at $HOME/.clutch/worklog.md. P1 covers the
# reader: anchor.sh shows the live window under a "Worklog:" header, before
# its git gate, so sessions outside a repo see it too. Live on: claims are
# kept first, then the newest moved: lines fill up to 8, printed in file
# order with the epoch dropped and each line cut to 160 chars. P2 covers the
# stop.sh writer (S1-S10): one moved: landed line per forward move of the
# user's newest authored commit, deduped by subject, silent on stdout.
# The scripts under test are staged into a scratch tree (anchor.sh, prelude.sh
# and stop.sh into $T/scripts, the constitution into $T/rules) and run under
# a scratch HOME with CLAUDE_PLUGIN_ROOT unset, so the anchor's
# $(dirname "$0")/../rules fallback reads the staged constitution. ANCHOR_SH,
# PRELUDE_SH, STOP_SH and CONST_FILE override the targets for replay against
# a historical version. Every hide case carries a positive control in the
# same leg, so no case passes on the pre-change scripts.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
A=${ANCHOR_SH:-$HERE/../scripts/anchor.sh}
P=${PRELUDE_SH:-$HERE/../scripts/prelude.sh}
S=${STOP_SH:-$HERE/../scripts/stop.sh}
C=${CONST_FILE:-$HERE/../rules/constitution.md}

fail=0
for f in "$A" "$P" "$S" "$C"; do
  [ -f "$f" ] || { echo "FAIL: missing $f"; fail=1; }
done
[ "$fail" -eq 0 ] || exit 1

T=$(mktemp -d) || exit 1
trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
HOME=$T/home
export HOME
mkdir -p "$HOME" "$T/scripts" "$T/rules" "$T/plain"
cp "$A" "$T/scripts/anchor.sh"
cp "$P" "$T/scripts/prelude.sh"
cp "$S" "$T/scripts/stop.sh"
cp "$C" "$T/rules/constitution.md"
unset CLAUDE_PLUGIN_ROOT
RUN="$T/scripts/anchor.sh"
PLAIN="$T/plain"
W="$HOME/.clutch/worklog.md"
NOW=$(date +%s)
H=3600
Q='build, ideate, ops, or review?'

# rep <n> <char>: n copies of char.
rep() { printf "%$1s" '' | tr ' ' "$2"; }

# seed: an empty worklog in the scratch HOME.
seed() { mkdir -p "$HOME/.clutch" && : > "$W"; }
# add <age seconds> <rest of line>: append one stored line aged <age>.
add() { printf '%s %s\n' "$((NOW - $1))" "$2" >> "$W"; }

# anchor <label> <dir> [source]: sets OUT and ERR; asserts rc 0.
OUT=""
ERR=""
anchor() {
  OUT=$(cd "$2" && printf '{"source":"%s"}' "${3:-startup}" | sh "$RUN" 2>"$T/err"); rc=$?
  ERR=$(cat "$T/err")
  [ "$rc" = 0 ] || { echo "FAIL: $1 -- anchor exited $rc"; fail=1; }
}

# block: the lines after the Worklog: header (outside git the block is last).
block() { printf '%s\n' "$OUT" | awk 'f { print } $0 == "Worklog:" { f = 1 }'; }

# has <label> <line>: an exact output line must be present.
has() {
  printf '%s\n' "$OUT" | grep -qxF -- "$2"
  rc=$?
  case $rc in
    0) ;;
    1) echo "FAIL: $1 -- line not shown: $2"; fail=1 ;;
    *) echo "FAIL: $1 -- grep error rc=$rc: $2"; fail=1 ;;
  esac
}
# lacks <label> <text>: the fixed text must appear nowhere in the output.
lacks() {
  printf '%s\n' "$OUT" | grep -qF -- "$2"
  rc=$?
  case $rc in
    1) ;;
    0) echo "FAIL: $1 -- hidden text shown: $2"; fail=1 ;;
    *) echo "FAIL: $1 -- grep error rc=$rc: $2"; fail=1 ;;
  esac
}
# nblock <label> <n>: the block holds exactly n lines.
nblock() {
  nb=$(block | grep -c .)
  [ "$nb" = "$2" ] || { echo "FAIL: $1 -- block has ${nb:-?} lines, want $2"; fail=1; }
}

# --- W1 a moved: line 1 h old shows without its epoch
seed
add "$H" "proj moved: shipped-one"
anchor W1 "$PLAIN"
has W1 "proj moved: shipped-one"
lacks "W1 epoch" "$((NOW - H))"

# --- W2 a moved: line 25 h old is hidden
seed
add $((25 * H)) "proj moved: stale-two"
add "$H" "ctl moved: control-W2"
anchor W2 "$PLAIN"
has "W2 control" "ctl moved: control-W2"
lacks W2 "stale-two"

# --- W3 an on: line 3 h old shows
seed
add $((3 * H)) "proj on: claim-three"
anchor W3 "$PLAIN"
has W3 "proj on: claim-three"

# --- W4 an on: line 5 h old is hidden
seed
add $((5 * H)) "proj on: old-four"
add "$H" "ctl moved: control-W4"
anchor W4 "$PLAIN"
has "W4 control" "ctl moved: control-W4"
lacks W4 "old-four"

# --- W5 a line dated 1 h in the future is hidden
seed
add $((-H)) "proj moved: future-five"
add "$H" "ctl moved: control-W5"
anchor W5 "$PLAIN"
has "W5 control" "ctl moved: control-W5"
lacks W5 "future-five"

# --- W6 malformed lines are hidden
seed
printf 'abc proj moved: bad-epoch\n' >> "$W"
add "$H" "proj did: bad-verb"
add "$H" "proj moved:"
add "$H" "ctl moved: control-W6"
anchor W6 "$PLAIN"
has "W6 control" "ctl moved: control-W6"
lacks "W6 epoch" "bad-epoch"
lacks "W6 verb" "bad-verb"
printf '%s\n' "$OUT" | grep -qxF 'proj moved:' && { echo "FAIL: W6 -- text-less line shown"; fail=1; }

# --- W7 ten fresh moved: lines: the last 8 by file order, in file order
seed
for i in 1 2 3 4 5 6 7 8 9 10; do add $(((11 - i) * 60)) "proj moved: m$i"; done
anchor W7 "$PLAIN"
nblock W7 8
EXP='proj moved: m3
proj moved: m4
proj moved: m5
proj moved: m6
proj moved: m7
proj moved: m8
proj moved: m9
proj moved: m10'
[ "$(block)" = "$EXP" ] || { echo "FAIL: W7 -- block is not m3..m10 in file order"; fail=1; }

# --- W8 a 300-char text is cut to a 160-char displayed line
seed
add "$H" "proj moved: $(rep 300 x)"
anchor W8 "$PLAIN"
nblock W8 1
L8=$(block | awk '{ print length($0) }')
[ "$L8" = 160 ] || { echo "FAIL: W8 -- displayed line is ${L8:-?} chars, want 160"; fail=1; }
block | grep -q '^proj moved: xxx' || { echo "FAIL: W8 -- cut line lost its head"; fail=1; }

# --- W9 outside git: constitution plus block; inside git: block, ask last
seed
add "$H" "proj moved: nine"
anchor "W9 plain" "$PLAIN"
has "W9 plain constitution" "# Clutch constitution"
has "W9 plain header" "Worklog:"
has "W9 plain line" "proj moved: nine"
R="$T/repo"
mkdir "$R"
git -C "$R" init -q
git -C "$R" config user.email t@t
git -C "$R" config user.name t
git -C "$R" commit -q --allow-empty -m seed
anchor "W9 git" "$R"
has "W9 git header" "Worklog:"
has "W9 git line" "proj moved: nine"
printf '%s\n' "$OUT" | tail -n 1 | grep -qF "$Q" \
  || { echo "FAIL: W9 git -- intent ask is not the last line"; fail=1; }

# --- W10 empty file, missing file, missing ~/.clutch: no block, nothing created
# w10 <label>: no header but the constitution; then a control line shows.
w10() {
  anchor "$1" "$PLAIN"
  has "$1 constitution" "# Clutch constitution"
  printf '%s\n' "$OUT" | grep -qx 'Worklog:' && { echo "FAIL: $1 -- block shown"; fail=1; }
}
w10ctl() {
  mkdir -p "$HOME/.clutch"
  add "$H" "ctl moved: control-$1"
  anchor "$1 control" "$PLAIN"
  has "$1 control header" "Worklog:"
  has "$1 control line" "ctl moved: control-$1"
}
seed
w10 "W10 empty"
w10ctl "W10-empty"
rm -f "$W"
w10 "W10 missing file"
w10ctl "W10-file"
rm -rf "$HOME/.clutch"
w10 "W10 missing dir"
{ [ -e "$HOME/.clutch" ] || [ -L "$HOME/.clutch" ]; } && { echo "FAIL: W10 -- reader created ~/.clutch"; fail=1; }
w10ctl "W10-dir"

# --- W11 an unreadable worklog: no block, rc 0, empty stderr
if [ "$(id -u)" = 0 ]; then
  echo "SKIP: W11 (root reads chmod 000 files)"
else
  seed
  add "$H" "proj moved: eleven"
  chmod 000 "$W"
  anchor W11 "$PLAIN"
  has "W11 constitution" "# Clutch constitution"
  lacks W11 "eleven"
  [ -z "$ERR" ] || { echo "FAIL: W11 -- stderr not empty: $ERR"; fail=1; }
  chmod 644 "$W"
  anchor "W11 control" "$PLAIN"
  has "W11 control" "proj moved: eleven"
fi

# --- W12 a live claim survives ten newer moved: lines
seed
add $((3 * H)) "proj on: claim-twelve"
for i in 1 2 3 4 5 6 7 8 9 10; do add $(((11 - i) * 60)) "proj moved: m$i"; done
anchor W12 "$PLAIN"
nblock W12 8
EXP='proj on: claim-twelve
proj moved: m4
proj moved: m5
proj moved: m6
proj moved: m7
proj moved: m8
proj moved: m9
proj moved: m10'
[ "$(block)" = "$EXP" ] || { echo "FAIL: W12 -- block is not the claim then m4..m10"; fail=1; }
for i in 1 2 3; do
  block | grep -qxF "proj moved: m$i" && { echo "FAIL: W12 -- m$i shown"; fail=1; }
done

# --- W12b nine live claims and one newer move: the newest 8 claims
seed
for i in 1 2 3 4 5 6 7 8 9; do add $(((20 - i) * 60)) "proj on: c$i"; done
add 60 "proj moved: after-claims"
anchor W12b "$PLAIN"
nblock W12b 8
EXP='proj on: c2
proj on: c3
proj on: c4
proj on: c5
proj on: c6
proj on: c7
proj on: c8
proj on: c9'
[ "$(block)" = "$EXP" ] || { echo "FAIL: W12b -- block is not c2..c9 in file order"; fail=1; }
lacks "W12b move" "after-claims"

# ===== P2: the stop.sh writer =====
# No global or system git config may leak an identity into the scratch repos.
unset XDG_CONFIG_HOME
GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_NOSYSTEM
STOP="$T/scripts/stop.sh"
rm -rf "$HOME/.clutch"

# stop <label> <dir>: one Stop run; asserts rc 0 and empty stdout.
stop() {
  SOUT=$(cd "$2" && printf '{}' | sh "$STOP"); rc=$?
  [ "$rc" = 0 ] || { echo "FAIL: $1 -- stop exited $rc"; fail=1; }
  [ -z "$SOUT" ] || { echo "FAIL: $1 -- stop wrote stdout: $SOUT"; fail=1; }
}
# mkrepo <dir>: a repo with a repo-local identity and one commit.
mkrepo() {
  mkdir -p "$1" && git -C "$1" init -q &&
    git -C "$1" config user.email s@s && git -C "$1" config user.name s &&
    git -C "$1" commit -q --allow-empty -m "seed $(basename "$1")"
}
# commit <dir> <subject>
commit() { git -C "$1" commit -q --allow-empty -m "$2"; }
# lines: the worklog's line count (0 when absent).
lines() { if [ -f "$W" ]; then wc -l < "$W" | tr -d ' '; else echo 0; fi; }
# nlines <label> <n>
nlines() {
  nl=$(lines)
  [ "$nl" = "$2" ] || { echo "FAIL: $1 -- worklog has $nl lines, want $2"; fail=1; }
}
# headis <label> <dir>: .clutch/worklog-head holds "<HEAD> <stop-epoch>".
headis() {
  hrec=$(head -n 1 "$2/.clutch/worklog-head" 2>/dev/null)
  [ "$(printf '%s\n' "$hrec" | cut -d' ' -f1)" = "$(git -C "$2" rev-parse HEAD)" ] \
    || { echo "FAIL: $1 -- worklog-head is not HEAD"; fail=1; }
  case "$(printf '%s\n' "$hrec" | cut -s -d' ' -f2)" in
    '' | *[!0-9]*) echo "FAIL: $1 -- worklog-head has no numeric stop-epoch"; fail=1 ;;
  esac
}
# lastline <label> <ERE>: the worklog's last line matches.
lastline() {
  tail -n 1 "$W" 2>/dev/null | grep -qE -- "$2" \
    || { echo "FAIL: $1 -- last line does not match: $2"; fail=1; }
}
noclutch() {
  { [ -e "$HOME/.clutch" ] || [ -L "$HOME/.clutch" ]; } && { echo "FAIL: $1 -- ~/.clutch exists"; fail=1; }
}

SR="$T/srepo"
mkrepo "$SR" || exit 1

# --- S1 first stop seeds the head, writes no line, creates no ~/.clutch
stop S1 "$SR"
headis S1 "$SR"
noclutch S1

# --- S2 a new commit logs exactly one line and creates ~/.clutch
commit "$SR" "feat two"
stop S2 "$SR"
[ -d "$HOME/.clutch" ] || { echo "FAIL: S2 -- ~/.clutch not created"; fail=1; }
nlines S2 1
grep -qxE "[0-9]+ srepo moved: landed 'feat two'" "$W" 2>/dev/null \
  || { echo "FAIL: S2 -- line is not <epoch> srepo moved: landed 'feat two'"; fail=1; }

# --- S3 the same head logs nothing more
stop S3 "$SR"
nlines S3 1

# --- S4 a side branch off the first commit reseeds silently
git -C "$SR" checkout -q -b side "$(git -C "$SR" rev-list --max-parents=0 HEAD)"
commit "$SR" "side"
stop S4 "$SR"
nlines S4 1
headis S4 "$SR"

# --- S5 no ~/.clutch: the same head creates nothing; a new commit does
rm -rf "$HOME/.clutch"
stop "S5 same" "$SR"
noclutch S5
commit "$SR" "feat five"
stop "S5 new" "$SR"
nlines S5 1
lastline S5 "^[0-9]+ srepo moved: landed 'feat five'$"

# --- S6 an unwritable ~/.clutch or HOME writes nothing, silently
if [ "$(id -u)" = 0 ]; then
  echo "SKIP: S6 (root writes through chmod 555)"
else
  rm -f "$W"
  chmod 555 "$HOME/.clutch"
  commit "$SR" "feat six"
  stop S6a "$SR"
  [ -e "$W" ] && { echo "FAIL: S6a -- worklog written"; fail=1; }
  chmod 755 "$HOME/.clutch"
  rm -rf "$HOME/.clutch"
  chmod 555 "$HOME"
  commit "$SR" "feat six b"
  stop S6b "$SR"
  chmod 755 "$HOME"
  noclutch S6b
  commit "$SR" "feat six c"
  stop "S6 control" "$SR"
  nlines "S6 control" 1
  lastline "S6 control" "^[0-9]+ srepo moved: landed 'feat six c'$"
fi

# --- S7 round trip: the hook's line shows in the anchor
commit "$SR" "feat seven"
stop S7 "$SR"
anchor S7 "$PLAIN"
has S7 "srepo moved: landed 'feat seven'"

# --- S8 a spaced repo name becomes a dashed project field
S8R="$T/my repo"
mkrepo "$S8R" || exit 1
stop "S8 seed" "$S8R"
commit "$S8R" "feat eight"
stop S8 "$S8R"
lastline S8 "^[0-9]+ my-repo moved: landed 'feat eight'$"
anchor S8 "$PLAIN"
has S8 "my-repo moved: landed 'feat eight'"

# --- S9 no matching identity: no head, no line; then the head seeds
S9R="$T/r9"
mkdir -p "$S9R" && git -C "$S9R" init -q || exit 1
git -C "$S9R" -c user.email=o@o -c user.name=o commit -q --allow-empty -m "nine a"
git -C "$S9R" -c user.email=o@o -c user.name=o commit -q --allow-empty -m "nine b"
n9=$(lines)
stop S9 "$S9R"
[ -e "$S9R/.clutch/worklog-head" ] && { echo "FAIL: S9 -- head file written"; fail=1; }
nlines S9 "$n9"
git -C "$S9R" config user.email o@o
git -C "$S9R" config user.name o
stop "S9 control" "$S9R"
headis "S9 control" "$S9R"
nlines "S9 control" "$n9"

# --- S10 a pull of own commits logs nothing; the clone's own commit does
mkrepo "$T/r10" || exit 1
git clone -q "$T/r10" "$T/clone" || exit 1
git -C "$T/clone" config user.email s@s
git -C "$T/clone" config user.name s
stop "S10 seed" "$T/r10"
stop "S10 seed clone" "$T/clone"
n10=$(lines)
commit "$T/r10" "feat ten"
stop S10 "$T/r10"
nlines S10 $((n10 + 1))
git -C "$T/clone" pull -q --ff-only 2>/dev/null \
  || { echo "FAIL: S10 -- pull failed"; fail=1; }
[ "$(git -C "$T/clone" rev-parse HEAD)" = "$(git -C "$T/r10" rev-parse HEAD)" ] \
  || { echo "FAIL: S10 -- clone is not at r10's HEAD after the pull"; fail=1; }
stop "S10 pull" "$T/clone"
nlines "S10 pull" $((n10 + 1))
headis "S10 pull" "$T/clone"
commit "$T/clone" "feat ten b"
stop "S10 control" "$T/clone"
nlines "S10 control" $((n10 + 2))
lastline "S10 control" "^[0-9]+ clone moved: landed 'feat ten b'$"

# dated <dir> <age seconds> <subject>: a commit dated <age> ago.
dated() {
  d="$((NOW - $2)) +0000"
  GIT_AUTHOR_DATE="$d" GIT_COMMITTER_DATE="$d" git -C "$1" commit -q --allow-empty -m "$3"
}
# r7init <dir>: an empty repo on main with the repo-local identity.
r7init() {
  mkdir -p "$1" && git -C "$1" init -q -b main &&
    git -C "$1" config user.email s@s && git -C "$1" config user.name s
}
D=86400

# --- S4b checkout to an old descendant and bisect-style steps log nothing
rm -rf "$HOME/.clutch"
B="$T/r4b"
r7init "$B" || exit 1
dated "$B" $((40 * D)) "base"
git -C "$B" checkout -q -b old
dated "$B" $((35 * D)) "old one"
dated "$B" $((30 * D)) "old feature"
git -C "$B" checkout -q main
stop "S4b seed" "$B"
git -C "$B" checkout -q old
stop "S4b old" "$B"
[ -e "$W" ] && { echo "FAIL: S4b -- checkout of old wrote a line"; fail=1; }
noclutch "S4b old"
headis "S4b old" "$B"
for ref in main old~1 old; do
  git -C "$B" checkout -q --detach "$ref"
  stop "S4b $ref" "$B"
done
[ -e "$W" ] && { echo "FAIL: S4b -- bisect steps wrote a line"; fail=1; }
noclutch "S4b bisect"
git -C "$B" checkout -q old
commit "$B" "feat four b"
stop "S4b control" "$B"
nlines "S4b control" 1
lastline "S4b control" "^[0-9]+ r4b moved: landed 'feat four b'$"

# --- S11 a return to a logged branch past the dedupe window logs nothing
E="$T/r11"
r7init "$E" || exit 1
commit "$E" "seed r11"
stop "S11 seed" "$E"
# Fixture: the last head change was 2 h ago.
printf '%s %s\n' "$(git -C "$E" rev-parse HEAD)" "$((NOW - 2 * H))" > "$E/.clutch/worklog-head"
git -C "$E" checkout -q -b feat
dated "$E" "$H" "feat eleven"
n11=$(lines)
stop S11 "$E"
nlines S11 $((n11 + 1))
lastline S11 "^[0-9]+ r11 moved: landed 'feat eleven'$"
git -C "$E" checkout -q main
stop "S11 main" "$E"
i=1
while [ "$i" -le 201 ]; do printf '%s filler moved: x%s\n' "$NOW" "$i"; i=$((i + 1)); done >> "$W"
n11=$(lines)
git -C "$E" checkout -q feat
stop "S11 return" "$E"
nlines "S11 return" "$n11"
commit "$E" "feat eleven b"
stop "S11 control" "$E"
nlines "S11 control" $((n11 + 1))
lastline "S11 control" "^[0-9]+ r11 moved: landed 'feat eleven b'$"

[ "$fail" -eq 0 ] || exit 1
echo PASS
