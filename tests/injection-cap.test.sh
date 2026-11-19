#!/bin/sh
# Injection-size guard: hook output is capped at 10,000 chars, so the two
# injected payloads, the SessionStart anchor and the UserPromptSubmit
# heartbeat, must stay under BUDGET (500 chars of headroom) at their worst
# case. (i) anchor on startup with every optional line present, including a
# full worklog block (10 fresh 300-char lines under a scratch HOME), the
# session tag line and the guessed intent ask (the longer form of the ask,
# guessing investigate, the longest focus),
# which must also keep HEADROOM (61) under BUDGET; (ii) heartbeat with a gear, a live sprint and spent
# budget; (iv) the plain clutch folder anchor, never above (i); (v) the plain
# heartbeat, byte-equal to (ii); (vi) the tagged heartbeat over (ii)'s state in
# this session's own .clutch/s/0123abcd/, exactly 11 bytes longer than (ii); (iii) negative control: the anchor with a constitution padded to
# 10,000 chars must trip the same check, so the size assert cannot pass
# vacuously. The real anchor.sh runs beside the real prelude.sh.
# PLUGIN_ROOT_UNDER_TEST overrides the CLAUDE_PLUGIN_ROOT used for (i), so a
# padded rules/ tree can be replayed through it.
set -u
# The title has its own suite (session-title.test.sh); this one pins other switches against history.
export CLUTCH_TITLE=off
# An ambient CLUTCH_WATCH=off or CLUTCH_GUESS=off would drop the tag line or
# the guessed ask and under-measure; CLUTCH_PLAIN=off would silence (iv)/(v);
# CLUTCH_INVESTIGATE=off would shorten the ask; CLUTCH_PER_SESSION=off
# would hide (vi)'s per-session path.
unset CLUTCH_WATCH CLUTCH_GUESS CLUTCH_PLAIN CLUTCH_INVESTIGATE CLUTCH_PER_SESSION

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
A="$ROOT/scripts/anchor.sh"
HB="$ROOT/scripts/heartbeat.sh"
PR=${PLUGIN_ROOT_UNDER_TEST:-$ROOT}
BUDGET=9500
HEADROOM=61

fail=0
for f in "$A" "$HB" "$ROOT/scripts/prelude.sh" "$ROOT/rules/constitution.md"; do
  [ -f "$f" ] || { echo "FAIL: missing $f"; fail=1; }
done
[ "$fail" -eq 0 ] || exit 1

# rep <n> <char>: n copies of char.
rep() { printf "%$1s" '' | tr ' ' "$2"; }

# roomy <n>: n keeps the HEADROOM floor under BUDGET (the 2.12.0 headroom).
roomy() { [ "$1" -le $((BUDGET - HEADROOM)) ]; }
# Negative control for the floor: 9439 passes, 9440 fails.
roomy 9439 && ! roomy 9440 || { echo "FAIL: headroom predicate -- 9439/9440 control broken"; fail=1; }

T=$(mktemp -d) || exit 1
HOME=$T/home; export HOME
mkdir -p "$HOME"
trap 'rm -rf "$T"' EXIT
R="$T/repo"
mkdir "$R"
git -C "$R" init -q
# Repo config, not one-off -c: clutch_last_authored reads git config at hook
# time, and without a matching identity the Last landed line disappears.
git -C "$R" config user.email t@t
git -C "$R" config user.name t
git -C "$R" commit -q --allow-empty -m "$(rep 200 s)"

# anchor_out <plugin root>: sets OUT from a startup run over the worst-case
# .clutch fixture (300-char breadcrumb, 3 captures, no tempo).
OUT=""
anchor_out() {
  rm -rf "$R/.clutch"
  mkdir "$R/.clutch"
  printf '%s; most recent: %s\n' "$(rep 135 b)" "$(rep 150 p)" > "$R/.clutch/breadcrumb"
  printf 'one\ntwo\nthree\n' > "$R/.clutch/captures.md"
  mkdir -p "$HOME/.clutch"
  : > "$HOME/.clutch/worklog.md"
  printf 'repo investigate\n' > "$HOME/.clutch/intents"
  for i in 1 2 3 4 5 6 7 8 9 10; do
    printf '%s\n' "$(date +%s) $(rep 20 p) moved: $(rep 300 m)" >> "$HOME/.clutch/worklog.md"
  done
  OUT=$(cd "$R" && printf '%s' '{"session_id":"0123abcd-4567-89ab-cdef-0123456789ab","source":"startup"}' | CLAUDE_PLUGIN_ROOT=$1 sh "$A"); rc=$?
  [ "$rc" = 0 ] || { echo "FAIL: anchor exited $rc"; fail=1; }
}

# --- (i) anchor worst case
anchor_out "$PR"
case "$OUT" in *"Last landed: '"*) ;; *) echo "FAIL: anchor -- no Last landed line, fixture under-measures"; fail=1 ;; esac
case "$OUT" in *'looks like investigate again'*) ;; *) echo "FAIL: anchor -- no guessed intent ask, not the startup worst case"; fail=1 ;; esac
printf '%s\n' "$OUT" | grep -qx 'Worklog:' || { echo "FAIL: anchor -- no worklog block, fixture under-measures"; fail=1; }
printf '%s\n' "$OUT" | grep -qx 'Session tag: @0123abcd' || { echo "FAIL: anchor -- no session tag line, fixture under-measures"; fail=1; }
N=$(printf '%s\n' "$OUT" | wc -c | tr -d ' ')
[ "$N" -lt "$BUDGET" ] || { echo "FAIL: anchor worst case -- $N chars >= $BUDGET"; fail=1; }
roomy "$N" || { echo "FAIL: anchor worst case -- $N chars > $BUDGET - $HEADROOM headroom"; fail=1; }
NG=$N

