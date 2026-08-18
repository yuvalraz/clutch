#!/bin/sh
# The rituals trio: grep-pin the setup skill, the morning spine, and the EOD
# spine; pin the shared error contracts; then mirror the F/G wording gates
# locally, because de-private.test.sh applies those two patterns only to its
# five divergent skills and would let the three ritual skills drift. Same
# rc-discipline as siblings, planted-probe self-check included.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
R=${RITUALS_SKILL:-$HERE/../skills/rituals/SKILL.md}
M=${MORNING_SKILL:-$HERE/../skills/morning/SKILL.md}
E=${EOD_SKILL:-$HERE/../skills/eod/SKILL.md}

fail=0
for f in "$R" "$M" "$E"; do
  [ -f "$f" ] || { echo "FAIL: missing $f"; fail=1; }
done
[ "$fail" -eq 0 ] || exit 1

# rc 0 = pin holds, 1 = pattern gone, >=2 = grep itself broke. Only 0 passes;
# everything else fails loudly.
pin() {
  file=$1; label=$2; pat=$3
  grep -q "$pat" "$file"
  rc=$?
  case $rc in
    0) ;;
    1) echo "FAIL: $label -- pattern not found: $pat"; fail=1 ;;
    *) echo "FAIL: $label -- grep error rc=$rc: $pat"; fail=1 ;;
  esac
}

# --- every skill: user-fired only, config home
for f in "$R" "$M" "$E"; do
  pin "$f" "frontmatter: no model invocation ($f)" 'disable-model-invocation: true'
  pin "$f" "config home ($f)"                      '\.clutch/rituals\.md'
done

# --- rituals: batch interview, schema sections, re-run edits in place
pin "$R" "rituals: batch not drip"     'one batch'
pin "$R" "rituals: interview cited"    '/clutch:interview'
pin "$R" "rituals: shared section"     '^## Shared'
pin "$R" "rituals: morning section"    '^## Morning'
pin "$R" "rituals: eod section"        '^## EOD'
pin "$R" "rituals: extra steps"        '^### Extra steps'
pin "$R" "rituals: close-out"          '^### Close-out'
pin "$R" "rituals: workdays key"       '^- workdays:'
pin "$R" "rituals: state dir key"      '^- state dir:'
pin "$R" "rituals: focus file key"     '^- focus file:'
pin "$R" "rituals: time key"           '^- time:'
pin "$R" "rituals: prep key"           '^- prep:'
pin "$R" "rituals: integrations key"   '^- integrations:'
pin "$R" "rituals: re-run shows values" 'show current values as defaults'
pin "$R" "rituals: re-run edits"       'edit it in place'
pin "$R" "rituals: never unbidden"     'Never runs unbidden'
pin "$R" "rituals: unset-key note"     'ask once when they first need it'
pin "$R" "rituals: exit resumes sender" 'resume the ritual that sent you here'

# --- morning + eod: handoff and shared error contracts
for f in "$M" "$E"; do
  pin "$f" "handoff to setup ($f)"      '/clutch:rituals'
  pin "$f" "never-scaffold contract ($f)" 'Never scaffold a default config'
  pin "$f" "prep-failure contract ($f)" 'show the failure and continue with direct reads'
  pin "$f" "state-dir contract ($f)"    'offer to continue without state'
  pin "$f" "integration-skip contract ($f)" 'say so and skip'
  pin "$f" "unset-key persist contract ($f)" 'offer to persist the answer'
  pin "$f" "focus-file resolution ($f)"      'ask once where'
  pin "$f" "empty-pool contract ($f)"        'never invent a banked item'
done

# --- morning spine
pin "$M" "morning: deep ping"          'deep ping'
pin "$M" "morning: ping follow-through" 'do these signals change'
pin "$M" "morning: user confirms edit" 'after the user confirms'
pin "$M" "morning: banked write-off"   '/clutch:fomo'
pin "$M" "morning: quick win"          'one quick win'
pin "$M" "morning: closing move"       'first move on focus #1'
pin "$M" "morning: first-run ping"     'no prior close'

# --- eod spine
pin "$E" "eod: mini-retro"             'mini-retro'
pin "$E" "eod: triage fork"            '/clutch:triage'
pin "$E" "eod: fork named"             'a flinch at the wall versus never entering awareness'
pin "$E" "eod: one tweak"              'ONE tweak'
pin "$E" "eod: workday wrap"           'wraps to the first'
pin "$E" "eod: fun slot"               'fun slot'
pin "$E" "eod: closing name"           'naming tomorrow'
pin "$E" "eod: workdays unset"         'never assume a week'
pin "$E" "eod: focus file empty"       'missing or empty'
pin "$E" "eod: tweak lands in file"    'next to tomorrow'

# --- local mirror of the F/G wording gates over the three ritual skills.
# Same regex string as de-private.test.sh PAT_F; a literal template-token
# check stands in for PAT_G2's first alternate. rc 1 = clean, 0 = leak,
# >=2 = loud grep failure.
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

check_empty "F daemon (rituals trio)"   -niE "$PAT_F" "$R" "$M" "$E"
check_empty "G template (rituals trio)" -nF  "$PAT_T" "$R" "$M" "$E"

# Self-check: both mirrored patterns must still catch a planted probe, so a
# typo'd pattern fails here instead of passing vacuously.
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
printf 'a daemon fires at HH:MM\n' > "$T/probe"
grep -iE "$PAT_F" "$T/probe" >/dev/null 2>&1 \
  || { echo "FAIL: self-check missed probe for F"; fail=1; }
grep -F "$PAT_T" "$T/probe" >/dev/null 2>&1 \
  || { echo "FAIL: self-check missed probe for G template"; fail=1; }

[ "$fail" -eq 0 ] || exit 1
echo PASS
