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
# The title has its own suite (session-title.test.sh); this one pins other switches against history.
export CLUTCH_TITLE=off
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
tempo|tempo|"<gear>"|W|tempo|ferment
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

# PS8: the bare /clutch:tempo read resolves the file the way the writes and
# the hooks do: the session's folder, else folder-wide under either switch
# off or a symlinked session folder.
extract "$ROOT/skills/tempo/SKILL.md" 'head -c 32' > "$T/snip/tempo-read.new"
grep -qF -- "$DD3_PRE$(dd3 F tempo)" "$T/snip/tempo-read.new" || { echo "FAIL: PS8 -- the bare read has no DD3 line"; fail=1; }
for sh in $SHELLS; do
  mkfx; mkdir -p "$R/.clutch/s/$A"; printf 'craft\n' > "$R/.clutch/s/$A/tempo"; printf 'espresso\n' > "$R/.clutch/tempo"
  go tempo-read.new "$sh" "@$A"; [ "$RC" = 0 ] && [ "$OUT" = craft ] || { echo "FAIL: PS8 $sh folder -- read '$OUT' rc $RC"; fail=1; }
  for sw in CLUTCH_PER_SESSION=off CLUTCH_WATCH=off; do
    go tempo-read.new "$sh" "@$A" "$sw"; [ "$RC" = 0 ] && [ "$OUT" = espresso ] || { echo "FAIL: PS8 $sh $sw -- read '$OUT' rc $RC"; fail=1; }
  done
  go tempo-read.new "$sh" "@$B"; [ "$OUT" = espresso ] || { echo "FAIL: PS8 $sh no-folder -- read '$OUT'"; fail=1; }
  rm -rf "$R/.clutch/s/$A"; mkdir -p "$T/else"; printf 'ballmer\n' > "$T/else/tempo"; ln -s "$T/else" "$R/.clutch/s/$A"
  go tempo-read.new "$sh" "@$A"; [ "$OUT" = espresso ] || { echo "FAIL: PS8 $sh link-tag -- read '$OUT'"; fail=1; }
done

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

# ===================== PH: hooks =====================
# The real hooks run with JSON on stdin under the scratch HOME. A and B are
# two sessions in one repo or one plain folder; F and G are forks.

ID_A=0123abcd-4567-89ab-cdef-0123456789ab
ID_B=fedc9876-5432-10fe-dcba-9876543210fe
ID_F=aaaa2222-0000-0000-0000-000000000000
src() { printf '{"session_id":"%s","source":"%s"%s}' "$1" "$2" "${3:-}"; }
hbi() { printf '{"session_id":"%s","prompt":"hi"}' "$1"; }
sti() { printf '{"session_id":"%s","stop_hook_active":false}' "$1"; }
rdi() { printf '{"session_id":"%s","tool_name":"Bash","hook_event_name":"PostToolUseFailure","tool_input":{"command":"pytest"}}' "$1"; }
NOW=$(date +%s)
# stamp <epoch>: a touch -t stamp (BSD date, else GNU).
stamp() { date -r "$1" +%Y%m%d%H%M.%S 2>/dev/null || date -d "@$1" +%Y%m%d%H%M.%S; }
age() { find "$2" -exec touch -t "$(stamp $((NOW - $1)))" {} + ; }

# hook <name> <cwd> <stdin> [VAR=val...]: sets OUT RC ERR.
hook() {
  H_N=$1 H_C=$2 H_I=$3
  shift 3
  H_K=1
  [ "$H_N" = red2 ] && H_N=red-moment && H_K=2
  : > "$T/err"
  OUT=$(cd "$H_C" && i=0 && while [ "$i" -lt "$H_K" ]; do
    printf '%s' "$H_I" | env "$@" HOME="$HOME" CLAUDE_PLUGIN_ROOT="$ROOT" sh "$ROOT/scripts/$H_N.sh" 2>>"$T/err"
    H_RC=$?
    i=$((i + 1))
  done; exit "$H_RC")
  RC=$?
  ERR=$(cat "$T/err")
}
ok() { [ "$RC" = 0 ] && [ -z "$ERR" ] || { echo "FAIL: $1 -- rc $RC err '$ERR'"; fail=1; }; }
gear() { G_D=$1 G_I=$2; shift 2; hook heartbeat "$G_D" "$G_I" "$@"; printf '%s' "$OUT" | sed -n 's/.*tempo gear: \([a-z]*\) .*/\1/p'; }
spent() { hook heartbeat "$1" "$2"; printf '%s' "$OUT" | sed -n 's/.*clutch-budget: \([0-9]*\)\/2.*/\1/p'; }
asks() { printf '%s\n' "$OUT" | tail -n 1 | grep -q '^Intent for this session'; }
# snip <name> <tag> <cwd>: a P1 skill snippet, filled, run in cwd.
snip() { fill "$T/snip/$1.new" "$T/run.sh" "$2"; (cd "$3" && sh "$T/run.sh" >/dev/null 2>&1); }
# fx <repo|plain>: a fresh fixture at $X; a repo has one seed commit, a
# plain folder an active .clutch.
X=$T/x
fx() {
  chmod -R u+rwx "$X" "$T/else" 2>/dev/null
  rm -rf "$X" "$T/else"
  mkdir -p "$X/.clutch"
  if [ "$1" = repo ]; then
    git -C "$X" init -q
    git -C "$X" config user.email t@t
    git -C "$X" config user.name t
    git -C "$X" commit -q --allow-empty -m seed
  else
    printf 'start 1700000000\nbase -\n' > "$X/.clutch/session-state"
  fi
}
three() { for x in tempo session-state sprint-start; do printf '%s: ' "$x"; cat "$1/$x" 2>/dev/null; echo; done; }
SA=$X/.clutch/s/$A
SB=$X/.clutch/s/$B

