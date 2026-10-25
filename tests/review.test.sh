#!/bin/sh
# Review mode: grep-pin the review skill (espresso marker, the rituals config
# home and the review-conventions key, the conventions-file contracts, the
# one-PR loop, the harvest line and its append contract, the declined-rule
# record in .clutch/session-state, the outward checkpoint, the no-count law),
# the rituals key and batch question, and the tempo mentions; then run the
# heartbeat in a scratch repo to assert that a declared espresso gear rides
# every turn and that a declined line never spends the uninvited budget.
# Same rc-discipline as siblings; the A/C/E/F/G wording gates are mirrored
# locally from ops.test.sh, plus a `$` + digit argument-shorthand gate.
# Overrides: REVIEW_SKILL, RITUALS_SKILL, TEMPO_SKILL, HB_FILE.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
RV=${REVIEW_SKILL:-$HERE/../skills/review/SKILL.md}
RT=${RITUALS_SKILL:-$HERE/../skills/rituals/SKILL.md}
TP=${TEMPO_SKILL:-$HERE/../skills/tempo/SKILL.md}
HB=${HB_FILE:-$HERE/../scripts/heartbeat.sh}

fail=0
for f in "$RV" "$RT" "$TP" "$HB"; do
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

# --- review skill: gear, config home, error contracts
pin "$RV" "review: espresso marker write"  'printf .%s.n. "espresso" 2>/dev/null > "\$ROOT/\.clutch/tempo"'
pin "$RV" "review: marker-fail contract"   'only the re-injection is lost'
pin "$RV" "review: next PR is the gait"    'Moving from one PR to the next is the gait'
pin "$RV" "review: config home"            '\.clutch/rituals\.md'
pin "$RV" "review: conventions key"        'review-conventions:'
pin "$RV" "review: handoff to setup"       '/clutch:rituals'
pin "$RV" "review: never-scaffold config"  'Never scaffold a default config'
pin "$RV" "review: unset-key persist"      'offer to persist the answer'
pin "$RV" "review: missing file named"     'name the missing file'
pin "$RV" "review: create on a yes"        'offer to create it on a yes'
pin "$RV" "review: never create silently"  'Never create the conventions file silently'
pin "$RV" "review: continue without"       'continue without conventions'
pin "$RV" "review: loads first"            'before the first PR'

# --- review skill: the PR loop
pin "$RV" "review: asks for a PR"          'ask which PR'
pin "$RV" "review: one PR at a time"       'One PR at a time'
pin "$RV" "review: never two open"         'Never two PRs open at once'
pin "$RV" "review: one pulse"              'one blast-radius read'
pin "$RV" "review: cites conventions"      'cites the convention it rests on'
pin "$RV" "review: checkpoint"             'checkpoint in one line naming what moved'

# --- review skill: harvest, one ignorable line, append-only on a yes
pin "$RV" "review: one proposal line"      'exactly one proposal line'
pin "$RV" "review: proposal ignorable"     'ignoring it writes nothing to the conventions file'
pin "$RV" "review: append on a yes"        'append it on a yes'
pin "$RV" "review: never queued"           'nothing is written to the conventions file and nothing is queued'
pin "$RV" "review: no re-proposal"         'never proposed again this session'
pin "$RV" "review: held rule cited"        'already in the conventions is cited, never proposed'
pin "$RV" "review: append heading"         '^## Conventions$'
pin "$RV" "review: append format"          '^- <rule, imperative, one line>\. Why: <the reason the user gave or accepted>\.$'
pin "$RV" "review: append only"            'appends only; it never rewrites or reorders'
pin "$RV" "review: append-fail contract"   'show the line so the user can paste it'
pin "$RV" "review: confirm names file"     'one line naming the file'

# --- review skill: guardrails and triggers
pin "$RV" "review: outward checkpoint"     'post on a yes'
pin "$RV" "review: reading is free"        'Reading is free'
pin "$RV" "review: gh unreachable"         'ask for the diff another way'
pin "$RV" "review: tangent banks"          '/clutch:fomo'
pin "$RV" "review: build leaves review"    '/clutch:intent build'
pin "$RV" "review: no counts"              'No counts'
pin "$RV" "review: no overdue framing"     'never as overdue'
pin "$RV" "review: fires when fired"       'Nothing here runs on its own'
pin "$RV" "review: never polls"            'never polls for PRs'
pin "$RV" "review: description trigger"    'hands off after a "review" answer'
pin "$RV" "review: passing mention"        'A passing "review this"'
pin "$RV" "review: proposal carries its reason" 'the rule and its reason in one line'
pin "$RV" "review: named PR outside the mode"   'outside review mode is not a trigger'

