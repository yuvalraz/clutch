#!/bin/sh
# clutch red-moment: PostToolUseFailure + PostToolUse hook.
#
# Catches the RSD spiral at a red test result, but ONLY on true zero movement:
# the SAME runner command failing AGAIN with the working tree UNCHANGED since its
# last failure. That is "you re-ran the exact failing thing without editing
# anything." A green result, or any edit between reds, resets it. It never fires
# on the first red (that is the expected half of red-green), never on a different
# target, never on a non-runner failure, never on a designed-to-fail command.
#
# Output is model-facing hookSpecificOutput.additionalContext only (this event
# has no plain-stdout path to the model). The model is the final gate: it
# surfaces at most ONE recognition line and only if the user is genuinely stuck,
# else silence. The red count is never stated. This hook does not itself spend
# the anti-nag budget (the model spends a cap line only if it surfaces one,
# exactly like heartbeat.sh). Fail-open everywhere: any error emits nothing and
# exits 0, and it never blocks the tool.

IN=$(cat 2>/dev/null) || exit 0

# Only Bash tool events carry a shell command to classify.
case "$IN" in
  *'"tool_name":"Bash"'* | *'"tool_name": "Bash"'*) ;;
  *) exit 0 ;;
esac

# Which event fired. The closing quote in each pattern disambiguates
# PostToolUse from PostToolUseFailure (one is not a prefix-match of the other).
EVENT=""
case "$IN" in
  *'"hook_event_name":"PostToolUseFailure"'* | *'"hook_event_name": "PostToolUseFailure"'*) EVENT=failure ;;
  *'"hook_event_name":"PostToolUse"'* | *'"hook_event_name": "PostToolUse"'*) EVENT=success ;;
esac
[ -n "$EVENT" ] || exit 0

# Extract tool_input.command. Flatten newlines first so a pretty-printed payload
# still parses, then take the value up to the first quote. A truncated-at-an-
# escaped-quote value is fine: identical commands still produce identical text,
# which is all the fingerprint needs.
FLAT=$(printf '%s' "$IN" | tr '\n' ' ') || exit 0
CMD=$(printf '%s' "$FLAT" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"\\]*\(\\.[^"\\]*\)*\)".*/\1/p')
[ -n "$CMD" ] || exit 0

# Positive runner allowlist. Anything not a known test/build runner is not a red.
is_runner() {
  # Every arm is boundary-anchored on both sides so a substring like "go test"
  # inside "mongo test.js" does not match.
  printf '%s' "$1" | grep -qE '(^|[^[:alnum:]_/])((pytest|tox|jest|vitest|rspec|phpunit|ctest)([^[:alnum:]_]|$)|(npm|pnpm|yarn)[[:space:]]+(run[[:space:]]+)?test([^[:alnum:]_]|$)|cargo[[:space:]]+test([^[:alnum:]_]|$)|go[[:space:]]+test([^[:alnum:]_]|$)|make[[:space:]]+test([^[:alnum:]_]|$)|bundle[[:space:]]+exec[[:space:]]+rspec([^[:alnum:]_]|$)|mvn[[:space:]]+test([^[:alnum:]_]|$)|gradle[[:space:]]+test([^[:alnum:]_]|$)|dotnet[[:space:]]+test([^[:alnum:]_]|$))'
}
is_runner "$CMD" || exit 0

# Designed-to-fail commands are not unexpected reds.
case "$CMD" in
  *'|| true'* | *'|| :'* | *'|| exit 0'* | *'--expect-fail'* | *'--should-fail'* | *xfail*) exit 0 ;;
  '! '* | '!	'*) exit 0 ;;
esac

PRELUDE=$(dirname "$0")/prelude.sh
[ -f "$PRELUDE" ] || exit 0
. "$PRELUDE" || exit 0
[ "$CLUTCH_GIT" = 1 ] || exit 0
clutch_ensure_dir || exit 0

STATE="$CLUTCH_DIR/session-state"
CMDHASH=$(printf '%s' "$CMD" | cksum 2>/dev/null | cut -d' ' -f1) || exit 0
[ -n "$CMDHASH" ] || exit 0

# A runner that SUCCEEDED clears its red records: green is the progress signal.
if [ "$EVENT" = success ]; then
  [ -f "$STATE" ] || exit 0
  TMP="$STATE.tmp.$$"
  # mv runs regardless of grep's exit status: grep -v exits 1 when it filters
  # out every line (the whole file was this cmdhash's records), and that is a
  # successful clear, not a failure.
  grep -v -e "^redmoment $CMDHASH " -e "^redseen $CMDHASH\$" "$STATE" 2>/dev/null > "$TMP" 2>/dev/null
  mv "$TMP" "$STATE" 2>/dev/null || rm -f "$TMP" 2>/dev/null
  exit 0
