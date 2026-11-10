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
fpin "$O" "ops: sweep writes only L2"  'the sweep itself still writes nothing beyond its L2 and Auto lines'
fpin "$O" "ops: sweep bound L2 exception" '- The sweep reads; it never writes to any integration; L2 actions and Auto posts run after the reads (see Delegation).'
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
fpin "$O" "deleg: L2 lines written"     'and the L2 and Auto lines (see Delegation)'
fpin "$O" "deleg: one exception"        'An L2 action or Auto post your delegation policy lists is the one exception (see Delegation).'
fpin "$O" "deleg: L3 untouchable"       'L3 is untouchable: a production change, a direct send, a merge or a delete always waits for a yes'
# Paired with the direct-send pins: the old "send to anyone" wording is gone everywhere it lived.
for f in "$O" "$C" "$R"; do
  nsa=$(tr -s '[:space:]' ' ' < "$f" | grep -c 'send to anyone')
  [ "$nsa" = 0 ] || { echo "FAIL: $f -- still says 'send to anyone'"; fail=1; }
done
pin  "$O" "deleg: section"              '^### Delegation$'
fpin "$O" "deleg: absent is S1"         'With no `### Delegation` section, nothing here applies and every outward action waits for a yes.'
fpin "$O" "deleg: classify inbound"     'Classify every inbound item the sweep reads against the policy:'
fpin "$O" "deleg: L3 line"              '- L3: the yes gate, exactly as in Step 5.'
fpin "$O" "deleg: L2 log text"          'text `L2: <what was done>`'
fpin "$O" "deleg: L1 waits"             'any other draft waits for the next approval window, unmentioned until then'
fpin "$O" "deleg: L0 line"              '- L0: one line, only when it touches the critical path.'
fpin "$O" "deleg: Noise line"           '- Noise: never shown.'
fpin "$O" "deleg: critical path"        'The critical path is today'"'"'s focuses and the steps under the focus file'"'"'s `## Critical path`.'
ncp=$(grep -cF 'The critical path is today'"'"'s focuses from the focus file.' "$O")
[ "$ncp" = 0 ] || { echo "FAIL: ops -- still says the critical path is only today's focuses ($ncp hit)"; fail=1; }
nwh=$(grep -cF 'or today'"'"'s focuses when it has none' "$O")
[ "$nwh" = 0 ] || { echo "FAIL: ops -- a critical path still drops today's focuses ($nwh hit)"; fail=1; }
# --- the day brief: the first sweep of a day opens with it, from `## Critical path`
fpin "$O" "brief: gated on a path"      'When today'"'"'s focus file has a `## Critical path`, check the day brief once'
fpin "$O" "brief: due is first sweep"   '`due` means this is the first sweep today'
fpin "$O" "brief: silent otherwise"     'with nothing said about a brief'
fpin "$O" "brief: leads the situation"  'The brief leads the situation: what moved, the L2 and Auto lines and the L0 lines still follow, inside the same seven lines.'
nbw=$(grep -c 'meetings or wait loops that touch a step' "$O")
[ "$nbw" = 0 ] || { echo "FAIL: ops -- the brief still lists wait loops ($nbw hit)"; fail=1; }
fpin "$O" "brief: the move"             'its move (the first step neither done nor blocked)'
fpin "$O" "brief: never late"           'never calls anything late'
fpin "$O" "window: empty due is silent" 'A due window with nothing to draft says nothing either.'
fpin "$R" "readme: brief sentence"      'A `## Critical path` in your focus file makes the first sweep of the day open with a brief.'
fpin "$O" "deleg: unnamed is L3"        'Anything the policy does not name is L3.'
# Paired with the pin above: the done-it-once rule is an authoring rule in rituals, never a run-time check.
ndo=$(grep -cF 'any action you have not done yourself at least once' "$O")
[ "$ndo" = 0 ] || { echo "FAIL: ops -- still checks 'done yourself at least once' at run time ($ndo hit)"; fail=1; }
fpin "$O" "deleg: L1 deadline shows"    'An L1 item whose deadline falls before the next approval window touches the critical path, so its draft shows now.'
fpin "$O" "deleg: no focuses L0"        'With no focuses set, each L0 item shows as one line instead of being hidden.'
fpin "$O" "window: draft wait loop"     'An approved window draft that awaits a reply or a state change is held as a wait loop, as in Step 5.'
fpin "$O" "deleg: strictness order"     'When an item matches two levels, the stricter one wins, in this order: L3, L1, L0, Noise, Auto/L2.'
fpin "$O" "deleg: L2 only match"        'An item runs at L2 or Auto only when that level is its only match.'
fpin "$O" "deleg: send is L3"           'A direct send is any message, email, channel post, thread reply or comment a person receives, except an Auto post as its policy line describes; no policy line makes one L2.'
fpin "$O" "deleg: Auto and L2 tie is L3" 'An item that matches both Auto and L2 is L3.'
fpin "$O" "auto: level line"            '- Auto: post into a channel the policy names as automated, an intake queue'
fpin "$O" "auto: log text"              'text `Auto: <what was posted where>`'
fpin "$O" "auto: held as wait loop"     'An Auto post of an item that awaits a review or a reply is also held as a wait loop, with the Step 5 snippet.'
fpin "$O" "auto: mention is direct"     'An @-mention in an Auto post makes it a direct send, so L3, unless its policy line names the person mentioned.'
fpin "$O" "auto: unnamed channel L3"    'A channel the policy does not name stays L3.'
fpin "$O" "auto: sweep reads channel"   "The sweep reads each Auto channel the policy names once, looking back 5 days, for the item's link in any message there whoever posted it, and never posts an item already there nor proposes a direct ask for one."
fpin "$O" "auto: worklog blocks repost" 'An open `wait:` line or a `moved: Auto:` line for the same item also blocks a new post.'
fpin "$O" "auto: failed read is L3"     'An Auto channel read that fails or cannot be read holds every item it covers at L3, named in one line.'
fpin "$O" "auto: exact channel match"   'Auto posts only to a channel whose name matches the policy line exactly and resolves to one channel; a near match, more than one match, no match or a DM is L3, named in one line.'
fpin "$O" "auto: unconfirmed state L3"  'A state the line names that ops cannot confirm (for example ready while checks are pending, failing or unreadable, or a draft PR) holds the item at L3.'
fpin "$O" "auto: named as what moved"   'text `Auto: <what was posted where>`, and name it once as what moved.'
fpin "$O" "auto: sweep reads own items" 'For each Auto line, also read your own items it covers (for example your open PRs).'
OJ=$(tr -s '[:space:]' ' ' < "$O")
for old in 'A send is any message' \
  'A direct send is any message, email, thread reply or comment' \
  'once, for your own items, so it never proposes' \
  'An L2 action that rests on a link,' \
  'reads the link first and acts only when it holds'; do
  case $OJ in *"$old"*) echo "FAIL: ops -- replaced wording is back: $old"; fail=1 ;; esac
