#!/bin/sh
# The brain (user-level pool at $HOME/.clutch): pin the promotion-door
# contract in fomo's SKILL.md and EXECUTE the door snippet live under
# scratch HOMEs, so doc and behavior cannot drift.
# Every pattern here is absent at BASE 027b9da, so a revert turns this red
# instead of passing vacuously.
# Override vars replay the pins per file against any historical version
# (e.g. git show BASE:... > tmp): FOMO_SKILL SPARK_SKILL IDEATE_SKILL
# DAYDREAM_SKILL DREAMSPARK_SKILL RETRACE_SKILL README_FILE
# GLOSSARY_FILE.
# HOME discipline is HARD: every probe runs under an explicit HOME= scratch
# dir; the end-of-run canary fails loudly if anything leaked into the real
# HOME.
set -u

ORIG_HOME=$HOME

HERE=$(cd "$(dirname "$0")" && pwd)
FOMO=${FOMO_SKILL:-$HERE/../skills/fomo/SKILL.md}
SPARK=${SPARK_SKILL:-$HERE/../skills/spark/SKILL.md}
DAYDREAM=${DAYDREAM_SKILL:-$HERE/../skills/daydream/SKILL.md}
DREAMSPARK=${DREAMSPARK_SKILL:-$HERE/../skills/dream-spark/SKILL.md}
IDEATE=${IDEATE_SKILL:-$HERE/../skills/ideate/SKILL.md}
RETRACE=${RETRACE_SKILL:-$HERE/../skills/retrace/SKILL.md}
README=${README_FILE:-$HERE/../README.md}
GLOSSARY=${GLOSSARY_FILE:-$HERE/../GLOSSARY.md}
CONSTITUTION=${CONSTITUTION_FILE:-$HERE/../rules/constitution.md}
HEARTBEAT=${HEARTBEAT_SH:-$HERE/../scripts/heartbeat.sh}

# The merge retired delve and capture into fomo; a resurrected skill dir means
# the one-door contract silently forked again.
for gone in "$HERE/../skills/delve" "$HERE/../skills/capture"; do
  [ -e "$gone" ] && { echo "FAIL: $gone came back -- fomo is the one door"; exit 1; }
done

[ -f "$FOMO" ] || { echo "FAIL: missing $FOMO"; exit 1; }
[ -f "$SPARK" ] || { echo "FAIL: missing $SPARK"; exit 1; }
[ -f "$DAYDREAM" ] || { echo "FAIL: missing $DAYDREAM"; exit 1; }
[ -f "$DREAMSPARK" ] || { echo "FAIL: missing $DREAMSPARK"; exit 1; }
[ -f "$IDEATE" ] || { echo "FAIL: missing $IDEATE"; exit 1; }
[ -f "$RETRACE" ] || { echo "FAIL: missing $RETRACE"; exit 1; }
[ -f "$README" ] || { echo "FAIL: missing $README"; exit 1; }
[ -f "$CONSTITUTION" ] || { echo "FAIL: missing $CONSTITUTION"; exit 1; }
[ -f "$HEARTBEAT" ] || { echo "FAIL: missing $HEARTBEAT"; exit 1; }
[ -f "$GLOSSARY" ] || { echo "FAIL: missing $GLOSSARY"; exit 1; }

fail=0
# rc 0 = pin holds, 1 = pattern gone, >=2 = grep itself broke. Only 0 passes;
# everything else fails loudly.
pinf() {
  file=$1; label=$2; pat=$3
  grep -q "$pat" "$file"
  rc=$?
  case $rc in
    0) ;;
    1) echo "FAIL: $label -- pattern not found: $pat"; fail=1 ;;
    *) echo "FAIL: $label -- grep error rc=$rc: $pat"; fail=1 ;;
  esac
}

# Negative counterpart to pinf. The bare `grep -q PAT f && { FAIL }` form
# passes VACUOUSLY when grep exits >=2 (file missing, unreadable, or wiped) --
# which is exactly the state these probes exist to catch. Discriminate rc the
# same way pinf does: only a clean rc=1 (present file, pattern absent) passes.
negf() {
  file=$1; label=$2; pat=$3
  grep -q "$pat" "$file"
  rc=$?
  case $rc in
    1) ;;
    0) echo "FAIL: $label -- pattern present, must be absent: $pat"; fail=1 ;;
    *) echo "FAIL: $label -- grep rc=$rc; file missing or unreadable"; fail=1 ;;
  esac
}

