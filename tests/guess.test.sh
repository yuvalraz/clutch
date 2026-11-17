#!/bin/sh
# Guessed intent: each declaration appends "<key> <focus>" to
# ~/.clutch/intents, and a fresh session's anchor names the last focus for
# this folder in place of the four-way ask. G1 covers clutch_guess_intent
# (rc 0 prints the focus, rc 1 no file or no valid line, rc 2 an unreadable
# or non-regular store). G2-G10 run the anchor in a scratch repo: with no
# record, another key only, CLUTCH_GUESS=off, an unreadable store or invalid
# lines the output equals the no-store output byte for byte; a valid record
# swaps the last line for the guessed ask; resume with a gear and compact
# stay silent. G11-G12 run outside git: the guessed ask is a new last line on
# startup or clear only, and the key is the folder name exactly, spaces as
# hyphens. G13-G16 pin the intent skill's record line, guessed question and
# go answer and the README sentences; G14 runs the skill's own record
# snippet, then the anchor, as a round trip. prelude.sh and anchor.sh are
# staged into a scratch scripts/ dir; PRELUDE_SH, ANCHOR_SH, INTENT_SKILL and
# README_FILE override the targets for replay against a historical version.
# Every anchor run must leave stderr empty. Silent apart from PASS.
set -u
unset CLUTCH_GUESS CLUTCH_WATCH CLAUDE_PLUGIN_ROOT

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
A=${ANCHOR_SH:-$ROOT/scripts/anchor.sh}
P=${PRELUDE_SH:-$ROOT/scripts/prelude.sh}
S=${INTENT_SKILL:-$ROOT/skills/intent/SKILL.md}
R=${README_FILE:-$ROOT/README.md}
for f in "$A" "$P" "$S" "$R" "$ROOT/rules/constitution.md"; do
  [ -f "$f" ] || { echo "FAIL: missing $f"; exit 1; }
done

T=$(mktemp -d) || exit 1
trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
HOME=$T/home
export HOME
CLAUDE_PLUGIN_ROOT=$ROOT
GIT_CEILING_DIRECTORIES=$T
export CLAUDE_PLUGIN_ROOT GIT_CEILING_DIRECTORIES
mkdir -p "$HOME/.clutch" "$T/scripts" "$T/plain/my dir" "$T/plain/a.b" "$T/repo"
cp "$A" "$T/scripts/anchor.sh"
cp "$P" "$T/scripts/prelude.sh"
git -C "$T/repo" init -q
git -C "$T/repo" config user.email t@t
git -C "$T/repo" config user.name t
git -C "$T/repo" commit -q --allow-empty -m seed
ST="$HOME/.clutch/intents"
TODAY='Intent for this session: build, ideate, ops, or review? /clutch:intent sets the frame.'
guessed() { printf 'Intent for this session: looks like %s again; say go, or pick build, ideate, ops, or review. /clutch:intent sets the frame.' "$1"; }
fail=0
ROOTUSER=0
[ "$(id -u)" = 0 ] && ROOTUSER=1

# store <printf format>: replace the store with exactly that content.
store() { chmod -R u+rwx "$ST" 2>/dev/null; rm -rf "$ST"; printf "$1" > "$ST"; }
nostore() { chmod -R u+rwx "$ST" 2>/dev/null; rm -rf "$ST"; }
dirstore() { nostore; mkdir "$ST"; }

# run <label> <dir> <source> [extra json]: the staged anchor; sets OUT.
# GV is the CLUTCH_GUESS value for the run (empty means unset-equivalent).
GV=""
OUT=""
run() {
  OUT=$(cd "$2" && printf '{"source":"%s"%s}' "$3" "${4:-}" | CLUTCH_GUESS=$GV sh "$T/scripts/anchor.sh" 2>"$T/err"); rc=$?
  [ "$rc" = 0 ] || { echo "FAIL: $1 -- anchor exited $rc"; fail=1; }
  [ -s "$T/err" ] && { echo "FAIL: $1 -- stderr: $(head -3 "$T/err")"; fail=1; }
  return 0
}
last() { printf '%s\n' "$1" | tail -n 1; }
butlast() { printf '%s\n' "$1" | sed '$d'; }
same() { [ "$2" = "$3" ] || { echo "FAIL: $1 -- output differs from the no-store output"; fail=1; }; }