done
fpin "$O" "deleg: link read first"      'An L2 action or Auto post that rests on a link or a state, such as a ticket linked to a PR you authored, reads it first and acts only when it holds.'
fpin "$O" "deleg: failed L2"            'A failed L2 action or Auto post gets one line naming it; it logs nothing and is not retried.'
fpin "$O" "deleg: L2 after reads"       "L2 actions and Auto posts run after the sweep's reads end, never inside them."
fpin "$O" "window: once per sweep"      'Check the approval window once per sweep, after the situation:'
fpin "$O" "window: one screen"          'approved with one yes or "all but N"'
fpin "$O" "window: empty or error"      'Empty output or an error: no window is due; say nothing about drafts.'
fpin "$O" "window: no stored queue"     'No draft is kept between windows: each window reads fresh, so there is no pending list.'
fpin "$O" "window: after situation"     'In the sweep, the window screen follows the situation, and approving it is the one smallest move.'
fpin "$O" "window: not in a tick"       'A tick never runs the window.'
fpin "$O" "deleg: does-not send"        'Send anything without a yes, or write to any integration without one beyond the L2 actions and Auto posts your policy lists'
nwi=$(grep -c 'Write to any integration, or send anything, without a yes' "$O")
[ "$nwi" = 0 ] || { echo "FAIL: ops -- still has the old does-not send line ($nwi hit)"; fail=1; }

