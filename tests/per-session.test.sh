#!/bin/sh
# Per-session state: each session keeps its own tempo, session-state and
# sprint-start in .clutch/s/<tag8>/ when that folder exists, and the
# folder-wide files otherwise.
# PS (skills): each skill snippet that writes or reads tempo, sprint-start or
# a review decline, extracted from its SKILL.md with the tag filled by sed,
# runs as a file under sh and zsh -f. It picks this session's folder only
# when the folder exists, is not a symlink at either level, and neither
# CLUTCH_PER_SESSION=off nor CLUTCH_WATCH=off is set; a garbled, empty or
# unfilled tag falls back. PS7 replays every snippet against fbb2aa8's own
# snippet (git show) on fixtures without .clutch/s/.
# Hermetic: scratch HOME, ambient CLUTCH_* unset. Silent apart from PASS.
set -u
unset CLUTCH_PER_SESSION CLUTCH_WATCH CLUTCH_PLAIN CLUTCH_GUESS CLUTCH_INVESTIGATE CLUTCH_BEAT CLUTCH_STATE CLAUDE_PLUGIN_ROOT

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
BASE=fbb2aa8
T=$(mktemp -d) || exit 1
trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
HOME=$T/home
GIT_CEILING_DIRECTORIES=$T
GIT_CONFIG_NOSYSTEM=1
export HOME GIT_CEILING_DIRECTORIES GIT_CONFIG_NOSYSTEM
mkdir -p "$HOME" "$T/snip"
ROOTUSER=0
[ "$(id -u)" = 0 ] && ROOTUSER=1
fail=0
SHELLS=sh
command -v zsh >/dev/null 2>&1 && SHELLS="sh zsh"
A=0123abcd
B=fedc9876

# ===================== PS: skill snippets =====================

# extract <file> <ERE>: the first sh fence (indented or not) whose body
# matches the ERE.
extract() {
  RE="$2" awk '/^ *```sh *$/{f=1;b="";next} f && /^ *```/{f=0; if (b ~ ENVIRON["RE"]) {printf "%s", b; exit} next} f{b=b $0 "\n"}' "$1"
}
# fill <in> <out> <tag value|-> [gear]: '-' leaves the placeholder unfilled.
RULE="Never force-push a shared branch"
fill() {
  if [ "$3" = - ]; then cp "$1" "$2"; else sed "s|'@<tag>'|'$3'|" "$1" > "$2"; fi
  sed -i.bak -e "s/<gear>/${4:-ferment}/" -e "s/<the rule>/$RULE/" "$2" && rm -f "$2.bak"
}
runsh() { if [ "$1" = zsh ]; then zsh -f "$2"; else sh "$2"; fi; }

# The snippet table: name|skill|ERE|kind (W writes, X removes)|file|content
SNIPS='intent|intent|\.clutch/tempo|W|tempo|craft
ideate|ideate|\.clutch/tempo|W|tempo|ballmer
ops|ops|\.clutch/tempo|W|tempo|espresso
review|review|\.clutch/tempo|W|tempo|espresso
investigate|investigate|\.clutch/tempo|W|tempo|craft
tempo|tempo|\.clutch/tempo|W|tempo|ferment
sprint-start|sprint|the shippable|W|sprint-start|the shippable
sprint-close|sprint|rm -f|X|sprint-start|
decline|review|declined %s|W|session-state|declined '

DD3_PRE='T='"'"'@<tag>'"'"'; '
dd3() {
  printf '%s=%s; case $T in %s) ;; *) [ "${CLUTCH_PER_SESSION:-}" = off ] || [ "${CLUTCH_WATCH:-}" = off ] || [ -L "$ROOT/.clutch/s" ] || [ -L "$ROOT/.clutch/s/${T#@}" ] || [ ! -d "$ROOT/.clutch/s/${T#@}" ] || %s="$ROOT/.clutch/s/${T#@}/%s" ;; esac' \
    "$1" "\"\$ROOT/.clutch/$2\"" "'' | @ | *[./]*" "$1" "$2"
}

# Stage every snippet: new (working tree) and base (fbb2aa8).
printf '%s\n' "$SNIPS" | while IFS='|' read -r n sk re k f c; do
  extract "$ROOT/skills/$sk/SKILL.md" "$re" > "$T/snip/$n.new"
  git -C "$ROOT" show "$BASE:skills/$sk/SKILL.md" > "$T/snip/$n.base.md" 2>/dev/null \
    || { echo "FAIL: parity base $BASE not reachable from $ROOT"; exit 1; }
  extract "$T/snip/$n.base.md" "$re" > "$T/snip/$n.base"
done || exit 1
for n in intent ideate ops review investigate tempo sprint-start sprint-close decline; do
  [ -s "$T/snip/$n.new" ] && [ -s "$T/snip/$n.base" ] || { echo "FAIL: $n snippet extraction came up empty"; fail=1; }
