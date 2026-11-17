#!/bin/sh
# Plain clutch folder: outside git, a folder whose .clutch holds tempo (a
# declaration) or a session-state whose first line starts with "start " (the
# anchor's write) gets the gear line, the budget line and the session clock.
# Everything else must match 7201788 byte for byte: the parity section stages
# 7201788's own hook scripts and constitution from git history (it fails
# loudly when that commit is unreachable, never skips) and replays every
# fixture through both, comparing stdout, stderr, rc and a dump of the
# fixture's files (9+ digit runs masked). DD7: move BASE in the same commit as
# any deliberate in-git output change. Hermetic: scratch HOME, ambient
# CLUTCH_* unset. Silent apart from PASS.
set -u
unset CLUTCH_PLAIN CLUTCH_STATE CLUTCH_WATCH CLUTCH_GUESS CLAUDE_PLUGIN_ROOT

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
BASE=7201788
T=$(mktemp -d) || exit 1
trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
HOME=$T/home
GIT_CEILING_DIRECTORIES=$T
GIT_CONFIG_NOSYSTEM=1
export HOME GIT_CEILING_DIRECTORIES GIT_CONFIG_NOSYSTEM
mkdir -p "$HOME" "$T/base/scripts" "$T/base/rules"
ROOTUSER=0
[ "$(id -u)" = 0 ] && ROOTUSER=1
fail=0

for f in anchor heartbeat stop red-moment prelude; do
  git -C "$ROOT" show "$BASE:scripts/$f.sh" > "$T/base/scripts/$f.sh" 2>/dev/null \
    || { echo "FAIL: parity base $BASE not reachable from $ROOT"; exit 1; }
done
git -C "$ROOT" show "$BASE:rules/constitution.md" > "$T/base/rules/constitution.md" 2>/dev/null \
  || { echo "FAIL: parity base $BASE not reachable from $ROOT"; exit 1; }

SID='"session_id":"0123abcd-4567-89ab-cdef-0123456789ab"'
src() { printf '{%s,"source":"%s"%s}' "$SID" "$1" "${2:-}"; }
HB_IN='{"prompt":"hi"}'
STOP_IN="{$SID,\"stop_hook_active\":false}"
RED_IN='{"tool_name":"Bash","hook_event_name":"PostToolUseFailure","tool_input":{"command":"pytest"}}'
W=$T/work

# dump: every path under the work dir (no .git internals) with file contents,
# 9+ digit runs masked, plus any git exclude file.
dump() {
  (cd "$W" 2>/dev/null && {
    find . -name .git -prune -o -print 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
      if [ -L "$f" ]; then
        printf 'L %s\n' "$f"
      elif [ -f "$f" ]; then
        printf 'F %s\n' "$f"
        sed -E 's/[0-9]{9,}/N/g' "$f" 2>/dev/null
      else
        printf 'D %s\n' "$f"
      fi
    done
    find . -path '*/.git/info/exclude' 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
      printf 'X %s\n' "$f"
      cat "$f"
    done
  })
}

# run_one <base|new> <hook> <cwd rel> <stdin> [VAR=val...]: fresh copy of the
# fixture at $W, optional $POST run in the cwd, then the hook (red2 = the
# red-moment hook twice). Sets OUT, RC, ERR, DUMP; leaves $W for inspection.
POST=""
run_one() {
  RO_W=$1 RO_H=$2 RO_C=$3 RO_I=$4
  shift 4
  if [ "$RO_W" = base ]; then RO_P=$T/base; else RO_P=$ROOT; fi
  chmod -R u+rwx "$W" 2>/dev/null
  rm -rf "$W"
  cp -pR "$T/fx" "$W"
  [ -n "$POST" ] && (cd "$W/$RO_C" && eval "$POST")
  RO_N=1
  [ "$RO_H" = red2 ] && RO_H=red-moment && RO_N=2
  : > "$T/err"
  OUT=$(cd "$W/$RO_C" && i=0 && while [ "$i" -lt "$RO_N" ]; do
    printf '%s' "$RO_I" | env HOME="$W/home" CLAUDE_PLUGIN_ROOT="$RO_P" "$@" sh "$RO_P/scripts/$RO_H.sh" 2>>"$T/err"
    RO_RC=$?
    i=$((i + 1))
  done; exit "$RO_RC")
  RC=$?
  ERR=$(cat "$T/err")
  chmod -R u+rwx "$W" 2>/dev/null
  DUMP=$(dump)
}