# PH1/PH2/PH3: two sessions in a repo (PH1) and a plain folder (PH2).
for kind in repo plain; do
  P="PH1"; [ "$kind" = plain ] && P=PH2
  fx "$kind"
  printf 'craft\n' > "$X/.clutch/tempo"
  printf 'start 1700000000\nbase -\n' > "$X/.clutch/session-state"
  printf '1700000000 g\n' > "$X/.clutch/sprint-start"
  FW0=$(three "$X/.clutch")
  hook anchor "$X" "$(src "$ID_A" startup)"
  ok "$P A startup"
  [ -d "$SA" ] && [ ! -L "$SA" ] || { echo "FAIL: $P -- A's folder not created"; fail=1; }
  [ "$(head -c 6 "$SA/session-state" 2>/dev/null)" = "start " ] || { echo "FAIL: $P -- A's session-state not written"; fail=1; }
  [ ! -e "$SA/tempo" ] && [ ! -e "$SA/sprint-start" ] || { echo "FAIL: $P -- A's folder seeded on startup"; fail=1; }
  asks || { echo "FAIL: $P -- A's startup did not ask"; fail=1; }
  [ "$(three "$X/.clutch")" = "$FW0" ] || { echo "FAIL: $P -- A's startup touched the folder-wide files"; fail=1; }
  snip intent "@$A" "$X"
  printf 'emit model 1700000001\n' >> "$SA/session-state"
  printf '%s g\n' "$((NOW - 60))" > "$SA/sprint-start"
  A0=$(three "$SA")
  hook anchor "$X" "$(src "$ID_B" startup)"
  ok "$P B startup"
  [ "$(three "$SA")" = "$A0" ] || { echo "FAIL: $P -- B's startup changed A's files"; fail=1; }
  [ -d "$SB" ] || { echo "FAIL: $P -- B's folder not created"; fail=1; }
  [ "$(gear "$X" "$(hbi "$ID_A")")" = craft ] || { echo "FAIL: $P -- A lost craft at B's startup"; fail=1; }
  hook heartbeat "$X" "$(hbi "$ID_A")"
  case "$OUT" in *"min left on 'g'"*) ;; *) echo "FAIL: $P -- A lost its sprint at B's startup"; fail=1 ;; esac
  case "$OUT" in *"to .clutch/s/$A/session-state;"*) ;; *) echo "FAIL: $P -- A's budget line does not name its file"; fail=1 ;; esac
  [ "$(spent "$X" "$(hbi "$ID_A")")" = 1 ] || { echo "FAIL: $P -- A's budget is not 1"; fail=1; }
  [ -z "$(gear "$X" "$(hbi "$ID_B")")" ] || { echo "FAIL: $P -- B is not neutral"; fail=1; }
  [ "$(spent "$X" "$(hbi "$ID_B")")" = 0 ] || { echo "FAIL: $P -- B's budget is not 0"; fail=1; }
  # PH3: B declares espresso through the ops snippet; A keeps craft.
  snip ops "@$B" "$X"
  [ "$(gear "$X" "$(hbi "$ID_B")")" = espresso ] || { echo "FAIL: PH3 $kind -- B's declaration missed B"; fail=1; }
  [ "$(gear "$X" "$(hbi "$ID_A")")" = craft ] || { echo "FAIL: PH3 $kind -- B's declaration changed A"; fail=1; }
  [ "$(three "$X/.clutch")" = "$FW0" ] || { echo "FAIL: PH3 $kind -- the folder-wide files changed"; fail=1; }
