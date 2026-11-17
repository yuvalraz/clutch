#!/bin/sh
# Per-session state parity with fbb2aa8 (2.14.0). The base side runs
# fbb2aa8's own hook scripts and skill snippets, staged from git history
# (FAIL when that commit is unreachable, never a skip), with the working
# tree's rules/constitution.md on both sides. Compared: stdout, stderr, rc
# and a dump of the fixture's files (9+ digit runs masked).
# PO1 CLUTCH_PER_SESSION=off equals fbb2aa8 on every hook and fixture, .clutch/s/
#     folders included. PO2 the same under CLUTCH_WATCH=off on both sides.
# PO3 positive controls: unset creates the folder (differs), =on equals unset.
# PO4 a lone session replayed through both: anchor, stop and red are equal;
#     the heartbeat differs only by its per-session path tokens.
# PO5 fbb2aa8 ignores .clutch/s/ (rollback). PO6 input without session_id
#     equals fbb2aa8 under the default.
# Hermetic: scratch HOME, ambient CLUTCH_* unset. Silent apart from PASS.
set -u
unset CLUTCH_PER_SESSION CLUTCH_PLAIN CLUTCH_STATE CLUTCH_WATCH CLUTCH_GUESS CLUTCH_INVESTIGATE CLUTCH_BEAT CLAUDE_PLUGIN_ROOT

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
BASE=fbb2aa8
T=$(mktemp -d) || exit 1
trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
HOME=$T/home
GIT_CEILING_DIRECTORIES=$T
GIT_CONFIG_NOSYSTEM=1
export HOME GIT_CEILING_DIRECTORIES GIT_CONFIG_NOSYSTEM
mkdir -p "$HOME" "$T/base/scripts" "$T/base/rules" "$T/snip"
fail=0

for f in anchor heartbeat stop red-moment prelude; do
  git -C "$ROOT" show "$BASE:scripts/$f.sh" > "$T/base/scripts/$f.sh" 2>/dev/null \
    || { echo "FAIL: parity base $BASE not reachable from $ROOT"; exit 1; }
done
cp "$ROOT/rules/constitution.md" "$T/base/rules/constitution.md" \
  || { echo "FAIL: could not stage the working-tree constitution for the base side"; exit 1; }

A=0123abcd
ID_A=0123abcd-4567-89ab-cdef-0123456789ab
src() { printf '{"session_id":"%s","source":"%s"%s}' "${3:-$ID_A}" "$1" "${2:-}"; }
HB_IN="{\"session_id\":\"$ID_A\",\"prompt\":\"hi\"}"
STOP_IN="{\"session_id\":\"$ID_A\",\"stop_hook_active\":false}"
RED_IN="{\"session_id\":\"$ID_A\",\"tool_name\":\"Bash\",\"hook_event_name\":\"PostToolUseFailure\",\"tool_input\":{\"command\":\"pytest\"}}"
W=$T/work
NOW=$(date +%s)
stamp() { date -r "$1" +%Y%m%d%H%M.%S 2>/dev/null || date -d "@$1" +%Y%m%d%H%M.%S; }

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

# run_one <base|new> <hook> <stdin> [VAR=val...]: fresh copy of the fixture
# at $W, then the hook in $W/w (red2 = red-moment twice). Sets OUT RC ERR DUMP.
run_one() {
  RO_W=$1 RO_H=$2 RO_I=$3
  shift 3
  if [ "$RO_W" = base ]; then RO_P=$T/base; else RO_P=$ROOT; fi
  chmod -R u+rwx "$W" 2>/dev/null
  rm -rf "$W"
  cp -pR "$T/fx" "$W"
  RO_N=1
  [ "$RO_H" = red2 ] && RO_H=red-moment && RO_N=2
  : > "$T/err"
  OUT=$(cd "$W/w" && i=0 && while [ "$i" -lt "$RO_N" ]; do
    printf '%s' "$RO_I" | env HOME="$W/home" CLAUDE_PLUGIN_ROOT="$RO_P" "$@" sh "$RO_P/scripts/$RO_H.sh" 2>>"$T/err"
    RO_RC=$?
    i=$((i + 1))
  done; exit "$RO_RC")
  RC=$?
  ERR=$(cat "$T/err")
  chmod -R u+rwx "$W" 2>/dev/null
  DUMP=$(dump)
}