# build <fixture-fn>: a fresh fixture at $T/fx (home/ and w/ at least).
build() {
  chmod -R u+rwx "$T/fx" 2>/dev/null
  rm -rf "$T/fx"
  mkdir -p "$T/fx/home" "$T/fx/w"
  "$1" "$T/fx"
}

# same <label> <hook> <fixture-fn> <cwd rel> <stdin> [VAR=val...]: base and
# new agree on stdout, stderr, rc and the file dump.
same() {
  S_L=$1 S_H=$2
  build "$3"
  S_C=$4 S_I=$5
  shift 5
  run_one base "$S_H" "$S_C" "$S_I" "$@"
  BO=$OUT BR=$RC BE=$ERR BD=$DUMP
  run_one new "$S_H" "$S_C" "$S_I" "$@"
  [ "$OUT" = "$BO" ] || { echo "FAIL: $S_L $S_H -- stdout differs from $BASE"; fail=1; }
  [ "$RC" = "$BR" ] || { echo "FAIL: $S_L $S_H -- rc $RC, $BASE gave $BR"; fail=1; }
  [ "$ERR" = "$BE" ] || { echo "FAIL: $S_L $S_H -- stderr differs from $BASE"; fail=1; }
  [ "$DUMP" = "$BD" ] || { echo "FAIL: $S_L $S_H -- files differ from $BASE"; fail=1; }
  return 0
}

# four <label> <fixture-fn> <cwd rel> <anchor source json> [VAR=val...]
four() {
  F_L=$1 F_F=$2 F_C=$3 F_S=$4
  shift 4
  same "$F_L" anchor "$F_F" "$F_C" "$F_S" "$@"
  same "$F_L" heartbeat "$F_F" "$F_C" "$HB_IN" "$@"
  same "$F_L" stop "$F_F" "$F_C" "$STOP_IN" "$@"
  same "$F_L" red2 "$F_F" "$F_C" "$RED_IN" "$@"
}

# new_run <hook> <fixture-fn> <cwd rel> <stdin> [VAR=val...]: new scripts only.
new_run() {
  N_H=$1
  build "$2"
  N_C=$3 N_I=$4
  shift 4
  run_one new "$N_H" "$N_C" "$N_I" "$@"
}

has() { case "$2" in *"$3"*) ;; *) echo "FAIL: $1 -- missing '$3'"; fail=1 ;; esac; }
hasnt() { case "$2" in *"$3"*) echo "FAIL: $1 -- unexpected '$3'"; fail=1 ;; esac; }
clean() { [ "$RC" = 0 ] && [ -z "$ERR" ] || { echo "FAIL: $1 -- rc $RC stderr: $ERR"; fail=1; }; }

mkrepo() {
  git -C "$1" init -q
  git -C "$1" config user.email t@t
  git -C "$1" config user.name t
  git -C "$1" commit -q --allow-empty -m "${2:-seed}"
}

# --- parity
# G-parity: inside a git work tree every hook equals 7201788.
TEMPO=""
fx_g() {
  mkrepo "$1/w"
  mkdir -p "$1/w/.clutch" "$1/home/.clutch"
  printf 'on main; 0 modified; most recent: a.txt\n' > "$1/w/.clutch/breadcrumb"
  printf 'one\ntwo\n' > "$1/w/.clutch/captures.md"
  printf 'w build\n' > "$1/home/.clutch/intents"
  if [ -n "$TEMPO" ]; then
    printf '%s\n' "$TEMPO" > "$1/w/.clutch/tempo"
    printf 'start 1700000000\nbase -\n' > "$1/w/.clutch/session-state"
  fi
}
for TEMPO in "" craft; do
  for s in startup resume clear compact; do
    same "G-anchor-$s-${TEMPO:-none}" anchor fx_g w "$(src "$s")"
  done
  same "G-anchor-coldfork-${TEMPO:-none}" anchor fx_g w "$(src fork ',"seconds_since_last_response":6000')"
done
TEMPO=""

