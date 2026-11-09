#!/bin/sh
# Ops as the third focus: grep-pin the ops skill (espresso marker, the
# rituals config home and its error contracts, the read-only sweep, the
# one-loop guardrails, the human checkpoint on outward actions, the no-count
# law), the intent handoff, the tempo and GLOSSARY mentions; then run the
# heartbeat and the anchor in a scratch repo to assert that a declared
# espresso gear rides every turn and silences the session-start ask on
# resume. Same rc-discipline as siblings; the F/G wording gates are mirrored
# locally because de-private.test.sh applies them only to the divergent set.
# Wait loops and the tick: fixed-string pins on the arm, tick and fold prose,
# then the skill's own wait snippet and tick read line run as a round trip.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
O=${OPS_SKILL:-$HERE/../skills/ops/SKILL.md}
I=${INTENT_SKILL:-$HERE/../skills/intent/SKILL.md}
TP=${TEMPO_SKILL:-$HERE/../skills/tempo/SKILL.md}
G=${GLOSSARY_FILE:-$HERE/../GLOSSARY.md}
R=${README_FILE:-$HERE/../README.md}
HB=${HB_FILE:-$HERE/../scripts/heartbeat.sh}
A=${ANCHOR_SH:-$HERE/../scripts/anchor.sh}
C=${CONST_FILE:-$HERE/../rules/constitution.md}

fail=0
for f in "$O" "$I" "$TP" "$G" "$R" "$HB" "$A" "$C"; do
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
# fpin: pin with a fixed string (grep -F), same rc discipline.
fpin() {
  file=$1; label=$2; pat=$3
  grep -qF -- "$pat" "$file"
  rc=$?
  case $rc in
    0) ;;
    1) echo "FAIL: $label -- text not found: $pat"; fail=1 ;;
    *) echo "FAIL: $label -- grep error rc=$rc: $pat"; fail=1 ;;
  esac
}

# --- ops skill: gear, config home, error contracts
pin "$O" "ops: espresso marker write"   'printf .%s.n. "espresso" 2>/dev/null > "\$ROOT/\.clutch/tempo"'
pin "$O" "ops: marker-fail contract"    'only the re-injection is lost'
pin "$O" "ops: hopping is the gait"     'Hopping between loops is the gait'
pin "$O" "ops: config home"             '\.clutch/rituals\.md'
pin "$O" "ops: handoff to setup"        '/clutch:rituals'
pin "$O" "ops: never-scaffold contract" 'Never scaffold a default config'
pin "$O" "ops: state-dir contract"      'offer to continue without state'
pin "$O" "ops: integration-skip"        'say so and skip'
pin "$O" "ops: reachable only"          'only if it is reachable'
pin "$O" "ops: unset-key persist"       'offer to persist the answer'

# --- ops skill: the sweep is one read-only divergent pulse
pin "$O" "ops: sweep reads only"        'The sweep reads; it never writes'
pin "$O" "ops: horizon bound"           'nothing past the next workday'
pin "$O" "ops: sweep runs once"         'reads each reachable tool once'
pin "$O" "ops: not a dashboard"         'not a dashboard'
pin "$O" "ops: lives in the turn"       'lives in the turn'
pin "$O" "ops: situation line cap"      'at most seven lines'

# --- ops skill: guardrails
pin "$O" "ops: one loop at a time"      'One loop at a time'
pin "$O" "ops: never two open"          'Never two loops open at once'
pin "$O" "ops: human checkpoint"        'send on a yes'
pin "$O" "ops: reading is free"         'Reading is free'
pin "$O" "ops: tangent banks"           '/clutch:fomo'
pin "$O" "ops: build leaves ops"        '/clutch:intent build'
pin "$O" "ops: no counts"               'No counts'
pin "$O" "ops: no overdue framing"      'never as overdue'
pin "$O" "ops: re-sweep on request"     'Re-sweep on request only'
pin "$O" "ops: one smallest move"       'one loop that closes in one sitting'
pin "$O" "ops: fires when fired"        'Nothing here runs on its own'
pin "$O" "ops: eod owns the close"      '/clutch:eod'
pin "$O" "ops: description trigger"     'hands off after an "ops" answer'