# Fixtures: KIND repo (a landed commit, a ringing bell, an expired sprint)
# or plain (an active folder); SDIRS none, fresh (this session's folder
# holding ballmer) or stale (a 10-day peer).
KIND=repo SDIRS=none
fx() {
  chmod -R u+rwx "$T/fx" 2>/dev/null
  rm -rf "$T/fx"
  mkdir -p "$T/fx/home/.clutch" "$T/fx/w/.clutch"
  C=$T/fx/w/.clutch
  printf 'craft\n' > "$C/tempo"
  if [ "$KIND" = repo ]; then
    git -C "$T/fx/w" init -q
    git -C "$T/fx/w" config user.email t@t
    git -C "$T/fx/w" config user.name t
    git -C "$T/fx/w" commit -q --allow-empty -m seed
    H1=$(git -C "$T/fx/w" rev-parse HEAD)
    git -C "$T/fx/w" commit -q --allow-empty -m 'landed thing'
    printf 'start %s\nbase %s\nstop %s\n' "$((NOW - 3000))" "$H1" "$((NOW - 2000))" > "$C/session-state"
    printf '%s goal\n' "$((NOW - 1300))" > "$C/sprint-start"
  else
    printf 'start 1700000000\nbase -\n' > "$C/session-state"
  fi
  case $SDIRS in
    fresh) mkdir -p "$C/s/$A"; printf 'ballmer\n' > "$C/s/$A/tempo"; printf 'start 1\nbase -\nemit 1\nemit 2\n' > "$C/s/$A/session-state" ;;
    stale) mkdir -p "$C/s/aaaa1111"; printf 'ballmer\n' > "$C/s/aaaa1111/tempo"
      find "$C/s/aaaa1111" -exec touch -t "$(stamp $((NOW - 864000)))" {} + ;;
  esac
}

# same <label> <hook> <stdin> <base env|-> <new env|->: equal on all four.
same() {
  S_L=$1 S_H=$2 S_I=$3 S_B=$4 S_N=$5
  fx
  if [ "$S_B" = - ]; then run_one base "$S_H" "$S_I"; else run_one base "$S_H" "$S_I" "$S_B"; fi
  BO=$OUT BR=$RC BE=$ERR BD=$DUMP
  if [ "$S_N" = - ]; then run_one new "$S_H" "$S_I"; else run_one new "$S_H" "$S_I" "$S_N"; fi
  [ "$OUT" = "$BO" ] || { echo "FAIL: $S_L $S_H -- stdout differs from $BASE"; fail=1; }
  [ "$RC" = "$BR" ] || { echo "FAIL: $S_L $S_H -- rc $RC, $BASE gave $BR"; fail=1; }
  [ "$ERR" = "$BE" ] || { echo "FAIL: $S_L $S_H -- stderr differs from $BASE"; fail=1; }
  [ "$DUMP" = "$BD" ] || { echo "FAIL: $S_L $S_H -- files differ from $BASE"; fail=1; }
  return 0
}
# every <label> <stdin-mode tagged|untagged> <base env|-> <new env|->
every() {
  E_L=$1 E_M=$2 E_B=$3 E_N=$4
  for s in startup resume clear compact fork coldfork; do
    case $s in
      fork) I=$(src fork) ;;
      coldfork) I=$(src fork ',"seconds_since_last_response":6000') ;;
      *) I=$(src "$s") ;;
    esac
    [ "$E_M" = untagged ] && I=$(printf '%s' "$I" | sed "s/\"session_id\":\"$ID_A\",//")
    same "$E_L-$s" anchor "$I" "$E_B" "$E_N"
  done
  for h in heartbeat stop red2; do
    case $h in heartbeat) I=$HB_IN ;; stop) I=$STOP_IN ;; red2) I=$RED_IN ;; esac
    [ "$E_M" = untagged ] && I=$(printf '%s' "$I" | sed "s/\"session_id\":\"$ID_A\",//")
    same "$E_L" "$h" "$I" "$E_B" "$E_N"
  done
}

for KIND in repo plain; do
  for SDIRS in none fresh stale; do
    L="$KIND/$SDIRS"
    every "PO1 $L" tagged - CLUTCH_PER_SESSION=off
    every "PO2 $L" tagged CLUTCH_WATCH=off CLUTCH_WATCH=off
    every "PO6 $L" untagged - -
  done
done