done

# PH4: A at 2/2, B at 0, both past the bell's 25 minutes with a landed commit.
fx repo
H1=$(git -C "$X" rev-parse HEAD)
git -C "$X" commit -q --allow-empty -m 'landed thing'
mkdir -p "$SA" "$SB"
printf 'start %s\nbase %s\nstop %s\n' "$((NOW - 3000))" "$H1" "$((NOW - 2000))" > "$SB/session-state"
{ cat "$SB/session-state"; printf 'emit 1700000001\nemit model 1700000002\n'; } > "$SA/session-state"
[ "$(spent "$X" "$(hbi "$ID_A")")" = 2 ] && [ "$(spent "$X" "$(hbi "$ID_B")")" = 0 ] || { echo "FAIL: PH4 -- budgets not counted per session"; fail=1; }
hook stop "$X" "$(sti "$ID_A")"; ok "PH4 A stop"
[ -z "$OUT" ] || { echo "FAIL: PH4 -- A spoke at 2/2: $OUT"; fail=1; }
hook stop "$X" "$(sti "$ID_B")"; ok "PH4 B stop"
case "$OUT" in *"Landed: 'landed thing'"*) ;; *) echo "FAIL: PH4 -- B's bell did not ring: $OUT"; fail=1 ;; esac
[ "$(grep -c '^stop ' "$SA/session-state")" = 2 ] || { echo "FAIL: PH4 -- A's stop line not in A's file"; fail=1; }
[ ! -e "$X/.clutch/session-state" ] || { echo "FAIL: PH4 -- the folder-wide state was written"; fail=1; }

# PH5: red-moment, A at 2/2 stays silent, B speaks; each records in its own file.
fx repo
mkdir -p "$SA" "$SB"
printf 'start 1\nbase -\nemit 1\nemit 2\n' > "$SA/session-state"
printf 'start 1\nbase -\n' > "$SB/session-state"
hook red2 "$X" "$(rdi "$ID_A")"; ok "PH5 A red2"
[ -z "$OUT" ] || { echo "FAIL: PH5 -- A's red spoke at 2/2"; fail=1; }
grep -q '^redmoment ' "$SA/session-state" || { echo "FAIL: PH5 -- A's red not recorded in A's file"; fail=1; }
hook red2 "$X" "$(rdi "$ID_B")"; ok "PH5 B red2"
case "$OUT" in *red-moment*) ;; *) echo "FAIL: PH5 -- B's red did not fire"; fail=1 ;; esac
[ ! -e "$X/.clutch/session-state" ] || { echo "FAIL: PH5 -- the folder-wide state was written"; fail=1; }

# PH6: no session_id, a malformed one, a tag without a folder, a closed stdin: folder-wide.
fx repo
mkdir -p "$SA"
printf 'ballmer\n' > "$SA/tempo"
printf 'craft\n' > "$X/.clutch/tempo"
for inp in '{"prompt":"hi"}' '{"session_id":"../../x","prompt":"hi"}' '{"session_id":"0123abcd.x","prompt":"hi"}' "$(hbi "$ID_B")"; do
  [ "$(gear "$X" "$inp")" = craft ] || { echo "FAIL: PH6 heartbeat [$inp] -- not folder-wide"; fail=1; }
  hook heartbeat "$X" "$inp"
  case "$OUT" in *'to .clutch/session-state;'*) ;; *) echo "FAIL: PH6 heartbeat [$inp] -- budget line not folder-wide"; fail=1 ;; esac
done
OUT=$(cd "$X" && HOME="$HOME" sh "$ROOT/scripts/heartbeat.sh" </dev/null 2>&1); RC=$?
case "$OUT" in *'tempo gear: craft'*) ;; *) echo "FAIL: PH6 closed stdin -- not folder-wide"; fail=1 ;; esac
hook stop "$X" "$(sti "$ID_B")"; ok "PH6 stop"
grep -q '^stop ' "$X/.clutch/session-state" 2>/dev/null || { echo "FAIL: PH6 -- stop without a folder did not write folder-wide"; fail=1; }
hook red2 "$X" "$(rdi "$ID_B")"; ok "PH6 red2"
grep -q '^redmoment ' "$X/.clutch/session-state" 2>/dev/null || { echo "FAIL: PH6 -- red without a folder did not write folder-wide"; fail=1; }
[ ! -e "$SB" ] || { echo "FAIL: PH6 -- a non-anchor hook created a folder"; fail=1; }
hook stop "$X" '{"stop_hook_active":false}'; ok "PH6 untagged stop"
[ "$(grep -c '^stop ' "$X/.clutch/session-state")" = 2 ] || { echo "FAIL: PH6 -- untagged stop not folder-wide"; fail=1; }