# --- ops skill: the sweep reads the worklog window; a closed loop logs one line
pin "$O" "ops: worklog window read"     'clutch_worklog_window'
pin "$O" "ops: claims never proposed"   'never propose them'
pin "$O" "ops: explicit ask wins"       "the user's explicit ask wins over any claim"
pin "$O" "ops: empty read goes on"      'means no peer context'
pin "$O" "ops: not loaded as a plugin"  '`/scripts/prelude\.sh` not-found error means clutch is not loaded as a plugin'
pin "$O" "ops: say so once"             'say so once and go on'
# Paired with the positive pin above: a failed read no longer passes as no peer context.
nfr=$(grep -c 'failed read means' "$O")
[ "$nfr" = 0 ] || { echo "FAIL: ops -- still says 'failed read means' ($nfr hit)"; fail=1; }
pin "$O" "ops: closed loop logs"        'A closed loop logs one line'
pin "$O" "ops: snippet speaks on MISS"  'silently; speak on MISS or an error'
pin "$O" "ops: only write"              'the only thing a closed loop writes'
fpin "$O" "ops: sweep writes only L2"  'the sweep itself still writes nothing beyond its L2 lines'
fpin "$O" "ops: sweep bound L2 exception" '- The sweep reads; it never writes to any integration; L2 actions run after the reads (see Delegation).'
# Paired with the two pins above: neither write ban stands without its L2 exception.
nsw=$(grep -cF -e 'the sweep itself still writes nothing.' -e 'it never writes to any integration.' "$O")
[ "$nsw" = 0 ] || { echo "FAIL: ops -- a sweep write ban lacks its L2 exception ($nsw hit)"; fail=1; }
# The old unqualified Step 3 ban cannot come back beside the tick pass's write.
nwa=$(grep -c 'is written anywhere;' "$O")
[ "$nwa" = 0 ] || { echo "FAIL: ops -- still says 'is written anywhere;' ($nwa hit)"; fail=1; }

# --- ops skill: wait loops, the tick, the sweep's tick pass
fpin "$O" "ops: tick argument hint"     'argument-hint: "[re-sweep|tick]"'
fpin "$O" "ops: tick trigger"           '"re-sweep", "tick")'
fpin "$O" "tick: on request only"       'A tick happens on request only'
fpin "$O" "tick: skips Steps 0-4"       'A tick skips Steps 0-4: no gear, no config read, no sweep.'
fpin "$O" "sweep: one tick pass"        'Run one tick pass'
fpin "$O" "sweep: unmoved unmentioned"  'A loop that did not move stays unmentioned'
fpin "$O" "sweep: one read per loop"    'it reads each wait loop once'
fpin "$O" "sweep: window read once"     'Read the worklog window in the same pulse, once'
fpin "$O" "sweep: tick pass own read"   'the tick pass reads the wait loops with its own line'
fpin "$O" "sweep: tick pass writes"     "except the tick pass's \`moved:\` lines"
fpin "$O" "wait: never listed"          'Wait loops are never listed or counted, at the close or anywhere.'
fpin "$O" "arm: clause"                 "(I'll hold this as an open loop)"
fpin "$O" "arm: opt-out"                "send, don't watch"
fpin "$O" "arm: replaces moved, MISS"   "instead of its \`moved:\` line; speak on MISS or an error"
fpin "$O" "arm: failed action"          'A failed action holds nothing'
fpin "$O" "arm: one token each"         'one token each, no spaces'
fpin "$O" "arm: escape rule"            "Escape ' as '\\''."
fpin "$O" "close: tick pass included"   "the sweep's tick pass included"
fpin "$O" "tick: reads and writes"      'A tick reads only the wait loops, once each, and writes only their `moved:` lines.'
fpin "$O" "tick: record, then speak"    'A loop that moved: append its `moved:` line first (record, then speak)'
fpin "$O" "tick: silent when unmoved"   'When nothing moved, a tick prints nothing.'
fpin "$O" "tick: unreachable tool"      'A tool that is not reachable gets one line naming it, and that loop stays open.'
fpin "$O" "tick: never re-arms"         'A tick never re-arms a loop, never names one that did not move, and never says how long anything has waited.'
fpin "$O" "tick: unreadable loops"      'Any other exit status means the wait loops are unreadable'
fpin "$O" "tick: bounded line read"     'cut -c1-300'
fpin "$O" "tick: rc 1 with stderr"      'Exit status 1 with error text on stderr means the same: the wait loops are unreadable.'
fpin "$O" "tick: ref its own token"     'as its own token followed by a space'