# --- G1 (unit): clutch_guess_intent's rc and stdout
unit() { UOUT=$(cd "$1" && . "$T/scripts/prelude.sh" && clutch_guess_intent 2>/dev/null); URC=$?; }
nostore
unit "$T/repo"
[ "$URC" = 1 ] && [ -z "$UOUT" ] || { echo "FAIL: G1 no store -- want rc 1 and no stdout, got rc $URC: $UOUT"; fail=1; }
dirstore
unit "$T/repo"
[ "$URC" = 2 ] || { echo "FAIL: G1 directory store -- want rc 2, got rc $URC"; fail=1; }
if [ "$ROOTUSER" = 0 ]; then
  store 'repo build\n'
  chmod 000 "$ST"
  unit "$T/repo"
  [ "$URC" = 2 ] || { echo "FAIL: G1 mode 000 store -- want rc 2, got rc $URC"; fail=1; }
fi
store 'repo build\n'
unit "$T/repo"
[ "$URC" = 0 ] && [ "$UOUT" = build ] || { echo "FAIL: G1 valid record -- want rc 0 and build, got rc $URC: $UOUT"; fail=1; }
# The read is bounded in bytes: a record 70000 bytes back is out of the window.
nostore
{ printf 'repo build\n'; awk 'BEGIN { s = sprintf("%70000s", ""); gsub(/ /, "x", s); print s }'; } > "$ST"
unit "$T/repo"
[ "$URC" = 1 ] && [ -z "$UOUT" ] || { echo "FAIL: G1 byte bound -- want rc 1 and no stdout, got rc $URC: $UOUT"; fail=1; }
printf 'repo ops\n' >> "$ST"
unit "$T/repo"
[ "$URC" = 0 ] && [ "$UOUT" = ops ] || { echo "FAIL: G1 byte bound tail -- want rc 0 and ops, got rc $URC: $UOUT"; fail=1; }
# A full window starts mid-line; that fragment ("repo build" cut from "xxrepo build") never counts.
nostore
{ printf 'xxrepo build\n'; awk 'BEGIN { for (i = 0; i < 6552; i++) print "other ops"; print "abcd" }'; } > "$ST"
unit "$T/repo"
[ "$URC" = 1 ] && [ -z "$UOUT" ] || { echo "FAIL: G1 window fragment -- want rc 1 and no stdout, got rc $URC: $UOUT"; fail=1; }

# --- G2: git startup, no store -> today's ask is the last line
nostore
run G2 "$T/repo" startup
X0=$OUT
[ "$(last "$X0")" = "$TODAY" ] || { echo "FAIL: G2 -- last line is not today's ask: $(last "$X0")"; fail=1; }

# --- G3: only another key's record
store 'other ops\n'
run G3 "$T/repo" startup
same G3 "$OUT" "$X0"

# --- G4: a valid record under CLUTCH_GUESS=off
store 'repo build\n'
GV=off
run G4 "$T/repo" startup
GV=""
same G4 "$OUT" "$X0"

# --- G5: the store is a directory, or unreadable
dirstore
run "G5 directory" "$T/repo" startup
same "G5 directory" "$OUT" "$X0"
if [ "$ROOTUSER" = 0 ]; then
  store 'repo build\n'
  chmod 000 "$ST"
  run "G5 mode 000" "$T/repo" startup
  same "G5 mode 000" "$OUT" "$X0"
fi

# --- G6: a valid record swaps the last line, nothing else
store 'repo build\n'
run G6 "$T/repo" startup
[ "$(last "$OUT")" = "$(guessed build)" ] || { echo "FAIL: G6 -- last line is not the guessed ask: $(last "$OUT")"; fail=1; }
[ "$(butlast "$OUT")" = "$(butlast "$X0")" ] || { echo "FAIL: G6 -- output differs above the ask line"; fail=1; }

# --- G7: the last valid line for the key wins; invalid lines are skipped
store 'repo build\nrepo review\nrepo bogus\nrepo ops extra\nother ideate\n'
run G7 "$T/repo" startup
[ "$(last "$OUT")" = "$(guessed review)" ] || { echo "FAIL: G7 -- want the review guess, got: $(last "$OUT")"; fail=1; }

# --- G8: only invalid lines (bogus word, 3 fields, CRLF)
store 'repo bogus\nrepo build extra\nrepo ops\r\n'
run G8 "$T/repo" startup
same G8 "$OUT" "$X0"

# --- G9: resume with a declared gear: no ask, record or not
nostore
printf 'craft\n' > "$T/repo/.clutch/tempo"
run "G9 no store" "$T/repo" resume
R0=$OUT
store 'repo build\n'
printf 'craft\n' > "$T/repo/.clutch/tempo"
run G9 "$T/repo" resume
same G9 "$OUT" "$R0"

# --- G10: compact never asks
nostore
run "G10 no store" "$T/repo" compact
C0=$OUT
store 'repo build\n'
run G10 "$T/repo" compact
same G10 "$OUT" "$C0"

