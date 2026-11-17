#!/bin/sh
# CLUTCH_INVESTIGATE=off parity: with the switch off, every hook (anchor,
# heartbeat, stop, red-moment) must match 5f709b5 (2.12.0) byte for byte:
# stdout, stderr, rc and a dump of the fixture's files (9+ digit runs
# masked). The base side runs 5f709b5's own hook scripts, staged from git
# history (FAIL when that commit is unreachable, never a skip), with the
# working tree's rules/constitution.md on both sides, so constitution edits
# are held constant. Fixtures cover intents stores holding investigate lines,
# which 2.12.0 skips (rollback safety). Positive controls with the switch
# unset prove the parity is not vacuous: the investigate guess and the
# five-way heartbeat differ from base, and CLUTCH_INVESTIGATE=on equals
# unset. Hermetic: scratch HOME, ambient CLUTCH_* unset. Silent apart from PASS.
set -u
unset CLUTCH_PLAIN CLUTCH_STATE CLUTCH_WATCH CLUTCH_GUESS CLUTCH_INVESTIGATE CLAUDE_PLUGIN_ROOT

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
BASE=5f709b5
T=$(mktemp -d) || exit 1
trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
HOME=$T/home
GIT_CEILING_DIRECTORIES=$T
GIT_CONFIG_NOSYSTEM=1
export HOME GIT_CEILING_DIRECTORIES GIT_CONFIG_NOSYSTEM
mkdir -p "$HOME" "$T/base/scripts" "$T/base/rules"
fail=0

for f in anchor heartbeat stop red-moment prelude; do
  git -C "$ROOT" show "$BASE:scripts/$f.sh" > "$T/base/scripts/$f.sh" 2>/dev/null \
    || { echo "FAIL: parity base $BASE not reachable from $ROOT"; exit 1; }
done
cp "$ROOT/rules/constitution.md" "$T/base/rules/constitution.md" \
  || { echo "FAIL: could not stage the working-tree constitution for the base side"; exit 1; }

SID='"session_id":"0123abcd-4567-89ab-cdef-0123456789ab"'
src() { printf '{%s,"source":"%s"%s}' "$SID" "$1" "${2:-}"; }
HB_IN='{"prompt":"hi"}'
STOP_IN="{$SID,\"stop_hook_active\":false}"
RED_IN='{"tool_name":"Bash","hook_event_name":"PostToolUseFailure","tool_input":{"command":"pytest"}}'
W=$T/work
OFF=CLUTCH_INVESTIGATE=off

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
# fixture at $W, then the hook (red2 = the red-moment hook twice). Sets OUT,
# RC, ERR, DUMP.
run_one() {
  RO_W=$1 RO_H=$2 RO_C=$3 RO_I=$4
  shift 4
  if [ "$RO_W" = base ]; then RO_P=$T/base; else RO_P=$ROOT; fi
  chmod -R u+rwx "$W" 2>/dev/null
  rm -rf "$W"
  cp -pR "$T/fx" "$W"
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
  mkdir -p "$T/fx/home/.clutch" "$T/fx/w"
  "$1" "$T/fx"
}

# same <label> <hook> <fixture-fn> <cwd rel> <stdin>: base, and new under
# CLUTCH_INVESTIGATE=off, agree on stdout, stderr, rc and the file dump.
same() {
  S_L=$1 S_H=$2
  build "$3"
  run_one base "$S_H" "$4" "$5"
  BO=$OUT BR=$RC BE=$ERR BD=$DUMP
  run_one new "$S_H" "$4" "$5" "$OFF"
  [ "$OUT" = "$BO" ] || { echo "FAIL: $S_L $S_H -- stdout differs from $BASE"; fail=1; }
  [ "$RC" = "$BR" ] || { echo "FAIL: $S_L $S_H -- rc $RC, $BASE gave $BR"; fail=1; }
  [ "$ERR" = "$BE" ] || { echo "FAIL: $S_L $S_H -- stderr differs from $BASE"; fail=1; }
  [ "$DUMP" = "$BD" ] || { echo "FAIL: $S_L $S_H -- files differ from $BASE"; fail=1; }
  return 0
}

mkrepo() {
  git -C "$1" init -q
  git -C "$1" config user.email t@t
  git -C "$1" config user.name t
  git -C "$1" commit -q --allow-empty -m "${2:-seed}"
}