# A failure path must leave the banked pool intact, not merely unmarked. A door
# that wipes captures.md on a failure leg satisfies "no [delved token" and ships
# green without this.
pool_intact() {
  file=$1; label=$2
  grep -qF '1111111111 probe line' "$file" 2>/dev/null \
    || { echo "FAIL: $label -- target capture line did not survive"; fail=1; }
  grep -qF '2222222222 other line' "$file" 2>/dev/null \
    || { echo "FAIL: $label -- sibling capture line did not survive"; fail=1; }
}

# --- fomo pins: the absorb door contract (inherited from delve at the merge) ---
pinf "$FOMO" "fomo: absorb routes up"          'absorb into the brain'
pinf "$FOMO" "fomo: brain path literal"        'HOME/\.clutch'
pinf "$FOMO" "fomo: SKIP token"                'SKIP no-brain'
pinf "$FOMO" "fomo: MISS token"                'MISS brain-no-write'
pinf "$FOMO" "fomo: ordering law"              'brain append lands before the marker'
pinf "$FOMO" "fomo: door snippet present"      'rev-parse'
pinf "$FOMO" "fomo: no-match token"            'MISS marker-no-match'
pinf "$FOMO" "fomo: unbanked-entry rule"       'stop before the marker leg'
pinf "$FOMO" "fomo: two-pool boundary"         "the pool's two levels"
pinf "$FOMO" "fomo: marker ownership"          'never mark by hand alongside it'
pinf "$FOMO" "fomo: slug charset"              'lowercase letters, digits, and hyphens only'

# --- merge pins: one door, banked first, metabolized in the background ---
pinf "$FOMO" "fomo: bank snippet target"       'captures\.md'
pinf "$FOMO" "fomo: --brain destination"       'clutch:fomo --brain'
pinf "$FOMO" "fomo: brain is chosen"           'never a silent fallback'
pinf "$FOMO" "fomo: bank honesty token"        'echo BANKED'
pinf "$FOMO" "fomo: background pass"           'background sub-agent'
pinf "$FOMO" "fomo: foreground fallback"       'backgrounding is unavailable'
pinf "$FOMO" "fomo: gist is a reply"           'not an uninvited interrupt'
pinf "$FOMO" "fomo: retroactive why"           'an OUTPUT, not an input'
pinf "$FOMO" "fomo: takes leaps too"           'oh wait, idea'
pinf "$FOMO" "fomo: pull-only"                 'The user pulls; nothing pushes'
pinf "$FOMO" "fomo: trace-back on request"     'licensed first, explained after'
# Model-invocable: the constitution's row-5 dispatch engages fomo by name, so a
# disable-model-invocation line (delve and old-fomo carried one) would mute it.
N=$(grep -c 'disable-model-invocation' "$FOMO")
[ "$N" = "0" ] \
  || { echo "FAIL: fomo carries disable-model-invocation; row 5 cannot engage it"; fail=1; }

# --- bank-only pins: the row-5 carve-out is stated in THREE files and they
# --- must agree. Unpinned, reverting scripts/heartbeat.sh's spine to the old
# --- "-> capture" wording kept all nine suites green, which would silently
# --- route row 5 at a skill this repo no longer ships. ---
pinf "$FOMO" "fomo: bank-only on auto-engage"  'never off a row-5 match'
pinf "$FOMO" "fomo: auto-engage stops early"   'Auto-engaged, fomo banks only'
pinf "$FOMO" "fomo: user-fired always answers" 'never gates it'
pinf "$CONSTITUTION" "row 5: engages fomo"     'mid-task engages fomo'
pinf "$CONSTITUTION" "row 5: banks only"       'fomo banks only'
pinf "$CONSTITUTION" "row 8: tangent is fomo"  'single tangent is a fomo'
pinf "$HEARTBEAT" "spine: routes to fomo"      'mid-task -> fomo'
pinf "$HEARTBEAT" "spine: BANK ONLY"           'BANK ONLY'
pinf "$HEARTBEAT" "spine: tangent is fomo"     'single tangent is a fomo'
# Negative: the retired skills must not reappear in the shipped dispatch spine.
for stale in "$CONSTITUTION" "$HEARTBEAT"; do
  N=$(grep -c 'engages capture\|-> capture\|is a capture' "$stale")
  [ "$N" = "0" ] \
    || { echo "FAIL: $stale still routes row 5 at capture ($N hit)"; fail=1; }
