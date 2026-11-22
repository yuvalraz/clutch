#!/bin/sh
# clutch stop: the single Stop hook. Same-event hooks run in parallel, so the
# thread breadcrumb writer, the worklog writer (~/.clutch/worklog.md) and the
# recognition bell live in one process, run sequentially, and never race each
# other on .clutch/ state.
# Silent by default; any error degrades to nothing. Exit 0 always. The
# stdout exceptions are the watch and beat gates' block lines below.

INPUT=$(cat 2>/dev/null) || INPUT=""
PRELUDE=$(dirname "$0")/prelude.sh
[ -f "$PRELUDE" ] || exit 0
. "$PRELUDE" || exit 0

# --- watch gate: a session holding its own open wait loops (field 6 = its
# @tag) and no armed /clutch:watch is blocked with the arming step, only when
# an owned wait is not yet recorded in ~/.clutch/watch/<tag8>; a smaller or
# equal set never blocks again. The new lines land there before the block
# prints, so a lost block is possible and a repeated one is not. Runs outside
# git too. Every failure falls through to the rest of the script.
# CLUTCH_WATCH=off skips it. Matches stay linear over the whole input (bash
# 3.2 slicing is quadratic on a long last_assistant_message). Armed means a
# "prompt" whose whole JSON value is the watch prompt: inside a JSON string
# every " is escaped, so a mention in a message cannot match. A key is the
# only string followed by ':', so "session_crons": is the key itself; no key
# means the registry was unreachable, so no block.
# The silent check (scripts/poll.sh, beside this script): when every owned
# wait parses as gh:<owner>/<repo>#<n>, as poll.sh reads it, a live poller
# (clutch_poll_alive 0) or a cannot-tell (2) arms the set; otherwise the ask
# is to start the poller, once per line recorded in neither <tag8> nor
# <tag8>.polled (the ask records in .polled, which 2.16.2 never reads), and
# once more after a poller that ran has ended (3). Its .poll is removed only
# once the dedupe read and the .polled append worked, right before the ask
# prints. A dead poller that started under one round ago (poll.sh's sleep,
# CLUTCH_POLL_SLEEP when 1-5 digits >= 1, else 600 s) and never woke (an
# empty .woke, or its .poll newer than .woke) died young (clutch_poll_young),
# say killed by a Bash timeout or a headless exit: its .poll is
# dropped quietly and the dedupe applies as with no .poll, so a poller that
# keeps dying young is asked for once, not at every stop.
# A set with any other wait is asked the 30-minute watch through <tag8> and
# leaves .poll alone. CLUTCH_POLL=off, or a scripts dir that is not absolute,
# holds a byte outside the spelled-out class, or has no poll.sh, keeps the
# 2.16.2 */10 ask byte for byte.
if [ "${CLUTCH_WATCH:-}" != off ]; then
  case $INPUT in
    *'"stop_hook_active":true'* | *'"stop_hook_active": true'*) ;;
    *'"session_crons":'*)
      if WATCH_TAG=$(clutch_session_tag "$INPUT") &&
        WATCH_OWN=$(clutch_owned_loops "$WATCH_TAG" 2>/dev/null) &&
        [ -n "$WATCH_OWN" ]; then
        WATCH_KIND=old
        WATCH_DIR=$(dirname "$0")
        if [ "${CLUTCH_POLL:-}" != off ] && [ -f "$WATCH_DIR/poll.sh" ]; then
          case $WATCH_DIR in
            /*[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._/~+-]*) ;;
            /*)
              if printf '%s\n' "$WATCH_OWN" | LC_ALL=C awk '{ r = $4; sub(/[,;:.\r]+$/, "", r) }
                r !~ /^gh:[A-Za-z0-9._-]+\/[A-Za-z0-9._-]+#[0-9]+$/ { f = 1 } END { exit f }'; then
                WATCH_KIND=poll
              else
                WATCH_KIND=cron30
              fi
              ;;
          esac
        fi
        case $INPUT in
          *"\"prompt\":\"/clutch:watch $WATCH_TAG\""* | *"\"prompt\": \"/clutch:watch $WATCH_TAG\""*) ;;
          *)
            WATCH_FILE="$HOME/.clutch/watch/${WATCH_TAG#@}"
            if [ "$WATCH_KIND" = poll ]; then
              clutch_poll_alive "$WATCH_TAG"
              WATCH_RC=$?
              # Died young (clutch_poll_young): drop its .poll quietly and
              # dedupe as rc 1.
              if [ "$WATCH_RC" = 3 ] && clutch_poll_young "$WATCH_TAG"; then
                rm -f "$WATCH_FILE.poll" 2>/dev/null
                WATCH_RC=1
              fi
              case $WATCH_RC in 1 | 3) ;; *) WATCH_RC=0 ;; esac
              WATCH_NEW=$WATCH_OWN
              for WATCH_REC in "$WATCH_FILE" "$WATCH_FILE.polled"; do
                [ "$WATCH_RC" != 0 ] && [ -n "$WATCH_NEW" ] && [ -e "$WATCH_REC" ] || continue
                WATCH_NEW=$(printf '%s\n' "$WATCH_NEW" | grep -vxF -f "$WATCH_REC" 2>/dev/null)
                [ "$?" -le 1 ] || WATCH_RC=0
              done
              [ "$WATCH_RC" = 3 ] || [ -n "$WATCH_NEW" ] || WATCH_RC=0
              if [ "$WATCH_RC" != 0 ]; then
                mkdir -p "$HOME/.clutch/watch" 2>/dev/null &&
                  { [ -z "$WATCH_NEW" ] || { printf '%s\n' "$WATCH_NEW" >> "$WATCH_FILE.polled"; } 2>/dev/null; } &&
                  { [ "$WATCH_RC" != 3 ] || rm -f "$WATCH_FILE.poll" 2>/dev/null; } &&
                  printf '{"decision":"block","reason":"This session holds open wait loops and no watch. Start `sh %s/poll.sh %s` with the Bash tool'\''s run_in_background, then end the turn: it stays silent until a wait moves. If the user said not to watch them, just end the turn."}\n' "$WATCH_DIR" "$WATCH_TAG" &&
                  exit 0
              fi
            else
              WATCH_CRON='*/10 8-21 * * *'
              [ "$WATCH_KIND" = old ] || WATCH_CRON='7,37 8-21 * * *'
              if [ -e "$WATCH_FILE" ]; then
                WATCH_NEW=$(printf '%s\n' "$WATCH_OWN" | grep -vxF -f "$WATCH_FILE" 2>/dev/null)
              else
                WATCH_NEW=$WATCH_OWN
              fi &&
                [ -n "$WATCH_NEW" ] &&
                mkdir -p "$HOME/.clutch/watch" 2>/dev/null &&
                printf '%s\n' "$WATCH_NEW" 2>/dev/null >> "$WATCH_FILE" &&
                printf '{"decision":"block","reason":"This session holds open wait loops and no watch. Arm one now with CronCreate, schedule `%s`, recurring, prompt `/clutch:watch %s`, then end the turn. If the user said not to watch them, just end the turn."}\n' "$WATCH_CRON" "$WATCH_TAG" &&
                exit 0
            fi
            ;;
        esac
      fi
      ;;
  esac