done
[ "$fail" -eq 0 ] || exit 1

# Every snippet carries the DD3 line verbatim (F for gear and sprint, S for the decline).
printf '%s\n' "$SNIPS" | while IFS='|' read -r n sk re k f c; do
  v=F; [ "$n" = decline ] && v=S
  grep -qF -- "$DD3_PRE$(dd3 "$v" "$f")" "$T/snip/$n.new" || echo "FAIL: PS0 $n -- the DD3 line is missing"
done > "$T/ps0"
[ -s "$T/ps0" ] && { cat "$T/ps0"; fail=1; }

# mkfx: a fresh repo at $R with .clutch/.
R=$T/r
mkfx() {
  chmod -R u+rwx "$T/r" "$T/else" 2>/dev/null
  rm -rf "$T/r" "$T/else"
  mkdir -p "$R/.clutch"
  git -C "$R" init -q
}
# snap <dir>: names and contents; frozen <dir>: nothing newer than the ref.
snap() { (cd "$1" && find . -print | LC_ALL=C sort | while IFS= read -r p; do printf '%s\n' "$p"; [ -f "$p" ] && cat "$p"; done); }
freeze() { find "$1" -exec touch -t 202001010000 {} + ; touch -t 202001010001 "$T/ref"; }
frozen() { [ -z "$(find "$1" -newer "$T/ref" 2>/dev/null)" ]; }

# go <name> <shell> <tag|-> [VAR=val...]: run the filled snippet in $R; sets OUT RC ERR.
go() {
  G_N=$1 G_S=$2 G_T=$3
  shift 3
  fill "$T/snip/$G_N" "$T/run.sh" "$G_T"
  OUT=$(cd "$R" && env "$@" HOME="$HOME" sh -c 'if [ "$1" = zsh ]; then exec zsh -f "$2"; else exec sh "$2"; fi' x "$G_S" "$T/run.sh" 2>"$T/err")
  RC=$?
  ERR=$(cat "$T/err")
}
# where <n> <k> <f> <c> <expected path> <other path> <label>: a writer wrote
# the expected file (content c) and not the other; a remover removed the
# expected one and kept the other (both pre-created by the caller).
where() {
  W_K=$2 W_F=$3 W_C=$4 W_E=$5 W_O=$6 W_L=$7
  [ "$RC" = 0 ] && [ -z "$OUT" ] && [ -z "$ERR" ] || { echo "FAIL: $W_L -- rc $RC out '$OUT' err '$ERR'"; fail=1; }
  if [ "$W_K" = W ]; then
    grep -qF -- "$W_C" "$W_E" 2>/dev/null || { echo "FAIL: $W_L -- $W_E not written"; fail=1; }
    [ "$W_O" = - ] || [ ! -e "$W_O" ] || { echo "FAIL: $W_L -- $W_O written too"; fail=1; }
  else
    [ ! -e "$W_E" ] || { echo "FAIL: $W_L -- $W_E not removed"; fail=1; }
    [ "$W_O" = - ] || [ -e "$W_O" ] || { echo "FAIL: $W_L -- $W_O removed too"; fail=1; }
  fi
}
# pre <k> <f> <dir>...: a remover's fixture holds the marker in each dir.
pre() { P_K=$1 P_F=$2; shift 2; [ "$P_K" = X ] || return 0; for d in "$@"; do printf '1700000000 g\n' > "$d/$P_F"; done; }

