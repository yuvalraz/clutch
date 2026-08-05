#!/bin/sh
# clutch heartbeat: UserPromptSubmit hook. Fires every turn and re-injects the
# dispatch spine plus the live emission budget as model-facing context.
#
# The constitution is injected only at SessionStart, so in a long uncompacted
# session the dispatch table decays and is buried right when stalls pile up.
# This keeps the table live at the point of performance. Output is model-facing
# additionalContext only, never a user-visible message. Fail-open everywhere:
# any error emits nothing and exits 0. No anti-nag budget is spent here.

PRELUDE=$(dirname "$0")/prelude.sh
[ -f "$PRELUDE" ] || exit 0
. "$PRELUDE" || exit 0
[ "$CLUTCH_GIT" = 1 ] || exit 0

# Emission budget: count of recorded uninvited lines this session (sprint,
# landing, and safe-landing all record as '^emit '). No file means zero.
STATE="$CLUTCH_DIR/session-state"
EMITS=0
if [ -f "$STATE" ]; then
  EMITS=$(grep -c "^emit " "$STATE" 2>/dev/null) || EMITS=0
fi
case "$EMITS" in
  '' | *[!0-9]*) EMITS=0 ;;
esac

# Live sprint: carry the clock to the model every turn. stop.sh surfaces the
# one user-visible countdown; this is the model-facing signal that lets the
# sprint skill's 20-minute close actually fire. Read-only here: malformed and
# stale markers are stop.sh's job to clean. The expired branch survives the
# gap between turns (stop.sh only prunes at turn end), which is exactly the
# window where the close must be spoken.
SPRINTLINE=""
SPRINT="$CLUTCH_DIR/sprint-start"
if [ -f "$SPRINT" ]; then
  SLINE=$(head -n 1 "$SPRINT" 2>/dev/null) || SLINE=""
  SEPOCH=${SLINE%% *}
  GOAL=${SLINE#* }
  case "$SEPOCH" in
    '' | *[!0-9]*) : ;;
    *)
      if [ "$GOAL" != "$SLINE" ]; then
        NOW=$(date +%s) || NOW=0
        AGE=$((NOW - SEPOCH))
        if [ "$AGE" -ge 0 ] && [ "$AGE" -lt 1200 ]; then
          REM=$(((1200 - AGE + 59) / 60))
          SPRINTLINE="sprint clock: $REM min left on '$GOAL'.
"
        elif [ "$AGE" -ge 1200 ]; then
          SPRINTLINE="sprint clock: time is up on '$GOAL'. Close now: name what shipped, recognition wording (the concrete thing that moved, one smallest next move), then remove .clutch/sprint-start.
"
        fi
      fi
      ;;
  esac
fi

# Engaged gear: carry the session shape to the model every turn as posture.
# Closed vocabulary doubles as the injection guard: anything but the five
# gear words (after whitespace-stripping) collapses to silence. Model-facing
# only, never a user-visible line; no anti-nag budget is spent here.
TEMPOLINE=""
TEMPOF="$CLUTCH_DIR/tempo"
if [ -f "$TEMPOF" ]; then
  GEAR=$(head -c 32 "$TEMPOF" 2>/dev/null | tr -d '[:space:]') || GEAR=""
  SHAPE=""
  case "$GEAR" in
    espresso) SHAPE="tight convergence, one divergent pulse" ;;
    craft) SHAPE="converge-dominant, regular divergent pulses" ;;
    ballmer) SHAPE="fast divergence, periodic convergence checkpoints" ;;
    freefall) SHAPE="pure divergence, rate afterwards" ;;
    ferment) SHAPE="slow deliberate divergence, long pulses" ;;
    *) GEAR="" ;;
  esac
  [ -n "$GEAR" ] && TEMPOLINE="tempo gear: ${GEAR} (${SHAPE}). Pace divergent and convergent pulses to this gear; on a sustained shape mismatch the dispatch spine's gear-shift row applies, budget and all.
"
fi

# The dispatch spine, compressed to a few model-facing lines. Silence is the
# terminal row and the default. The only non-fixed text in this block is the
# sprint goal, operator-authored at sprint start and passed through the JSON
# encoder below.
#
# Audited 2026-08-05. This block ships every turn, so its wording is a per-turn
# tax and gets held to that standard. Cut in that pass: the parenthetical
# justifications ("a miss is free; a wrong shift lays a brick", "never an
# unhesitant big goal", the full carve-out recital). Those argued the rules to a
# model that needed persuading; the routing mapping is what a turn actually
# consumes. Every row, the terminal row, and the budget survive verbatim in
# behaviour. Rationale lives in the constitution, which loads once at
# SessionStart and is the place to explain rather than repeat.
CTX="${TEMPOLINE}${SPRINTLINE}clutch dispatch spine (route on the primary activity, not the first keyword; quoted stalls do not count): spoken stall -> smallest-move; too-big next step WITH hesitation -> offer smallest-move; pre-dread before understood boring work -> ignite (not work already in motion, that is venting); same options circling 3+ turns with no edits -> STATE one smallest move, no yes needed; tangent or leap mid-task -> fomo, BANK ONLY (no background read, no auto-surfacing); undone task with cause unclear -> triage, ask the one question first; explicit timebox -> sprint; sustained shape mismatch (a single tangent is a fomo, a single terse reply is nothing) -> offer one gear shift.
TERMINAL: anything else, or no established focus -> SILENCE. The default and the safe state.
clutch-budget: ${EMITS}/2 spent. Before any uninvited line append 'emit model <epoch seconds>' to .clutch/session-state; at 2, stay silent even on a match. One carve-out: the session-start intent ask (build or ideate), at session start only and only when no gear is declared, asked once, never counted against the budget; ignoring it is a legal answer."

# JSON-encode the body: drop control chars, escape backslash then double quote,
# fold newlines to spaces so the value is a single JSON string.
BODY=$(printf '%s' "$CTX" | tr '\n' ' ' | tr -d '\000-\037' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g') || exit 0

printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' "$BODY"

exit 0