done

# --- reader pins, batch 1: both-level sweeps (spark, daydream, dream-spark,
# --- and fomo's step 2 cross-reference) ---
pinf "$FOMO" "fomo: sweep both levels"         'the same files under .HOME/\.clutch when a brain exists'
pinf "$FOMO" "fomo: merge order"               'Repo items come first'
pinf "$FOMO" "fomo: brain label"               '\[brain\]'
pinf "$FOMO" "fomo: brain skip"                'a missing brain skips silently'
pinf "$SPARK" "spark: brain path literal"      'HOME/\.clutch'
pinf "$SPARK" "spark: brain skip"              'a missing brain skips silently'
pinf "$SPARK" "spark: merge order"             'Repo items come first'
pinf "$SPARK" "spark: brain label"             '\[brain\]'
pinf "$SPARK" "spark: deep sweep both levels"  'both levels of the pool'
pinf "$DAYDREAM" "daydream: brain path literal" 'HOME/\.clutch'
pinf "$DAYDREAM" "daydream: brain skip"        'a missing brain skips silently'
pinf "$DAYDREAM" "daydream: merge order"       'Repo items come first'
pinf "$DAYDREAM" "daydream: brain label"       '\[brain\]'
pinf "$DAYDREAM" "daydream: scaffold reads brain" 'Also read .HOME/\.clutch'
pinf "$DAYDREAM" "daydream: scaffold labels"   'Label brain finds \[brain\]'
pinf "$DREAMSPARK" "dream-spark: brain path literal" 'HOME/\.clutch'
pinf "$DREAMSPARK" "dream-spark: brain skip"   'a missing brain skips silently'
pinf "$DREAMSPARK" "dream-spark: merge order"  'Repo items come first'
pinf "$DREAMSPARK" "dream-spark: brain label"  '\[brain\]'
pinf "$DREAMSPARK" "dream-spark: sources label" 'carry the \[brain\] label in the Sources line'

# --- ideate pins: both-level load, scoring, and the bell draw ---
pinf "$IDEATE" "ideate: brain path literal"    'HOME/\.clutch'
pinf "$IDEATE" "ideate: brain skip"            'a missing brain skips silently'
pinf "$IDEATE" "ideate: merge order"           'Repo items come first'
pinf "$IDEATE" "ideate: brain label"           '\[brain\]'
pinf "$IDEATE" "ideate: draw phrase"           'The draw may hand back a brain item'
pinf "$IDEATE" "ideate: scoring label"         'keeps its \[brain\] label through scoring'
pinf "$IDEATE" "ideate: captures count"        'its captures count in too'
pinf "$IDEATE" "ideate: count-floor honesty"   'only repo lines get read'

# --- retrace pins: the Pulled-at-you window admits labeled brain entries ---
pinf "$RETRACE" "retrace: brain path literal"  'HOME/\.clutch'
pinf "$RETRACE" "retrace: window entries"      'in-window brain entries'
pinf "$RETRACE" "retrace: narrower rule"       'narrower rule binds them too'
pinf "$RETRACE" "retrace: brain label"         '\[brain\]'

# --- pull-report pins: the no-argument report form counts both levels
# --- (capture's step 2, folded into fomo at the merge) ---
pinf "$FOMO" "fomo: captures count"            'its captures count in too'
pinf "$FOMO" "fomo: count-floor honesty"       'only repo lines get read'

