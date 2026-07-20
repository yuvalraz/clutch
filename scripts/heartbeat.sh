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

# The dispatch spine, compressed to a few model-facing lines. Silence is the
# terminal row and the default. The only non-fixed text in this block is the
# sprint goal, operator-authored at sprint start and passed through the JSON
# encoder below.
CTX="${SPRINTLINE}clutch dispatch spine (read and obey; route on the primary thing being done, not the first keyword; quoted or rhetorical stalls do not count): spoken stall -> smallest-move; too-big goal stated as the next action WITH hesitation -> offer smallest-move (never an unhesitant big goal); pre-dread at the threshold of boring or mechanical work already understood -> ignite (never on work already in motion, that is venting); the same options circling across 3+ turns with no narrowing and no edits -> STATE one smallest move as an ignorable recognition line that needs no yes; tangent or leap mid-task -> capture, one line then return, pull-only, never surface waiting captures; a task that did not happen with cause unclear -> triage, ask the one disambiguating question first and engage nothing until answered, never auto-classify; an explicit timebox request -> sprint.
TERMINAL ROW: anything unmatched or uncertain, and any session with no clearly established focus -> SILENCE, do nothing. This is the default and the safe state. A miss is free; a wrong shift lays a brick.
Self-cap: at most 2 uninvited lines per session, shared across every channel. clutch-budget: at least ${EMITS}/2 spent by hooks so far, and every dispatch line you state counts against the same 2 as well. Track your own; when the 2 are spent, stay silent even on a matched signal."

# JSON-encode the body: drop control chars, escape backslash then double quote,
# fold newlines to spaces so the value is a single JSON string.
BODY=$(printf '%s' "$CTX" | tr '\n' ' ' | tr -d '\000-\037' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g') || exit 0

printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' "$BODY"

exit 0
