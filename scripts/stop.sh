#!/bin/sh
# clutch stop: the single Stop hook. Same-event hooks run in parallel, so the
# thread breadcrumb writer and the recognition bell live in one process, run
# sequentially, and never race each other on .clutch/ state.
# Silent by default; any error degrades to nothing. Exit 0 always.

PRELUDE=$(dirname "$0")/prelude.sh
[ -f "$PRELUDE" ] || exit 0
. "$PRELUDE" || exit 0
[ "$CLUTCH_GIT" = 1 ] || exit 0
clutch_ensure_dir || exit 0

# --- thread: breadcrumb + Stop timestamp. Emits nothing, ever. ---
{
  BRANCH=$(git symbolic-ref --short -q HEAD 2>/dev/null) || BRANCH=""
  SUBJECT=$(clutch_last_authored %s) || SUBJECT=""

  MODIFIED=$(git diff --name-only 2>/dev/null | grep -c . 2>/dev/null) || MODIFIED=0

  # Most recently modified path among the changed files (mtime, not diff
  # order). Read line-wise so spaced filenames survive; the winner is printed
  # from inside the pipeline's subshell.
  RECENT=$(git diff --name-only 2>/dev/null | {
    R=""
    while IFS= read -r f; do
      if [ -e "$ROOT/$f" ]; then
        if [ -z "$R" ] || [ "$ROOT/$f" -nt "$ROOT/$R" ]; then
          R="$f"
        fi
      fi
    done
    printf '%s' "$R"
  }) || RECENT=""

  LINE=""
  [ -n "$BRANCH" ] && LINE="on $BRANCH"
  if [ -n "$SUBJECT" ]; then
    [ -n "$LINE" ] && LINE="$LINE; "
    LINE="${LINE}last landed '$SUBJECT'"
  fi
  [ -n "$LINE" ] && LINE="$LINE; "
  LINE="${LINE}$MODIFIED modified"
  [ -n "$RECENT" ] && LINE="$LINE; most recent: $RECENT"

  printf '%s\n' "$LINE" > "$CLUTCH_DIR/breadcrumb"
  NOW=$(date +%s)
  printf 'stop %s\n' "$NOW" >> "$CLUTCH_DIR/session-state"
} >/dev/null 2>&1

# --- bell: gated recognition. Silent by default; the gate is the point. ---
# Speaks only when (a) 25 minutes have passed since this session's first Stop,
# (b) a new commit authored by the user landed since session start, and
# (c) it has spoken fewer than 2 times this session. During a live sprint it
# instead surfaces the remaining minutes, once, under the same cap.

STATE="$CLUTCH_DIR/session-state"
[ -f "$STATE" ] || exit 0

NOW=$(date +%s) || exit 0
EMITS=$(grep -c "^emit " "$STATE" 2>/dev/null) || EMITS=0
[ "$EMITS" -lt 2 ] 2>/dev/null || exit 0

# JSON-encode $1 into a double-quoted JSON string body: strip control chars,
# escape backslash then double quote.
clutch_json() {
  printf '%s' "$1" | tr -d '\000-\037' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# Emit one hook-JSON object with a systemMessage. Stop-hook plain stdout goes
# to the debug log only; systemMessage is the documented visible channel.
clutch_say() {
  BODY=$(clutch_json "$1") || return 1
  printf '{"systemMessage":"%s"}\n' "$BODY"
}

# Live sprint: surface the countdown once, instead of the recognition line.
# A malformed, goal-less, future-dated, or expired marker is deleted and the
# recognition logic proceeds; a sprint never outlives its 20 minutes.
SPRINT="$CLUTCH_DIR/sprint-start"
if [ -f "$SPRINT" ]; then
  SLINE=$(head -n 1 "$SPRINT" 2>/dev/null) || SLINE=""
  SEPOCH=${SLINE%% *}
  GOAL=${SLINE#* }
  STALE=0
  case "$SEPOCH" in
    '' | *[!0-9]*) STALE=1 ;;
  esac
  # No space in the line means no goal text; never print the epoch as a goal.
  [ "$STALE" = 0 ] && [ "$GOAL" = "$SLINE" ] && STALE=1
  if [ "$STALE" = 0 ]; then
    AGE=$((NOW - SEPOCH))
    if [ "$AGE" -lt 0 ] || [ "$AGE" -ge 1200 ]; then
      STALE=1
    fi
  fi
  if [ "$STALE" = 1 ]; then
    rm -f "$SPRINT" 2>/dev/null
  else
    if ! grep -qF "emit sprint $SEPOCH" "$STATE" 2>/dev/null; then
      # Record first, emit only if the record landed. A lost emission is
      # acceptable; a repeated one is not.
      if printf 'emit sprint %s\n' "$SEPOCH" >> "$STATE" 2>/dev/null; then
        REM=$(((1200 - AGE + 59) / 60))
        clutch_say "Sprint: $REM min left on '$GOAL'"
      fi
    fi
    exit 0
  fi
fi

# (a) 25 minutes since the session's first Stop.
FIRST=$(grep "^stop " "$STATE" 2>/dev/null | head -n 1) || FIRST=""
FIRST=${FIRST#stop }
case "$FIRST" in
  '' | *[!0-9]*) exit 0 ;;
esac
[ $((NOW - FIRST)) -ge 1500 ] || exit 0

# (b) actual movement: a new authored commit since the session baseline.
BASE=$(grep "^base " "$STATE" 2>/dev/null | tail -n 1) || BASE=""
BASE=${BASE#base }
[ -n "$BASE" ] || exit 0
CUR=$(clutch_last_authored %H) || CUR=""
[ -n "$CUR" ] || exit 0
[ "$CUR" != "$BASE" ] || exit 0

SUBJECT=$(clutch_last_authored %s) || SUBJECT=""
[ -n "$SUBJECT" ] || exit 0

# Record first (rewrite-and-swap), emit only if the whole chain landed.
if {
  grep -v "^base " "$STATE" 2>/dev/null > "$STATE.tmp" &&
    printf 'base %s\nemit %s\n' "$CUR" "$NOW" >> "$STATE.tmp" &&
    mv "$STATE.tmp" "$STATE"
} >/dev/null 2>&1; then
  clutch_say "Landed: '$SUBJECT'. Smallest next move: one commit."
fi

exit 0
