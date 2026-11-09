#!/bin/sh
# Worklog: the cross-session log at $HOME/.clutch/worklog.md. P1 covers the
# reader: anchor.sh shows the live window under a "Worklog:" header, before
# its git gate, so sessions outside a repo see it too. Live on: claims are
# kept first, then the newest moved: lines fill up to 8, printed in file
# order with the epoch dropped and each line cut to 160 chars. W13-W22 cover
# wait: loops: open until a moved: line names the same ref or 5 days pass,
# kept after live claims and printed first in the window, and listed raw by
# clutch_open_loops (rc 1 with no worklog, rc 2 when it is unreadable).
# W24-W26 cover the ref key: a trailing ,;:. or CR is ignored on the wait and
# the moved side alike, and a moved: L2: line never closes a wait.
# D1-D8 cover clutch_ops_due: brief is due once per local day, window once
# per window time (### Windows in rituals.md, default 11:00 and 16:30), never
# creating ~/.clutch and printing nothing on a bad argument or a bad date.
# P2 covers the
# stop.sh writer (S1-S12, S4b): one moved: landed line per forward move of the
# user's newest authored commit, deduped by subject, silent on stdout. C covers
# the constitution's worklog snippet, extracted from the shipped rules file and
# run: it targets worklog.md, creates ~/.clutch, and its line round-trips
# through the anchor. P5 doc pins (dpin) check that README and GLOSSARY name
# the worklog write and keep the stale wording out.
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
README=${README_FILE:-$HERE/../README.md}
GLOSSARY=${GLOSSARY_FILE:-$HERE/../GLOSSARY.md}

fail=0
for f in "$A" "$P" "$S" "$C" "$README" "$GLOSSARY"; do
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

# loops: clutch_open_loops from the staged prelude; sets LOUT and LRC.
LOUT=""
LRC=0
loops() {
  LOUT=$(cd "$PLAIN" && . "$T/scripts/prelude.sh" && clutch_open_loops 2>"$T/lerr"); LRC=$?
}
# lhas <label> <text> / llacks <label> <text>: fixed text in the loops output.
lhas() {
  printf '%s\n' "$LOUT" | grep -qF -- "$2" || { echo "FAIL: $1 -- loops lacks: $2"; fail=1; }
}
llacks() {
  printf '%s\n' "$LOUT" | grep -qF -- "$2" && { echo "FAIL: $1 -- loops shows: $2"; fail=1; }
}
# lcount <label> <n>: loops printed exactly n lines with rc 0.
lcount() {
  [ "$LRC" = 0 ] || { echo "FAIL: $1 -- loops rc $LRC, want 0"; fail=1; }
  nl=$(printf '%s' "$LOUT" | grep -c .)
  [ "$nl" = "$2" ] || { echo "FAIL: $1 -- loops has ${nl:-?} lines, want $2"; fail=1; }
}

# --- W13 a wait 1 h old: first in the block, raw (epoch kept) in loops
seed
add "$H" "proj wait: slack:D1/1.1 1.1 asked-thirteen"
anchor W13 "$PLAIN"
has W13 "proj wait: slack:D1/1.1 1.1 asked-thirteen"
loops
lcount "W13 loops" 1
printf '%s\n' "$LOUT" | grep -qxE '[0-9]+ proj wait: slack:D1/1\.1 1\.1 asked-thirteen' \
  || { echo "FAIL: W13 -- loops line is not the raw wait: $LOUT"; fail=1; }

# --- W14 a moved: line with the same ref closes; another ref or landed does not
seed
add $((3 * H)) "proj wait: gh:o/r#1 t1 w14-one"
add $((3 * H)) "proj wait: gh:o/r#2 t2 w14-two"
add $((2 * H)) "proj moved: gh:o/r#1 merged"
add "$H" "srepo moved: landed 'gh:o/r#2'"
anchor W14 "$PLAIN"
has W14 "proj wait: gh:o/r#2 t2 w14-two"
has "W14 move" "proj moved: gh:o/r#1 merged"
has "W14 landed" "srepo moved: landed 'gh:o/r#2'"
lacks W14 "w14-one"
loops
lcount "W14 loops" 1
lhas "W14 loops" "w14-two"
llacks "W14 loops" "w14-one"

