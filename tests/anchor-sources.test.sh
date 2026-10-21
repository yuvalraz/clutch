#!/bin/sh
# Forked sessions: SessionStart runs on source "fork", and the anchor treats a
# fork as the same session continuing unless its parent has been silent for
# >= 5400 s (a cold fork), which resets like resume. Pins the matcher and the
# intent skill's fork sentence, then feeds fork fixtures on stdin to a staged
# anchor.sh in a scratch repo and asserts preserve or reset per fixture, plus
# that no timing value is ever echoed. HOOKS_JSON, ANCHOR_SH and INTENT_SKILL
# override the targets so the pins can be replayed against any historical
# version. As in intent.test.sh, the anchor under test is staged beside the
# real prelude.sh, so a historical anchor fails on a behavior assert, not on
# the prelude guard.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
J=${HOOKS_JSON:-$ROOT/hooks/hooks.json}
A=${ANCHOR_SH:-$ROOT/scripts/anchor.sh}
S=${INTENT_SKILL:-$ROOT/skills/intent/SKILL.md}

fail=0
for f in "$J" "$A" "$S"; do
  [ -f "$f" ] || { echo "FAIL: missing $f"; fail=1; }
done
[ "$fail" -eq 0 ] || exit 1

# rc 0 = pin holds, 1 = pattern gone, >=2 = grep itself broke. Only 0 passes.
pin() {
  file=$1; label=$2; pat=$3
  grep -qF "$pat" "$file"
  rc=$?
  case $rc in
    0) ;;
    1) echo "FAIL: $label -- pattern not found: $pat"; fail=1 ;;
    *) echo "FAIL: $label -- grep error rc=$rc: $pat"; fail=1 ;;
  esac
}

# --- (i) and (ii): static pins
pin "$J" "matcher includes fork" '"matcher": "startup|resume|clear|compact|fork"'
pin "$S" "intent: fork inherits gear" 'A fork inherits the declared gear too.'

# --- (iii) harness
Q='build, ideate, or ops?'
T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT
mkdir "$T/scripts"
cp "$A" "$T/scripts/anchor.sh"
cp "$ROOT/scripts/prelude.sh" "$T/scripts/prelude.sh"
RUN="$T/scripts/anchor.sh"
CLAUDE_PLUGIN_ROOT=$ROOT
export CLAUDE_PLUGIN_ROOT
R="$T/repo"
mkdir "$R"
git -C "$R" init -q
git -C "$R" config user.email t@t
git -C "$R" config user.name t
git -C "$R" commit -q --allow-empty -m seed

SUM=""
seed() {
  rm -rf "$R/.clutch"
  mkdir "$R/.clutch"
  printf 'start 100\nbase -\nemit 100\nemit model 101\nstop 102\n' > "$R/.clutch/session-state"
  printf 'craft\n' > "$R/.clutch/tempo"
  printf '%s goal\n' "$(date +%s)" > "$R/.clutch/sprint-start"
  SUM=$(cksum < "$R/.clutch/session-state")
}

# run <label> <stdin>: sets OUT; asserts rc 0, constitution, move line, and
# that no timing value from any fixture leaks into the injected text.
OUT=""
run() {
  label=$1
  OUT=$(cd "$R" && printf '%s' "$2" | sh "$RUN"); rc=$?
  [ "$rc" = 0 ] || { echo "FAIL: $label -- anchor exited $rc"; fail=1; }
  case "$OUT" in *'# Clutch constitution'*) ;; *) echo "FAIL: $label -- no constitution"; fail=1 ;; esac
  case "$OUT" in *Smallest*) ;; *) echo "FAIL: $label -- no move line"; fail=1 ;; esac
  for v in 4321 90061 5399 5400 182340 0.3416; do
    case "$OUT" in *"$v"*) echo "FAIL: $label -- echoed timing value $v"; fail=1 ;; esac
  done
}

no_ask() {
  case "$OUT" in *"$Q"*) echo "FAIL: $1 -- asked the intent question"; fail=1 ;; esac
}

tempo_kept() {
  grep -qx craft "$R/.clutch/tempo" 2>/dev/null || { echo "FAIL: $1 -- tempo lost"; fail=1; }
}