# --- delegation: the policy sections, the levels, the approval window
fpin "$O" "deleg: never ask for them"   'Neither is a missing key: never ask for them.'
nak=$(grep -c 'Ops adds no keys of its own' "$O")
[ "$nak" = 0 ] || { echo "FAIL: ops -- still says 'Ops adds no keys of its own' ($nak hit)"; fail=1; }
fpin "$O" "deleg: classify after reads" 'Then classify what the sweep read (see Delegation).'
fpin "$O" "deleg: L2 lines written"     'and the L2 lines (see Delegation)'
fpin "$O" "deleg: one exception"        'An L2 action your delegation policy lists is the one exception (see Delegation).'
fpin "$O" "deleg: L3 untouchable"       'L3 is untouchable: a production change, a send to anyone, a merge or a delete always waits for a yes'
pin  "$O" "deleg: section"              '^### Delegation$'
fpin "$O" "deleg: absent is S1"         'With no `### Delegation` section, nothing here applies and every outward action waits for a yes.'
fpin "$O" "deleg: classify inbound"     'Classify every inbound item the sweep reads against the policy:'
fpin "$O" "deleg: L3 line"              '- L3: the yes gate, exactly as in Step 5.'
fpin "$O" "deleg: L2 log text"          'text `L2: <what was done>`'
fpin "$O" "deleg: L1 waits"             'any other draft waits for the next approval window, unmentioned until then'
fpin "$O" "deleg: L0 line"              '- L0: one line, only when it touches the critical path.'
fpin "$O" "deleg: Noise line"           '- Noise: never shown.'
fpin "$O" "deleg: critical path"        'The critical path is today'"'"'s focuses from the focus file.'
fpin "$O" "deleg: unnamed is L3"        'Anything the policy does not name is L3.'
# Paired with the pin above: the done-it-once rule is an authoring rule in rituals, never a run-time check.
ndo=$(grep -cF 'any action you have not done yourself at least once' "$O")
[ "$ndo" = 0 ] || { echo "FAIL: ops -- still checks 'done yourself at least once' at run time ($ndo hit)"; fail=1; }
fpin "$O" "deleg: L1 deadline shows"    'An L1 item whose deadline falls before the next approval window touches the critical path, so its draft shows now.'
fpin "$O" "deleg: no focuses L0"        'With no focuses set, each L0 item shows as one line instead of being hidden.'
fpin "$O" "window: draft wait loop"     'An approved window draft that awaits a reply or a state change is held as a wait loop, as in Step 5.'
fpin "$O" "deleg: strictness order"     'When an item matches two levels, the stricter one wins, in this order: L3, L1, L0, Noise, L2.'
fpin "$O" "deleg: L2 only match"        'An item runs at L2 only when L2 is its only match.'
fpin "$O" "deleg: send is L3"           'A send is any message, email, comment or post another person receives; no policy line makes one L2.'
fpin "$O" "deleg: link read first"      'reads the link first and acts only when it holds'
fpin "$O" "deleg: failed L2"            'A failed L2 action gets one line naming it; it logs nothing and is not retried.'
fpin "$O" "deleg: L2 after reads"       "L2 actions run after the sweep's reads end, never inside them."
fpin "$O" "window: once per sweep"      'Check the approval window once per sweep, after the situation:'
fpin "$O" "window: one screen"          'approved with one yes or "all but N"'
fpin "$O" "window: empty or error"      'Empty output or an error: no window is due; say nothing about drafts.'
fpin "$O" "window: no stored queue"     'No draft is kept between windows: each window reads fresh, so there is no pending list.'
fpin "$O" "window: after situation"     'In the sweep, the window screen follows the situation, and approving it is the one smallest move.'
fpin "$O" "window: not in a tick"       'A tick never runs the window.'
fpin "$O" "deleg: does-not send"        'Send anything without a yes, or write to any integration without one beyond the L2 actions your policy lists'
nwi=$(grep -c 'Write to any integration, or send anything, without a yes' "$O")
[ "$nwi" = 0 ] || { echo "FAIL: ops -- still has the old does-not send line ($nwi hit)"; fail=1; }