fi

# --- beat gate: a session whose tag has an ops record
# (~/.clutch/watch/<tag8>.beat, written by ops Step 0) and no armed
# /clutch:beat is blocked with the arming step once a local day. "asked
# <YYYY-MM-DD>" lands in the record before the block prints, so a lost block
# is possible and a repeated one is not; an unreadable record (grep rc 2)
# never blocks. Runs after the watch gate, whose block wins the stop, and
# outside git too. Never creates the record. Every failure falls through.
# CLUTCH_BEAT=off or CLUTCH_WATCH=off skips it. Same linear matches and armed-prompt rule as the
# watch gate. When the beat does not block, the same record asks the sweep
# (`/clutch:ops re-sweep armed`, no tag) the same way, once a local day, with
# its own "sweep asked <YYYY-MM-DD>" line. A cron whose whole prompt is the
# hand-typed `/clutch:ops re-sweep` counts as armed too: never armed twice.
if [ "${CLUTCH_BEAT:-}" != off ] && [ "${CLUTCH_WATCH:-}" != off ]; then
  case $INPUT in
    *'"stop_hook_active":true'* | *'"stop_hook_active": true'*) ;;
    *'"session_crons":'*)
      if BEAT_TAG=$(clutch_session_tag "$INPUT") &&
        BEAT_FILE="$HOME/.clutch/watch/${BEAT_TAG#@}.beat" &&
        [ -f "$BEAT_FILE" ] &&
        BEAT_DAY=$(date +%Y-%m-%d 2>/dev/null) && [ -n "$BEAT_DAY" ]; then
        grep -qx "asked $BEAT_DAY" "$BEAT_FILE" 2>/dev/null
        if [ "$?" = 1 ]; then
          case $INPUT in
            *"\"prompt\":\"/clutch:beat $BEAT_TAG\""* | *"\"prompt\": \"/clutch:beat $BEAT_TAG\""*) ;;
            *)
              { printf 'asked %s\n' "$BEAT_DAY" >> "$BEAT_FILE"; } 2>/dev/null &&
                printf '{"decision":"block","reason":"This ops session has no beat. Arm one now with CronCreate, schedule `7 8-20 * * *`, recurring, prompt `/clutch:beat %s`, then end the turn. If the user said not to arm a beat, just end the turn."}\n' "$BEAT_TAG" &&
                exit 0
              ;;
          esac
        fi
        grep -qx "sweep asked $BEAT_DAY" "$BEAT_FILE" 2>/dev/null
        if [ "$?" = 1 ]; then
          # shortcut: an exact old-prompt `/clutch:ops re-sweep` cron (only from pre-release 323c0ed installs) counts as armed but runs the acting sweep; it dies with its session.
          case $INPUT in
            *'"prompt":"/clutch:ops re-sweep armed"'* | *'"prompt": "/clutch:ops re-sweep armed"'* | \
              *'"prompt":"/clutch:ops re-sweep"'* | *'"prompt": "/clutch:ops re-sweep"'*) ;;
            *)
              { printf 'sweep asked %s\n' "$BEAT_DAY" >> "$BEAT_FILE"; } 2>/dev/null &&
                printf '%s\n' '{"decision":"block","reason":"This ops session has no sweep. Arm one now with CronCreate, schedule `37 8,12,16 * * *`, recurring, prompt `/clutch:ops re-sweep armed`, then end the turn. If the user said not to arm a sweep, just end the turn."}' &&
                exit 0
              ;;
          esac
        fi
      fi
      ;;
  esac
