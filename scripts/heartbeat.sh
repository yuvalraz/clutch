#!/bin/sh
# clutch heartbeat: UserPromptSubmit hook. Fires every turn and re-injects the
# dispatch spine plus the live emission budget as model-facing context.
#
# The constitution is injected only at SessionStart, so in a long uncompacted
# session the dispatch table decays and is buried right when stalls pile up.
# This keeps the table live at the point of performance. Output is model-facing
# additionalContext only, never a user-visible message. Fail-open everywhere:
# any error emits nothing and exits 0. No anti-nag budget is spent here.

# Hook input JSON on stdin, for the session tag only. Never read a terminal.
INPUT=""
[ -t 0 ] || INPUT=$(cat 2>/dev/null) || INPUT=""

PRELUDE=$(dirname "$0")/prelude.sh
[ -f "$PRELUDE" ] || exit 0
. "$PRELUDE" || exit 0
[ "$CLUTCH_STATE" = 1 ] || exit 0

# This session's own state folder when it has one, else the folder-wide
# files. A turn refreshes the folder's mtime (touch -c never creates), so
# the startup prune never takes a session that still gets prompts.
if clutch_session_paths "$INPUT"; then
  touch -c "$CLUTCH_SDIR" 2>/dev/null || :
fi

# Emission budget: count of recorded uninvited lines this session (sprint,
# landing, and safe-landing all record as '^emit '). No file means zero.
STATE="$CLUTCH_SDIR/session-state"
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
SPRINT="$CLUTCH_SDIR/sprint-start"
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
          SPRINTLINE="sprint clock: time is up on '$GOAL'. Close now: name what shipped, recognition wording (the concrete thing that moved, one smallest next move), then remove ${CLUTCH_SREL}sprint-start.
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
TEMPOF="$CLUTCH_SDIR/tempo"
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
clutch-budget: ${EMITS}/2 spent. Before any uninvited line append 'emit model <epoch seconds>' to ${CLUTCH_SREL}session-state; at 2, stay silent even on a match; a tick from the session's armed watch, beat or sweep is invited output too. One carve-out: the session-start intent ask (${CLUTCH_FOCI}), at session start only and only when no gear is declared, asked once, never counted against the budget; ignoring it is a legal answer."

