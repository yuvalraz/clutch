#!/bin/sh
# clutch anchor: SessionStart hook (startup|resume|clear|compact).
# Injects the constitution plus at most 3 lines of thread context.
# Outside a git work tree: constitution only. Fail-open everywhere.

# Hook input JSON arrives on stdin; only the source field matters here.
INPUT=$(cat 2>/dev/null) || INPUT=""

# The constitution rides every session start, resume, clear, and compaction.
CONST="${CLAUDE_PLUGIN_ROOT:-}/rules/constitution.md"
if [ ! -f "$CONST" ]; then
  CONST=$(dirname "$0")/../rules/constitution.md
fi
[ -f "$CONST" ] && cat "$CONST" 2>/dev/null

PRELUDE=$(dirname "$0")/prelude.sh
[ -f "$PRELUDE" ] || exit 0
. "$PRELUDE" || exit 0
[ "$CLUTCH_GIT" = 1 ] || exit 0

# Reset the session clock only on a positively identified fresh session
# boundary: startup, resume, or clear. A compaction is the same session
# continuing, and an unrecognized, empty, or malformed source is treated the
# same way: preserve existing state. A wrongly preserved counter is mild; a
# wrongly reset one re-arms the emission cap mid-session.
FRESH=0
case "$INPUT" in
  *'"source":"startup"'* | *'"source": "startup"'* | \
    *'"source":"resume"'* | *'"source": "resume"'* | \
    *'"source":"clear"'* | *'"source": "clear"'*)
    FRESH=1
    if clutch_ensure_dir; then
      NOW=$(date +%s)
      BASE=$(clutch_last_authored %H) || BASE=""
      [ -n "$BASE" ] || BASE="-"
      printf 'start %s\nbase %s\n' "$NOW" "$BASE" 2>/dev/null > "$CLUTCH_DIR/session-state"
      # A sprint never legitimately spans a session boundary.
      rm -f "$CLUTCH_DIR/sprint-start" 2>/dev/null
    fi
    ;;
esac

echo ""
# The breadcrumb's last field is the most-recently-modified path (written by
# stop.sh). When present it turns the generic resume line into a specific one.
RECENT_PATH=""
if [ -f "$CLUTCH_DIR/breadcrumb" ]; then
  BC=$(cat "$CLUTCH_DIR/breadcrumb" 2>/dev/null)
  [ -n "$BC" ] && printf 'Thread: %s\n' "$BC"
  case "$BC" in
    *"most recent: "*) RECENT_PATH=${BC##*most recent: } ;;
  esac
fi
SUBJECT=$(clutch_last_authored %s) || SUBJECT=""
[ -n "$SUBJECT" ] && printf "Last landed: '%s'\n" "$SUBJECT"
if [ -s "$CLUTCH_DIR/captures.md" ]; then
  NCAP=$(grep -c . "$CLUTCH_DIR/captures.md" 2>/dev/null) || NCAP=0
  [ "$NCAP" -gt 0 ] 2>/dev/null && printf 'Captures held: %s.\n' "$NCAP"
fi
if [ -n "$RECENT_PATH" ]; then
  printf 'Smallest move to resume: finish or bank the change in %s.\n' "$RECENT_PATH"
else
  printf 'Smallest legal move: one commit.\n'
fi

# Intent ask: one final line, only at a true session boundary (the same
# startup|resume|clear gate that resets the clock; a compaction is the same
# session continuing) and only when no gear is declared. Declared means the
# heartbeat's exact predicate: the tempo file reads as one of the five gear
# words. Empty, truncated, or invalid content is not a declaration and the
# question fires. Fail-open: the question fires only on a positive read of
# "no gear" (readable state, no valid gear); an unreadable .clutch means
# silence, the safe state.
ASK=0
if [ "$FRESH" = 1 ]; then
  if [ ! -e "$CLUTCH_DIR" ]; then
    ASK=1
  elif ls "$CLUTCH_DIR" >/dev/null 2>&1; then
    GEAR=$(head -c 32 "$CLUTCH_DIR/tempo" 2>/dev/null | tr -d '[:space:]') || GEAR=""
    case "$GEAR" in
      espresso | craft | ballmer | freefall | ferment) ;;
      *) ASK=1 ;;
    esac
  fi
fi
if [ "$ASK" = 1 ]; then
  printf 'Intent for this session: build or ideate? /clutch:intent sets the frame.\n'
fi

exit 0