printf '%s\n' "$SNIPS" > "$T/snips"
while IFS='|' read -r n sk re k f c; do
  for sh in $SHELLS; do
    L="$n/$sh"
    # PS1: the session's folder exists.
    mkfx; mkdir -p "$R/.clutch/s/$A" "$R/.clutch/s/$B"
    pre "$k" "$f" "$R/.clutch/s/$A" "$R/.clutch"
    go "$n.new" "$sh" "@$A"
    where "$n" "$k" "$f" "$c" "$R/.clutch/s/$A/$f" "$R/.clutch/$f" "PS1 $L"
    [ ! -e "$R/.clutch/s/$B/$f" ] || { echo "FAIL: PS1 $L -- the peer folder was written"; fail=1; }
    # PS3 control: CLUTCH_PER_SESSION=on equals unset.
    mkfx; mkdir -p "$R/.clutch/s/$A"
    pre "$k" "$f" "$R/.clutch/s/$A" "$R/.clutch"
    go "$n.new" "$sh" "@$A" CLUTCH_PER_SESSION=on
    where "$n" "$k" "$f" "$c" "$R/.clutch/s/$A/$f" "$R/.clutch/$f" "PS3-on $L"
    # PS2: tag filled, folder absent (a peer's folder present).
    mkfx; mkdir -p "$R/.clutch/s/$B"
    pre "$k" "$f" "$R/.clutch" "$R/.clutch/s/$B"
    go "$n.new" "$sh" "@$A"
    where "$n" "$k" "$f" "$c" "$R/.clutch/$f" "$R/.clutch/s/$B/$f" "PS2 $L"
    [ ! -e "$R/.clutch/s/$A" ] || { echo "FAIL: PS2 $L -- the folder was created"; fail=1; }
    # PS3: either switch off means folder-wide.
    for sw in CLUTCH_PER_SESSION=off CLUTCH_WATCH=off; do
      mkfx; mkdir -p "$R/.clutch/s/$A"
      pre "$k" "$f" "$R/.clutch" "$R/.clutch/s/$A"
      go "$n.new" "$sh" "@$A" "$sw"
      where "$n" "$k" "$f" "$c" "$R/.clutch/$f" "$R/.clutch/s/$A/$f" "PS3 $sw $L"
    done
    # PS4: unfilled, empty, bare and garbled tags never pick a folder.
    for tg in - '' @ '@../..' '@a.b'; do
      mkfx; mkdir -p "$R/.clutch/s"
      [ "$k" = X ] && printf '1700000000 g\n' > "$R/.clutch/$f"
      go "$n.new" "$sh" "$tg"
      where "$n" "$k" "$f" "$c" "$R/.clutch/$f" - "PS4 tag[$tg] $L"
      [ -z "$(ls -A "$R/.clutch/s")" ] || { echo "FAIL: PS4 tag[$tg] $L -- .clutch/s is not empty: $(ls -A "$R/.clutch/s")"; fail=1; }
      [ "$(ls -A "$T/r" | tr '\n' ' ')" = ".clutch .git " ] || { echo "FAIL: PS4 tag[$tg] $L -- wrote outside .clutch"; fail=1; }
    done
    # PS4: a symlinked .clutch/s is never followed.
    mkfx; mkdir -p "$T/else/$A"
    for x in tempo sprint-start session-state; do printf 'ballmer\n' > "$T/else/$A/$x"; done
    ln -s "$T/else" "$R/.clutch/s"
    pre "$k" "$f" "$R/.clutch"
    freeze "$T/else"; S0=$(snap "$T/else")
    go "$n.new" "$sh" "@$A"
    where "$n" "$k" "$f" "$c" "$R/.clutch/$f" - "PS4 link-s $L"
    [ "$(snap "$T/else")" = "$S0" ] && frozen "$T/else" || { echo "FAIL: PS4 link-s $L -- the link target changed"; fail=1; }
    # PS4: a symlinked .clutch/s/<tag8> is never followed.
    mkfx; mkdir -p "$T/else" "$R/.clutch/s"
    for x in tempo sprint-start session-state; do printf 'ballmer\n' > "$T/else/$x"; done
    ln -s "$T/else" "$R/.clutch/s/$A"
    pre "$k" "$f" "$R/.clutch"
    freeze "$T/else"; S0=$(snap "$T/else")
    go "$n.new" "$sh" "@$A"
    where "$n" "$k" "$f" "$c" "$R/.clutch/$f" - "PS4 link-tag $L"
    [ "$(snap "$T/else")" = "$S0" ] && frozen "$T/else" || { echo "FAIL: PS4 link-tag $L -- the link target changed"; fail=1; }
    # PS2 read-only leg (gear only): a failed write stays silent, rc 0.
    if [ "$f" = tempo ] && [ "$ROOTUSER" = 0 ]; then
      mkfx; mkdir -p "$R/.clutch/s/$A"; chmod 555 "$R/.clutch/s/$A"
      go "$n.new" "$sh" "@$A"
      [ "$RC" = 0 ] && [ -z "$OUT" ] && [ -z "$ERR" ] || { echo "FAIL: PS2-ro $L -- rc $RC out '$OUT' err '$ERR'"; fail=1; }
      [ ! -e "$R/.clutch/tempo" ] || { echo "FAIL: PS2-ro $L -- fell through to the folder-wide file"; fail=1; }
      chmod 755 "$R/.clutch/s/$A"
    fi
  done
done < "$T/snips"

# PS5: sprint start then close remove the same file, with and without the folder.
for sh in $SHELLS; do
  for withf in yes no; do
    mkfx; [ "$withf" = yes ] && mkdir -p "$R/.clutch/s/$A"
    P=$R/.clutch/sprint-start; [ "$withf" = yes ] && P=$R/.clutch/s/$A/sprint-start
    go sprint-start.new "$sh" "@$A"
    [ -f "$P" ] || { echo "FAIL: PS5 $sh folder=$withf -- start did not write $P"; fail=1; }
    go sprint-close.new "$sh" "@$A"
    [ ! -e "$P" ] || { echo "FAIL: PS5 $sh folder=$withf -- close left $P"; fail=1; }
    [ -z "$(find "$R/.clutch" -name sprint-start)" ] || { echo "FAIL: PS5 $sh folder=$withf -- a marker is left"; fail=1; }
  done
