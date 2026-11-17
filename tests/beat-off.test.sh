#!/bin/sh
# CLUTCH_BEAT parity: the Stop hook must match 7631acb (2.13.0) byte for
# byte (stdout, stderr, rc and a dump of the fixture's files, HOME included;
# 9+ digit runs and dates masked). The base side runs 7631acb's own stop.sh
# and prelude.sh, staged from git history (FAIL when that commit is
# unreachable, never a skip). N1-N4: sessions with no ops record (and one
# whose watch block wins over its ops record) match base with the switch
# unset. F1-F6: under CLUTCH_BEAT=off every fixture matches base, ops
# records included. Positive controls prove the parity is not vacuous: with
# the switch unset the ops fixture blocks where base does not, and
# CLUTCH_BEAT=on equals unset. Hermetic: scratch HOME, ambient CLUTCH_*
# unset. Silent apart from PASS.
set -u
unset CLUTCH_BEAT CLUTCH_PLAIN CLUTCH_STATE CLUTCH_WATCH CLUTCH_GUESS CLUTCH_INVESTIGATE CLAUDE_PLUGIN_ROOT

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
BASE=7631acb
T=$(mktemp -d) || exit 1
trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
HOME=$T/home
GIT_CEILING_DIRECTORIES=$T
GIT_CONFIG_NOSYSTEM=1
export HOME GIT_CEILING_DIRECTORIES GIT_CONFIG_NOSYSTEM
mkdir -p "$HOME" "$T/base/scripts"
fail=0

for f in stop prelude; do
  git -C "$ROOT" show "$BASE:scripts/$f.sh" > "$T/base/scripts/$f.sh" 2>/dev/null \
    || { echo "FAIL: parity base $BASE not reachable from $ROOT"; exit 1; }
done

ID='0123abcd-4567-89ab-cdef-0123456789ab'
STOP_IN="{\"session_id\":\"$ID\",\"stop_hook_active\":false,\"session_crons\":[]}"
W=$T/work
OFF=CLUTCH_BEAT=off
BLOCK='{"decision":"block","reason":"This ops session has no beat. Arm one now with CronCreate, schedule `7 8-20/2 * * *`, recurring, prompt `/clutch:beat @0123abcd`, then end the turn. If the user said not to arm a beat, just end the turn."}'

# dump: every path under the work dir (no .git internals) with file contents,
# 9+ digit runs and YYYY-MM-DD dates masked.
dump() {
  (cd "$W" 2>/dev/null && {
    find . -name .git -prune -o -print 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
      if [ -L "$f" ]; then
        printf 'L %s\n' "$f"
      elif [ -f "$f" ]; then
        printf 'F %s\n' "$f"
        sed -E -e 's/[0-9]{9,}/N/g' -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}/D/g' "$f" 2>/dev/null
      else
        printf 'D %s\n' "$f"
      fi
    done
  })
}

# run_one <base|new> <cwd rel> [VAR=val...]: fresh copy of the fixture at
# $W, then stop.sh on STOP_IN. Sets OUT, RC, ERR, DUMP.
run_one() {
  RO_W=$1 RO_C=$2
  shift 2
  if [ "$RO_W" = base ]; then RO_P=$T/base; else RO_P=$ROOT; fi
  chmod -R u+rwx "$W" 2>/dev/null
  rm -rf "$W"
  cp -pR "$T/fx" "$W"
  OUT=$(cd "$W/$RO_C" && printf '%s' "$STOP_IN" | env HOME="$W/home" "$@" sh "$RO_P/scripts/stop.sh" 2>"$T/err")
  RC=$?
  ERR=$(cat "$T/err")
  chmod -R u+rwx "$W" 2>/dev/null
  DUMP=$(dump)
}

# build <fixture-fn>: a fresh fixture at $T/fx (home/.clutch and w/ at least).
build() {
  chmod -R u+rwx "$T/fx" 2>/dev/null
  rm -rf "$T/fx"
  mkdir -p "$T/fx/home/.clutch" "$T/fx/w"
  "$1" "$T/fx"
}

