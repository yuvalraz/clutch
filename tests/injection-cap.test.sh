#!/bin/sh
# Injection-size guard: hook output is capped at 10,000 chars, so the two
# injected payloads, the SessionStart anchor and the UserPromptSubmit
# heartbeat, must stay under BUDGET (1,000 chars of headroom) at their worst
# case. (i) anchor on startup with every optional line present; (ii) heartbeat
# with a gear, a live sprint and spent budget; (iii) negative control: the
# anchor with a constitution padded to 10,000 chars must trip the same check,
# so the size assert cannot pass vacuously. The real anchor.sh runs beside the
# real prelude.sh. PLUGIN_ROOT_UNDER_TEST overrides the CLAUDE_PLUGIN_ROOT used
# for (i), so a padded rules/ tree can be replayed through it.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
A="$ROOT/scripts/anchor.sh"
HB="$ROOT/scripts/heartbeat.sh"
PR=${PLUGIN_ROOT_UNDER_TEST:-$ROOT}
BUDGET=9000

fail=0
for f in "$A" "$HB" "$ROOT/scripts/prelude.sh" "$ROOT/rules/constitution.md"; do
  [ -f "$f" ] || { echo "FAIL: missing $f"; fail=1; }
done
[ "$fail" -eq 0 ] || exit 1

# rep <n> <char>: n copies of char.
rep() { printf "%$1s" '' | tr ' ' "$2"; }

T=$(mktemp -d) || exit 1
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
  OUT=$(cd "$R" && printf '%s' '{"source":"startup"}' | CLAUDE_PLUGIN_ROOT=$1 sh "$A"); rc=$?
  [ "$rc" = 0 ] || { echo "FAIL: anchor exited $rc"; fail=1; }
}

# --- (i) anchor worst case
anchor_out "$PR"
case "$OUT" in *"Last landed: '"*) ;; *) echo "FAIL: anchor -- no Last landed line, fixture under-measures"; fail=1 ;; esac
case "$OUT" in *'build, ideate, ops, or review?'*) ;; *) echo "FAIL: anchor -- no intent ask, not the startup worst case"; fail=1 ;; esac
N=$(printf '%s\n' "$OUT" | wc -c | tr -d ' ')
[ "$N" -lt "$BUDGET" ] || { echo "FAIL: anchor worst case -- $N chars >= $BUDGET"; fail=1; }

# --- (ii) heartbeat worst case
mkdir -p "$R/.clutch"
printf 'craft\n' > "$R/.clutch/tempo"
printf '%s %s\n' "$(date +%s)" "$(rep 200 g)" > "$R/.clutch/sprint-start"
printf 'start 100\nbase -\nemit 100\nemit model 101\n' > "$R/.clutch/session-state"
HOUT=$(cd "$R" && sh "$HB"); rc=$?
[ "$rc" = 0 ] || { echo "FAIL: heartbeat exited $rc"; fail=1; }
case "$HOUT" in *'tempo gear: craft'*'min left on'*'clutch-budget: 2/2'*) ;; *) echo "FAIL: heartbeat -- worst-case lines missing"; fail=1 ;; esac
N=$(printf '%s\n' "$HOUT" | wc -c | tr -d ' ')
[ "$N" -lt "$BUDGET" ] || { echo "FAIL: heartbeat worst case -- $N chars >= $BUDGET"; fail=1; }

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