# --- README and GLOSSARY pins: the docs tell the two-level truth ---
pinf "$README" "README: pool gains a brain"    'it becomes the brain'
pinf "$README" "README: second pool level"     'the second pool level'
pinf "$README" "README: reads-list brain"      'brain if you keep one'
pinf "$README" "README: honesty, work repo"    'a work repo included'
pinf "$README" "README: honesty, your call"    'is your call'
pinf "$GLOSSARY" "GLOSSARY: user-level pool"   'user-level pool'
pinf "$GLOSSARY" "GLOSSARY: promotion door"    'promotion upward is the absorb verdict'
pinf "$GLOSSARY" "GLOSSARY: no-brain identity" 'No brain, no change'
# Stale-claim negative check: the "named later step" sentence must be gone.
# Non-vacuous by construction: a BASE GLOSSARY replay counts 1 and goes red.
N=$(grep -c 'named later step' "$GLOSSARY")
[ "$N" = "0" ] \
  || { echo "FAIL: GLOSSARY still carries the stale repo-scoped claim ($N hit)"; fail=1; }

# --- live door probes: extract the snippet from the shipped skill and run it ---
T=$(mktemp -d)
trap 'chmod -R u+w "$T" 2>/dev/null; rm -rf "$T"' EXIT

# Fomo carries two sh blocks since the merge: block 1 banks the line, block 2
# is the absorb door probed below. Block 1 is covered by fomo-snippet.test.sh.
# n counts sh blocks and never resets; f tracks "inside a block". The older
# single-var form reset on every fence, so it could not tell two blocks apart.
awk '/```sh/{n++;f=1;next} /```/{f=0} f && n==2' "$FOMO" > "$T/raw.sh"
grep -q 'rev-parse' "$T/raw.sh" \
  || { echo "FAIL: door snippet extraction came up empty"; exit 1; }
grep -q 'SKIP no-brain' "$T/raw.sh" \
  || { echo "FAIL: block 2 is not the absorb door -- sh block order changed"; exit 1; }
sed 's/<slug>/brain-probe-slug/; s/<epoch>/1111111111/g; s/<YYYY-MM-DD>/2026-01-01/g; s|<the resonance>|literal $HOME and $(probe) text|' \
  "$T/raw.sh" > "$T/door.sh"

mkrepo() {
  mkdir -p "$1/.clutch"
  git -C "$1" init -q
  printf '1111111111 probe line\n2222222222 other line\n' > "$1/.clutch/captures.md"
}

# P1 absorb lands: brain append then marker, heredoc content stays literal.
mkdir "$T/repo"; mkrepo "$T/repo"
mkdir -p "$T/h1/.clutch"
OUT=$(cd "$T/repo" && HOME="$T/h1" sh "$T/door.sh")
[ "$OUT" = "ABSORBED" ] \
  || { echo "FAIL: P1 expected ABSORBED, got: $OUT"; fail=1; }
grep -q 'Core pattern' "$T/h1/.clutch/ideas/brain-probe-slug.md" 2>/dev/null \
  || { echo "FAIL: P1 brain file missing the idea block"; fail=1; }
grep -qF 'literal $HOME and $(probe) text' "$T/h1/.clutch/ideas/brain-probe-slug.md" 2>/dev/null \
  || { echo "FAIL: P1 heredoc content was expanded, not literal"; fail=1; }
grep -q '^1111111111 \[delved 2026-01-01\]' "$T/repo/.clutch/captures.md" \
  || { echo "FAIL: P1 captures line not marked"; fail=1; }
grep -qF '2222222222 other line' "$T/repo/.clutch/captures.md" \
  || { echo "FAIL: P1 non-target line did not survive verbatim"; fail=1; }

# P2 unwritable brain: honest MISS, line unmarked, nothing written.
mkdir "$T/repo2"; mkrepo "$T/repo2"
mkdir -p "$T/h2/.clutch"
chmod 555 "$T/h2/.clutch"
OUT=$(cd "$T/repo2" && HOME="$T/h2" sh "$T/door.sh")
[ "$OUT" = "MISS brain-no-write" ] \
  || { echo "FAIL: P2 expected MISS brain-no-write, got: $OUT"; fail=1; }
negf "$T/repo2/.clutch/captures.md" "P2 unmarked on failed absorb" '\[delved'
pool_intact "$T/repo2/.clutch/captures.md" "P2"
[ -z "$(ls -A "$T/h2/.clutch")" ] \
  || { echo "FAIL: P2 wrote into an unwritable brain"; fail=1; }