# --- W15 a wait outlives the 4 h on: rule
seed
add $((5 * H)) "proj wait: gh:o/r#15 t15 wait-fifteen"
add $((5 * H)) "proj on: on-fifteen"
add "$H" "ctl moved: control-W15"
anchor W15 "$PLAIN"
has W15 "proj wait: gh:o/r#15 t15 wait-fifteen"
has "W15 control" "ctl moved: control-W15"
lacks "W15 on" "on-fifteen"
loops
lcount "W15 loops" 1
lhas "W15 loops" "wait-fifteen"

# --- W16 a wait lives 5 days
seed
add $((5 * 24 * H + H)) "proj wait: dd:16b ok ttl-dead"
add $((4 * 24 * H)) "proj wait: dd:16a ok ttl-alive"
anchor W16 "$PLAIN"
has W16 "proj wait: dd:16a ok ttl-alive"
lacks W16 "ttl-dead"
loops
lcount "W16 loops" 1
lhas "W16 loops" "ttl-alive"
llacks "W16 loops" "ttl-dead"

# --- W17 an open wait is kept first against ten newer moves
seed
add $((3 * H)) "proj wait: slack:C17/1.7 1.7 kept-17"
for i in 1 2 3 4 5 6 7 8 9 10; do add $(((11 - i) * 60)) "proj moved: m$i"; done
anchor W17 "$PLAIN"
nblock W17 8
EXP='proj wait: slack:C17/1.7 1.7 kept-17
proj moved: m4
proj moved: m5
proj moved: m6
proj moved: m7
proj moved: m8
proj moved: m9
proj moved: m10'
[ "$(block)" = "$EXP" ] || { echo "FAIL: W17 -- block is not the wait then m4..m10"; fail=1; }

# --- W17b waits print first, then the other kept lines in file order
seed
add $((2 * H)) "proj moved: early-m"
add 5400 "proj on: mid-on"
add "$H" "proj wait: ld:flag-x 7 newest-w"
anchor W17b "$PLAIN"
EXP='proj wait: ld:flag-x 7 newest-w
proj moved: early-m
proj on: mid-on'
[ "$(block)" = "$EXP" ] || { echo "FAIL: W17b -- block is not the wait, early-m, mid-on"; fail=1; }

# --- W17c eight open waits cannot hide a live claim: the claim takes a slot,
# the newest seven waits fill the rest and still print first.
seed
for i in 1 2 3 4 5 6 7 8; do add $((2 * H)) "proj wait: gh:o/r#$i b w17c-$i"; done
add 60 "proj on: claim-17c"
anchor W17c "$PLAIN"
nblock W17c 8
EXP='proj wait: gh:o/r#2 b w17c-2
proj wait: gh:o/r#3 b w17c-3
proj wait: gh:o/r#4 b w17c-4
proj wait: gh:o/r#5 b w17c-5
proj wait: gh:o/r#6 b w17c-6
proj wait: gh:o/r#7 b w17c-7
proj wait: gh:o/r#8 b w17c-8
proj on: claim-17c'
[ "$(block)" = "$EXP" ] || { echo "FAIL: W17c -- block is not waits 2..8 then the claim"; fail=1; }

# --- W18 a wait behind 300 newer lines is still found
seed
add $((2 * 24 * H)) "proj wait: linear:ENG-18 u18 lookback-18"
i=1
while [ "$i" -le 300 ]; do add 60 "filler moved: x$i"; i=$((i + 1)); done
anchor W18 "$PLAIN"
[ "$(block | head -n 1)" = "proj wait: linear:ENG-18 u18 lookback-18" ] \
  || { echo "FAIL: W18 -- the wait is not the block's first line"; fail=1; }
loops
lcount "W18 loops" 1
lhas "W18 loops" "lookback-18"

# --- W19 malformed waits are skipped
seed
add "$H" "proj wait: slack:D9/1.1 short"
add "$H" "proj wait: nocolon 1 t-nocolon"
add "$H" "proj wait: :x 1 t-emptykind"
add "$H" "proj wait: dd:42 ok control-19"
anchor W19 "$PLAIN"
has "W19 control" "proj wait: dd:42 ok control-19"
lacks "W19 short" "slack:D9/1.1 short"
lacks "W19 nocolon" "t-nocolon"
lacks "W19 emptykind" "t-emptykind"
loops
lcount "W19 loops" 1
lhas "W19 loops" "control-19"