# --- constitution: the Delegation section, paid for by four repeats removed
fpin "$C" "const: delegation heading"   '## Delegation'
fpin "$C" "const: L2 from policy"       'an L2 item from their delegation policy'
fpin "$C" "const: L2 logs, nothing else" 'runs without a yes and logs one moved: L2: line. Nothing else is L2: a'
fpin "$C" "const: L3 always waits"      'production change, a send to anyone, a merge or a delete always waits for'
fpin "$C" "const: whatever the policy"  'whatever the policy says.'
fpin "$C" "const: merged no-count"      'Never count missed days, streaks, staleness, or'
fpin "$C" "const: primary-thing lead-in" 'Match on the primary thing the user is'
nrp=$(grep -c 'Route on the primary thing' "$C")
[ "$nrp" = 0 ] || { echo "FAIL: constitution -- the duplicate 'Route on the primary thing' rule is back ($nrp hit)"; fail=1; }

# --- README: delegation in one paragraph
fpin "$R" "README: delegation policy"   'With a `### Delegation` policy in `~/.clutch/rituals.md`, ops sorts what it reads'
fpin "$R" "README: L2 chore"            'L2 does a chore you listed and logs it'
fpin "$R" "README: L3 waits"            'always waits for a yes'
fpin "$R" "README: window opens"        'which opens on your next sweep'
# The handoff path: /clutch:intent ops must be able to invoke the skill, so
# model invocation stays enabled (negative pin).
if grep -q 'disable-model-invocation: true' "$O"; then
  echo "FAIL: ops skill disables model invocation -- the handoff path is dead"
  fail=1
fi

# --- intent: the ops form and its handoff
pin "$I" "intent: ops form"            '/clutch:intent ops'
pin "$I" "intent: ops handoff"         'run /clutch:ops'
pin "$I" "intent: four focuses"        'Four focuses exist'

# --- tempo, GLOSSARY, README: ops is named where the gears are
pin "$TP" "tempo: ops drives espresso" 'ops drives espresso'
pin "$TP" "tempo: ops names its gear"  '/clutch:ops. engages espresso'
pin "$G"  "GLOSSARY: ops in Intent"    'Ops engages espresso'
pin "$R"  "README: ops command"        '/clutch:ops'
pin "$R"  "README: four-way ask"       'build, ideate, ops, or review?'
fpin "$R" "README: wait bullet"        'In ops, an action you approve that awaits a reply logs a `wait:` line'
fpin "$R" "README: watch code span"    '`watch <thing>`'
fpin "$R" "README: closing ref"        'A later `moved:` line that starts with the same ref closes it.'
fpin "$R" "README: three verbs"      '`on:` claim or `wait:` loop'
fpin "$R" "README: tick sentence"      '`/clutch:ops tick` checks only those waits, on request, and speaks only when one moved.'

# --- local mirror of the private-vocab, intent, F and G wording gates.
# Same regex strings as de-private.test.sh; rc 1 = clean, 0 = leak,
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
check_empty "A private-vocab (ops)" -niE "$PAT_A" "$O"
check_empty "C intent (ops)"        -nE  "$PAT_C" "$O"
check_empty "E fuel (ops)"          -niE "$PAT_E" "$O"
check_empty "F daemon (ops)"        -niE "$PAT_F" "$O"
check_empty "G template (ops)"      -nF  "$PAT_T" "$O"

T=$(mktemp -d) || exit 1
HOME=$T/home; export HOME
mkdir -p "$HOME"
trap 'rm -rf "$T"' EXIT
printf 'a javos /intent fuel daemon at HH:MM\n' > "$T/probe"
grep -iE "$PAT_A" "$T/probe" >/dev/null 2>&1 || { echo "FAIL: self-check missed probe for A"; fail=1; }
grep -E  "$PAT_C" "$T/probe" >/dev/null 2>&1 || { echo "FAIL: self-check missed probe for C"; fail=1; }
grep -iE "$PAT_E" "$T/probe" >/dev/null 2>&1 || { echo "FAIL: self-check missed probe for E"; fail=1; }
grep -iE "$PAT_F" "$T/probe" >/dev/null 2>&1 || { echo "FAIL: self-check missed probe for F"; fail=1; }
grep -F  "$PAT_T" "$T/probe" >/dev/null 2>&1 || { echo "FAIL: self-check missed probe for G"; fail=1; }

[ "$fail" -eq 0 ] || exit 1