# PH7: resume.
fx repo
mkdir -p "$SA"
printf 'craft\n' > "$SA/tempo"
printf 'start 1\nbase -\nemit 5\n' > "$SA/session-state"
printf '1 g\n' > "$SA/sprint-start"
hook anchor "$X" "$(src "$ID_A" resume)"; ok "PH7 own"
[ "$(cat "$SA/tempo")" = craft ] && ! grep -q '^emit' "$SA/session-state" && [ ! -e "$SA/sprint-start" ] \
  || { echo "FAIL: PH7 own -- tempo not kept, state not rewritten or sprint kept"; fail=1; }
! asks || { echo "FAIL: PH7 own -- asked"; fail=1; }
for leg in fw-newest none peer-newer; do
  fx repo
  printf 'craft\n' > "$X/.clutch/tempo"
  case $leg in
    fw-newest)
      mkdir -p "$SB"; printf 'start 1\n' > "$SB/session-state"; printf 'start 1\n' > "$X/.clutch/session-state"
      touch -t "$(stamp $((NOW - 600)))" "$SB/session-state"; touch -t "$(stamp $((NOW - 300)))" "$X/.clutch/session-state" ;;
    peer-newer)
      mkdir -p "$SB"; printf 'start 1\n' > "$SB/session-state"; printf 'start 1\n' > "$X/.clutch/session-state"
      touch -t "$(stamp $((NOW - 300)))" "$SB/session-state"; touch -t "$(stamp $((NOW - 600)))" "$X/.clutch/session-state" ;;
  esac
  FW0=$(three "$X/.clutch")
  hook anchor "$X" "$(src "$ID_A" resume)"; ok "PH7 $leg"
  [ -d "$SA" ] || { echo "FAIL: PH7 $leg -- folder not created"; fail=1; }
  [ "$(three "$X/.clutch")" = "$FW0" ] || { echo "FAIL: PH7 $leg -- the folder-wide files changed"; fail=1; }
  if [ "$leg" = peer-newer ]; then
    [ ! -e "$SA/tempo" ] && asks || { echo "FAIL: PH7 $leg -- seeded or no ask"; fail=1; }
  else
    [ "$(cat "$SA/tempo" 2>/dev/null)" = craft ] && ! asks || { echo "FAIL: PH7 $leg -- not seeded craft, or asked"; fail=1; }
  fi
done

# PH8: forks seed from the newest state.
fx repo
mkdir -p "$SA" "$SB"
printf 'craft\n' > "$SA/tempo"
printf 'start 1\nbase -\nemit model 2\n' > "$SA/session-state"
printf '%s g\n' "$((NOW - 60))" > "$SA/sprint-start"
printf 'ballmer\n' > "$SB/tempo"; printf 'start 1\n' > "$SB/session-state"
touch -t "$(stamp $((NOW - 600)))" "$SB/session-state"
SF=$X/.clutch/s/aaaa2222
hook anchor "$X" "$(src "$ID_F" fork)"; ok "PH8 hot"
for x in tempo session-state sprint-start; do cmp -s "$SA/$x" "$SF/$x" || { echo "FAIL: PH8 hot -- $x not copied from A"; fail=1; }; done
! asks || { echo "FAIL: PH8 hot -- asked"; fail=1; }
hook heartbeat "$X" "$(hbi "$ID_A")"; HA=$OUT
hook heartbeat "$X" "$(hbi "$ID_F")"
[ "$(printf '%s' "$OUT" | sed "s|s/aaaa2222/|s/$A/|g")" = "$HA" ] || { echo "FAIL: PH8 hot -- F's heartbeat differs from A's beyond the path"; fail=1; }
rm -rf "$SF"
hook anchor "$X" "$(src "$ID_F" fork ',"seconds_since_last_response":6000')"; ok "PH8 cold"
[ "$(cat "$SF/tempo" 2>/dev/null)" = craft ] && [ "$(head -c 6 "$SF/session-state")" = "start " ] && ! grep -q emit "$SF/session-state" && [ ! -e "$SF/sprint-start" ] \
  || { echo "FAIL: PH8 cold -- not tempo-only with a fresh state"; fail=1; }
! asks || { echo "FAIL: PH8 cold -- asked"; fail=1; }
fx repo
hook anchor "$X" "$(src "$ID_F" fork)"; ok "PH8 none"
[ -d "$SF" ] && [ -z "$(ls -A "$SF")" ] || { echo "FAIL: PH8 none -- not an empty folder"; fail=1; }
[ -z "$OUT" ] || ! asks || { echo "FAIL: PH8 none -- a hot fork asked"; fail=1; }

