#!/bin/sh
# Investigate mode: grep-pin the investigate skill (craft confirm line, the
# pointer ask, read-only evidence, findings tied to evidence, the close by a
# reply on a yes plus a wait: line or a build handoff, the guardrails), its
# frontmatter, and the negative pins; cmp its gear-marker snippet against the
# intent skill's Build snippet and run it under sh and zsh -f in a scratch
# plain folder. Then the banned-word gates, mirrored from review.test.sh, over
# the new skill, and PAT_F alone over the prose this slice adds to README.md,
# the intent and tempo skills and GLOSSARY.md's ### Intent entry (only that
# entry: elsewhere "acronym" contains cron). Probe self-checks keep the gates
# from passing vacuously. Overrides: INVESTIGATE_SKILL, INTENT_SKILL.
# Hermetic: scratch HOME. Silent apart from PASS.
set -u
unset CLUTCH_PLAIN

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
V=${INVESTIGATE_SKILL:-$ROOT/skills/investigate/SKILL.md}
I=${INTENT_SKILL:-$ROOT/skills/intent/SKILL.md}

fail=0
for f in "$V" "$I" "$ROOT/README.md" "$ROOT/skills/tempo/SKILL.md" "$ROOT/GLOSSARY.md"; do
  [ -f "$f" ] || { echo "FAIL: missing $f"; fail=1; }
done
[ "$fail" -eq 0 ] || exit 1

# fpin <file> <label> <fixed string>: rc 0 passes; 1 = gone, >=2 = grep broke.
fpin() {
  grep -qF -- "$3" "$1"
  case $? in
    0) ;;
    1) echo "FAIL: $2 -- not found: $3"; fail=1 ;;
    *) echo "FAIL: $2 -- grep error: $3"; fail=1 ;;
  esac
}

# --- frontmatter
fpin "$V" "name"            'name: investigate'
fpin "$V" "argument hint"   'argument-hint: "[pointer]"'
fpin "$V" "when_to_use"     'when /clutch:intent hands off after an "investigate" answer'
fpin "$V" "passing mention" 'A passing "look into this" or "why is this" mid-session is not a trigger.'

# --- body pins, each on one line
for p in \
  'Craft engaged: explore, then commit, checkpoint at each finding.' \
  'ask for it in one line' \
  'Read-only until a yes' \
  'one hypothesis at a time' \
  'say so in one line and ask for it another way' \
  'TL;DR first' \
  'each finding marked verified, with its evidence, or unverified' \
  'draft it, show it, send on a yes' \
  'a `wait:` line' \
  '/clutch:intent build' \
  '/clutch:fomo' \
  'One pointer at a time' \
  'on a yes, run `/clutch:intent build` in this same session' \
  "outside clutch's own \`.clutch\` state" \
  'banking a tangent with `/clutch:fomo` is free' \
  'No counts, no overdue framing'; do
  fpin "$V" "body" "$p"
done

# The guardrail is scoped to work outside clutch's own state, and the build
# handoff waits for a yes (negative pins on the pre-fix wording).
for p in 'no writes anywhere outside the marker above' 'and hand off with' 'reply or write anything without a yes'; do
  if grep -qF -- "$p" "$V"; then echo "FAIL: stale guardrail wording: $p"; fail=1; fi
done

# The handoff path: /clutch:intent investigate must be able to invoke the
# skill, so model invocation stays enabled (negative pin).
if grep -q 'disable-model-invocation: true' "$V"; then
  echo "FAIL: investigate skill disables model invocation -- the handoff path is dead"
  fail=1
fi

# --- the gear-marker snippet: byte for byte the intent Build snippet.
extract() {
  awk '/^```sh/{f=1;b="";next} f && /^```/{f=0; if (b ~ /\.clutch\/tempo/) {printf "%s", b; exit} next} f{b=b $0 "\n"}' "$1"
}
T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT
HOME=$T/home; export HOME
mkdir -p "$HOME"
extract "$V" > "$T/v.sh"
extract "$I" > "$T/i.sh"
if [ ! -s "$T/v.sh" ] || ! grep -q '"craft"' "$T/v.sh"; then
  echo "FAIL: investigate marker snippet extraction came up empty"; fail=1
elif ! cmp -s "$T/v.sh" "$T/i.sh"; then
  echo "FAIL: investigate marker snippet differs from the intent Build snippet"; fail=1