# The repo fixture is not vacuous: the bell rings and the sprint is expired.
KIND=repo SDIRS=none
fx
run_one base stop "$STOP_IN"
case "$OUT" in *"Landed: 'landed thing'"*) ;; *) echo "FAIL: control -- the repo fixture's bell did not ring"; fail=1 ;; esac
run_one base heartbeat "$HB_IN"
case "$OUT" in *'time is up'*) ;; *) echo "FAIL: control -- the repo fixture's sprint is not expired"; fail=1 ;; esac

# PO3: unset creates the folder, so it differs from base; =on equals unset.
for KIND in repo plain; do
  SDIRS=none
  fx
  run_one base anchor "$(src startup)"; BD=$DUMP
  run_one new anchor "$(src startup)"; UO=$OUT UD=$DUMP
  case "$UD" in *"D ./w/.clutch/s/$A"*) ;; *) echo "FAIL: PO3 $KIND -- unset did not create the folder"; fail=1 ;; esac
  [ "$UD" != "$BD" ] || { echo "FAIL: PO3 $KIND -- unset equals $BASE"; fail=1; }
  run_one new anchor "$(src startup)" CLUTCH_PER_SESSION=on
  [ "$OUT" = "$UO" ] && [ "$DUMP" = "$UD" ] || { echo "FAIL: PO3 $KIND -- =on differs from unset"; fail=1; }
done

# PO5: fbb2aa8 over the fixtures with .clutch/s/ equals fbb2aa8 without it.
for KIND in repo plain; do
  for h in anchor heartbeat stop red2; do
    case $h in anchor) I=$(src startup) ;; heartbeat) I=$HB_IN ;; stop) I=$STOP_IN ;; red2) I=$RED_IN ;; esac
    SDIRS=none; fx; run_one base "$h" "$I"; NO=$OUT NR=$RC
    for SDIRS in fresh stale; do
      fx; run_one base "$h" "$I"
      [ "$OUT" = "$NO" ] && [ "$RC" = "$NR" ] || { echo "FAIL: PO5 $KIND/$SDIRS $h -- $BASE output changed with .clutch/s/"; fail=1; }
    done
  done
done

# PO4: a lone session, replayed through fbb2aa8 and the working tree, each
# with its own snippets. Anchor, stop and red are equal at every step; the
# heartbeat is equal once the per-session path tokens are mapped back.
RE_SNIP() { RE="$2" awk '/^ *```sh *$/{f=1;b="";next} f && /^ *```/{f=0; if (b ~ ENVIRON["RE"]) {printf "%s", b; exit} next} f{b=b $0 "\n"}' "$1"; }
for v in base new; do
  for sk in intent sprint; do
    if [ "$v" = base ]; then git -C "$ROOT" show "$BASE:skills/$sk/SKILL.md" > "$T/snip/$sk.md"; else cp "$ROOT/skills/$sk/SKILL.md" "$T/snip/$sk.md"; fi
  done
  RE_SNIP "$T/snip/intent.md" '\.clutch/tempo' | sed "s|'@<tag>'|'@$A'|" > "$T/snip/declare.$v"
  RE_SNIP "$T/snip/sprint.md" 'the shippable' | sed "s|'@<tag>'|'@$A'|" > "$T/snip/sprint.$v"
  [ -s "$T/snip/declare.$v" ] && [ -s "$T/snip/sprint.$v" ] || { echo "FAIL: PO4 $v snippet extraction came up empty"; exit 1; }
  rm -rf "$T/lone/$v"
  mkdir -p "$T/lone/$v/home/.clutch" "$T/lone/$v/w"
  git -C "$T/lone/$v/w" init -q
  git -C "$T/lone/$v/w" config user.email t@t
  git -C "$T/lone/$v/w" config user.name t
  git -C "$T/lone/$v/w" commit -q --allow-empty -m seed