# --- W20 close, then re-arm the same ref: open again, latest wait
seed
add $((3 * H)) "proj wait: slack:a b1 first-arm"
add $((2 * H)) "proj moved: slack:a replied"
add "$H" "proj wait: slack:a b2 second-arm"
loops
lcount "W20 loops" 1
lhas "W20 loops" "second-arm"

# --- W21 two waits on one ref: one line, the latest
seed
add $((2 * H)) "proj wait: gh:o/r#3 b dup-old"
add "$H" "proj wait: gh:o/r#3 b dup-new"
loops
lcount "W21 loops" 1
lhas "W21 loops" "dup-new"

# --- W22 reader edges: missing file rc 1, nothing created; empty file rc 0
rm -rf "$HOME/.clutch"
loops
[ "$LRC" = 1 ] || { echo "FAIL: W22 missing -- loops rc $LRC, want 1"; fail=1; }
[ -z "$LOUT" ] || { echo "FAIL: W22 missing -- loops printed: $LOUT"; fail=1; }
{ [ -e "$HOME/.clutch" ] || [ -L "$HOME/.clutch" ]; } && { echo "FAIL: W22 -- reader created ~/.clutch"; fail=1; }
seed
loops
lcount "W22 empty" 0
add 60 "proj wait: gh:o/r#22 b control-22"
loops
lcount "W22 control" 1
lhas "W22 control" "control-22"

# --- W22b an unreadable worklog is rc 2, not the "no worklog" rc 1
if [ "$(id -u)" = 0 ]; then
  echo "SKIP: W22b (root reads chmod 000 files)"
else
  chmod 000 "$W"
  loops
  WRC=$(cd "$PLAIN" && . "$T/scripts/prelude.sh" && clutch_worklog_window >/dev/null 2>&1; echo $?)
  chmod 644 "$W"
  [ "$LRC" = 2 ] || { echo "FAIL: W22b -- loops rc $LRC, want 2"; fail=1; }
  [ -z "$LOUT" ] || { echo "FAIL: W22b -- loops printed: $LOUT"; fail=1; }
  [ "$WRC" = 2 ] || { echo "FAIL: W22b -- window rc $WRC, want 2"; fail=1; }
  loops
  lcount "W22b control" 1
fi

# --- W23 invalid UTF-8 cannot blank the scan: under a UTF-8 locale, a bad
# byte in a wait kind and in an epoch field is skipped, and the valid wait and
# the claim in the same file still show in the window and the loops.
seed
add $((2 * H)) "proj on: claim-23"
add "$H" "proj wait: gh:o/r#23 b control-23"
printf '%s proj wait: g\351h:o/r#9 b badkind-23\n' "$((NOW - H))" >> "$W"
printf '1\377 proj moved: badepoch-23\n' >> "$W"
WOUT=$(cd "$PLAIN" && export LC_ALL=en_US.UTF-8 && . "$T/scripts/prelude.sh" && clutch_worklog_window 2>/dev/null); WRC=$?
[ "$WRC" = 0 ] || { echo "FAIL: W23 window -- rc $WRC, want 0"; fail=1; }
printf '%s\n' "$WOUT" | grep -qxF "proj wait: gh:o/r#23 b control-23" \
  || { echo "FAIL: W23 window -- valid wait not shown: $WOUT"; fail=1; }
printf '%s\n' "$WOUT" | grep -qxF "proj on: claim-23" \
  || { echo "FAIL: W23 window -- claim not shown: $WOUT"; fail=1; }
LOUT=$(cd "$PLAIN" && export LC_ALL=en_US.UTF-8 && . "$T/scripts/prelude.sh" && clutch_open_loops 2>/dev/null); LRC=$?
[ "$LRC" = 0 ] || { echo "FAIL: W23 loops -- rc $LRC, want 0"; fail=1; }
lhas "W23 loops" "control-23"

# --- W24 a moved: ref with a trailing comma or colon closes its wait; a
# longer ref is not a prefix match.
seed
add $((3 * H)) "proj wait: gh:o/r#2 b w24-a"
add $((3 * H)) "proj wait: slack:C1/1.1 b w24-b"
add $((3 * H)) "proj wait: gh:o/r#20 b w24-c"
add $((2 * H)) "proj moved: gh:o/r#2, merged"
add $((2 * H)) "proj moved: slack:C1/1.1: replied"
loops
lcount "W24 loops" 1
lhas "W24 loops" "w24-c"
llacks "W24 comma" "w24-a"
llacks "W24 colon" "w24-b"