chmod 755 "$T/h2/.clutch"

# P3 no brain: SKIP, nothing created under HOME, line unmarked.
mkdir "$T/repo3"; mkrepo "$T/repo3"
mkdir "$T/h3"
OUT=$(cd "$T/repo3" && HOME="$T/h3" sh "$T/door.sh")
[ "$OUT" = "SKIP no-brain" ] \
  || { echo "FAIL: P3 expected SKIP no-brain, got: $OUT"; fail=1; }
[ ! -e "$T/h3/.clutch" ] \
  || { echo "FAIL: P3 created .clutch with no brain present"; fail=1; }
negf "$T/repo3/.clutch/captures.md" "P3 unmarked with no brain" '\[delved'
pool_intact "$T/repo3/.clutch/captures.md" "P3"

# P4 marker idempotence: rerun P1's door in P1's env, marker lands once.
OUT=$(cd "$T/repo" && HOME="$T/h1" sh "$T/door.sh")
[ "$OUT" = "ABSORBED" ] \
  || { echo "FAIL: P4 rerun expected ABSORBED, got: $OUT"; fail=1; }
N=$(grep -c '\[delved 2026-01-01\]' "$T/repo/.clutch/captures.md")
[ "$N" = "1" ] \
  || { echo "FAIL: P4 marker count expected 1, got: $N"; fail=1; }

# TWIN twin-epoch co-mark: with two captures lines sharing the epoch, the
# marker lands on the FIRST unmarked match only; the sibling stays intact.
mkdir "$T/repotwin"; mkdir -p "$T/repotwin/.clutch"
git -C "$T/repotwin" init -q
printf '1111111111 twin one\n1111111111 twin two\n' > "$T/repotwin/.clutch/captures.md"
mkdir -p "$T/htwin/.clutch"
OUT=$(cd "$T/repotwin" && HOME="$T/htwin" sh "$T/door.sh")
[ "$OUT" = "ABSORBED" ] \
  || { echo "FAIL: TWIN expected ABSORBED, got: $OUT"; fail=1; }
N=$(grep -c '\[delved 2026-01-01\]' "$T/repotwin/.clutch/captures.md")
[ "$N" = "1" ] \
  || { echo "FAIL: TWIN expected exactly one marker, got: $N"; fail=1; }
grep -q '^1111111111 \[delved 2026-01-01\] twin one' "$T/repotwin/.clutch/captures.md" \
  || { echo "FAIL: TWIN first line did not take the marker"; fail=1; }
grep -qF '1111111111 twin two' "$T/repotwin/.clutch/captures.md" \
  || { echo "FAIL: TWIN sibling line did not survive intact"; fail=1; }

# NOMATCH marker honesty: a filled epoch that matches no captures line must
# report MISS marker-no-match, never a false ABSORBED; zero markers land.
sed 's/<slug>/brain-probe-slug/; s/<epoch>/9999999999/g; s/<YYYY-MM-DD>/2026-01-01/g; s|<the resonance>|wrong epoch probe|' \
  "$T/raw.sh" > "$T/door-wrong.sh"
mkdir "$T/repowrong"; mkrepo "$T/repowrong"
mkdir -p "$T/hwrong/.clutch"
OUT=$(cd "$T/repowrong" && HOME="$T/hwrong" sh "$T/door-wrong.sh")
[ "$OUT" = "MISS marker-no-match" ] \
  || { echo "FAIL: NOMATCH expected MISS marker-no-match, got: $OUT"; fail=1; }
negf "$T/repowrong/.clutch/captures.md" "NOMATCH unmarked on wrong epoch" '\[delved'
pool_intact "$T/repowrong/.clutch/captures.md" "NOMATCH"