done

# PS6: the decline check, composed as the review prose says (the write fence's
# ROOT=, H= and S= lines, then the check fence), reads what the write wrote.
tr -s '[:space:]' ' ' < "$ROOT/skills/review/SKILL.md" | grep -qF 'the same `ROOT=`, `H=` and `S=` lines above' \
  || { echo "FAIL: PS6 -- the check prose does not name the ROOT=, H= and S= lines"; fail=1; }
extract "$ROOT/skills/review/SKILL.md" 'grep -qx "declined' > "$T/snip/check.fence"
compose() { { grep -E '^ *(ROOT=|H=|T=)' "$1"; cat "$2"; } > "$3"; }
compose "$T/snip/decline.new" "$T/snip/check.fence" "$T/snip/check.new"
grep -q 'S=' "$T/snip/check.new" || { echo "FAIL: PS6 -- the composed check has no S= line"; fail=1; }
for sh in $SHELLS; do
  mkfx; mkdir -p "$R/.clutch/s/$A" "$R/.clutch/s/$B"; printf "start 1700000000\nbase -\n" > "$R/.clutch/s/$B/session-state"
  go decline.new "$sh" "@$A"
  go check.new "$sh" "@$A"; [ "$RC" = 0 ] && [ -z "$ERR" ] || { echo "FAIL: PS6 $sh -- A's check missed A's decline (rc $RC, err '$ERR')"; fail=1; }
  go check.new "$sh" "@$B"; [ "$RC" = 1 ] && [ -z "$ERR" ] || { echo "FAIL: PS6 $sh -- B's check saw A's decline (rc $RC, err '$ERR')"; fail=1; }
  [ ! -e "$R/.clutch/session-state" ] || { echo "FAIL: PS6 $sh -- the folder-wide state was written"; fail=1; }
  # Without folders, the write and the check share the folder-wide file.
  mkfx
  go decline.new "$sh" "@$A"
  go check.new "$sh" "@$A"; [ "$RC" = 0 ] || { echo "FAIL: PS6 $sh -- folder-wide check missed the decline (rc $RC)"; fail=1; }
  grep -q '^declined ' "$R/.clutch/session-state" 2>/dev/null || { echo "FAIL: PS6 $sh -- folder-wide decline not written"; fail=1; }
done

# PS7: with no .clutch/s/, every snippet, tag filled or not, equals fbb2aa8's.
mask() { (cd "$R" && find . -name .git -prune -o -print | LC_ALL=C sort | while IFS= read -r p; do printf '%s\n' "$p"; [ -f "$p" ] && sed -E 's/[0-9]{9,}/N/g' "$p"; done); }
extract "$T/snip/decline.base.md" 'grep -qx "declined' > "$T/snip/check.base.fence"
compose "$T/snip/decline.base" "$T/snip/check.base.fence" "$T/snip/check.base"
for n in intent ideate ops review investigate tempo sprint-start sprint-close decline check; do
  for sh in $SHELLS; do
    for tg in "@$A" -; do
      for st in none state marker; do
        for v in base new; do
          mkfx
          [ "$st" = state ] && printf 'start 1700000000\nbase -\ndeclined %s\n' "$(printf '%s\n' "$RULE" | cksum | cut -d' ' -f1)" > "$R/.clutch/session-state"
          [ "$st" = marker ] && printf '1700000000 g\n' > "$R/.clutch/sprint-start"
          go "$n.$v" "$sh" "$tg"
          eval "O_$v=\$OUT R_$v=\$RC E_$v=\$ERR"
          eval "D_$v=\$(mask)"
        done
        L="PS7 $n/$sh tag[$tg] $st"
        [ "$O_new" = "$O_base" ] && [ "$R_new" = "$R_base" ] && [ "$E_new" = "$E_base" ] \
          || { echo "FAIL: $L -- output differs from $BASE (rc $R_new vs $R_base)"; fail=1; }
        [ "$D_new" = "$D_base" ] || { echo "FAIL: $L -- files differ from $BASE"; fail=1; }
      done
    done
  done
done
# PS7 is not vacuous: the base decline check found the decline.
mkfx
printf 'declined %s\n' "$(printf '%s\n' "$RULE" | cksum | cut -d' ' -f1)" > "$R/.clutch/session-state"
go check.base sh -; [ "$RC" = 0 ] || { echo "FAIL: PS7 control -- the base check missed a recorded decline"; fail=1; }

[ "$fail" -eq 0 ] || exit 1
echo PASS