# --- constitution: the Delegation section, paid for by four repeats removed
fpin "$C" "const: delegation heading"   '## Delegation'
fpin "$C" "const: L2 from policy"       'an L2 item in their policy'
fpin "$C" "const: L2 logs, nothing else" 'runs without a yes and logs one moved: L2: line. Nothing else is L2: a'
fpin "$C" "const: L3 always waits"      'production change, a direct send (not an Auto post in that turn), a merge or a'
case $(tr -s '[:space:]' ' ' < "$C") in *'not an Auto channel post'*) echo "FAIL: const -- the unscoped Auto clause is back"; fail=1 ;; esac
fpin "$C" "const: whatever the policy"  'whatever the policy says.'
fpin "$C" "const: merged no-count"      'Never count missed days, streaks, staleness, or'
fpin "$C" "const: primary-thing lead-in" 'Match on the primary thing the user is'
nrp=$(grep -c 'Route on the primary thing' "$C")
[ "$nrp" = 0 ] || { echo "FAIL: constitution -- the duplicate 'Route on the primary thing' rule is back ($nrp hit)"; fail=1; }

# --- README: delegation in one paragraph
fpin "$R" "README: delegation policy"   'With a `### Delegation` policy in `~/.clutch/rituals.md`, ops sorts what it reads'
fpin "$R" "README: L2 chore"            'L2 does a chore you listed and logs it'
fpin "$R" "README: L3 waits"            'always waits for a yes'
fpin "$R" "README: Auto channels"       'An `- Auto:` line names an intake channel'
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