# --- (ii) heartbeat worst case
mkdir -p "$R/.clutch"
printf 'craft\n' > "$R/.clutch/tempo"
printf '%s %s\n' "$(date +%s)" "$(rep 200 g)" > "$R/.clutch/sprint-start"
printf 'start 100\nbase -\nemit 100\nemit model 101\n' > "$R/.clutch/session-state"
HOUT=$(cd "$R" && sh "$HB" </dev/null); rc=$?
[ "$rc" = 0 ] || { echo "FAIL: heartbeat exited $rc"; fail=1; }
case "$HOUT" in *'tempo gear: craft'*'min left on'*'clutch-budget: 2/2'*) ;; *) echo "FAIL: heartbeat -- worst-case lines missing"; fail=1 ;; esac
N=$(printf '%s\n' "$HOUT" | wc -c | tr -d ' ')
[ "$N" -lt "$BUDGET" ] || { echo "FAIL: heartbeat worst case -- $N chars >= $BUDGET"; fail=1; }

# --- (iv) plain clutch folder anchor worst case: active through a start
# session-state, no tempo, so the guessed ask fires; never above the git case.
P="$T/p/repo"
mkdir -p "$P/.clutch"
printf 'start 1700000000\nbase -\n' > "$P/.clutch/session-state"
POUT=$(cd "$P" && printf '%s' '{"session_id":"0123abcd-4567-89ab-cdef-0123456789ab","source":"startup"}' | GIT_CEILING_DIRECTORIES=$T CLAUDE_PLUGIN_ROOT=$PR sh "$A"); rc=$?
[ "$rc" = 0 ] || { echo "FAIL: plain anchor exited $rc"; fail=1; }
case "$POUT" in *'looks like investigate again'*) ;; *) echo "FAIL: plain anchor -- no guessed intent ask, not the plain worst case"; fail=1 ;; esac
NP=$(printf '%s\n' "$POUT" | wc -c | tr -d ' ')
[ "$NP" -le "$NG" ] || { echo "FAIL: plain anchor -- $NP chars > git worst case $NG"; fail=1; }
[ "$NP" -lt "$BUDGET" ] || { echo "FAIL: plain anchor -- $NP chars >= $BUDGET"; fail=1; }

# --- (v) plain heartbeat with gear, sprint and 2/2: the same bytes as (ii).
rm -rf "$P/.clutch"
cp -pR "$R/.clutch" "$P/.clutch"
PHOUT=$(cd "$P" && GIT_CEILING_DIRECTORIES=$T sh "$HB" </dev/null); rc=$?
[ "$rc" = 0 ] || { echo "FAIL: plain heartbeat exited $rc"; fail=1; }
[ "$PHOUT" = "$HOUT" ] || { echo "FAIL: plain heartbeat differs from the git heartbeat (ii)"; fail=1; }
N=$(printf '%s\n' "$PHOUT" | wc -c | tr -d ' ')
[ "$N" -lt "$BUDGET" ] || { echo "FAIL: plain heartbeat -- $N chars >= $BUDGET"; fail=1; }

# --- (vi) per-session heartbeat: (ii)'s state in s/0123abcd/; the budget
# line names .clutch/s/0123abcd/session-state, 11 bytes more than (ii).
mkdir -p "$R/.clutch/s/0123abcd"
cp -p "$R/.clutch/tempo" "$R/.clutch/sprint-start" "$R/.clutch/session-state" "$R/.clutch/s/0123abcd/"
SOUT=$(cd "$R" && printf '%s' '{"session_id":"0123abcd-4567-89ab-cdef-0123456789ab","prompt":"hi"}' | sh "$HB"); rc=$?
rm -rf "$R/.clutch/s"
[ "$rc" = 0 ] || { echo "FAIL: per-session heartbeat exited $rc"; fail=1; }
case "$SOUT" in *'to .clutch/s/0123abcd/session-state;'*) ;; *) echo "FAIL: per-session heartbeat -- no per-session budget path"; fail=1 ;; esac
NS=$(printf '%s\n' "$SOUT" | wc -c | tr -d ' ')
NH=$(printf '%s\n' "$HOUT" | wc -c | tr -d ' ')
[ "$NS" = $((NH + 11)) ] || { echo "FAIL: per-session heartbeat -- $NS chars, (ii) + 11 = $((NH + 11)) expected"; fail=1; }
[ "$NS" -lt "$BUDGET" ] || { echo "FAIL: per-session heartbeat -- $NS chars >= $BUDGET"; fail=1; }

# --- (iii) negative control: a 10,000-char constitution must trip the check
mkdir "$T/padroot"
cp -R "$ROOT/rules" "$T/padroot/rules"
C="$T/padroot/rules/constitution.md"
rep $((10000 - $(wc -c < "$C"))) x >> "$C"
[ "$(wc -c < "$C" | tr -d ' ')" = 10000 ] || { echo "FAIL: control -- padding did not reach 10000"; fail=1; }
anchor_out "$T/padroot"
N=$(printf '%s\n' "$OUT" | wc -c | tr -d ' ')
[ "$N" -ge "$BUDGET" ] || { echo "FAIL: negative control -- $N chars < $BUDGET, the size check cannot trip"; fail=1; }

[ "$fail" -eq 0 ] || exit 1
echo PASS