fx_g_hb() {
  mkrepo "$1/w"
  mkdir -p "$1/w/.clutch"
  printf 'craft\n' > "$1/w/.clutch/tempo"
  printf '%s fix the thing\n' "$(date +%s)" > "$1/w/.clutch/sprint-start"
  printf 'start 1700000000\nbase -\nemit 1700000001\nemit model 1700000002\n' > "$1/w/.clutch/session-state"
}
same G-heartbeat-gear heartbeat fx_g_hb w "$HB_IN"
fx_g_bare() { mkrepo "$1/w"; }
same G-heartbeat-noclutch heartbeat fx_g_bare w "$HB_IN"

fx_g_bell() {
  mkrepo "$1/w"
  H1=$(git -C "$1/w" rev-parse HEAD)
  git -C "$1/w" commit -q --allow-empty -m 'landed thing'
  mkdir -p "$1/w/.clutch"
  NOW=$(date +%s)
  printf 'start %s\nbase %s\nstop %s\n' "$((NOW - 3000))" "$H1" "$((NOW - 2000))" > "$1/w/.clutch/session-state"
}
same G-stop-bell stop fx_g_bell w "$STOP_IN"
case "$OUT" in *"Landed: 'landed thing'"*) ;; *) echo "FAIL: G-stop-bell -- the bell fixture did not ring, parity is vacuous"; fail=1 ;; esac
same G-red red2 fx_g_bare w "$RED_IN"
case "$OUT" in *red-moment*) ;; *) echo "FAIL: G-red -- red-moment did not fire, parity is vacuous"; fail=1 ;; esac

# PF8: a repo nested in an active plain folder: git wins, the outer .clutch is untouched.
fx_nested() {
  mkdir -p "$1/w/.clutch" "$1/w/inner"
  printf 'ballmer\n' > "$1/w/.clutch/tempo"
  printf 'start 1700000000\nbase -\n' > "$1/w/.clutch/session-state"
  mkrepo "$1/w/inner"
}
four PF8-nested fx_nested w/inner "$(src startup)"
new_run anchor fx_nested w/inner "$(src startup)"
[ "$(cat "$W/w/.clutch/tempo")" = ballmer ] || { echo "FAIL: PF8 -- outer tempo touched"; fail=1; }

# OLD (C6): 7201788's heartbeat and anchor ignore an active plain folder.
fx_tempo() { mkdir -p "$1/w/.clutch"; printf 'craft\n' > "$1/w/.clutch/tempo"; }
fx_none() { :; }
for h in anchor heartbeat; do
  [ "$h" = anchor ] && i=$(src startup) || i=$HB_IN
  build fx_none
  run_one base "$h" w "$i"
  O1=$OUT
  build fx_tempo
  run_one base "$h" w "$i"
  [ "$OUT" = "$O1" ] || { echo "FAIL: OLD $h -- $BASE reacts to a plain .clutch"; fail=1; }
done

# --- hooks
# PF0: pool-only .clutch stays as 7201788.
fx_pool() {
  mkdir -p "$1/w/.clutch/sparks"
  printf '### spark\n' > "$1/w/.clutch/dream-sparks.md"
  printf 'x\n' > "$1/w/.clutch/sparks/a.md"
}
for s in startup resume compact; do four "PF0-$s" fx_pool w "$(src "$s")"; done

# PF0b: a session-state the model wrote (no "start " first line) does not activate.
SS=""
fx_pool_ss() { fx_pool "$1"; printf "$SS" > "$1/w/.clutch/session-state"; }
for SS in 'emit model 1700000000\nemit model 1700000100\n' '' 'declined abc123\n' ' start 1\n' 'start\nbase -\n'; do
  for s in startup resume compact; do four "PF0b-$s-[$SS]" fx_pool_ss w "$(src "$s")"; done
  new_run anchor fx_pool_ss w "$(src startup)"
  [ "$(cat "$W/w/.clutch/session-state")" = "$(printf "$SS")" ] || { echo "FAIL: PF0b [$SS] -- session-state rewritten"; fail=1; }
  new_run heartbeat fx_pool_ss w "$HB_IN"
  [ -z "$OUT" ] || { echo "FAIL: PF0b [$SS] -- heartbeat printed"; fail=1; }
done
SS='start 1700000000\n'
new_run heartbeat fx_pool_ss w "$HB_IN"
has "PF0b positive control" "$OUT" 'clutch-budget: 0/2'

# PF1: no .clutch: 7201788, and none is created.
for s in startup resume compact; do four "PF1-$s" fx_none w "$(src "$s")"; done
new_run anchor fx_none w "$(src startup)"
[ ! -e "$W/w/.clutch" ] || { echo "FAIL: PF1 -- .clutch created"; fail=1; }