# --- G11: outside git, folder "my dir" (key my-dir)
D="$T/plain/my dir"
nostore
# With no record the output ends where it ended before this slice: the
# constitution, the Worklog block, the Session tag line, and no line after.
printf '%s plain moved: the seed\n' "$(date +%s)" > "$HOME/.clutch/worklog.md"
run "G11 today" "$D" startup ',"session_id":"0123abcd-4567"'
rm -f "$HOME/.clutch/worklog.md"
WANT=$(cat "$ROOT/rules/constitution.md"; printf '\nWorklog:\nplain moved: the seed\nSession tag: @0123abcd\n')
[ "$OUT" = "$WANT" ] || { echo "FAIL: G11 today -- no-record output outside git is not constitution, Worklog block, Session tag"; fail=1; }
run "G11 no store" "$D" startup
N0=$OUT
case "$N0" in *'Intent for this session'*) echo "FAIL: G11 -- no-store run outside git asks"; fail=1 ;; esac
store 'my-dir ideate\n'
for src in startup clear; do
  run "G11 $src" "$D" "$src"
  [ "$(last "$OUT")" = "$(guessed ideate)" ] || { echo "FAIL: G11 $src -- last line is not the guessed ask: $(last "$OUT")"; fail=1; }
  [ "$(butlast "$OUT")" = "$N0" ] || { echo "FAIL: G11 $src -- output differs above the ask line"; fail=1; }
done
for src in resume compact fork; do
  extra=""
  [ "$src" = fork ] && extra=',"seconds_since_last_response": 9999'
  nostore
  run "G11 $src no store" "$D" "$src" "$extra"
  B=$OUT
  store 'my-dir ideate\n'
  run "G11 $src" "$D" "$src" "$extra"
  same "G11 $src" "$OUT" "$B"
done
GV=off
run "G11 off" "$D" startup
GV=""
same "G11 off" "$OUT" "$N0"
dirstore
run "G11 directory" "$D" startup
same "G11 directory" "$OUT" "$N0"

# --- G12: the key is matched exactly, never as a pattern
D="$T/plain/a.b"
nostore
run "G12 no store" "$D" startup
B=$OUT
store 'aXb build\n'
run G12 "$D" startup
same "G12 aXb" "$OUT" "$B"
store 'a.b build\n'
run "G12 a.b" "$D" startup
[ "$(last "$OUT")" = "$(guessed build)" ] || { echo "FAIL: G12 a.b -- want the build guess, got: $(last "$OUT")"; fail=1; }

# fpin <file> <label> <fixed string>: rc 0 passes, 1 is a missing pin, >=2 a grep error.
fpin() {
  grep -qF -- "$3" "$1"
  frc=$?
  case $frc in
    0) ;;
    1) echo "FAIL: $2 -- not found: $3"; fail=1 ;;
    *) echo "FAIL: $2 -- grep error rc=$frc: $3"; fail=1 ;;
  esac
}

# --- G13: the record line is silent on failure and needs an existing ~/.clutch
fpin "$S" "G13 grouped redirect" '>> "$HOME/.clutch/intents"; } 2>/dev/null'
fpin "$S" "G13 brain guard" '[ -d "$HOME/.clutch" ] && { printf'