done
# step <hook> <stdin> <id>: run on both sides; anchor/stop/red compare
# straight, the heartbeat after the token mapping. Sets HB_base, HB_new.
step() {
  for v in base new; do
    if [ "$v" = base ]; then P=$T/base; else P=$ROOT; fi
    K=1; H=$1; [ "$H" = red2 ] && H=red-moment && K=2
    : > "$T/err"
    O=$(cd "$T/lone/$v/w" && i=0 && while [ "$i" -lt "$K" ]; do
      printf '%s' "$2" | env HOME="$T/lone/$v/home" CLAUDE_PLUGIN_ROOT="$P" sh "$P/scripts/$H.sh" 2>>"$T/err"; r=$?; i=$((i + 1))
    done; exit "$r")
    r0=$?
    eval "O_$v=\$O R_$v=\$r0"
    eval "E_$v=\$(cat \"\$T/err\")"
  done
  if [ "$1" = heartbeat ]; then
    t=$3
    NS=$(printf '%s' "$O_new" | grep -o "\.clutch/s/$t/session-state" | wc -l | tr -d ' ')
    BS=$(printf '%s' "$O_base" | grep -o '\.clutch/s/' | wc -l | tr -d ' ')
    NP=$(printf '%s' "$O_new" | grep -o "\.clutch/s/$t/sprint-start" | wc -l | tr -d ' ')
    BP=$(printf '%s' "$O_base" | grep -o '\.clutch/sprint-start' | wc -l | tr -d ' ')
    [ "$NS" = 1 ] && [ "$BS" = 0 ] && [ "$NP" = "$BP" ] || { echo "FAIL: PO4 $4 -- path tokens: state $NS/$BS, sprint $NP/$BP"; fail=1; }
    HB_base=$O_base HB_new=$O_new
    O_new=$(printf '%s' "$O_new" | sed "s|\.clutch/s/$t/|.clutch/|g")
  fi
  [ "$O_new" = "$O_base" ] && [ "$R_new" = "$R_base" ] && [ "$E_new" = "$E_base" ] \
    || { echo "FAIL: PO4 $4 -- differs from $BASE"; fail=1; }
}
# named <side>: the state path the side's last heartbeat names, from the repo root.
named() { eval "printf '%s' \"\$HB_$1\"" | sed -n "s/.* to \(\.clutch\/[^ ]*session-state\);.*/\1/p"; }

step anchor "$(src startup)" "" "startup"
for v in base new; do (cd "$T/lone/$v/w" && sh "$T/snip/declare.$v" >/dev/null 2>&1); done
step heartbeat "$HB_IN" "$A" "heartbeat after declare"
case "$HB_new" in *'tempo gear: craft'*) ;; *) echo "FAIL: PO4 -- the declaration did not reach the heartbeat"; fail=1 ;; esac
for v in base new; do printf 'emit model %s\n' "$NOW" >> "$T/lone/$v/w/$(named "$v")"; done
step stop "$STOP_IN" "" "stop 1"
for v in base new; do
  F=$T/lone/$v/w/$(named "$v")
  sed "s/^stop [0-9]*$/stop $((NOW - 2000))/" "$F" > "$F.x" && mv "$F.x" "$F"
  git -C "$T/lone/$v/w" commit -q --allow-empty -m 'landed thing'
done
step stop "$STOP_IN" "" "stop bell"
case "$O_new" in *"Landed: 'landed thing'"*) ;; *) echo "FAIL: PO4 -- the bell did not ring"; fail=1 ;; esac
step red2 "$RED_IN" "" "red2"
for v in base new; do (cd "$T/lone/$v/w" && sh "$T/snip/sprint.$v" >/dev/null 2>&1); done
step heartbeat "$HB_IN" "$A" "heartbeat in sprint"
for v in base new; do
  M=$(find "$T/lone/$v/w/.clutch" -name sprint-start)
  [ -n "$M" ] || { echo "FAIL: PO4 $v -- no sprint marker"; fail=1; continue; }
  printf '%s goal\n' "$((NOW - 1300))" > "$M"
done
step heartbeat "$HB_IN" "$A" "heartbeat expired sprint"
case "$HB_base" in *'time is up'*) ;; *) echo "FAIL: PO4 -- the expired-sprint line did not show"; fail=1 ;; esac
step stop "$STOP_IN" "" "stop at 2/2"
for v in base new; do [ -n "$(find "$T/lone/$v/w/.clutch" -name sprint-start)" ] || { echo "FAIL: PO4 $v -- stop at 2/2 removed the marker"; fail=1; }; done
step anchor "$(src clear)" "" "clear"
step anchor "$(src resume)" "" "resume"
ID_F=aaaa2222-0000-0000-0000-000000000000
step anchor "$(src fork '' "$ID_F")" "" "hot fork"
step heartbeat "{\"session_id\":\"$ID_F\",\"prompt\":\"hi\"}" aaaa2222 "heartbeat F"
step anchor "$(src fork ',"seconds_since_last_response":6000' bbbb3333-0000-0000-0000-000000000000)" "" "cold fork"
step anchor "$(src compact)" "" "compact"

[ "$fail" -eq 0 ] || exit 1
echo PASS