fi
SHELLS=sh
command -v zsh >/dev/null 2>&1 && SHELLS="sh zsh"
for sh in $SHELLS; do
  D="$T/plain-$sh"
  mkdir -p "$D"
  if [ "$sh" = zsh ]; then
    OUT=$(cd "$D" && GIT_CEILING_DIRECTORIES=$T zsh -f "$T/v.sh" 2>"$T/err"); RC=$?
  else
    OUT=$(cd "$D" && GIT_CEILING_DIRECTORIES=$T sh "$T/v.sh" 2>"$T/err"); RC=$?
  fi
  [ "$RC" = 0 ] && [ -z "$OUT" ] && [ ! -s "$T/err" ] || { echo "FAIL: snippet $sh -- rc $RC out '$OUT'"; fail=1; }
  [ "$(cat "$D/.clutch/tempo" 2>/dev/null)" = craft ] || { echo "FAIL: snippet $sh -- tempo is not craft"; fail=1; }
done
# $HOME is never written.
(cd "$HOME" && GIT_CEILING_DIRECTORIES=$T sh "$T/v.sh" >/dev/null 2>&1)
[ ! -e "$HOME/.clutch/tempo" ] || { echo "FAIL: snippet wrote a marker in HOME"; fail=1; }

# --- banned-word gates, the same strings as review.test.sh; rc 1 = clean,
# 0 = leak, >=2 = loud grep failure.
PAT_A='javos|knowledge-ops|aipaper|daylog|MEMORY\.md|trust ledger|trust-ledger|\.claude/tempo|config/intents'
PAT_C='/intent\b|intent default'
PAT_E='fuel'
PAT_F='daemon|launchd|cron|nightly|overnight|schedul|auto-trigger'
PAT_T='HH:MM'

check_empty() {
  label=$1; shift
  hits=$(grep "$@" 2>&1)
  rc=$?
  case $rc in
    1) ;;
    0) echo "FAIL: $label"
       printf '%s\n' "$hits" | head -5
       fail=1 ;;
    *) echo "FAIL: $label -- grep error rc=$rc"
       printf '%s\n' "$hits" | head -5
       fail=1 ;;
  esac
}
check_empty "A private-vocab (investigate)"    -niE "$PAT_A" "$V"
check_empty "C intent (investigate)"           -nE  "$PAT_C" "$V"
check_empty "E fuel (investigate)"             -niE "$PAT_E" "$V"
check_empty "F daemon (investigate)"           -niE "$PAT_F" "$V"
check_empty "G template (investigate)"         -nF  "$PAT_T" "$V"
# A `$` + digit in a SKILL.md body is argument shorthand and gets swallowed.
check_empty "argument shorthand (investigate)" -nE '\$[0-9]' "$V"
# PAT_F over the other prose this slice adds to.
check_empty "F daemon (README)"                -niE "$PAT_F" "$ROOT/README.md"
check_empty "F daemon (intent)"                -niE "$PAT_F" "$I"
check_empty "F daemon (tempo)"                 -niE "$PAT_F" "$ROOT/skills/tempo/SKILL.md"
awk '/^### Intent$/{s=1;next} /^### /{s=0} s' "$ROOT/GLOSSARY.md" > "$T/gi"
if [ -s "$T/gi" ]; then
  check_empty "F daemon (GLOSSARY Intent)"     -niE "$PAT_F" "$T/gi"
else
  echo "FAIL: GLOSSARY ### Intent extract is empty"; fail=1
fi

printf 'a javos /intent fuel daemon at HH:MM\n' > "$T/probe"
grep -iE "$PAT_A" "$T/probe" >/dev/null 2>&1 || { echo "FAIL: self-check missed probe for A"; fail=1; }
grep -E  "$PAT_C" "$T/probe" >/dev/null 2>&1 || { echo "FAIL: self-check missed probe for C"; fail=1; }
grep -iE "$PAT_E" "$T/probe" >/dev/null 2>&1 || { echo "FAIL: self-check missed probe for E"; fail=1; }
grep -iE "$PAT_F" "$T/probe" >/dev/null 2>&1 || { echo "FAIL: self-check missed probe for F"; fail=1; }
grep -F  "$PAT_T" "$T/probe" >/dev/null 2>&1 || { echo "FAIL: self-check missed probe for G"; fail=1; }
printf 'x $0 y\n' > "$T/probe-n"
grep -E '\$[0-9]' "$T/probe-n" >/dev/null 2>&1 || { echo "FAIL: self-check missed probe for argument shorthand"; fail=1; }

[ "$fail" -eq 0 ] || exit 1
echo PASS