# P5 both-level reachability (live): from a repo cwd, the documented union
# (repo files, then the same names under $HOME/.clutch) reaches both levels,
# and the repo file comes before the brain file in the documented order.
mkdir "$T/repo5"; mkrepo "$T/repo5"
printf '### [dream] repo probe entry (2026-01-01)\n' > "$T/repo5/.clutch/dream-sparks.md"
mkdir -p "$T/h5/.clutch"
printf '### [dream] brain probe entry (2026-01-01)\n' > "$T/h5/.clutch/dream-sparks.md"
WALK=$(cd "$T/repo5" && HOME="$T/h5" sh -c '
  for f in .clutch/dream-sparks.md "$HOME/.clutch/dream-sparks.md"; do
    [ -f "$f" ] && printf "%s\n" "$f"
  done')
[ "$(printf '%s\n' "$WALK" | sed -n 1p)" = ".clutch/dream-sparks.md" ] \
  || { echo "FAIL: P5 union did not list the repo file first"; fail=1; }
[ "$(printf '%s\n' "$WALK" | sed -n 2p)" = "$T/h5/.clutch/dream-sparks.md" ] \
  || { echo "FAIL: P5 union did not reach the brain file second"; fail=1; }
HITS=$(cd "$T/repo5" && HOME="$T/h5" sh -c \
  'grep -h "probe entry" .clutch/dream-sparks.md "$HOME/.clutch/dream-sparks.md" 2>/dev/null')
printf '%s\n' "$HITS" | sed -n 1p | grep -q 'repo probe entry' \
  || { echo "FAIL: P5 repo entry not reached from the repo cwd"; fail=1; }
printf '%s\n' "$HITS" | sed -n 2p | grep -q 'brain probe entry' \
  || { echo "FAIL: P5 brain entry not reached via HOME resolution"; fail=1; }

# P6 suite-under-scratch-HOME: the whole sibling suite passes with no brain
# (byte-identity with 1.9.0) and with a seeded brain (presence breaks
# nothing). Self-exclusion by filename is the recursion guard.
# Env hygiene: every sibling invocation clears the thirteen-name override-var
# scrub list (Durable Decision 8) via ONE subshell unset line below -- the ten
# vars this file takes plus the siblings' own SPRINT_SKILL INTENT_SKILL
# ANCHOR_SH. FOMO_SKILL is shared with fomo-snippet.test.sh. Any new override var added to this file or a sibling suite MUST
# be added to that unset line in the same edit. Without the scrub, a BASE
# replay's poisoned var (e.g. README_FILE) inherits into the children and
# lights sibling suites red.
run_scrubbed() {
  ( unset FOMO_SKILL SPARK_SKILL IDEATE_SKILL DAYDREAM_SKILL DREAMSPARK_SKILL RETRACE_SKILL README_FILE GLOSSARY_FILE CONSTITUTION_FILE HEARTBEAT_SH SPRINT_SKILL INTENT_SKILL ANCHOR_SH
    HOME="$1" sh "$2" >/dev/null )
}
mkdir "$T/h6"
mkdir -p "$T/h7/.clutch/ideas"
printf '### [dream] seeded (2026-01-01)\n' > "$T/h7/.clutch/dream-sparks.md"
for t in "$HERE"/*.test.sh; do
  [ "$t" = "$HERE/brain.test.sh" ] && continue
  run_scrubbed "$T/h6" "$t" \
    || { echo "FAIL: no-brain suite: $t"; fail=1; }
done
for t in "$HERE"/*.test.sh; do
  [ "$t" = "$HERE/brain.test.sh" ] && continue
  run_scrubbed "$T/h7" "$t" \
    || { echo "FAIL: with-brain suite: $t"; fail=1; }
done
# Scrub-proof assert: with a poisoned README_FILE set in this script's own
# environment, a sibling invoked through the scrubbed form still PASSes; a
# var that survived the scrub would go red, so this proves the scrub strips.
README_FILE=/dev/null
export README_FILE
run_scrubbed "$T/h6" "$HERE/sprint-pool.test.sh" \
  || { echo "FAIL: P6 scrub-proof -- poisoned README_FILE leaked into a sibling"; fail=1; }
unset README_FILE

# Canary (runs last, always): no probe may leak into the real HOME.
[ ! -e "$ORIG_HOME/.clutch/ideas/brain-probe-slug.md" ] \
  || { echo "FAIL: CANARY -- a probe leaked into the real HOME"; fail=1; }

[ "$fail" -eq 0 ] || exit 1
echo PASS