# --- G14: round trip, the skill's own record snippet then the staged anchor
nsn=$(awk '/^[ \t]*```sh/{n++; f=1; b[n] = ""; next} /^[ \t]*```/{f=0} f{b[n] = b[n] $0 "\n"}
  END {k = 0; for (i = 1; i <= n; i++) if (index(b[i], ".clutch/intents")) {k++; s = b[i]}
       printf "%s", s > out; print k}' out="$T/rsnip.raw" "$S")
if [ "$nsn" != 1 ]; then
  echo "FAIL: G14 -- want exactly one sh block naming .clutch/intents, got $nsn"; fail=1
else
  # snip <focus>: the snippet with <focus> filled, at $T/rsnip.sh.
  snip() {
    RF=$1 awk '{ i = index($0, "<focus>"); while (i) { $0 = substr($0, 1, i - 1) ENVIRON["RF"] substr($0, i + 7); i = index($0, "<focus>") } print }' \
      "$T/rsnip.raw" > "$T/rsnip.sh"
  }
  # record <label> <dir> <focus>: run the snippet; exit 0, no stdout or stderr.
  record() {
    snip "$3"
    ROUT=$(cd "$2" && sh "$T/rsnip.sh" 2>"$T/rerr"); rrc=$?
    [ "$rrc" = 0 ] || { echo "FAIL: $1 -- snippet exited $rrc"; fail=1; }
    [ -z "$ROUT" ] || { echo "FAIL: $1 -- snippet wrote stdout: $ROUT"; fail=1; }
    [ -s "$T/rerr" ] && { echo "FAIL: $1 -- snippet wrote stderr: $(head -3 "$T/rerr")"; fail=1; }
    return 0
  }
  nostore
  record "G14 (a)" "$T/repo" ops
  [ "$(tail -n 1 "$ST" 2>/dev/null)" = "repo ops" ] || { echo "FAIL: G14 (a) -- store's last line is not 'repo ops': $(tail -n 1 "$ST" 2>/dev/null)"; fail=1; }
  run "G14 (a) anchor" "$T/repo" startup
  [ "$(last "$OUT")" = "$(guessed ops)" ] || { echo "FAIL: G14 (a) -- anchor did not guess ops: $(last "$OUT")"; fail=1; }
  record "G14 (b)" "$T/plain/my dir" review
  [ "$(tail -n 1 "$ST" 2>/dev/null)" = "my-dir review" ] || { echo "FAIL: G14 (b) -- store's last line is not 'my-dir review': $(tail -n 1 "$ST" 2>/dev/null)"; fail=1; }
  run "G14 (b) anchor" "$T/plain/my dir" startup
  [ "$(last "$OUT")" = "$(guessed review)" ] || { echo "FAIL: G14 (b) -- anchor did not guess review: $(last "$OUT")"; fail=1; }
  # (c) also kills a mutant that swaps the brain guard for mkdir -p.
  KEEP=$HOME
  HOME=$T/bare
  mkdir -p "$HOME"
  record "G14 (c)" "$T/repo" build
  [ -e "$HOME/.clutch" ] && { echo "FAIL: G14 (c) -- the record created ~/.clutch"; fail=1; }
  HOME=$KEEP
  # (d) a key with a newline would split the record; the snippet skips it.
  NLD="$T/plain/nl
x"
  mkdir -p "$NLD"
  store 'other ops\n'
  record "G14 (d)" "$NLD" build
  [ "$(cat "$ST")" = "other ops" ] || { echo "FAIL: G14 (d) -- a newline key changed the store: $(cat "$ST")"; fail=1; }
  # (e) under zsh (the Bash tool's shell) a directory store stays silent.
  if command -v zsh >/dev/null 2>&1; then
    dirstore
    snip build
    ZOUT=$(cd "$T/repo" && zsh -f "$T/rsnip.sh" 2>"$T/zerr"); zrc=$?
    [ "$zrc" = 0 ] || { echo "FAIL: G14 (e) -- zsh snippet exited $zrc"; fail=1; }
    [ -z "$ZOUT" ] || { echo "FAIL: G14 (e) -- zsh snippet wrote stdout: $ZOUT"; fail=1; }
    [ -s "$T/zerr" ] && { echo "FAIL: G14 (e) -- zsh snippet wrote stderr: $(head -3 "$T/zerr")"; fail=1; }
  fi
fi

# --- G15: the skill's bare form, guessed branch and answers
fpin "$S" "G15 bare form" 'ask one question: build, ideate, ops, or review?'
fpin "$S" "G15 trigger" 'looks like <focus> again'
fpin "$S" "G15 question" '"Looks like <focus> on <thread>, go?"'
fpin "$S" "G15 threadless question" '"Looks like <focus>, go?"'
fpin "$S" "G15 go declares" 'A plain go or yes declares <focus>'
fpin "$S" "G15 same as the argument" 'run it exactly as `/clutch:intent <focus>`, record included'
fpin "$S" "G15 other reply" 'Any other reply is an ignored'
fpin "$S" "G15 when_to_use" 'and so does a plain "go" or "yes" when the question named a likely focus'
fpin "$S" "G15 go is not an unknown argument" 'except a plain go or yes when a guess is in context'
# Coupling: the anchor's guessed line carries the skill's trigger with <focus> filled.
case "$(guessed build)" in *'looks like build again'*) ;; *) echo "FAIL: G15 coupling -- guessed line lacks the trigger"; fail=1 ;; esac
TRIG=$(grep -oF 'looks like <focus> again' "$S" | head -n 1 | sed 's/<focus>/build/')
nostore
store 'repo build\n'
run "G15 coupling" "$T/repo" startup
case "$(last "$OUT")" in *"${TRIG:-unset trigger}"*) ;; *) echo "FAIL: G15 coupling -- anchor line does not carry the skill trigger '$TRIG'"; fail=1 ;; esac

# --- G16: README names the kill switch and the store
fpin "$R" "G16 kill switch" '`CLUTCH_GUESS=off` turns the guess off'
fpin "$R" "G16 store" '`~/.clutch/intents`'

[ "$fail" -eq 0 ] || exit 1
echo PASS
