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
case "$INPUT" in
  *'"source":"startup"'* | *'"source": "startup"'* | \
    *'"source":"resume"'* | *'"source": "resume"'* | \
    *'"source":"clear"'* | *'"source": "clear"'*)
    if clutch_ensure_dir; then
      NOW=$(date +%s)
      BASE=$(clutch_last_authored %H) || BASE=""
      [ -n "$BASE" ] || BASE="-"
      printf 'start %s\nbase %s\n' "$NOW" "$BASE" > "$CLUTCH_DIR/session-state" 2>/dev/null
      # A sprint never legitimately spans a session boundary.
      rm -f "$CLUTCH_DIR/sprint-start" 2>/dev/null
    fi
    ;;
esac

echo ""
if [ -f "$CLUTCH_DIR/breadcrumb" ]; then
  BC=$(cat "$CLUTCH_DIR/breadcrumb" 2>/dev/null)
  [ -n "$BC" ] && printf 'Thread: %s\n' "$BC"
fi
SUBJECT=$(clutch_last_authored %s) || SUBJECT=""
[ -n "$SUBJECT" ] && printf "Last landed: '%s'\n" "$SUBJECT"
if [ -s "$CLUTCH_DIR/captures.md" ]; then
  NCAP=$(grep -c . "$CLUTCH_DIR/captures.md" 2>/dev/null) || NCAP=0
  [ "$NCAP" -gt 0 ] 2>/dev/null && printf 'Captures waiting: %s. Pull with /clutch:capture when you choose.\n' "$NCAP"
fi
printf 'Smallest legal move: one commit.\n'

exit 0