# --- the tablet inbox: the sweep claims, reads, sorts and routes it once
pin  "$O" "tablet: section"             '^### Tablet inbox$'
fpin "$O" "tablet: read in the sweep"   'Read the tablet inbox once, after the tick pass (see Tablet inbox).'
fpin "$O" "tablet: Step 3 writes"       'and the tablet inbox items (see Tablet inbox); the rest'
fpin "$O" "tablet: Step 5 writes"       'the sweep itself still writes nothing beyond its L2 and Auto lines and the tablet inbox items.'
fpin "$O" "tablet: buckets not a key"   'An optional `### Buckets` list under `## Ops` sorts the tablet inbox (see Tablet inbox); it is not a missing key either.'
fpin "$O" "tablet: empty is silent"     'Empty output: nothing arrived; say nothing about the tablet.'
fpin "$O" "tablet: other error"         'Any other error: one line, and the sweep goes on.'
fpin "$O" "tablet: stderr on rc 0"      'A claim or route that exits 0 but prints a `tablet:` line on stderr: name it once, in one line.'
fpin "$O" "tablet: before morning"      'When `~/.clutch/rituals.md` sets a focus file and today'"'"'s does not exist yet, skip the tablet inbox this sweep, unmentioned: morning creates it.'
fpin "$O" "tablet: own reading first"   'Sort each item by its own reading first: one that reads clearly as work or as personal takes that bucket.'
fpin "$O" "tablet: hints when unclear"  'Only an item that reads unclear takes a hint, in order:'
fpin "$O" "tablet: hint never forces"   'A hint alone never makes work of an item that reads personal.'
fpin "$O" "tablet: Daily date"          '`day_2026_1_5` is 2026-01-05'
fpin "$O" "tablet: no day, no date"     'Leave `date` out when the item has no day of its own: a typed task whose `date` is empty, a page outside Daily.'
fpin "$O" "tablet: rc 2 retry once"     'Exit status 2 names on stderr what it refused: fix the items once and run the route again; if that fails too, say so in one line.'
fpin "$O" "tablet: never release after" 'Never release after a route call, whatever its exit status'
fpin "$O" "tablet: release before route" 'If the sweep stops after the claim and before any route call, release them'
fpin "$O" "tablet: pool correction"     'move its line between today'"'"'s focus file, `~/.clutch/captures.md` and `~/.clutch/personal.md` in that turn.'
fpin "$O" "tablet: never guess work"    'Never guess work: an unsure item files with the personal ones, marked unsure.'
fpin "$O" "tablet: pass every folder"   'Pass every claimed folder but a `held` one, and under it in `pages_read` list only the `page_id`s you actually read'
fpin "$O" "tablet: unread page holds"   'A folder with a page you did not read is held, not retired, and the next sweep reads it again.'
fpin "$O" "tablet: personal sink"       'every personal and unsure item, ideas included, in `~/.clutch/personal.md`'
fpin "$O" "tablet: route non-zero"      'A route that exits non-zero filed nothing.'
fpin "$O" "tablet: never counted"       'one line per bucket that got items, naming them shortened, never counting them'
fpin "$O" "tablet: focus file missing"  'A capture held for a missing focus file gets one line: the tablet pages wait for today'"'"'s focus file.'
fpin "$O" "tablet: other hold"          'A capture held for another reason gets one line naming the reason.'
fpin "$O" "tablet: personal stays"      'A personal or unsure item never goes to the state dir, the fomo pool or any integration.'
fpin "$O" "tablet: tick never reads"    'A tick never reads the tablet inbox.'
fpin "$O" "tablet: inside seven lines"  'The tablet lines follow what moved, inside the same seven lines.'
fpin "$O" "tablet: never delegated"     'Tablet items are filed, never classified against the delegation policy: no L2 or Auto line acts on one.'
fpin "$O" "tablet: no focus file"       'With no focus file set in `~/.clutch/rituals.md`, drop `--focus-file`'
fpin "$O" "tablet: absolute paths"      'Fill `<state dir>` and `<today'"'"'s focus file>` with absolute paths, never a `~` form; inside the single quotes, escape '"'"' as '"'"'\'"'"''"'"'.'
# Paired with the pins above: the skill calls only the wrapper, and an unread
# folder is passed (held by route), never left out (its claim would go uncounted).
npy=$(grep -ci python "$O")
[ "$npy" = 0 ] || { echo "FAIL: ops -- the skill names python ($npy hit)"; fail=1; }
case $OJ in *'Leave out a folder'*|*'Pass a folder only when'*)
  echo "FAIL: ops -- the skill still tells the model to leave out an unread folder"; fail=1 ;; esac
# Release after a failed route un-counts the claim, so a refusal would loop forever.
case $OJ in *'and run release'*|*'run release, and the sweep'*|*'Run release only when'*|*'note name).'*)
  echo "FAIL: ops -- a replaced release or date rule is back"; fail=1 ;; esac
fpin "$R" "README: tablet inbox"        'When the tablet inbox has new pages, the sweep files each line once: work under `## From the tablet` in today'"'"'s focus file and work ideas in the fomo pool, personal and unsure ones in `~/.clutch/personal.md`, and it names what arrived without counting it.'
fpin "$R" "README safe: ops reads"      'Ops also reads the tablet inbox under `~/.clutch/inbox/`, and `~/.clutch/people.md` when it exists, to sort what arrived.'
fpin "$R" "README safe: ops writes"     '`/clutch:ops` files them: work lines into today'"'"'s focus file (or, with no focus file set, `~/.clutch/personal.md`)'
fpin "$R" "README safe: helper imports" 'its test suite parses its imports and fails on any network module'

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