# --- behavior: a declared espresso gear rides every turn and counts as a
# declaration at the session boundary.
mkdir "$T/scripts"
cp "$A" "$T/scripts/anchor.sh"
cp "$HERE/../scripts/prelude.sh" "$T/scripts/prelude.sh"
RUN="$T/scripts/anchor.sh"
mkdir "$T/repo"
git -C "$T/repo" init -q
git -C "$T/repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m seed
mkdir -p "$T/repo/.clutch"
Q='build, ideate, ops, or review?'

# heartbeat: espresso -> tempo line names the gear and its shape
printf 'espresso\n' > "$T/repo/.clutch/tempo"
OUT=$(cd "$T/repo" && sh "$HB"); RC=$?
[ "$RC" = 0 ] || { echo "FAIL: heartbeat exited $RC with espresso"; exit 1; }
printf '%s\n' "$OUT" | grep -q 'tempo gear: espresso (tight convergence, one divergent pulse)' \
  || { echo "FAIL: heartbeat missing the espresso tempo line: $OUT"; exit 1; }

# anchor on resume with espresso declared -> no question, file intact
OUT=$(cd "$T/repo" && printf '%s' '{"source":"resume"}' | sh "$RUN"); RC=$?
[ "$RC" = 0 ] || { echo "FAIL: anchor exited $RC on resume with espresso"; exit 1; }
printf '%s\n' "$OUT" | grep -qF "$Q" \
  && { echo "FAIL: resume with espresso declared still asks the intent question"; exit 1; }
grep -q '^espresso$' "$T/repo/.clutch/tempo" \
  || { echo "FAIL: resume wiped or mangled an espresso tempo"; exit 1; }

# anchor on startup -> the ask names all four focuses as its final line
OUT=$(cd "$T/repo" && printf '%s' '{"source":"startup"}' | sh "$RUN"); RC=$?
[ "$RC" = 0 ] || { echo "FAIL: anchor exited $RC on startup"; exit 1; }
printf '%s\n' "$OUT" | tail -n 1 | grep -qF "$Q" \
  || { echo "FAIL: startup ask does not name the four focuses as its final line"; exit 1; }

# --- O-run: the skill's own worklog read line, run against the real
# prelude.sh from a plain dir, prints a fresh on: claim and hides a 5 h one.
# The plugin root must be fully substituted and is unset for the run, so an
# inherited CLAUDE_PLUGIN_ROOT cannot carry a line the substitution missed.
LINE=$(grep -F 'sh -c' "$O" | grep -F 'clutch_worklog_window')
[ "$(printf '%s\n' "$LINE" | grep -c .)" = 1 ] \
  || { echo "FAIL: O-run wants exactly one sh -c line reading clutch_worklog_window, got: $LINE"; exit 1; }
# subroot <line>: the line with ${CLAUDE_PLUGIN_ROOT} replaced by the repo root.
subroot() {
  printf '%s\n' "$1" | RR=$(cd "$HERE/.." && pwd) awk '{
    k = "${CLAUDE_PLUGIN_ROOT}"; i = index($0, k)
    if (i) $0 = substr($0, 1, i - 1) ENVIRON["RR"] substr($0, i + length(k))
    print }'
}
CMD=$(subroot "$LINE")
case "$CMD" in
  *CLAUDE_PLUGIN_ROOT*) echo "FAIL: O-run -- plugin root left unsubstituted: $CMD"; exit 1 ;;
esac
unset CLAUDE_PLUGIN_ROOT
NOW=$(date +%s)
mkdir -p "$HOME/.clutch" "$T/plain"
printf '%s proj on: fresh-claim\n%s proj on: stale-claim\n' "$NOW" "$((NOW - 5 * 3600))" > "$HOME/.clutch/worklog.md"
OUT=$(cd "$T/plain" && sh -c "$CMD"); RC=$?
[ "$RC" = 0 ] || { echo "FAIL: O-run exited $RC: $CMD"; exit 1; }
[ "$OUT" = "proj on: fresh-claim" ] \
  || { echo "FAIL: O-run wanted only the fresh claim, got: $OUT"; exit 1; }

# --- O-tick: the skill's one tick read line, root substituted like O-run.
TLINE=$(grep -F 'sh -c' "$O" | grep -F 'clutch_open_loops')
[ "$(printf '%s\n' "$TLINE" | grep -c .)" = 1 ] \
  || { echo "FAIL: O-tick wants exactly one sh -c line reading clutch_open_loops, got: $TLINE"; exit 1; }