# PH9: compact, no source, an unknown source: no folder.
for s in compact '' weird; do
  fx repo
  if [ -n "$s" ]; then I=$(src "$ID_A" "$s"); else I="{\"session_id\":\"$ID_A\"}"; fi
  hook anchor "$X" "$I"; ok "PH9 [$s]"
  [ ! -e "$X/.clutch/s" ] || { echo "FAIL: PH9 [$s] -- a folder was created"; fail=1; }
done

# PH10: prune at startup only.
pfx() {
  fx "$1"
  for d in aaaa1111 bbbb2222 dddd4444 eeee5555 "$B"; do mkdir -p "$X/.clutch/s/$d"; printf 'craft\n' > "$X/.clutch/s/$d/tempo"; printf 'start 1\n' > "$X/.clutch/s/$d/session-state"; done
  printf 'x\n' > "$X/.clutch/s/aaaa1111/session-state.tmp"
  printf 'note\n' > "$X/.clutch/s/dddd4444/notes"
  mkdir -p "$T/else"; printf 'craft\n' > "$T/else/tempo"
  ln -s "$T/else" "$X/.clutch/s/cccc3333"
  age 864000 "$X/.clutch/s/aaaa1111"; age 864000 "$X/.clutch/s/dddd4444"; age 864000 "$X/.clutch/s/$B"; age 864000 "$T/else"
  age 86400 "$X/.clutch/s/bbbb2222"
  rm -f "$X/.clutch/s/eeee5555/tempo" "$X/.clutch/s/eeee5555/session-state"
  touch -h -t "$(stamp $((NOW - 864000)))" "$X/.clutch/s/cccc3333" 2>/dev/null
  touch -t "$(stamp $((NOW - 864000)))" "$X/.clutch/s"
}
pfx repo
S0=$(snap "$T/else")
hook anchor "$X" "$(src "$ID_B" startup)"; ok "PH10 startup"
[ ! -e "$X/.clutch/s/aaaa1111" ] || { echo "FAIL: PH10 -- the stale folder was kept"; fail=1; }
for d in bbbb2222 eeee5555 "$B"; do [ -d "$X/.clutch/s/$d" ] || { echo "FAIL: PH10 -- $d was pruned"; fail=1; }; done
[ -L "$X/.clutch/s/cccc3333" ] && [ "$(snap "$T/else")" = "$S0" ] || { echo "FAIL: PH10 -- the symlinked folder or its target changed"; fail=1; }
[ "$(ls -A "$X/.clutch/s/dddd4444" 2>/dev/null)" = notes ] || { echo "FAIL: PH10 -- the unknown-file folder: $(ls -A "$X/.clutch/s/dddd4444" 2>&1)"; fail=1; }
for s in resume clear fork compact; do
  pfx repo
  hook anchor "$X" "$(src "$ID_B" "$s")"; ok "PH10 $s"
  [ -d "$X/.clutch/s/aaaa1111" ] || { echo "FAIL: PH10 -- prune ran on $s"; fail=1; }
done
# A symlinked .clutch/s: no create, seed or prune, on startup, resume and fork.
for s in startup resume fork; do
  fx repo
  mkdir -p "$T/else/$B" "$T/else/$A"
  printf 'ballmer\n' > "$T/else/$A/tempo"; printf 'start 1\n' > "$T/else/$A/session-state"; printf 'ballmer\n' > "$T/else/$B/tempo"
  age 864000 "$T/else/$B"
  freeze "$T/else"; S0=$(snap "$T/else")
  ln -s "$T/else" "$X/.clutch/s"
  hook anchor "$X" "$(src "$ID_A" "$s")"; ok "PH10 link-s $s"
  [ "$(snap "$T/else")" = "$S0" ] && frozen "$T/else" || { echo "FAIL: PH10 link-s $s -- the link target changed"; fail=1; }
  [ "$s" = fork ] || [ "$(head -c 6 "$X/.clutch/session-state" 2>/dev/null)" = "start " ] || { echo "FAIL: PH10 link-s $s -- the folder-wide state not written"; fail=1; }
  [ "$(gear "$X" "$(hbi "$ID_A")")" != ballmer ] || { echo "FAIL: PH10 link-s $s -- the heartbeat read through the link"; fail=1; }
  [ "$(snap "$T/else")" = "$S0" ] && frozen "$T/else" || { echo "FAIL: PH10 link-s $s -- the heartbeat changed the link target"; fail=1; }