# --- W24b a wait: ref with a trailing comma is closed by the clean ref.
seed
add $((3 * H)) "proj wait: gh:o/r#5, b w24b"
add $((3 * H)) "proj wait: gh:o/r#6 b w24b-ctl"
add $((2 * H)) "proj moved: gh:o/r#5 merged"
loops
lcount "W24b loops" 1
lhas "W24b control" "w24b-ctl"
llacks "W24b" "gh:o/r#5,"

# --- W25 a moved: L2: line never closes a wait; the plain moved: line does.
seed
add $((3 * H)) "proj wait: linear:ENG-1 b w25"
add $((2 * H)) "proj moved: L2: linear:ENG-1 Done"
loops
lcount "W25 loops" 1
lhas "W25 L2" "w25"
add "$H" "proj moved: linear:ENG-1 Done"
loops
lcount "W25 closed" 0

# --- W26 a 4-field moved: line ending in CRLF closes its wait.
seed
add $((3 * H)) "proj wait: gh:o/r#7 b w26"
add $((3 * H)) "proj wait: gh:o/r#8 b w26-ctl"
printf '%s proj moved: gh:o/r#7\r\n' "$((NOW - 2 * H))" >> "$W"
loops
lcount "W26 loops" 1
lhas "W26 control" "w26-ctl"
llacks "W26" "gh:o/r#7 "

# ===== clutch_ops_due: the day brief and approval window checks =====
# D1-D8 run clutch_ops_due from the staged prelude with a PATH-shim date that
# answers only '+%Y-%m-%d %H%M' (FAKE_NOW; "fail" exits 1) and execs /bin/date
# otherwise, each case in a fresh HOME under $T.
mkdir -p "$T/fakebin" "$T/dh"
cat > "$T/fakebin/date" <<'EOF'
#!/bin/sh
if [ "$#" = 1 ] && [ "$1" = '+%Y-%m-%d %H%M' ]; then
  [ "$FAKE_NOW" = fail ] && exit 1
  printf '%s\n' "$FAKE_NOW"
  exit 0
fi
exec /bin/date "$@"
EOF
chmod +x "$T/fakebin/date"
OHOME=$HOME
# dhome <name>: a fresh HOME with ~/.clutch; restored by dend.
dhome() { HOME=$T/dh/$1; export HOME; mkdir -p "$HOME/.clutch"; }
dend() { HOME=$OHOME; export HOME; }
# due <kind> <now>: sets DOUT and DRC.
DOUT=""
DRC=0
due() {
  DOUT=$(cd "$PLAIN" && PATH="$T/fakebin:$PATH" FAKE_NOW="$2" sh -c ". '$T/scripts/prelude.sh' && clutch_ops_due $1" 2>"$T/derr"); DRC=$?
}
# dis <label> <want>: DOUT equals want ("" for nothing) with rc 0.
dis() {
  [ "$DRC" = 0 ] || { echo "FAIL: $1 -- rc $DRC, want 0 ($(cat "$T/derr"))"; fail=1; }
  [ "$DOUT" = "$2" ] || { echo "FAIL: $1 -- printed '$DOUT', want '$2'"; fail=1; }
}
# dmark <label> <file> <want>: the marker file holds exactly want.
dmark() {
  got=$(cat "$HOME/.clutch/$2" 2>/dev/null)
  [ "$got" = "$3" ] || { echo "FAIL: $1 -- $2 holds '$got', want '$3'"; fail=1; }
}

# --- D1 the brief is due once per local day
dhome d1
due brief "2026-11-09 0905"; dis "D1 first" due
dmark "D1 marker" ops-brief-last 2026-11-09
due brief "2026-11-09 1500"; dis "D1 again" ""
due brief "2026-11-10 0800"; dis "D1 next day" due
dend

# --- D2 default windows 11:00 and 16:30 with no rituals.md
dhome d2
due window "2026-11-09 1059"; dis "D2 1059" ""
[ -e "$HOME/.clutch/ops-window-last" ] && { echo "FAIL: D2 1059 -- marker written before the first window"; fail=1; }
due window "2026-11-09 1100"; dis "D2 1100" due
due window "2026-11-09 1500"; dis "D2 1500" ""
due window "2026-11-09 1631"; dis "D2 1631" due
dmark "D2 marker" ops-window-last "2026-11-09 1630"
due window "2026-11-09 2300"; dis "D2 2300" ""
due window "2026-11-10 1700"; dis "D2 next day" due
due window "2026-11-10 1701"; dis "D2 next day again" ""
dend