# --- review skill: the declined-rule record (OD-1 B)
pin "$RV" "review: decline hash"           'H=\$(printf .%s.n. .<the rule>. | cksum | cut -d. . -f1)'
pin "$RV" "review: decline write"          'printf .declined %s.n. "\$H" >> "\$ROOT/\.clutch/session-state"'
pin "$RV" "review: decline check"          'grep -qx "declined \$H" "\$ROOT/\.clutch/session-state"'
pin "$RV" "review: decline write fails"    'If the decline write fails, say so in the same turn and still do not re-offer the rule in this conversation'
pin "$RV" "review: conversation memory wins" 'only if this conversation has not already declined the rule'

# The handoff path: /clutch:intent review must be able to invoke the skill,
# so model invocation stays enabled (negative pin).
if grep -q 'disable-model-invocation: true' "$RV"; then
  echo "FAIL: review skill disables model invocation -- the handoff path is dead"
  fail=1
fi

# --- rituals and tempo: review is named where its key and gear live
pin "$RT" "rituals: review-conventions key"  '^- review-conventions:'
pin "$RT" "rituals: review batch question"   '\*\*Review conventions\*\*'
pin "$TP" "tempo: review drives espresso"    'ops drives espresso and so does review'
pin "$TP" "tempo: review names its gear"     '/clutch:review. engages espresso'

# --- local mirror of the private-vocab, intent, F and G wording gates.
# Same regex strings as ops.test.sh; rc 1 = clean, 0 = leak,
# >=2 = loud grep failure.
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
check_empty "A private-vocab (review)"     -niE "$PAT_A" "$RV"
check_empty "C intent (review)"            -nE  "$PAT_C" "$RV"
check_empty "E fuel (review)"              -niE "$PAT_E" "$RV"
check_empty "F daemon (review)"            -niE "$PAT_F" "$RV"
check_empty "G template (review)"          -nF  "$PAT_T" "$RV"
# A `$` + digit in a SKILL.md body is argument shorthand and gets swallowed.
check_empty "argument shorthand (review)"  -nE '\$[0-9]' "$RV"

T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT
printf 'a javos /intent fuel daemon at HH:MM\n' > "$T/probe"
grep -iE "$PAT_A" "$T/probe" >/dev/null 2>&1 || { echo "FAIL: self-check missed probe for A"; fail=1; }
grep -E  "$PAT_C" "$T/probe" >/dev/null 2>&1 || { echo "FAIL: self-check missed probe for C"; fail=1; }
grep -iE "$PAT_E" "$T/probe" >/dev/null 2>&1 || { echo "FAIL: self-check missed probe for E"; fail=1; }
grep -iE "$PAT_F" "$T/probe" >/dev/null 2>&1 || { echo "FAIL: self-check missed probe for F"; fail=1; }
grep -F  "$PAT_T" "$T/probe" >/dev/null 2>&1 || { echo "FAIL: self-check missed probe for G"; fail=1; }
printf 'x $0 y\n' > "$T/probe-n"
grep -E '\$[0-9]' "$T/probe-n" >/dev/null 2>&1 || { echo "FAIL: self-check missed probe for argument shorthand"; fail=1; }

[ "$fail" -eq 0 ] || exit 1

# --- behavior (guard): a declared espresso gear rides every turn.
mkdir "$T/repo"
git -C "$T/repo" init -q
git -C "$T/repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m seed
mkdir -p "$T/repo/.clutch"

printf 'espresso\n' > "$T/repo/.clutch/tempo"
OUT=$(cd "$T/repo" && sh "$HB"); RC=$?
[ "$RC" = 0 ] || { echo "FAIL: heartbeat exited $RC with espresso"; exit 1; }
printf '%s\n' "$OUT" | grep -q 'tempo gear: espresso (tight convergence, one divergent pulse)' \
  || { echo "FAIL: heartbeat missing the espresso tempo line: $OUT"; exit 1; }

# --- behavior (guard, OD-1 B): a declined line never counts as an emission.
printf 'start 100\nbase -\nemit model 101\n' > "$T/repo/.clutch/session-state"
OUT=$(cd "$T/repo" && sh "$HB"); RC=$?
[ "$RC" = 0 ] || { echo "FAIL: heartbeat exited $RC with one emission"; exit 1; }
printf '%s\n' "$OUT" | grep -qF 'clutch-budget: 1/2 spent' \
  || { echo "FAIL: heartbeat budget wrong before a declined line: $OUT"; exit 1; }
printf 'declined 889814453\n' >> "$T/repo/.clutch/session-state"
OUT=$(cd "$T/repo" && sh "$HB"); RC=$?
[ "$RC" = 0 ] || { echo "FAIL: heartbeat exited $RC with a declined line"; exit 1; }
printf '%s\n' "$OUT" | grep -qF 'clutch-budget: 1/2 spent' \
  || { echo "FAIL: the declined line was counted as an emission: $OUT"; exit 1; }

echo PASS