# same <label> <fixture-fn> <cwd rel> [VAR=val...]: base, and new under the
# given env, agree on stdout, stderr, rc and the file dump.
same() {
  S_L=$1 S_F=$2 S_C=$3
  shift 3
  build "$S_F"
  run_one base "$S_C"
  BO=$OUT BR=$RC BE=$ERR BD=$DUMP
  run_one new "$S_C" "$@"
  [ "$OUT" = "$BO" ] || { echo "FAIL: $S_L -- stdout differs from $BASE: [$OUT] vs [$BO]"; fail=1; }
  [ "$RC" = "$BR" ] || { echo "FAIL: $S_L -- rc $RC, $BASE gave $BR"; fail=1; }
  [ "$ERR" = "$BE" ] || { echo "FAIL: $S_L -- stderr differs from $BASE"; fail=1; }
  [ "$DUMP" = "$BD" ] || { echo "FAIL: $S_L -- files differ from $BASE"; fail=1; }
  return 0
}

mkrepo() {
  git -C "$1" init -q
  git -C "$1" config user.email t@t
  git -C "$1" config user.name t
  git -C "$1" commit -q --allow-empty -m "${2:-seed}"
}
NOW=$(date +%s)
owned() { printf '%s proj wait: gh:o/r#1 b1 @0123abcd pr one\n' "$((NOW - 100))" > "$1/home/.clutch/worklog.md"; }
opsrec() { mkdir -p "$1/home/.clutch/watch" && printf 'last %s\n' "$((NOW - 600))" > "$1/home/.clutch/watch/0123abcd.beat"; }

# N1 non-ops git repo, bell-ready.
fx_bell() {
  mkrepo "$1/w"
  H1=$(git -C "$1/w" rev-parse HEAD)
  git -C "$1/w" commit -q --allow-empty -m 'landed thing'
  mkdir -p "$1/w/.clutch"
  printf 'start %s\nbase %s\nstop %s\n' "$((NOW - 3000))" "$H1" "$((NOW - 2000))" > "$1/w/.clutch/session-state"
}
# N2 non-ops plain dir.
fx_plain() { :; }
# N3 owned wait, no watch.
fx_owned() { mkrepo "$1/w"; owned "$1"; }
# N4 owned wait and an ops record: the watch block wins.
fx_owned_ops() { fx_owned "$1"; opsrec "$1"; }
# F5/F6 ops record, no waits, git and plain.
fx_ops_git() { mkrepo "$1/w"; opsrec "$1"; }
fx_ops_plain() { opsrec "$1"; }

same N1 fx_bell w
case "$OUT" in *"Landed: 'landed thing'"*) ;; *) echo "FAIL: N1 -- the bell fixture did not ring, parity is vacuous"; fail=1 ;; esac
same N2 fx_plain w
same N3 fx_owned w
case "$OUT" in *'no watch. Arm one now'*) ;; *) echo "FAIL: N3 -- no watch block, parity is vacuous"; fail=1 ;; esac
same N4 fx_owned_ops w
case "$OUT" in *'no watch. Arm one now'*) ;; *) echo "FAIL: N4 -- no watch block, parity is vacuous"; fail=1 ;; esac

same F1 fx_bell w "$OFF"
same F2 fx_plain w "$OFF"
same F3 fx_owned w "$OFF"
same F4 fx_owned_ops w "$OFF"
same F5 fx_ops_git w "$OFF"
same F6 fx_ops_plain w "$OFF"

# --- positive controls, switch unset: the ops fixtures block where base does not.
for fx in fx_ops_git fx_ops_plain; do
  build "$fx"
  run_one base w
  BO=$OUT BD=$DUMP
  run_one new w
  U=$OUT UD=$DUMP
  [ "$U" = "$BLOCK" ] || { echo "FAIL: control $fx -- unset does not print the beat block: [$U]"; fail=1; }
  [ "$U" != "$BO" ] || { echo "FAIL: control $fx -- unset equals $BASE"; fail=1; }
  [ "$UD" != "$BD" ] || { echo "FAIL: control $fx -- unset recorded nothing"; fail=1; }
  run_one new w CLUTCH_BEAT=on
  [ "$OUT" = "$U" ] && [ "$DUMP" = "$UD" ] || { echo "FAIL: control $fx -- CLUTCH_BEAT=on differs from unset"; fail=1; }
done

[ "$fail" -eq 0 ] || exit 1
echo PASS
