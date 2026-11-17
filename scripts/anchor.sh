#!/bin/sh
# clutch anchor: SessionStart hook (startup|resume|clear|compact|fork).
# Injects the constitution plus at most 3 lines of thread context.
# The worklog block prints before the git gate, so it shows inside and outside a repo. Fail-open everywhere.

# Hook input JSON arrives on stdin; only the source field matters here, plus seconds_since_last_response on a fork (read, never printed).
INPUT=$(cat 2>/dev/null) || INPUT=""

# The constitution rides every session start, resume, clear, compaction, and fork.
CONST="${CLAUDE_PLUGIN_ROOT:-}/rules/constitution.md"
if [ ! -f "$CONST" ]; then
  CONST=$(dirname "$0")/../rules/constitution.md
fi
[ -f "$CONST" ] && cat "$CONST" 2>/dev/null

PRELUDE=$(dirname "$0")/prelude.sh
[ -f "$PRELUDE" ] || exit 0
. "$PRELUDE" || exit 0
# Read before the git gate so sessions outside a repo see the worklog too.
WLINES=$(clutch_worklog_window 2>/dev/null) || WLINES=""
[ -n "$WLINES" ] && printf '\nWorklog:\n%s\n' "$WLINES"
# Before the git gate so sessions outside a repo get the tag too; CLUTCH_WATCH=off drops it.
[ "${CLUTCH_WATCH:-}" = off ] || { STAG=$(clutch_session_tag "$INPUT") && printf 'Session tag: %s\n' "$STAG"; }
# The guessed form of the intent ask; prints nothing and returns 1 without a guess or under CLUTCH_GUESS=off.
guess_ask() {
  [ "${CLUTCH_GUESS:-}" = off ] && return 1
  GUESS=$(clutch_guess_intent 2>/dev/null) || return 1
  printf 'Intent for this session: looks like %s again; say go, or pick %s. /clutch:intent sets the frame.\n' "$GUESS" "$CLUTCH_FOCI"
}
# Outside git and outside an active plain clutch folder there is no tempo, so a new session (startup or clear) has no gear: the intent ask rides it, guessed when it can be.
if [ "$CLUTCH_STATE" != 1 ]; then
  case "$INPUT" in
    *'"source":"startup"'* | *'"source": "startup"'* | *'"source":"clear"'* | *'"source": "clear"'*)
      guess_ask || printf 'Intent for this session: %s? /clutch:intent sets the frame.\n' "$CLUTCH_FOCI" ;;
  esac
  exit 0
fi

# Reset the session clock only on a positively identified fresh session
# boundary: startup, resume, or clear. A compaction is the same session
# continuing, and an unrecognized, empty, or malformed source is treated the
# same way: preserve existing state. A wrongly preserved counter is mild; a
# wrongly reset one re-arms the emission cap mid-session. A fork is the same
# session continuing too, unless its parent has been silent >= 5400 s: a cold
# fork, reset like resume. A missing or odd seconds value preserves.
COLD=0
case "$INPUT" in
  *'"source":"fork"'* | *'"source": "fork"'*)
    SECS=$(printf '%s' "$INPUT" | sed -n 's/.*"seconds_since_last_response": *\([0-9][0-9]*\).*/\1/p')
    [ -n "$SECS" ] && [ "$SECS" -ge 5400 ] 2>/dev/null && COLD=1
    ;;
esac
FRESH=0
case "$INPUT" in
  *'"source":"startup"'* | *'"source": "startup"'* | \
    *'"source":"resume"'* | *'"source": "resume"'* | \
    *'"source":"clear"'* | *'"source": "clear"'*)
    FRESH=1
    ;;
esac
[ "$COLD" = 1 ] && FRESH=1

# Per-session state: at a startup, resume, clear or fork this session gets
# its own folder .clutch/s/<tag8>/ for tempo, session-state and
# sprint-start; every hook and skill uses it once it exists. Never on a
# compaction or an unknown source, never through a symlinked .clutch/s or
# .clutch/s/<tag8>, never under CLUTCH_PER_SESSION=off or CLUTCH_WATCH=off.
# Any failure leaves the session on the folder-wide files, as before.
PS_SRC=""
case "$INPUT" in
  *'"source":"startup"'* | *'"source": "startup"'*) PS_SRC=startup ;;
  *'"source":"resume"'* | *'"source": "resume"'*) PS_SRC=resume ;;
  *'"source":"clear"'* | *'"source": "clear"'*) PS_SRC=clear ;;
  *'"source":"fork"'* | *'"source": "fork"'*) PS_SRC=fork ;;