# PF2: the heartbeat carries gear and budget; same body as in a repo.
EMITS=""
fx_pt() { fx_tempo "$1"; [ -n "$EMITS" ] && printf 'emit a\nemit b\n' > "$1/w/.clutch/session-state"; return 0; }
new_run heartbeat fx_pt w "$HB_IN"
clean PF2
has PF2 "$OUT" 'tempo gear: craft'
has PF2 "$OUT" 'clutch-budget: 0/2'
P1OUT=$OUT
new_run heartbeat fx_pt w "$HB_IN" CLUTCH_PLAIN=on
[ "$OUT" = "$P1OUT" ] || { echo "FAIL: PF2 -- CLUTCH_PLAIN=on differs from unset"; fail=1; }
EMITS=1
new_run heartbeat fx_pt w "$HB_IN"
has PF2-emits "$OUT" 'clutch-budget: 2/2'
PEOUT=$OUT
fx_pt_git() { fx_pt "$1"; mkrepo "$1/w"; }
new_run heartbeat fx_pt_git w "$HB_IN"
[ "$OUT" = "$PEOUT" ] || { echo "FAIL: PF2 -- plain heartbeat differs from the repo heartbeat"; fail=1; }
EMITS=""

# PF3: startup with tempo: tempo wiped, clock reset, stdout as 7201788 outside git.
build fx_tempo
run_one base anchor w "$(src startup)"
BO=$OUT
run_one new anchor w "$(src startup)"
clean PF3
[ "$OUT" = "$BO" ] || { echo "FAIL: PF3 -- stdout differs from the $BASE non-git startup"; fail=1; }
[ ! -e "$W/w/.clutch/tempo" ] || { echo "FAIL: PF3 -- tempo not wiped"; fail=1; }
printf '%s\n' "$DUMP" | grep -qx 'F ./w/.clutch/session-state' || { echo "FAIL: PF3 -- no session-state"; fail=1; }
[ "$(sed 's/^start [0-9][0-9]*$/start N/' "$W/w/.clutch/session-state" 2>/dev/null)" = "$(printf 'start N\nbase -')" ] \
  || { echo "FAIL: PF3 -- session-state is not start/base -"; fail=1; }
has PF3 "$OUT" 'Intent for this session'
for x in 'Smallest legal move' 'Last landed' 'Thread:'; do hasnt PF3 "$OUT" "$x"; done
WOUT=$OUT
if [ "$ROOTUSER" = 0 ]; then
  POST='chmod 555 .clutch'
  run_one new anchor w "$(src startup)"
  POST=""
  clean PF3-unwritable
  [ "$(cat "$W/w/.clutch/tempo" 2>/dev/null)" = craft ] || { echo "FAIL: PF3-unwritable -- tempo not kept"; fail=1; }
  [ ! -e "$W/w/.clutch/session-state" ] || { echo "FAIL: PF3-unwritable -- session-state created"; fail=1; }
  hasnt PF3-unwritable "$OUT" 'Intent for this session'
  [ "$OUT" = "$(printf '%s\n' "$WOUT" | sed '$d')" ] || { echo "FAIL: PF3-unwritable -- stdout is not the writable one minus the ask"; fail=1; }
fi

# PF4: resume, active through a start session-state.
fx_start() {
  mkdir -p "$1/w/.clutch" "$1/home/.clutch"
  printf 'start 1700000000\nbase -\n' > "$1/w/.clutch/session-state"
  [ -n "$TEMPO" ] && printf '%s\n' "$TEMPO" > "$1/w/.clutch/tempo"
  printf 'w ideate\n' > "$1/home/.clutch/intents"
}
TEMPO=craft
new_run anchor fx_start w "$(src resume)"
clean PF4-gear
hasnt PF4-gear "$OUT" 'Intent for this session'
[ "$(cat "$W/w/.clutch/tempo")" = craft ] || { echo "FAIL: PF4-gear -- tempo touched"; fail=1; }
grep -q 'start 1700000000' "$W/w/.clutch/session-state" && { echo "FAIL: PF4-gear -- clock not reset"; fail=1; }
TEMPO=""
new_run anchor fx_start w "$(src resume)"
clean PF4-nogear
[ "$(printf '%s\n' "$OUT" | tail -n 1)" = 'Intent for this session: looks like ideate again; say go, or pick build, ideate, ops, or review. /clutch:intent sets the frame.' ] \
  || { echo "FAIL: PF4-nogear -- the guessed ask is not last"; fail=1; }