done
# Liveness: in a plain folder the heartbeat keeps its own folder from looking stale.
fx plain
for d in "$A" aaaa1111; do mkdir -p "$X/.clutch/s/$d"; printf 'craft\n' > "$X/.clutch/s/$d/tempo"; printf 'start 1\n' > "$X/.clutch/s/$d/session-state"; age 691200 "$X/.clutch/s/$d"; done
A0=$(three "$SA")
hook heartbeat "$X" "$(hbi "$ID_A")"; ok "PH10 live heartbeat"; HB1=$OUT
hook heartbeat "$X" "$(hbi "$ID_A")"
[ "$OUT" = "$HB1" ] || { echo "FAIL: PH10 live -- the heartbeat output moved"; fail=1; }
hook anchor "$X" "$(src "$ID_B" startup)"; ok "PH10 live startup"
[ -d "$SA" ] && [ "$(three "$SA")" = "$A0" ] || { echo "FAIL: PH10 live -- A's folder was pruned or changed"; fail=1; }
[ ! -e "$X/.clutch/s/aaaa1111" ] || { echo "FAIL: PH10 live -- the control folder was kept"; fail=1; }

# PH11: CLUTCH_PER_SESSION=off: no create, no prune, folder-wide.
pfx repo
L0=$(cd "$X/.clutch/s" && find . | LC_ALL=C sort)
hook anchor "$X" "$(src "$ID_A" startup)" CLUTCH_PER_SESSION=off; ok "PH11 anchor"
[ "$(cd "$X/.clutch/s" && find . | LC_ALL=C sort)" = "$L0" ] || { echo "FAIL: PH11 -- .clutch/s changed under off"; fail=1; }
[ "$(head -c 6 "$X/.clutch/session-state" 2>/dev/null)" = "start " ] || { echo "FAIL: PH11 -- the folder-wide state not written"; fail=1; }
mkdir -p "$SA"; printf 'ballmer\n' > "$SA/tempo"; printf 'espresso\n' > "$X/.clutch/tempo"
[ "$(gear "$X" "$(hbi "$ID_A")" CLUTCH_PER_SESSION=off)" = espresso ] || { echo "FAIL: PH11 -- the heartbeat under off is not folder-wide"; fail=1; }

# PH12: failures stay closed.
if [ "$ROOTUSER" = 0 ]; then
  fx repo
  printf 'craft\n' > "$X/.clutch/tempo"
  chmod 555 "$X/.clutch"
  hook anchor "$X" "$(src "$ID_A" startup)"; ok "PH12 ro anchor"
  [ ! -e "$X/.clutch/s" ] || { echo "FAIL: PH12 ro -- a folder appeared"; fail=1; }
  hook heartbeat "$X" "$(hbi "$ID_A")"; ok "PH12 ro heartbeat"; H1=$OUT
  hook heartbeat "$X" '{"prompt":"hi"}'
  [ "$H1" = "$OUT" ] || { echo "FAIL: PH12 ro -- the tagged heartbeat is not the folder-wide one"; fail=1; }
  chmod 755 "$X/.clutch"
  # A failed seed cp leaves an unseeded folder.
  fx repo
  mkdir -p "$SA"; printf 'craft\n' > "$SA/tempo"; printf 'start 1\n' > "$SA/session-state"; chmod 000 "$SA/tempo"
  hook anchor "$X" "$(src "$ID_F" fork)"; ok "PH12 cp"
  [ -d "$SF" ] && [ ! -e "$SF/tempo" ] || { echo "FAIL: PH12 cp -- not an unseeded folder"; fail=1; }
  chmod 644 "$SA/tempo"
  # An unreadable .clutch/s.
  fx repo
  mkdir -p "$X/.clutch/s/aaaa1111"; age 864000 "$X/.clutch/s/aaaa1111"; chmod 000 "$X/.clutch/s"
  hook anchor "$X" "$(src "$ID_A" startup)"; ok "PH12 s000"
  [ "$(head -c 6 "$X/.clutch/session-state" 2>/dev/null)" = "start " ] || { echo "FAIL: PH12 s000 -- not folder-wide"; fail=1; }
  chmod 755 "$X/.clutch/s"
  # An unreadable .clutch at the ask: no ask, as today.
  fx repo
  chmod 333 "$X/.clutch"
  hook anchor "$X" "$(src "$ID_A" startup)"; ok "PH12 unreadable"
  ! asks || { echo "FAIL: PH12 unreadable -- asked"; fail=1; }
  chmod 755 "$X/.clutch"