fi

# --- failure path: the spiral check ---
NOW=$(date +%s 2>/dev/null) || NOW=0
case "$NOW" in '' | *[!0-9]*) NOW=0 ;; esac
# Fingerprint the WHOLE working state, not just unstaged tracked changes, or the
# hook would false-fire on real progress. git diff HEAD covers staged+unstaged
# tracked edits; git status --porcelain adds new-file presence; the untracked
# content loop (POSIX read, no xargs so an empty list cannot hang) covers edits
# to untracked files. Writing a new test or `git add`ing work all move DH.
DH=$( {
  git diff HEAD 2>/dev/null
  git status --porcelain 2>/dev/null
  git ls-files --others --exclude-standard 2>/dev/null | while IFS= read -r _f; do cat "$_f" 2>/dev/null; done
} | cksum 2>/dev/null | cut -d' ' -f1) || DH=0
[ -n "$DH" ] || DH=0

PDH=""
PTS=0
PRIOR=$(grep "^redmoment $CMDHASH " "$STATE" 2>/dev/null | tail -n1)
if [ -n "$PRIOR" ]; then
  PDH=$(printf '%s' "$PRIOR" | awk '{print $3}')
  PTS=$(printf '%s' "$PRIOR" | awk '{print $4}')
  case "$PTS" in '' | *[!0-9]*) PTS=0 ;; esac
fi

FIRE=0
if [ -n "$PRIOR" ] && [ "$PDH" = "$DH" ]; then
  AGE=$((NOW - PTS))
  if [ "$AGE" -ge 0 ] && [ "$AGE" -lt 900 ]; then
    if ! grep -q "^redseen $CMDHASH\$" "$STATE" 2>/dev/null; then
      EMITS=$(grep -c "^emit " "$STATE" 2>/dev/null) || EMITS=0
      case "$EMITS" in '' | *[!0-9]*) EMITS=0 ;; esac
      [ "$EMITS" -lt 2 ] && FIRE=1
    fi
  fi
fi

# Record-then-emit. Rewrite-and-swap the redmoment line to the current dh/ts. An
# edit since the last red (dh changed) or a fresh fire both clear any redseen so
# a later spiral on this target can fire again. If the write fails, abandon the
# fire: a lost record is acceptable, a false fire is not.
DROP_SEEN=0
[ "$PDH" != "$DH" ] && DROP_SEEN=1
[ "$FIRE" = 1 ] && DROP_SEEN=1
TMP="$STATE.tmp.$$"
{
  if [ -f "$STATE" ]; then
    if [ "$DROP_SEEN" = 1 ]; then
      grep -v -e "^redmoment $CMDHASH " -e "^redseen $CMDHASH\$" "$STATE" 2>/dev/null
    else
      grep -v "^redmoment $CMDHASH " "$STATE" 2>/dev/null
    fi
  fi
  printf 'redmoment %s %s %s\n' "$CMDHASH" "$DH" "$NOW"
  if [ "$FIRE" = 1 ]; then printf 'redseen %s\n' "$CMDHASH"; fi
} > "$TMP" 2>/dev/null
# Record-then-emit: only emit if the record landed. A skipped redseen printf
# must not poison the block's exit status, so the swap is its own statement.
if mv "$TMP" "$STATE" 2>/dev/null; then :; else rm -f "$TMP" 2>/dev/null; FIRE=0; fi

[ "$FIRE" = 1 ] || exit 0

CTX="clutch red-moment: a runner just failed again on the same target with nothing edited since the last failure. Red is the first half of the loop, not a verdict, and the runner pointing at one concrete thing is itself progress. If the user is genuinely stuck, surface at most ONE recognition line: isolate the single thing that is failing and make just that pass, or bank whatever already works with one commit and take the red on its own. Never say how many times it failed. If they are deliberately iterating rather than stuck, stay silent. If unsure, stay silent, a miss is free. A surfaced line counts against the 2-line self-cap."
BODY=$(printf '%s' "$CTX" | tr '\n' ' ' | tr -d '\000-\037' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g') || exit 0
printf '{"hookSpecificOutput":{"hookEventName":"PostToolUseFailure","additionalContext":"%s"}}\n' "$BODY"
exit 0
