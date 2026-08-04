#!/bin/sh
# The de-private sweep: no private vocabulary in shipped prose surfaces.
# Scope: skills/ rules/ README.md GLOSSARY.md ANNOTATIONS.md -- never tests/
# or scripts/ (this file names skill paths and carries a probe string, so a
# repo-wide run would flag itself).
# Plain grep, not git grep: git grep misses untracked files.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE/.." || { echo "FAIL: cannot cd to repo root"; exit 1; }

SCOPE="skills rules README.md GLOSSARY.md ANNOTATIONS.md"
FIVE="skills/fomo/SKILL.md skills/spark/SKILL.md skills/daydream/SKILL.md skills/dream-spark/SKILL.md skills/ideate/SKILL.md"
SURFACES="rules/constitution.md README.md GLOSSARY.md ANNOTATIONS.md"

# One home per pattern: the sweep and the self-check grep the SAME strings.
# A typo here breaks both at once, and the self-check catches it.
PAT_A='javos|knowledge-ops|aipaper|daylog|MEMORY\.md|trust ledger|trust-ledger|\.claude/tempo|config/intents'
PAT_B='[['
PAT_C='/intent\b|intent default'
PAT_D='/(spark|ideate|daydream|dream-spark|fomo|memory|loop)\b'
PAT_E='fuel'
PAT_F='daemon|launchd|cron|nightly|overnight|schedul|auto-trigger'
PAT_G1='\(20[0-9]{2}-[0-9]{2}-[0-9]{2} '
PAT_G2='HH:MM|YYYY-MM-DD HH'

fail=0

# A sweep over a missing surface proves nothing.
for f in $FIVE $SURFACES; do
  [ -f "$f" ] || { echo "FAIL: missing $f"; fail=1; }
done
[ "$fail" -eq 0 ] || exit 1

# rc 0 = hits (leak), 1 = clean, >=2 = grep itself broke (invalid regex,
# missing file). Only 1 passes; everything else fails loudly.
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

# Pattern A: private vocabulary.
check_empty "A private-vocab" -rniE "$PAT_A" $SCOPE
# Pattern B: wiki-links.
check_empty "B wiki-links" -rnF "$PAT_B" $SCOPE
# Pattern C: intent vocabulary.
check_empty "C intent" -rnE "$PAT_C" $SCOPE
# Pattern D: unprefixed command forms (cross-references use /clutch:<name>).
check_empty "D unprefixed-commands" -rnE "$PAT_D" $SCOPE
# Pattern E: fuel-tank language (six divergent skills only).
check_empty "E fuel" -niE "$PAT_E" $FIVE
# Pattern F: uninvited/daemon language (six divergent skills only).
check_empty "F daemon" -niE "$PAT_F" $FIVE
# Pattern G: pool date-format leak (six divergent skills only).
check_empty "G1 datetime" -nE "$PAT_G1" $FIVE
check_empty "G2 template" -nE "$PAT_G2" $FIVE

# Self-check: every pattern variable must still catch a planted probe. Same
# variables as the sweep, so a typo'd or broken pattern fails here. The probe
# lives in a temp dir OUTSIDE the sweep scope so it never pollutes the tree.
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
printf 'a javos [[probe]] /intent x /spark (2026-01-01 09:00) fuel daemon HH:MM\n' > "$T/probe"

probe_hit() {
  label=$1; shift
  grep "$@" "$T/probe" >/dev/null 2>&1 \
    || { echo "FAIL: self-check missed probe for $label"; fail=1; }
}
probe_hit "A"  -iE "$PAT_A"
probe_hit "B"  -F  "$PAT_B"
probe_hit "C"  -E  "$PAT_C"
probe_hit "D"  -E  "$PAT_D"
probe_hit "E"  -iE "$PAT_E"
probe_hit "F"  -iE "$PAT_F"
probe_hit "G1" -E  "$PAT_G1"
probe_hit "G2" -E  "$PAT_G2"

# Alternate-specific probes: each restored/added shape must trip on its own,
# never by riding a sibling alternate in the same pattern.
printf 'set the intent default here\n' > "$T/probe-c2"
grep -E "$PAT_C" "$T/probe-c2" >/dev/null 2>&1 \
  || { echo "FAIL: self-check missed probe for C (intent default)"; fail=1; }
printf 'see config/intents/dev.md\n' > "$T/probe-a2"
grep -iE "$PAT_A" "$T/probe-a2" >/dev/null 2>&1 \
  || { echo "FAIL: self-check missed probe for A (config/intents)"; fail=1; }

# Negative probe: the prefixed form is clutch's own vocabulary and must never
# trip pattern C. Same PAT_C variable as the sweep, never a copy.
printf 'x /clutch:intent y\n' > "$T/negprobe"
if grep -E "$PAT_C" "$T/negprobe" >/dev/null 2>&1; then
  echo "FAIL: pattern C wrongly trips on /clutch:intent"; fail=1
fi

# Negative probe: the brain vocabulary is clutch's own and must trip no
# pattern. Same PAT_ variables as the sweep, never copies.
printf 'the brain at ~/.clutch, read via $HOME/.clutch, labeled [brain]\n' > "$T/negprobe-brain"
neg_brain() {
  label=$1; shift
  if grep "$@" "$T/negprobe-brain" >/dev/null 2>&1; then
    echo "FAIL: pattern $label wrongly trips on brain vocabulary"; fail=1
  fi
}
neg_brain "A"  -iE "$PAT_A"
neg_brain "B"  -F  "$PAT_B"
neg_brain "C"  -E  "$PAT_C"
neg_brain "D"  -E  "$PAT_D"
neg_brain "E"  -iE "$PAT_E"
neg_brain "F"  -iE "$PAT_F"
neg_brain "G1" -E  "$PAT_G1"
neg_brain "G2" -E  "$PAT_G2"

[ "$fail" -eq 0 ] || exit 1
echo PASS