# PF5: compact and hot fork touch nothing and never ask.
fx_pf5() { fx_start "$1"; printf 'craft\n' > "$1/w/.clutch/tempo"; printf 'emit model 1700000001\n' >> "$1/w/.clutch/session-state"; }
for i in "$(src compact)" "$(src fork ',"seconds_since_last_response":10')"; do
  new_run anchor fx_pf5 w "$i"
  clean PF5
  [ "$(cat "$W/w/.clutch/session-state")" = "$(printf 'start 1700000000\nbase -\nemit model 1700000001')" ] || { echo "FAIL: PF5 -- session-state changed"; fail=1; }
  hasnt PF5 "$OUT" 'Intent for this session'
done

# PF6: $HOME (the brain) and a symlink to it are never plain folders.
fx_home() {
  mkdir -p "$1/home/.clutch"
  printf 'craft\n' > "$1/home/.clutch/tempo"
  printf 'start 1700000000\nbase -\n' > "$1/home/.clutch/session-state"
  ln -s home "$1/link"
}
for c in home link; do
  four "PF6-$c" fx_home "$c" "$(src startup)"
  [ "$(cat "$W/home/.clutch/tempo")" = craft ] || { echo "FAIL: PF6-$c -- brain tempo touched"; fail=1; }
done

# PF7: CLUTCH_PLAIN=off is 7201788 in an active plain folder.
TEMPO=craft
for s in startup resume; do four "PF7-$s" fx_start w "$(src "$s")" CLUTCH_PLAIN=off; done
TEMPO=""

# PF9: the plain path runs no git beyond detection.
mkdir -p "$T/shim"
REALGIT=$(command -v git)
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/gitlog"\nexec "%s" "$@"\n' "$T" "$REALGIT" > "$T/shim/git"
chmod +x "$T/shim/git"
TEMPO=craft
for h in anchor heartbeat stop red2; do
  case $h in anchor) i=$(src startup) ;; heartbeat) i=$HB_IN ;; stop) i=$STOP_IN ;; *) i=$RED_IN ;; esac
  rm -f "$T/gitlog"
  new_run "$h" fx_start w "$i" PATH="$T/shim:$PATH"
  BAD=$(grep -vx 'rev-parse --is-inside-work-tree' "$T/gitlog" 2>/dev/null)
  [ -s "$T/gitlog" ] && [ -z "$BAD" ] || { echo "FAIL: PF9 $h -- git calls: $(tr '\n' '|' < "$T/gitlog" 2>/dev/null)"; fail=1; }
done

# PF10: stop and red-moment stay silent and write nothing in a plain folder.
for h in stop red2; do
  case $h in stop) i=$STOP_IN ;; *) i=$RED_IN ;; esac
  new_run "$h" fx_start w "$i"
  [ -z "$OUT" ] || { echo "FAIL: PF10 $h -- printed"; fail=1; }
  [ ! -e "$W/w/.clutch/breadcrumb" ] || { echo "FAIL: PF10 $h -- breadcrumb written"; fail=1; }
  [ "$(cat "$W/w/.clutch/session-state")" = "$(printf 'start 1700000000\nbase -')" ] || { echo "FAIL: PF10 $h -- session-state changed"; fail=1; }
done
TEMPO=""

# PF11: an ambient CLUTCH_STATE=1 is ignored.
four PF11 fx_none w "$(src startup)" CLUTCH_STATE=1

# PF12: odd shapes stay inactive.
fx_cfile() { printf 'x\n' > "$1/w/.clutch"; }
fx_tdir() { mkdir -p "$1/w/.clutch/tempo"; }
four PF12-file fx_cfile w "$(src startup)"
four PF12-tempodir fx_tdir w "$(src startup)"
if [ "$ROOTUSER" = 0 ]; then
  TEMPO=craft
  POST='chmod 000 .clutch'
  four PF12-000 fx_start w "$(src startup)"
  TEMPO=""
  POST='chmod 000 .clutch/session-state'
  four PF12-ss000 fx_start w "$(src startup)"
  POST=""
fi

[ "$fail" -eq 0 ] || exit 1
echo PASS