# --- anchor in a git repo, over each intents store, with and without a gear
STORE="" TEMPO=""
fx_g() {
  mkrepo "$1/w"
  mkdir -p "$1/w/.clutch"
  printf 'on main; 0 modified; most recent: a.txt\n' > "$1/w/.clutch/breadcrumb"
  [ -n "$STORE" ] && printf "$STORE" > "$1/home/.clutch/intents"
  if [ -n "$TEMPO" ]; then
    printf '%s\n' "$TEMPO" > "$1/w/.clutch/tempo"
    printf 'start 1700000000\nbase -\n' > "$1/w/.clutch/session-state"
  fi
}
for STORE in "" 'w build\n' 'w investigate\n' 'w rebuild\nw investigated\n' 'w build\nw investigate\n' 'w investigate\nw build\n'; do
  for TEMPO in "" craft; do
    L="store[$STORE]-${TEMPO:-none}"
    for s in startup resume clear compact; do
      same "G-anchor-$s-$L" anchor fx_g w "$(src "$s")"
    done
    same "G-anchor-coldfork-$L" anchor fx_g w "$(src fork ',"seconds_since_last_response":6000')"
  done
done
STORE="" TEMPO=""

# Not vacuous: build then investigate under off ends on 2.12.0's build guess.
STORE='w build\nw investigate\n'
build fx_g
run_one new anchor w "$(src startup)" "$OFF"
[ "$(printf '%s\n' "$OUT" | tail -n 1)" = 'Intent for this session: looks like build again; say go, or pick build, ideate, ops, or review. /clutch:intent sets the frame.' ] \
  || { echo "FAIL: off build-then-investigate -- not 2.12.0's build guess"; fail=1; }
STORE=""

# --- heartbeat with a gear, a live sprint and 2/2 emits
fx_g_hb() {
  mkrepo "$1/w"
  mkdir -p "$1/w/.clutch"
  printf 'craft\n' > "$1/w/.clutch/tempo"
  printf '%s fix the thing\n' "$(date +%s)" > "$1/w/.clutch/sprint-start"
  printf 'start 1700000000\nbase -\nemit 1700000001\nemit model 1700000002\n' > "$1/w/.clutch/session-state"
}
same G-heartbeat heartbeat fx_g_hb w "$HB_IN"
case "$OUT" in *'clutch-budget: 2/2'*) ;; *) echo "FAIL: G-heartbeat -- worst-case fixture did not reach 2/2"; fail=1 ;; esac

# --- stop bell and red-moment
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
fx_g_bare() { mkrepo "$1/w"; }
same G-red red2 fx_g_bare w "$RED_IN"
case "$OUT" in *red-moment*) ;; *) echo "FAIL: G-red -- red-moment did not fire, parity is vacuous"; fail=1 ;; esac

# --- an active plain folder and a non-git folder, store w investigate
fx_plain() {
  mkdir -p "$1/w/.clutch"
  printf 'start 1700000000\nbase -\n' > "$1/w/.clutch/session-state"
  printf 'w investigate\n' > "$1/home/.clutch/intents"
}
for s in startup resume; do
  same "P-anchor-$s" anchor fx_plain w "$(src "$s")"
done
fx_nongit() { printf 'w investigate\n' > "$1/home/.clutch/intents"; }
same N-anchor-startup anchor fx_nongit w "$(src startup)"
case "$OUT" in *'build, ideate, ops, or review?'*) ;; *) echo "FAIL: N-anchor-startup -- no four-way ask, parity is vacuous"; fail=1 ;; esac

# --- positive controls, switch unset: the new text shows and differs from base
STORE='w investigate\n'
build fx_g
run_one base anchor w "$(src startup)"
BO=$OUT
run_one new anchor w "$(src startup)"
U=$OUT
[ "$(printf '%s\n' "$U" | tail -n 1)" = 'Intent for this session: looks like investigate again; say go, or pick build, ideate, ops, review, or investigate. /clutch:intent sets the frame.' ] \
  || { echo "FAIL: control -- unset does not end on the investigate guess"; fail=1; }
[ "$U" != "$BO" ] || { echo "FAIL: control -- unset anchor equals $BASE"; fail=1; }
run_one new anchor w "$(src startup)" CLUTCH_INVESTIGATE=on
[ "$OUT" = "$U" ] || { echo "FAIL: control -- CLUTCH_INVESTIGATE=on differs from unset"; fail=1; }
STORE=""

build fx_g_hb
run_one base heartbeat w "$HB_IN"
BO=$OUT
run_one new heartbeat w "$HB_IN"
case "$OUT" in *'build, ideate, ops, review, or investigate'*) ;; *) echo "FAIL: control -- unset heartbeat lacks the five-way carve-out"; fail=1 ;; esac
case "$BO" in *'or investigate'*) echo "FAIL: control -- $BASE heartbeat already names investigate"; fail=1 ;; esac

[ "$fail" -eq 0 ] || exit 1
echo PASS