# --- D3 ### Windows times count only inside the section and below 24:00
dhome d3
printf '## Ops\n### Windows\n- 9:30, 14:00 and 25:00\n### Other\n- 18:00\n' > "$HOME/.clutch/rituals.md"
due window "2026-11-09 0929"; dis "D3 0929" ""
due window "2026-11-09 0930"; dis "D3 0930" due
due window "2026-11-09 1700"; dis "D3 1700" due
dmark "D3 marker" ops-window-last "2026-11-09 1400"
due window "2026-11-09 1800"; dis "D3 1800" ""
dend

# --- D4 no ~/.clutch: due every time, and ~/.clutch is never created
dhome d4
rmdir "$HOME/.clutch"
due window "2026-11-09 1200"; dis "D4 first" due
due window "2026-11-09 1200"; dis "D4 second" due
{ [ -e "$HOME/.clutch" ] || [ -L "$HOME/.clutch" ]; } && { echo "FAIL: D4 -- clutch_ops_due created ~/.clutch"; fail=1; }
dend

# --- D5 a failed stamp still prints due
if [ "$(id -u)" = 0 ]; then
  echo "SKIP: D5 (root writes into mode 555 dirs)"
else
  dhome d5
  chmod 555 "$HOME/.clutch"
  due brief "2026-11-09 0905"; dis "D5 first" due
  due brief "2026-11-09 0906"; dis "D5 second" due
  chmod 755 "$HOME/.clutch"
  dend
fi

# --- D6 no argument or an unknown argument: nothing, no marker
dhome d6
due "" "2026-11-09 1200"; dis "D6 no arg" ""
due bogus "2026-11-09 1200"; dis "D6 bogus" ""
for m in ops-brief-last ops-window-last; do
  [ -e "$HOME/.clutch/$m" ] && { echo "FAIL: D6 -- $m written"; fail=1; }
done
due brief "2026-11-09 1200"; dis "D6 control" due
dend

# --- D7 a garbage marker is overwritten
dhome d7
printf 'xx\n' > "$HOME/.clutch/ops-brief-last"
due brief "2026-11-09 0905"; dis "D7" due
dmark "D7 marker" ops-brief-last 2026-11-09
dend

# --- D8 a failed or malformed date: nothing
dhome d8
due brief fail; dis "D8 fail" ""
due window fail; dis "D8 window fail" ""
due brief soon; dis "D8 soon" ""
due brief "2026-11-09 0905"; dis "D8 control" due
dend

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

# --- S12 every stop refreshes the stored epoch, so a branch fetched from
# another machine and checked out after an idle head logs nothing
R12="$T/r12"
r7init "$R12" || exit 1
dated "$R12" $((4 * D)) "seed r12"
stop "S12 seed" "$R12"
# Fixture: the head has not moved for 3 days.
printf '%s %s\n' "$(git -C "$R12" rev-parse HEAD)" "$((NOW - 3 * D))" > "$R12/.clutch/worklog-head"
stop "S12 idle 1" "$R12"
stop "S12 idle 2" "$R12"
stop "S12 idle 3" "$R12"
headis "S12 idle" "$R12"
s12ep=$(cut -s -d' ' -f2 "$R12/.clutch/worklog-head" 2>/dev/null)
[ "${s12ep:-0}" -ge "$NOW" ] 2>/dev/null \
  || { echo "FAIL: S12 -- same-head stops did not refresh the epoch: ${s12ep:-none}"; fail=1; }
git -C "$R12" checkout -q -b fetched
dated "$R12" "$H" "fetched twelve"
n12=$(lines)
stop "S12 fetched" "$R12"
nlines "S12 fetched" "$n12"
commit "$R12" "feat twelve"
stop "S12 control" "$R12"
nlines "S12 control" $((n12 + 1))
lastline "S12 control" "^[0-9]+ r12 moved: landed 'feat twelve'$"

# --- C: the constitution's worklog snippet, extracted from the shipped file
# with the fomo-snippet awk and run as is, so prose and test cannot drift.
nsh=$(grep -c '^```sh' "$C")
[ "$nsh" = 1 ] || { echo "FAIL: C -- constitution has $nsh sh blocks, want 1"; fail=1; }
awk '/```sh/{n++;f=1;next} /```/{f=0} f && n==1' "$C" > "$T/csnip.raw"
[ -s "$T/csnip.raw" ] || { echo "FAIL: C -- snippet extraction came up empty"; fail=1; }
grep -qF 'worklog.md' "$T/csnip.raw" || { echo "FAIL: C -- snippet does not target worklog.md"; fail=1; }
grep -qF 'mkdir -p "$HOME/.clutch"' "$T/csnip.raw" || { echo "FAIL: C -- snippet does not create ~/.clutch"; fail=1; }