# --- O-brief: the skill's one brief line, root substituted like O-window. In a
# fresh HOME the first sweep of the day is due; the second, same day, is not.
BLINE=$(grep -F 'sh -c' "$O" | grep -F 'clutch_ops_due brief')
[ "$(printf '%s\n' "$BLINE" | grep -c .)" = 1 ] \
  || { echo "FAIL: O-brief wants exactly one sh -c line running clutch_ops_due brief, got: $BLINE"; exit 1; }
BCMD=$(subroot "$BLINE")
case "$BCMD" in
  *CLAUDE_PLUGIN_ROOT*) echo "FAIL: O-brief -- plugin root left unsubstituted: $BCMD"; exit 1 ;;
esac
armhome b
mkdir -p "$HOME/.clutch"
B1=$(cd "$T/armdir" && sh -c "$BCMD" 2>&1); R1=$?
B2=$(cd "$T/armdir" && sh -c "$BCMD" 2>&1); R2=$?
[ "$R1" = 0 ] && [ "$B1" = due ] && [ "$R2" = 0 ] && [ -z "$B2" ] \
  || { echo "FAIL: O-brief -- want due then nothing; rc $R1: $B1 / rc $R2: $B2"; exit 1; }

# --- O-tablet: the skill's own claim, route and release lines. With no tablet
# inbox, (a)(b)(d) prove parity: no output, no file, no python3 started, with or
# without one on PATH; (e) is their positive control. (c)(f)(g) run the route
# template filled the way the prose says, against a real python3.
CL=$(grep -F 'tablet-inbox.sh" claim' "$O"); RL=$(grep -F 'tablet-inbox.sh" release' "$O")
[ "$(printf '%s\n' "$CL" | grep -c .)" = 1 ] && [ "$(printf '%s\n' "$RL" | grep -c .)" = 1 ] \
  || { echo "FAIL: O-tablet wants exactly one claim and one release line, got: $CL / $RL"; exit 1; }
CCMD=$(subroot "$(subroot "$CL")"); RCMD=$(subroot "$(subroot "$RL")")
nrb=$(awk '/^[ \t]*```sh/{n++; f=1; b[n] = ""; next} /^[ \t]*```/{f=0} f{b[n] = b[n] $0 "\n"}
  END {k = 0; for (i = 1; i <= n; i++) if (index(b[i], "tablet-inbox.sh\" route")) {k++; s = b[i]}
       printf "%s", s > out; print k}' out="$T/route.raw" "$O")
[ "$nrb" = 1 ] || { echo "FAIL: O-tablet wants exactly one sh block running route, got $nrb"; exit 1; }
subroot "$(cat "$T/route.raw")" > "$T/route.tpl"
case "$CCMD $RCMD $(cat "$T/route.tpl")" in
  *CLAUDE_PLUGIN_ROOT*) echo "FAIL: O-tablet -- plugin root left unsubstituted"; exit 1 ;;