fi
# A peer's symlinked sprint-start is never copied into a fork.
fx repo
mkdir -p "$SA" "$T/else"; printf 'outside\n' > "$T/else/secret"
printf 'craft\n' > "$SA/tempo"; printf 'start 1\n' > "$SA/session-state"; ln -s "$T/else/secret" "$SA/sprint-start"
hook anchor "$X" "$(src "$ID_F" fork)"; ok "PH12 link-file"
[ "$(cat "$SF/tempo" 2>/dev/null)" = craft ] && [ ! -e "$SF/sprint-start" ] || { echo "FAIL: PH12 link-file -- the fork copied a peer's symlinked file"; fail=1; }
# .clutch/s a regular file.
fx repo
printf 'keep\n' > "$X/.clutch/s"
hook anchor "$X" "$(src "$ID_A" startup)"; ok "PH12 s-file"
[ "$(cat "$X/.clutch/s")" = keep ] && [ "$(head -c 6 "$X/.clutch/session-state")" = "start " ] || { echo "FAIL: PH12 s-file -- the file changed or not folder-wide"; fail=1; }
# A dangling .clutch/s/<tag8> symlink.
fx repo
mkdir -p "$X/.clutch/s"; ln -s "$T/nothere" "$SA"
hook anchor "$X" "$(src "$ID_A" startup)"; ok "PH12 dangling"
[ ! -e "$T/nothere" ] || { echo "FAIL: PH12 dangling -- created through the link"; fail=1; }
# A symlinked .clutch/s/<tag8>: every hook acts on the folder-wide files.
lfx() {
  fx repo
  H1=$(git -C "$X" rev-parse HEAD)
  git -C "$X" commit -q --allow-empty -m 'landed thing'
  printf 'start %s\nbase %s\nstop %s\n' "$((NOW - 3000))" "$H1" "$((NOW - 2000))" > "$X/.clutch/session-state"
  mkdir -p "$T/else" "$X/.clutch/s"
  printf 'ballmer\n' > "$T/else/tempo"; printf 'start 1\nbase -\n' > "$T/else/session-state"; printf '%s g\n' "$((NOW - 60))" > "$T/else/sprint-start"
  ln -s "$T/else" "$SA"
  freeze "$T/else"; LS0=$(snap "$T/else")
}
lcheck() { [ "$(snap "$T/else")" = "$LS0" ] && frozen "$T/else" || { echo "FAIL: PH12 link-tag $1 -- the link target changed"; fail=1; }; }
for s in startup resume fork; do
  lfx
  hook anchor "$X" "$(src "$ID_A" "$s")"; ok "PH12 link-tag $s"; lcheck "$s"
  [ "$s" = fork ] || ! grep -q '^stop ' "$X/.clutch/session-state" || { echo "FAIL: PH12 link-tag $s -- the folder-wide state not rewritten"; fail=1; }
done
lfx
[ "$(gear "$X" "$(hbi "$ID_A")")" != ballmer ] || { echo "FAIL: PH12 link-tag -- the heartbeat read through the link"; fail=1; }
hook heartbeat "$X" "$(hbi "$ID_A")"
case "$OUT" in *'to .clutch/session-state;'*) ;; *) echo "FAIL: PH12 link-tag -- the heartbeat budget line is not folder-wide"; fail=1 ;; esac
lcheck heartbeat
hook stop "$X" "$(sti "$ID_A")"; ok "PH12 link-tag stop"; lcheck stop
case "$OUT" in *"Landed: 'landed thing'"*) ;; *) echo "FAIL: PH12 link-tag stop -- the folder-wide bell did not ring"; fail=1 ;; esac
grep -q '^emit ' "$X/.clutch/session-state" && [ "$(grep -c '^stop ' "$X/.clutch/session-state")" = 2 ] && [ ! -e "$X/.clutch/session-state.tmp" ] \
  || { echo "FAIL: PH12 link-tag stop -- the append and the bell rewrite missed the folder-wide state"; fail=1; }
hook red2 "$X" "$(rdi "$ID_A")"; ok "PH12 link-tag red2"; lcheck red2
grep -q '^redmoment ' "$X/.clutch/session-state" || { echo "FAIL: PH12 link-tag red -- not recorded folder-wide"; fail=1; }