fi

[ "$CLUTCH_GIT" = 1 ] || exit 0
clutch_ensure_dir || exit 0
# This session's own state folder when it has one, else the folder-wide files.
clutch_session_paths "$INPUT"

# --- thread: breadcrumb + Stop timestamp + worklog. Emits nothing, ever. ---
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
  printf 'stop %s\n' "$NOW" >> "$CLUTCH_SDIR/session-state"

  # Worklog: log a landed authored commit once for peer sessions. The head and
  # this stop's epoch are recorded first, on every stop, then the line
  # appended: a lost line is acceptable, a repeated one is not. The gate reads
  # the epoch stored by the previous stop, so an idle head stays fresh and a
  # fetched branch checked out later is not logged. The first run seeds without
  # backfill; a head that does not descend from the logged one (branch
  # switch, rebase) reseeds silently. A head whose committer time is older
  # than the stored epoch was reached by a checkout, not a new commit (old
  # branch, return to a logged branch, bisect), and reseeds silently; so does
  # a one-field head file with no epoch. A subject already in the last 200
  # lines is skipped, because a pull of the user's own commits from another
  # worktree or clone moves the head forward with recent commits too.
  # mkdir -p sits last so only a due line creates ~/.clutch, and creating it
  # starts a brain (accepted, see README).
  WHEAD="$CLUTCH_DIR/worklog-head"
  WCUR=$(clutch_last_authored %H) || WCUR=""
  if [ -n "$WCUR" ]; then
    WREC=$(head -n 1 "$WHEAD" 2>/dev/null) || WREC=""
    WPREV=${WREC%% *}
    WSEEN=${WREC#* }
    case "$WSEEN" in '' | *[!0-9]*) WSEEN="" ;; esac
    if printf '%s %s\n' "$WCUR" "$NOW" > "$WHEAD" && [ "$WCUR" != "$WPREV" ]; then
      WCT=$(git log -1 --format=%ct "$WCUR" 2>/dev/null) || WCT=""
      # shortcut: the 200 cut counts bytes, not characters, and can split a
      # glyph; upgrade if subjects that long show up.
      WLANDED=$(printf "landed '%.200s'" "$SUBJECT")
      if [ -n "$WPREV" ] && [ -n "$WSEEN" ] && [ -n "$SUBJECT" ] &&
        [ "$WCT" -ge "$WSEEN" ] &&
        git merge-base --is-ancestor "$WPREV" "$WCUR" &&
        ! tail -n 200 "$CLUTCH_WORKLOG" 2>/dev/null | grep -qF "moved: $WLANDED" &&
        mkdir -p "$HOME/.clutch" 2>/dev/null; then
        printf '%s %s moved: %s\n' "$NOW" \
          "$(basename "$ROOT" | tr ' ' -)" "$WLANDED" >> "$CLUTCH_WORKLOG"
      fi
    fi
  fi
} >/dev/null 2>&1