preserve() {
  [ "$(cksum < "$R/.clutch/session-state")" = "$SUM" ] \
    || { echo "FAIL: $1 -- session-state changed (expected preserve)"; fail=1; }
  tempo_kept "$1"
  [ -e "$R/.clutch/sprint-start" ] || { echo "FAIL: $1 -- sprint-start removed (expected preserve)"; fail=1; }
  no_ask "$1"
}

reset() {
  grep -qx 'start 100' "$R/.clutch/session-state" \
    && { echo "FAIL: $1 -- start line not rewritten (expected reset)"; fail=1; }
  grep -q '^emit ' "$R/.clutch/session-state" \
    && { echo "FAIL: $1 -- emit lines survived (expected reset)"; fail=1; }
  grep -q '^stop ' "$R/.clutch/session-state" \
    && { echo "FAIL: $1 -- stop line survived (expected reset)"; fail=1; }
  [ -e "$R/.clutch/sprint-start" ] && { echo "FAIL: $1 -- sprint-start kept (expected reset)"; fail=1; }
  tempo_kept "$1"
  no_ask "$1"
}

HOT='{"source":"fork","seconds_since_last_response":4321,"context_tokens":182340,"prompt_cache_likely_expired":false,"estimated_cache_write_usd":0.3416}'
COLD='{"source":"fork","seconds_since_last_response":90061,"context_tokens":182340,"prompt_cache_likely_expired":true}'
EDGE_LO='{"source":"fork","seconds_since_last_response":5399}'
EDGE_HI='{"source":"fork","seconds_since_last_response":5400}'
NOFIELD='{"source":"fork"}'
BADFIELD='{"source":"fork","seconds_since_last_response":"x"}'
SPACED_COLD='{"source": "fork", "seconds_since_last_response": 90061}'

# --- (iv)-(vi): fixtures, OD-1 column C
seed; run HOT "$HOT";                 preserve HOT
seed; run COLD "$COLD";               reset COLD
seed; run EDGE_LO "$EDGE_LO";         preserve EDGE_LO
seed; run EDGE_HI "$EDGE_HI";         reset EDGE_HI
seed; run NOFIELD "$NOFIELD";         preserve NOFIELD
seed; run BADFIELD "$BADFIELD";       preserve BADFIELD
seed; run SPACED_COLD "$SPACED_COLD"; reset SPACED_COLD

# --- (vii) cold fork, no gear -> asks
seed; rm -f "$R/.clutch/tempo"; run "cold fork, no gear" "$COLD"
case "$OUT" in *"$Q"*) ;; *) echo "FAIL: cold fork, no gear -- no intent question"; fail=1 ;; esac

# --- (viii) hot fork, no gear -> never asks
seed; rm -f "$R/.clutch/tempo"; run "hot fork, no gear" "$HOT"
no_ask "hot fork, no gear"

# --- (ix) resume carrying timing fields: no echo, start rewritten
seed
run "resume with timing fields" '{"source":"resume","seconds_since_last_response":4321,"context_tokens":182340,"prompt_cache_likely_expired":false,"estimated_cache_write_usd":0.3416}'
grep -qx 'start 100' "$R/.clutch/session-state" \
  && { echo "FAIL: resume with timing fields -- start line not rewritten"; fail=1; }

# --- (x) empty stdin
OUT=$(cd "$R" && printf '' | sh "$RUN"); rc=$?
[ "$rc" = 0 ] || { echo "FAIL: empty stdin -- anchor exited $rc"; fail=1; }
case "$OUT" in *'# Clutch constitution'*) ;; *) echo "FAIL: empty stdin -- no constitution"; fail=1 ;; esac

# --- (xi) malformed stdin -> constitution, state preserved
seed
OUT=$(cd "$R" && printf '%s' '{"source":' | sh "$RUN"); rc=$?
[ "$rc" = 0 ] || { echo "FAIL: malformed -- anchor exited $rc"; fail=1; }
case "$OUT" in *'# Clutch constitution'*) ;; *) echo "FAIL: malformed -- no constitution"; fail=1 ;; esac
[ "$(cksum < "$R/.clutch/session-state")" = "$SUM" ] \
  || { echo "FAIL: malformed -- session-state changed"; fail=1; }

[ "$fail" -eq 0 ] || exit 1
echo PASS