TCMD=$(subroot "$TLINE")
case "$TCMD" in
  *CLAUDE_PLUGIN_ROOT*) echo "FAIL: O-tick -- plugin root left unsubstituted: $TCMD"; exit 1 ;;
esac
# tick: run the tick read line from the arm dir; sets TOUT and TRC.
tick() { TOUT=$(cd "$T/armdir" && sh -c "$TCMD" 2>/dev/null); TRC=$?; }

# --- O-arm: the skill's wait snippet, filled the way the prose says, writes
# one wait: line; the tick line reads it; the constitution's moved: closes it.
nws=$(awk '/^[ \t]*```sh/{n++; f=1; b[n] = ""; next} /^[ \t]*```/{f=0} f{b[n] = b[n] $0 "\n"}
  END {k = 0; for (i = 1; i <= n; i++) if (index(b[i], " wait: ")) {k++; s = b[i]}
       printf "%s", s > out; print k}' out="$T/wsnip.raw" "$O")
[ "$nws" = 1 ] || { echo "FAIL: O-arm wants exactly one sh block with ' wait: ', got $nws"; exit 1; }
WK='slack:D0T/1.1' WB='1.1' WX="Or'\\''s reply" awk '
  function rl(s, a, b,   i) { i = index(s, a); return i ? substr(s, 1, i - 1) b substr(s, i + length(a)) : s }
  { $0 = rl($0, "<kind>:<ref>", ENVIRON["WK"]); $0 = rl($0, "<baseline>", ENVIRON["WB"])
    print rl($0, "<text>", ENVIRON["WX"]) }' "$T/wsnip.raw" > "$T/wsnip.sh"
mkdir -p "$T/armdir"
# armhome <name>: a fresh scratch HOME with no ~/.clutch.
armhome() { HOME="$T/arm-$1"; export HOME; W="$HOME/.clutch/worklog.md"; mkdir -p "$HOME"; }

# (a) no ~/.clutch: silent, created, exactly one literal wait: line
armhome a
OUT=$(cd "$T/armdir" && sh "$T/wsnip.sh" 2>/dev/null); RC=$?
[ "$RC" = 0 ] || { echo "FAIL: O-arm (a) -- snippet exited $RC"; exit 1; }
[ -z "$OUT" ] || { echo "FAIL: O-arm (a) -- snippet wrote stdout: $OUT"; exit 1; }
[ -d "$HOME/.clutch" ] || { echo "FAIL: O-arm (a) -- ~/.clutch not created"; exit 1; }
[ "$(grep -c . "$W" 2>/dev/null)" = 1 ] \
  && grep -qE "^[0-9]+ armdir wait: slack:D0T/1\\.1 1\\.1 Or's reply\$" "$W" \
  || { echo "FAIL: O-arm (a) -- want one wait: line, got: $(cat "$W" 2>/dev/null)"; exit 1; }

# (b) the tick read line prints exactly that line
tick
[ "$TRC" = 0 ] && [ "$TOUT" = "$(cat "$W")" ] \
  || { echo "FAIL: O-arm (b) -- tick rc $TRC, got: $TOUT"; exit 1; }

# (c) the constitution's snippet with moved: and the same ref closes it
nsh=$(grep -c '^```sh' "$C")
[ "$nsh" = 1 ] || { echo "FAIL: O-arm (c) -- constitution has $nsh sh blocks, want 1"; exit 1; }
awk '/```sh/{n++; f=1; next} /```/{f=0} f && n == 1' "$C" | CV='moved:' CX='slack:D0T/1.1 Or replied' awk '
  function rl(s, a, b,   i) { i = index(s, a); return i ? substr(s, 1, i - 1) b substr(s, i + length(a)) : s }
  { $0 = rl($0, "<moved:|on:>", ENVIRON["CV"]); print rl($0, "<one line>", ENVIRON["CX"]) }' > "$T/msnip.sh"
(cd "$T/armdir" && sh "$T/msnip.sh" >/dev/null 2>&1)
tick
[ "$TRC" = 0 ] && [ -z "$TOUT" ] \
  || { echo "FAIL: O-arm (c) -- loop still open after moved: (rc $TRC): $TOUT"; exit 1; }

# (d) an unwritable worklog: MISS
if [ "$(id -u)" = 0 ]; then
  echo "SKIP: O-arm (d) (root writes through chmod 444)"
else
  armhome d
  mkdir -p "$HOME/.clutch" && : > "$W" && chmod 444 "$W"
  OUT=$(cd "$T/armdir" && sh "$T/wsnip.sh" 2>/dev/null)
  chmod 644 "$W"
  [ "$OUT" = MISS ] || { echo "FAIL: O-arm (d) -- expected MISS, got: $OUT"; exit 1; }
fi

# (e) no worklog: the tick line keeps clutch_open_loops' rc 1, prints nothing
armhome e
tick
[ "$TRC" = 1 ] && [ -z "$TOUT" ] && [ ! -e "$HOME/.clutch" ] \
  || { echo "FAIL: O-arm (e) -- want rc 1, empty, nothing created; rc $TRC: $TOUT"; exit 1; }

# (e2) an unreadable worklog: the tick line exits 2 (unreadable), not 1
if [ "$(id -u)" = 0 ]; then
  echo "SKIP: O-arm (e2) (root reads chmod 000 files)"
else
  armhome e2
  mkdir -p "$HOME/.clutch" && : > "$W" && chmod 000 "$W"
  tick
  chmod 644 "$W"
  [ "$TRC" = 2 ] && [ -z "$TOUT" ] \
    || { echo "FAIL: O-arm (e2) -- want rc 2, empty; rc $TRC: $TOUT"; exit 1; }
fi

# (f) a long wait line is read cut to 300 bytes
armhome f
mkdir -p "$HOME/.clutch"
LONG=$(awk 'BEGIN { while (n++ < 400) printf "x" }')
printf '%s proj wait: gh:o/r#9 t9 %s\n' "$(date +%s)" "$LONG" > "$W"
tick
[ "$TRC" = 0 ] && [ "$(printf '%s' "$TOUT" | wc -c | tr -d ' ')" = 300 ] \
  && printf '%s\n' "$TOUT" | grep -qE '^[0-9]+ proj wait: gh:o/r#9 t9 x+$' \
  || { echo "FAIL: O-arm (f) -- want the line cut to 300 bytes; rc $TRC: $TOUT"; exit 1; }

# (g) a wait text ending in one invalid byte (a %.200s cut mid-glyph) hides
# no newer loop when the tick runs in a UTF-8 locale.
armhome g
mkdir -p "$HOME/.clutch"
printf '%s proj wait: gh:o/r#1 t1 caf\303\n%s proj wait: gh:o/r#2 t2 newer\n' "$(date +%s)" "$(date +%s)" > "$W"
TOUT=$(cd "$T/armdir" && LC_ALL=en_US.UTF-8 sh -c "$TCMD" 2>&1); TRC=$?
[ "$TRC" = 0 ] && printf '%s\n' "$TOUT" | grep -qF ' gh:o/r#1 ' \
  && printf '%s\n' "$TOUT" | grep -qF ' gh:o/r#2 ' \
  || { echo "FAIL: O-arm (g) -- want both loops under UTF-8; rc $TRC: $TOUT"; exit 1; }

# --- O-window: the skill's one window line, root substituted like O-run. A
# `### Windows` time of 00:00 has always passed, so the first run is due at any
# hour and the second, in the same window, prints nothing.
WLINE=$(grep -F 'sh -c' "$O" | grep -F 'clutch_ops_due window')
[ "$(printf '%s\n' "$WLINE" | grep -c .)" = 1 ] \
  || { echo "FAIL: O-window wants exactly one sh -c line running clutch_ops_due window, got: $WLINE"; exit 1; }
WCMD=$(subroot "$WLINE")
case "$WCMD" in
  *CLAUDE_PLUGIN_ROOT*) echo "FAIL: O-window -- plugin root left unsubstituted: $WCMD"; exit 1 ;;
esac
armhome w
mkdir -p "$HOME/.clutch"
printf '## Ops\n### Windows\n- 00:00\n' > "$HOME/.clutch/rituals.md"
W1=$(cd "$T/armdir" && sh -c "$WCMD" 2>&1); R1=$?
W2=$(cd "$T/armdir" && sh -c "$WCMD" 2>&1); R2=$?
[ "$R1" = 0 ] && [ "$W1" = due ] && [ "$R2" = 0 ] && [ -z "$W2" ] \
  || { echo "FAIL: O-window -- want due then nothing; rc $R1: $W1 / rc $R2: $W2"; exit 1; }

echo PASS