# --- bell: gated recognition. Silent by default; the gate is the point. ---
# Speaks only when (a) 25 minutes have passed since this session's first Stop,
# (b) a new commit authored by the user landed since session start, and
# (c) it has spoken fewer than 2 times this session. During a live sprint it
# instead surfaces the remaining minutes, once, under the same cap.

STATE="$CLUTCH_SDIR/session-state"
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
SPRINT="$CLUTCH_SDIR/sprint-start"
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
# No movement is not an exit: the landing check below still deserves its turn.
RANG=0
BASE=$(grep "^base " "$STATE" 2>/dev/null | tail -n 1) || BASE=""
BASE=${BASE#base }
CUR=$(clutch_last_authored %H) || CUR=""
SUBJECT=$(clutch_last_authored %s) || SUBJECT=""
if [ -n "$BASE" ] && [ -n "$CUR" ] && [ "$CUR" != "$BASE" ] && [ -n "$SUBJECT" ]; then
  # Record first (rewrite-and-swap), emit only if the whole chain landed.
  if {
    grep -v "^base " "$STATE" 2>/dev/null > "$STATE.tmp" &&
      printf 'base %s\nemit %s\n' "$CUR" "$NOW" >> "$STATE.tmp" &&
      mv "$STATE.tmp" "$STATE"
  } >/dev/null 2>&1; then
    clutch_say "Landed: '$SUBJECT'. Smallest next move: one commit."
    RANG=1
  fi
fi

# --- safe-landing: after a long unbroken run with unbanked work, one offer
# to bank the gains at a seam. Turn-end is the seam proxy; green-test seam
# detection needs session state that does not ship yet. One offer per state,
# never on a stop where the bell already spoke, same 2-line cap, and
# ignoring the offer is a full answer.
if [ "$RANG" = 0 ] && [ $((NOW - FIRST)) -ge 5400 ]; then
  if ! grep -q "^emit land " "$STATE" 2>/dev/null; then
    DIRTY=$(git status --porcelain 2>/dev/null | head -n 1)
    if [ -n "$DIRTY" ]; then
      if { printf 'emit land %s\n' "$NOW" >> "$STATE"; } 2>/dev/null; then
        clutch_say "Long run, unbanked work. A seam if you want one: bank what works with one commit and a resume note. Ignoring this is also a move."
      fi
    fi
  fi
fi

exit 0