esac
# The newest session-state among the folder-wide one and every real peer
# folder's, by mtime; prints nothing when there is none.
newest_state() {
  set --
  [ -f "$CLUTCH_DIR/session-state" ] && set -- "$CLUTCH_DIR/session-state"
  for NS_D in "$CLUTCH_DIR"/s/*; do
    [ "$NS_D" = "$CLUTCH_SDIR" ] || [ -L "$NS_D" ] || [ -L "$NS_D/session-state" ] ||
      [ ! -f "$NS_D/session-state" ] || set -- "$@" "$NS_D/session-state"
  done
  [ "$#" -gt 0 ] && ls -t "$@" 2>/dev/null | head -n 1
}
if ! clutch_session_paths "$INPUT" && [ -n "$CLUTCH_TAG8" ] && [ -n "$PS_SRC" ] &&
  [ ! -L "$CLUTCH_DIR/s" ] && { [ ! -e "$CLUTCH_DIR/s" ] || [ -d "$CLUTCH_DIR/s" ]; } &&
  [ ! -L "$CLUTCH_DIR/s/$CLUTCH_TAG8" ] && [ ! -e "$CLUTCH_DIR/s/$CLUTCH_TAG8" ] &&
  clutch_ensure_dir && mkdir -p "$CLUTCH_DIR/s/$CLUTCH_TAG8" 2>/dev/null &&
  clutch_session_paths "$INPUT"; then
  # Seed: a fork continues the newest state in this folder (a hot fork all
  # of it, a cold one its gear); a resume of a session that predates its
  # folder keeps the folder-wide gear unless another session has run since.
  PS_NEW=$(newest_state)
  case $PS_SRC in
    fork)
      if [ -n "$PS_NEW" ]; then
        PS_FROM=$(dirname "$PS_NEW")
        PS_FILES=tempo
        [ "$COLD" = 1 ] || PS_FILES="tempo session-state sprint-start"
        for PS_F in $PS_FILES; do
          [ ! -f "$PS_FROM/$PS_F" ] || cp "$PS_FROM/$PS_F" "$CLUTCH_SDIR/$PS_F" 2>/dev/null || :
        done
      fi
      ;;
    resume)
      if [ -z "$PS_NEW" ] || [ "$PS_NEW" = "$CLUTCH_DIR/session-state" ]; then
        [ ! -f "$CLUTCH_DIR/tempo" ] || cp "$CLUTCH_DIR/tempo" "$CLUTCH_SDIR/tempo" 2>/dev/null || :
      fi
      ;;
  esac
fi
if [ "$FRESH" = 1 ]; then
  # The gear is session-scoped: a brand-new session (startup or clear)
  # opens in neutral, so the intent ask below always fires at a fresh
  # start. A resume or a cold fork is a continued conversation and inherits
  # its gear; a compaction or a hot fork never reaches this branch.
  # Fail-open: rc pinned.
  case "$INPUT" in
    *'"source":"startup"'* | *'"source": "startup"'* | \
      *'"source":"clear"'* | *'"source": "clear"'*)
      rm -f "$CLUTCH_SDIR/tempo" 2>/dev/null || :
      ;;
  esac
  if clutch_ensure_dir; then
    NOW=$(date +%s)
    BASE=$(clutch_last_authored %H) || BASE=""
    [ -n "$BASE" ] || BASE="-"
    printf 'start %s\nbase %s\n' "$NOW" "$BASE" 2>/dev/null > "$CLUTCH_SDIR/session-state"
    # A sprint never legitimately spans a session boundary.
    rm -f "$CLUTCH_SDIR/sprint-start" 2>/dev/null
  fi
fi

# Prune, at startup only, once this session has its own folder: every other
# real folder under a real .clutch/s with no entry (itself included) changed
# within 7 days loses its known files, then rmdir, which keeps a folder that
# holds anything else. Silent.
# shortcut: a 7-day bound and one find; a session with no prompt for 7 days loses its folder and runs folder-wide until its next boundary.
if [ "$PS_SRC" = startup ] && [ "$CLUTCH_SDIR" != "$CLUTCH_DIR" ] && [ ! -L "$CLUTCH_DIR/s" ]; then
  PS_LIVE=$(find "$CLUTCH_DIR/s" -mindepth 1 -maxdepth 2 -mtime -7 2>/dev/null)
  for PS_D in "$CLUTCH_DIR"/s/*; do
    [ "$PS_D" != "$CLUTCH_SDIR" ] && [ ! -L "$PS_D" ] && [ -d "$PS_D" ] || continue
    case "
$PS_LIVE
" in
      *"
$PS_D
"* | *"
$PS_D/"*) continue ;;
    esac
    rm -f "$PS_D/tempo" "$PS_D/session-state" "$PS_D/sprint-start" "$PS_D"/session-state.tmp* 2>/dev/null
    rmdir "$PS_D" 2>/dev/null || :
  done
fi

# Git-derived lines; a plain clutch folder has no commits to name.
if [ "$CLUTCH_GIT" = 1 ]; then
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
fi

# Intent ask: one final line, only at a true session boundary (the same
# startup|resume|clear or cold-fork gate that resets the clock; a compaction
# or a hot fork is the same session continuing) and only when no gear is
# declared. Declared means the heartbeat's exact predicate: the tempo file
# reads as one of the five gear words. Empty, truncated, or invalid content is not a declaration and the
# question fires. Fail-open: the question fires only on a positive read of
# "no gear" (readable state, no valid gear); an unreadable .clutch means
# silence, the safe state.
ASK=0
if [ "$FRESH" = 1 ]; then
  if [ ! -e "$CLUTCH_DIR" ]; then
    ASK=1
  elif ls "$CLUTCH_DIR" >/dev/null 2>&1; then
    GEAR=$(head -c 32 "$CLUTCH_SDIR/tempo" 2>/dev/null | tr -d '[:space:]') || GEAR=""
    case "$GEAR" in
      espresso | craft | ballmer | freefall | ferment) ;;
      *) ASK=1 ;;
    esac
  fi
fi
if [ "$ASK" = 1 ]; then
  # A past declaration in this folder names its focus first; otherwise today's plain ask.
  guess_ask || printf 'Intent for this session: %s? /clutch:intent sets the frame.\n' "$CLUTCH_FOCI"
fi

exit 0