esac
# $T/nopy holds only sh; $T/stubpy also holds a python3 that records it ran.
# Neither holds git, so the prelude's git block is skipped.
mkdir -p "$T/nopy" "$T/stubpy" "$T/tplain"
ln -s /bin/sh "$T/nopy/sh"; ln -s /bin/sh "$T/stubpy/sh"
printf '#!/bin/sh\n: > "%s/py-ran"\n' "$T" > "$T/stubpy/python3"
chmod +x "$T/stubpy/python3"
# tquiet <label> <pathdir> <cmd>: rc 0, no output, no python3, HOME listing unchanged.
tquiet() {
  rm -f "$T/py-ran"
  find "$HOME" | sort > "$T/tb"
  TO=$(cd "$T/tplain" && PATH="$T/$2" /bin/sh -c "$3" 2>&1); TR=$?
  find "$HOME" | sort > "$T/ta"
  [ "$TR" = 0 ] && [ -z "$TO" ] && [ ! -e "$T/py-ran" ] && cmp -s "$T/tb" "$T/ta" \
    || { echo "FAIL: O-tablet $1 -- rc $TR, python3 ran: $([ -e "$T/py-ran" ] && echo yes || echo no), output: $TO"; exit 1; }
}
armhome ta
tquiet "(a) claim, no ~/.clutch" stubpy "$CCMD"
armhome tb; mkdir "$HOME/.clutch"
tquiet "(b) claim, no inbox" stubpy "$CCMD"
tquiet "(b) release, no inbox" stubpy "$RCMD"
armhome td; mkdir "$HOME/.clutch"
tquiet "(d) claim, no python3" nopy "$CCMD"
tquiet "(d) release, no python3" nopy "$RCMD"
armhome te; mkdir -p "$HOME/.clutch/inbox/aipaper"; rm -f "$T/py-ran"
(cd "$T/tplain" && PATH="$T/stubpy" /bin/sh -c "$CCMD" >/dev/null 2>&1)
[ -e "$T/py-ran" ] || { echo "FAIL: O-tablet (e) -- an inbox did not reach the helper, so (a)(b) cannot bite"; exit 1; }

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: O-tablet (c)(f)(g)(h)(i)(j) (no python3)"
else
  # tcap <case> [section] [note name] [todos JSON]: a fresh HOME holding one
  # invented capture, a focus file '# day', and the claim run; TF is the folder it printed.
  tcap() {
    armhome "$1"
    TC="$HOME/.clutch/inbox/aipaper/${2:-APP_PAPER}/${3:-Fixture}--abcd1234"
    mkdir -p "$TC" "$T/$1-work"
    printf '{"appType": "%s", "fileName": "%s", "format": "notebook", "pages": [{"file": "p00-pg000001.png", "pageId": "pg000001-x", "order": 0}], "todos": %s}\n' \
      "${2:-APP_PAPER}" "${3:-Fixture}" "${4:-[]}" > "$TC/note.json"
    printf '\211PNG\r\n\032\n' > "$TC/p00-pg000001.png"
    printf '# day\n' > "$T/$1-work/focus.md"
    TF=$(cd "$T/tplain" && sh -c "$CCMD" | python3 -c 'import json,sys; print(json.loads(sys.stdin.readline())["folder"])')
    [ -n "$TF" ] && [ -d "$TF" ] || { echo "FAIL: O-tablet ($1) -- the claim printed no folder: $TF"; exit 1; }
  }
  # troute <case> <bucket> [literal to drop] [pages_read literal to empty] [todo id]:
  # fill every placeholder of the route template (a todo id turns the item into a
  # typed task), then run it; output in TO, rc in TR.
  troute() {
    TW="$T/$1-work" TFD="$TF" TB="$2" TX="${3:-}" TP="${4:-}" TQ="${5:-}" TD=$(date +%Y-%m-%d) awk '
      function ra(s, a, b,   i, o) { o = ""; while ((i = index(s, a)) > 0) { o = o substr(s, 1, i - 1) b; s = substr(s, i + length(a)) } return o s }
      { if (ENVIRON["TX"] != "") $0 = ra($0, ENVIRON["TX"], "")
        if (ENVIRON["TP"] != "") $0 = ra($0, ENVIRON["TP"], "[]")
        if (ENVIRON["TQ"] != "") $0 = ra($0, "\"page_id\": \"<page>\"", "\"todo_id\": \"" ENVIRON["TQ"] "\"")
        $0 = ra($0, "<state dir>", ENVIRON["TW"]); $0 = ra($0, "<today" sq "s focus file>", ENVIRON["TW"] "/focus.md")
        $0 = ra($0, "<folder>", ENVIRON["TFD"]); $0 = ra($0, "<item>", "buy stamps")
        $0 = ra($0, "<task|note|action|idea>", "task"); $0 = ra($0, "<work|personal|unsure>", ENVIRON["TB"])
        $0 = ra($0, "<page>", "pg000001-x"); print ra($0, "<date>", ENVIRON["TD"]) }' sq="'" "$T/route.tpl" > "$T/$1-route.sh"
    grep -q '<[a-z|]*>\|<today' "$T/$1-route.sh" && { echo "FAIL: O-tablet ($1) -- a placeholder is left unfilled"; exit 1; }
    TO=$(cd "$T/tplain" && sh "$T/$1-route.sh" 2>&1); TR=$?
  }
  # (c) a personal item lands in personal.md only; the folder is retired.
  tcap tc; troute tc personal
  [ "$TR" = 0 ] && grep -qxF -- '- [ ] buy stamps' "$HOME/.clutch/personal.md" 2>/dev/null \
    && [ "$(cat "$T/tc-work/focus.md")" = '# day' ] && [ ! -e "$HOME/.clutch/captures.md" ] && [ ! -e "$TF" ] \
    || { echo "FAIL: O-tablet (c) -- rc $TR: $TO"; exit 1; }
  # (f) a page left out of pages_read holds the folder; nothing is filed.
  tcap tf; troute tf personal '' '["<page>"]'
  [ "$TR" = 0 ] && printf '%s\n' "$TO" | grep -qF '"status": "held"' && printf '%s\n' "$TO" | grep -qF 'not fully read' \
    && [ ! -e "$HOME/.clutch/personal.md" ] && [ -d "$TF" ] \
    || { echo "FAIL: O-tablet (f) -- rc $TR: $TO"; exit 1; }
  # (g) with no focus file and no state dir set, a work item files in personal.md marked work.
  tcap tg; troute tg work " --work-state-dir '<state dir>' --focus-file '<today's focus file>'"
  [ "$TR" = 0 ] && grep -qxF -- '- [ ] buy stamps (work)' "$HOME/.clutch/personal.md" 2>/dev/null \
    && [ "$(cat "$T/tg-work/focus.md")" = '# day' ] && [ ! -e "$TF" ] \
    || { echo "FAIL: O-tablet (g) -- rc $TR: $TO"; exit 1; }
  # (h) with a focus file, a work item lands under ## From the tablet; personal.md stays absent.
  tcap th; troute th work
  [ "$TR" = 0 ] && [ "$(cat "$T/th-work/focus.md")" = "$(printf '# day\n\n## From the tablet\n- [ ] buy stamps')" ] \
    && [ ! -e "$HOME/.clutch/personal.md" ] && [ ! -e "$TF" ] \
    || { echo "FAIL: O-tablet (h) -- rc $TR: $TO / $(cat "$T/th-work/focus.md")"; exit 1; }
  # (i) a Daily capture's typed task goes through the template with its todo_id.
  tcap ti APP_DAILY day_2026_11_10 '[{"id": "t1", "content": "buy stamps", "isDelete": false, "day": 10, "month": 11, "year": 2026}]'
  troute ti personal '' '' t1
  [ "$TR" = 0 ] && grep -qF -- '- [ ] buy stamps' "$HOME/.clutch/personal.md" 2>/dev/null \
    && grep -qF '"t1"' "$HOME/.clutch/aipaper/ledger.json" && [ ! -e "$TF" ] \
    || { echo "FAIL: O-tablet (i) -- rc $TR: $TO"; exit 1; }
  # (j) a route refused every sweep (rc 2), with no release after it, ends the
  # capture in held/ once the claim count runs out; each sweep's lease is lapsed by hand.
  tcap tj; n=1
  while [ "$n" -le 5 ]; do
    troute tj nope
    [ "$TR" = 2 ] || { echo "FAIL: O-tablet (j) -- want rc 2 on sweep $n, got rc $TR: $TO"; exit 1; }
    touch -t 200001010000 "$TF"
    TO=$(cd "$T/tplain" && sh -c "$CCMD" 2>&1); n=$((n + 1))
  done
  printf '%s\n' "$TO" | grep -qF '"held": "not read"' && [ ! -e "$TF" ] \
    || { echo "FAIL: O-tablet (j) -- a repeated refusal never reached held/: $TO"; exit 1; }
fi

echo PASS