# fill <text> <out>: the snippet with on: and <text> in its placeholders.
# Literal index() replacement through ENVIRON: no regex, no -v escape processing.
fill() {
  CV='on:' CX=$1 awk '
    function rl(s, a, b,   i) { i = index(s, a); return i ? substr(s, 1, i - 1) b substr(s, i + length(a)) : s }
    { $0 = rl($0, "<moved:|on:>", ENVIRON["CV"]); print rl($0, "<one line>", ENVIRON["CX"]) }' "$T/csnip.raw" > "$2"
}
fill 'parser rewrite' "$T/csnip.sh"
# fresh <name>: a new scratch HOME for one C case.
fresh() { HOME="$T/h-$1"; export HOME; W="$HOME/.clutch/worklog.md"; mkdir -p "$HOME"; }
# snip <dir> [script]: run the snippet in <dir>; sets SOUT (stderr dropped) and rc.
snip() { SOUT=$(cd "$1" && sh "${2:-$T/csnip.sh}" 2>/dev/null); rc=$?; }
# only <label> <ERE>: the worklog holds exactly one line, matching.
only() {
  nlines "$1" 1
  grep -qE -- "$2" "$W" 2>/dev/null || { echo "FAIL: $1 -- line does not match: $2"; fail=1; }
}
CR="$T/crepo"
mkdir -p "$CR" && git -C "$CR" init -q || exit 1

# --- C1 in a repo with ~/.clutch: silent, one line with the repo's name
fresh c1
mkdir -p "$HOME/.clutch"
snip "$CR"
[ -z "$SOUT" ] || { echo "FAIL: C1 -- snippet wrote stdout: $SOUT"; fail=1; }
only C1 '^[0-9][0-9]* crepo on: parser rewrite$'

# --- C2 in a plain dir: the project field is the dir's basename
fresh c2
mkdir -p "$HOME/.clutch" "$T/c2plain"
snip "$T/c2plain"
only C2 '^[0-9][0-9]* c2plain on: parser rewrite$'

# --- C3 no ~/.clutch: the snippet creates it and writes the line
fresh c3
snip "$CR"
[ "$rc" = 0 ] || { echo "FAIL: C3 -- snippet exited $rc"; fail=1; }
[ -z "$SOUT" ] || { echo "FAIL: C3 -- snippet wrote stdout: $SOUT"; fail=1; }
[ -d "$HOME/.clutch" ] || { echo "FAIL: C3 -- ~/.clutch not created"; fail=1; }
only C3 '^[0-9][0-9]* crepo on: parser rewrite$'

if [ "$(id -u)" = 0 ]; then
  echo "SKIP: C4, C4b (root writes through chmod)"
else
  # --- C4 an unwritable worklog: MISS
  fresh c4
  mkdir -p "$HOME/.clutch" && : > "$W" && chmod 444 "$W"
  snip "$CR"
  chmod 644 "$W"
  [ "$SOUT" = MISS ] || { echo "FAIL: C4 -- expected MISS, got: $SOUT"; fail=1; }
  # --- C4b no ~/.clutch under an unwritable HOME: MISS, nothing created
  fresh c4b
  chmod 555 "$HOME"
  snip "$CR"
  chmod 755 "$HOME"
  [ "$SOUT" = MISS ] || { echo "FAIL: C4b -- expected MISS, got: $SOUT"; fail=1; }
  noclutch C4b
fi

# --- C5 round trip: the anchor shows the written line under Worklog:
fresh c5
snip "$CR"
anchor C5 "$PLAIN"
block | grep -qxF 'crepo on: parser rewrite' \
  || { echo "FAIL: C5 -- line not under Worklog:"; fail=1; }

# --- C6 model text with an apostrophe, escaped per the constitution's
# rule "Escape ' as '\''."
fresh c6
fill "Dana'\\''s thread" "$T/csnip6.sh"
snip "$CR" "$T/csnip6.sh"
only C6 "^[0-9][0-9]* crepo on: Dana's thread$"
anchor C6 "$PLAIN"
block | grep -qxF "crepo on: Dana's thread" \
  || { echo "FAIL: C6 -- line not under Worklog:"; fail=1; }