# JSON-encode the body: drop control chars, escape backslash then double quote,
# fold newlines to spaces so the value is a single JSON string.
BODY=$(printf '%s' "$CTX" | tr '\n' ' ' | tr -d '\000-\037' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g') || exit 0

# Session title: the first prompt is always /clutch:intent, so Claude Code's
# generated title says only "Clutch intent <focus>". On the first real prompt
# of an untitled session, set "<focus> · <gist> @<tag8>" instead. Claude Code
# sends session_title only for a custom title (/rename, --name, or a hook's
# sessionTitle), so its presence is the whole guard: once we or the user name
# the session, later turns carry it and this stops. The focus is the
# transcript's first /clutch:intent command. The awk reads TOP-LEVEL string
# keys only, walking escapes. CLUTCH_TITLE=off turns this off. Any failure
# leaves TSEG empty: today's output.
TSEG=""
case $INPUT in
  # A prompt cannot forge this raw substring: its quotes arrive escaped (\").
  *'"session_title"'*) ;;
  *)
  [ "${CLUTCH_TITLE:-}" = off ] || TSEG=$(printf '%s' "$INPUT" | LC_ALL=C awk '
    function dec(s,   o, k, e) {
      o = ""
      while ((k = index(s, "\\")) > 0) {
        o = o substr(s, 1, k - 1); e = substr(s, k + 1, 1)
        if (e == "n") o = o "\n"; else if (e == "t" || e == "r") o = o " "
        else if (e == "\"" || e == "\\" || e == "/") o = o e
        else if (e == "u") k += 4
        s = substr(s, k + 2)
      }
      return o s
    }
    { all = all $0 "\n" }
    END {
      n = split(all, p, "\"")
      depth = 0; instr = 0; key = ""; want = ""; CAP = 8192
      for (i = 1; i <= n; i++) {
        if (!instr) {
          if (i > 1 && key != "") { want = (p[i] ~ /^[ \t\r\n]*:[ \t\r\n]*$/) ? key : ""; key = "" }
          else if (i > 1) want = ""
          t = p[i]; depth += gsub(/[{[]/, "", t); t = p[i]; depth -= gsub(/[]}]/, "", t)
          sd = depth; raw = ""; instr = 1; continue
        }
        # inside a string: a quote preceded by an odd run of backslashes is
        # escaped. Keep at most CAP bytes of a value: the gist needs one line.
        if (length(raw) < CAP) raw = raw substr(p[i], 1, CAP - length(raw))
        # trailing backslash run: the last field of a split on non-backslash
        # text (a run regex, gsub or per-char substr loop is quadratic in bwk awk)
        b = 0
        if (substr(p[i], length(p[i])) == "\\") { b = split(p[i], q, /[^\\]+/); b = length(q[b]) }
        if (b % 2) { if (length(raw) < CAP) raw = raw "\""; continue }
        instr = 0
        if (want != "") { v[want] = raw; want = ""; key = "" }
        else if (sd == 1) key = raw
      }
      if (!("prompt" in v)) exit
      pr = dec(substr(v["prompt"], 1, 4096)); gsub(/\r/, " ", pr)
      full = pr; gsub(/[\001-\037 ]+/, " ", full); sub(/^ /, "", full); sub(/ $/, "", full)
      if (full ~ /^\// || tolower(full) ~ /^(go|yes|y|ok|build|ideate|ops|review|investigate)[.!?,;:]*$/) exit
      m = split(pr, ln, "\n"); g = ""
      for (j = 1; j <= m && g == ""; j++) {
        g = ln[j]; gsub(/[\001-\037 ]+/, " ", g); sub(/^ /, "", g); sub(/ $/, "", g)
        if (g ~ /^<\/?pasted_content/) g = ""
      }
      if (g == "") exit
      # cut at 60 characters: a UTF-8 lead byte (not 0x80-0xBF) starts one
      c = 0; out = ""; cut = 0
      for (j = 1; j <= length(g); j++) {
        ch = substr(g, j, 1)
        if (ch < "\200" || ch >= "\300") { if (++c > 60) { cut = 1; break } }
        out = out ch
      }
      # the 4096-byte decode window can tear the last character: drop it
      k = length(out)
      while (k > 0 && (ch = substr(out, k, 1)) >= "\200" && ch < "\300") k--
      if (k > 0) {
        ch = substr(out, k, 1)
        need = (ch >= "\360") ? 4 : (ch >= "\340") ? 3 : (ch >= "\300") ? 2 : 1
        if (length(out) - k + 1 < need) out = substr(out, 1, k - 1)
      }
      if (out == "") exit
      print out (cut ? "…" : "")
      print "\"session_id\":\"" v["session_id"] "\""
      tp = dec(v["transcript_path"]); gsub(/[\001-\037]/, "", tp)
      print tp
    }' 2>/dev/null) || TSEG=""
  ;;
esac
if [ -n "$TSEG" ]; then
  TTL=$(printf '%s\n' "$TSEG" | sed -n 1p)
  TP=$(printf '%s\n' "$TSEG" | sed -n 3p)
  # Claude Code records the command JSON-escaped: <command-name>/clutch:intent
  # </command-name>\n<command-args>build</command-args>, with a literal \n.
  if [ -n "$TP" ] && [ -f "$TP" ] && [ -r "$TP" ]; then
    FOCUS=$(LC_ALL=C grep -m1 -oE '<command-name>/clutch:intent</command-name>(\\n| )*<command-args>(build|ideate|ops|review|investigate)</command-args>' "$TP" 2>/dev/null |
      LC_ALL=C sed -n '1s/.*<command-args>\([a-z]*\)<.*/\1/p') || FOCUS=""
    [ -n "$FOCUS" ] && TTL="$FOCUS · $TTL"
  fi
  TAG=$(clutch_session_tag "$(printf '%s\n' "$TSEG" | sed -n 2p)") && TTL="$TTL $TAG"
  TTL=$(printf '%s' "$TTL" | LC_ALL=C tr -d '\000-\037' | LC_ALL=C sed -e 's/\\/\\\\/g' -e 's/"/\\"/g') || TTL=""
  TSEG=""
  [ -n "$TTL" ] && TSEG=",\"sessionTitle\":\"$TTL\""
fi

printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"%s}}\n' "$BODY" "$TSEG"

exit 0