# PH13: a ~160 KB field, session_id first and last, stays inside a second.
BIG=$(head -c 160000 /dev/zero | tr '\0' a)
fx repo
mkdir -p "$SA"; printf 'start 1\nbase -\n' > "$SA/session-state"
for pos in first last; do
  if [ "$pos" = first ]; then
    HIN="{\"session_id\":\"$ID_A\",\"prompt\":\"$BIG\"}"; SIN="{\"session_id\":\"$ID_A\",\"last_assistant_message\":\"$BIG\"}"
  else
    HIN="{\"prompt\":\"$BIG\",\"session_id\":\"$ID_A\"}"; SIN="{\"last_assistant_message\":\"$BIG\",\"session_id\":\"$ID_A\"}"
  fi
  T0=$(date +%s); hook heartbeat "$X" "$HIN"; DT=$(($(date +%s) - T0))
  [ "$DT" -le 1 ] || { echo "FAIL: PH13 heartbeat $pos -- ${DT}s"; fail=1; }
  case "$OUT" in *"to .clutch/s/$A/session-state;"*) ;; *) echo "FAIL: PH13 heartbeat $pos -- the tag was not read"; fail=1 ;; esac
  T0=$(date +%s); hook stop "$X" "$SIN"; DT=$(($(date +%s) - T0))
  [ "$DT" -le 1 ] || { echo "FAIL: PH13 stop $pos -- ${DT}s"; fail=1; }
done
[ "$(grep -c '^stop ' "$SA/session-state")" = 2 ] || { echo "FAIL: PH13 stop -- the tag was not read"; fail=1; }
RB="\"tool_name\":\"Bash\",\"hook_event_name\":\"PostToolUseFailure\",\"tool_input\":{\"command\":\"npm test\"},\"tool_response\":\"$BIG\""
for pos in first last; do
  if [ "$pos" = first ]; then RIN="{\"session_id\":\"$ID_A\",$RB}"; else RIN="{$RB,\"session_id\":\"$ID_A\"}"; fi
  printf 'start 1\nbase -\n' > "$SA/session-state"; rm -f "$X/.clutch/session-state"
  T0=$(date +%s); hook red-moment "$X" "{$RB}"; D0=$(($(date +%s) - T0))
  T0=$(date +%s); hook red-moment "$X" "$RIN"; D1=$(($(date +%s) - T0))
  [ "$D1" -le $((D0 + 1)) ] || { echo "FAIL: PH13 red $pos -- ${D1}s against ${D0}s without session_id"; fail=1; }
  grep -q '^redmoment ' "$SA/session-state" || { echo "FAIL: PH13 red $pos -- the tag read was never reached"; fail=1; }
done

# PH14: an expired per-session sprint at 2/2 names only this session's marker.
fx repo
mkdir -p "$SA"
printf 'start 1\nbase -\nemit 1\nemit 2\n' > "$SA/session-state"
printf '%s goal\n' "$((NOW - 1500))" > "$SA/sprint-start"
printf '%s peer\n' "$((NOW - 60))" > "$X/.clutch/sprint-start"
cp -p "$X/.clutch/sprint-start" "$T/peer0"
hook heartbeat "$X" "$(hbi "$ID_A")"; ok "PH14 heartbeat"; HA=$OUT
case "$HA" in *"then remove .clutch/s/$A/sprint-start."*) ;; *) echo "FAIL: PH14 -- the expired line does not name A's marker"; fail=1 ;; esac
case "$HA" in *"to .clutch/s/$A/session-state;"*) ;; *) echo "FAIL: PH14 -- the budget line does not name A's file"; fail=1 ;; esac
mkdir -p "$T/fw/.clutch"; git -C "$T/fw" init -q
cp "$SA/session-state" "$SA/sprint-start" "$T/fw/.clutch/"
hook heartbeat "$T/fw" '{"prompt":"hi"}'
[ "${#HA}" = $((${#OUT} + 22)) ] || { echo "FAIL: PH14 -- ${#HA} bytes, folder-wide ${#OUT} + 22 expected"; fail=1; }
hook stop "$X" "$(sti "$ID_A")"; ok "PH14 stop"
[ -z "$OUT" ] && [ -e "$SA/sprint-start" ] && cmp -s "$X/.clutch/sprint-start" "$T/peer0" || { echo "FAIL: PH14 -- stop spoke or removed a marker"; fail=1; }
P=$(printf '%s' "$HA" | sed -n 's/.*then remove \([^ ]*sprint-start\)\..*/\1/p')
rm -f "$X/$P"
[ ! -e "$SA/sprint-start" ] && cmp -s "$X/.clutch/sprint-start" "$T/peer0" || { echo "FAIL: PH14 -- the named rm removed the wrong marker"; fail=1; }
hook heartbeat "$X" '{"prompt":"hi"}'
case "$OUT" in *"min left on 'peer'"*) ;; *) echo "FAIL: PH14 -- the peer's clock stopped"; fail=1 ;; esac

[ "$fail" -eq 0 ] || exit 1
echo PASS