# --- C7 raw text filled the way the prose instructs: apostrophes, $( ) and a
# backtick span stay literal text; nothing in them runs.
fresh c7
mkdir -p "$T/c7plain"
# The $( ) and backtick spans sit between the first two apostrophes, so an
# unescaped fill leaves them unquoted and they run (checked once by hand).
C7RAW="don't \$(touch pwned1) \`touch pwned2\` touch Bo's branch"
# The rule applied by awk gsub: each ' becomes '\''. The replacement string
# holds one backslash; a lone \ before ' is literal in gsub's replacement.
C7ESC=$(C7RAW=$C7RAW awk 'BEGIN { s = ENVIRON["C7RAW"]; gsub("\047", "\047\\\047\047", s); print s }')
fill "$C7ESC" "$T/csnip7.sh"
snip "$T/c7plain" "$T/csnip7.sh"
[ "$rc" = 0 ] || { echo "FAIL: C7 -- snippet exited $rc"; fail=1; }
[ -z "$SOUT" ] || { echo "FAIL: C7 -- snippet wrote stdout: $SOUT"; fail=1; }
nlines C7 1
c7got=$(sed -n 's/^[0-9][0-9]* c7plain on: //p' "$W" 2>/dev/null)
[ "$c7got" = "$C7RAW" ] || { echo "FAIL: C7 -- stored text is not the raw text: $c7got"; fail=1; }
for pw in pwned1 pwned2; do
  [ -e "$T/c7plain/$pw" ] && { echo "FAIL: C7 -- $pw ran"; fail=1; }
done

# Prose pins: single-line fragments of the constitution's Worklog section.
cpin() {
  grep -qF -- "$1" "$C"
  rc=$?
  case $rc in
    0) ;;
    1) echo "FAIL: pin -- pattern not found: $1"; fail=1 ;;
    *) echo "FAIL: pin -- grep error rc=$rc: $1"; fail=1 ;;
  esac
}
cpin '## Worklog'
cpin "The anchor's worklog block is legal"
cpin 'never speech to the user'
cpin 'A line may be yours from before a compaction'
cpin 'Never propose a live on: item uninvited'
cpin 'explicit ask wins over any claim'
cpin 'never a list for the user'
cpin '(commits log themselves)'
cpin "Escape ' as '\\''."
cpin 'Speak on MISS or an error'
nold=$(grep -c 'Speak only on MISS' "$C")
[ "$nold" = 0 ] || { echo "FAIL: pin -- old 'Speak only on MISS' still present"; fail=1; }

# Doc pins (P5): README and GLOSSARY name the worklog write. Each fragment
# sits on one line of the shipped text.
dpin() {
  grep -qF -- "$2" "$1"
  rc=$?
  case $rc in
    0) ;;
    1) echo "FAIL: doc pin -- pattern not found in $1: $2"; fail=1 ;;
    *) echo "FAIL: doc pin -- grep error rc=$rc in $1: $2"; fail=1 ;;
  esac
}
dpin "$README" '~/.clutch/worklog.md'
dpin "$README" 'commit subjects and repo names'
dpin "$README" 'the first note creates it'
dpin "$README" 'files ideas into'
dpin "$README" 'is not pool stock'
dpin "$README" 'without a command or a verdict'
dpin "$README" 'Pool writes stay repo-scoped by design'
dpin "$README" 'No pool item enters it ambiently'
# Paired with the positive pin above, so a missing README cannot pass this.
namb=$(grep -c 'Nothing enters it ambiently' "$README")
[ "$namb" = 0 ] || { echo "FAIL: doc pin -- README still says 'Nothing enters it ambiently' ($namb hit)"; fail=1; }
# Without a brain, absorb files into the repo's .clutch/ideas/, not nowhere.
dpin "$README" "instead of the repo's"
nskip=$(grep -c 'instead of skipping' "$README")
[ "$nskip" = 0 ] || { echo "FAIL: doc pin -- README still says 'instead of skipping' ($nskip hit)"; fail=1; }
dpin "$GLOSSARY" 'is not pool stock'
dpin "$GLOSSARY" 'no command or verdict asks for'
dpin "$GLOSSARY" 'Its first write creates'

[ "$fail" -eq 0 ] || exit 1
echo PASS
