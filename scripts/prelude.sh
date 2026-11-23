# Shared prelude for clutch hook scripts. Sourced, not executed.
# POSIX sh only. Every failure degrades to "do nothing".
#
# Sets: CLUTCH_GIT (1 inside a git work tree, else 0), CLUTCH_STATE (1 in a
# git work tree or an active plain clutch folder, else 0), ROOT, CLUTCH_DIR,
# EXCLUDE_FILE, CLUTCH_WORKLOG, CLUTCH_FOCI, CLUTCH_FOCUS_RE. Defines clutch_ensure_dir,
# clutch_last_authored, clutch_worklog_window, clutch_open_loops,
# clutch_session_tag, clutch_owned_loops, clutch_ops_due,
# clutch_guess_intent.
# Also defines clutch_beat_window and clutch_ops_record.
# Also defines clutch_poll_alive and clutch_poll_young.
# Also defines clutch_session_paths (CLUTCH_TAG8, CLUTCH_SDIR, CLUTCH_SREL).
# Also defines clutch_merge_listed and clutch_unwatched_loops.

CLUTCH_GIT=0
CLUTCH_STATE=0
ROOT=""
CLUTCH_DIR=""
EXCLUDE_FILE=""

# The focuses the hooks name and guess. CLUTCH_INVESTIGATE=off keeps 2.12.0's four.
if [ "${CLUTCH_INVESTIGATE:-}" = off ]; then
  CLUTCH_FOCI='build, ideate, ops, or review'
  CLUTCH_FOCUS_RE='^(build|ideate|ops|review)$'
else
  CLUTCH_FOCI='build, ideate, ops, review, or investigate'
  CLUTCH_FOCUS_RE='^(build|ideate|ops|review|investigate)$'
fi

if command -v git >/dev/null 2>&1; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || ROOT=""
    if [ -n "$ROOT" ]; then
      CLUTCH_GIT=1
      CLUTCH_DIR="$ROOT/.clutch"
      # info/exclude resolved via git so linked worktrees and submodules land
      # in the right place, never a guessed $PWD/.git.
      EXCLUDE_FILE=$(git rev-parse --git-path info/exclude 2>/dev/null) || EXCLUDE_FILE=""
      case "$EXCLUDE_FILE" in
        "") ;;
        /*) ;;
        *) EXCLUDE_FILE="$PWD/$EXCLUDE_FILE" ;;
      esac
    fi
  fi
fi

# A plain clutch folder: outside git, the physical cwd is active once its
# .clutch holds tempo (a declaration) or a session-state whose first line
# starts with "start " (only the anchor writes that). A model-written
# "emit model" line must not activate a pool-only .clutch. Never $HOME (its
# .clutch is the brain; -ef also refuses a symlink to it) or /.
# CLUTCH_PLAIN=off turns this off.
if [ "$CLUTCH_GIT" = 1 ]; then
  CLUTCH_STATE=1
elif [ "${CLUTCH_PLAIN:-}" != off ]; then
  CP_D=$(pwd -P 2>/dev/null) || CP_D=""
  if [ -n "$CP_D" ] && [ "$CP_D" != / ] && [ ! "$CP_D" -ef "$HOME" ]; then
    if [ -f "$CP_D/.clutch/tempo" ]; then
      CLUTCH_STATE=1
    elif [ -f "$CP_D/.clutch/session-state" ]; then
      CP_L=$(head -c 6 "$CP_D/.clutch/session-state" 2>/dev/null) || CP_L=""
      [ "$CP_L" = "start " ] && CLUTCH_STATE=1
    fi
    [ "$CLUTCH_STATE" = 1 ] && CLUTCH_DIR="$CP_D/.clutch"
  fi
fi

# The cross-session worklog is global, so it is set inside a repo or not.
CLUTCH_WORKLOG="$HOME/.clutch/worklog.md"

# Create .clutch/ on first write and keep it out of git status via the
# repo-local exclude file. Fail-open: any error returns nonzero, caller exits 0.
clutch_ensure_dir() {
  [ "$CLUTCH_STATE" = 1 ] || return 1
  if [ ! -d "$CLUTCH_DIR" ]; then
    mkdir -p "$CLUTCH_DIR" 2>/dev/null || return 1
  fi
  if [ -n "$EXCLUDE_FILE" ]; then
    EXDIR=$(dirname "$EXCLUDE_FILE" 2>/dev/null) || EXDIR=""
    if [ -n "$EXDIR" ] && [ ! -d "$EXDIR" ]; then
      mkdir -p "$EXDIR" 2>/dev/null || true
    fi
    if ! grep -qxF ".clutch/" "$EXCLUDE_FILE" 2>/dev/null; then
      printf '.clutch/\n' >> "$EXCLUDE_FILE" 2>/dev/null || true
    fi
  fi
  return 0
}

# Last commit authored by the user, in the given pretty format ($1).
# Identity is compared exactly (no substring/regex matching): first the
# author email against git config user.email, then the author name against
# user.name. Walk is bounded to the 50 most recent commits.
# Prints nothing if there is no author identity or no authored commit.
clutch_last_authored() {
  [ "$CLUTCH_GIT" = 1 ] || return 1
  FMT="$1"
  AE=$(git config user.email 2>/dev/null) || AE=""
  AN=$(git config user.name 2>/dev/null) || AN=""
  [ -n "$AE" ] || [ -n "$AN" ] || return 1
  H=""
  if [ -n "$AE" ]; then
    H=$(git log -50 --format='%H %ae' 2>/dev/null | {
      while IFS=' ' read -r h rest; do
        if [ "$rest" = "$AE" ]; then
          printf '%s' "$h"
          break
        fi
      done
    })
  fi
  if [ -z "$H" ] && [ -n "$AN" ]; then
    H=$(git log -50 --format='%H %an' 2>/dev/null | {
      while IFS=' ' read -r h rest; do
        if [ "$rest" = "$AN" ]; then
          printf '%s' "$h"
          break
        fi
      done
    })
  fi
  [ -n "$H" ] || return 1
  git log -1 --pretty="$FMT" "$H" 2>/dev/null
}

# One scan of the worklog for both readers ($1: window or loops). A wait loop
# is "<epoch> <repo> wait: <kind>:<ref> <baseline> <text>"; a later moved:
# line whose fourth field is the same <kind>:<ref> closes it, and an open wait
# ages out after 5 days. A wait whose text starts with an @tag is keyed by ref
# and tag, so peer sessions on one ref stay apart: a moved: line whose fifth
# field is an @tag closes only that tag's wait, an untagged moved: line closes
# every wait on the ref. Malformed, future-dated and unknown-verb lines are
# skipped. A ref's trailing ,;:. or CR is ignored on both sides, and a
# "moved: L2:" line never closes a wait. Returns 1 when the file does not
# exist (no worklog), 2 when it exists but is not a readable regular file or
# `date` or `tail` fails; never creates anything.
# shortcut: scans the last 2000 lines and cuts bytes, not characters; upgrade
# if 5 days log more than 2000 lines or a cut splits a glyph.
clutch_worklog_scan() {
  [ -e "$CLUTCH_WORKLOG" ] || return 1
  [ -f "$CLUTCH_WORKLOG" ] && [ -r "$CLUTCH_WORKLOG" ] || return 2
  WNOW=$(date +%s 2>/dev/null) || return 2
  WTAIL=$(tail -n 2000 "$CLUTCH_WORKLOG" 2>/dev/null) || return 2
  # LC_ALL=C: a UTF-8 awk aborts the whole scan on one invalid byte.
  printf '%s\n' "$WTAIL" | LC_ALL=C awk -v now="$WNOW" -v mode="$1" '
    $1 ~ /^[0-9]+$/ && NF >= 4 {
      age = now - $1
      if (age < 0) next
      n++; ln[n] = $0; vb[n] = $3; ag[n] = age
      r = $4; sub(/[,;:.\r]+$/, "", r)
      # A session tag is @ plus 8 lowercase hex (the head of a session id); any other @word is plain text.
      if ($3 == "wait:" && NF >= 6 && r ~ /^[^:]+:./) {
        k = ($6 ~ /^@[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$/) ? r SUBSEP $6 : r
        open[k] = n; ref[k] = r
      } else if ($3 == "moved:") {
        if ($5 ~ /^@[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$/) delete open[r SUBSEP $5]
        else for (k in open) if (ref[k] == r) delete open[k]
      }
    }
    # Live claims are kept first, then open waits, then moves, so neither a
    # burst of moves nor a pile of waits can push a claim out of view; waits
    # still print first.
    END {
      for (k in open) if (ag[open[k]] < 432000) w[open[k]] = 1
      if (mode == "loops") { for (i = 1; i <= n; i++) if (w[i]) print ln[i]; exit }
      k = 0
      for (i = n; i > 0 && k < 8; i--) if (vb[i] == "on:" && ag[i] < 14400) { keep[i] = 1; k++ }
      for (i = n; i > 0 && k < 8; i--) if (w[i]) { keep[i] = 1; k++ }
      for (i = n; i > 0 && k < 8; i--) if (vb[i] == "moved:" && ag[i] < 86400) { keep[i] = 1; k++ }
      for (p = 1; p >= 0; p--) for (i = 1; i <= n; i++) if (keep[i] && w[i] == p) {
        line = ln[i]; sub(/^[ \t]*[0-9]+[ \t]+/, "", line); print substr(line, 1, 160)
      }
    }' 2>/dev/null
}

# The open wait loops, raw (epoch kept), oldest first; read by the ops tick.
clutch_open_loops() { clutch_worklog_scan loops; }

# The session tag from hook input JSON ($1): "@" plus the first 8 chars of
# the FIRST "session_id" value, which must be [0-9A-Za-z-]. Prints nothing
# and returns 1 otherwise. Cut at the first key: a greedy sed takes the last.
clutch_session_tag() {
  case $1 in *'"session_id"'*) ;; *) return 1 ;; esac
  CST_R=${1#*\"session_id\"}
  CST_ID=$(printf '%s\n' "$CST_R" | sed -n '1s/^ *: *"\([0-9A-Za-z-]\{1,\}\)".*/\1/p')
  [ -n "$CST_ID" ] || return 1
  printf '@%.8s\n' "$CST_ID"
}

# The open wait lines owned by tag $1 (field 6 equals it), raw, oldest
# first. Returns 2 on a malformed tag, else clutch_open_loops' rc 1 or 2.
# rc 1 (no worklog) only when the absence is proven: an empty HOME, a
# dangling symlink, or a ~/.clutch or HOME that is not a searchable directory
# is rc 2, so a caller never reads "can't stat" as "no loops".
clutch_owned_loops() {
  # Spelled-out class: a range like A-Z matches é under a UTF-8 /bin/sh.
  case $1 in @|@*[!0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-]*|[!@]*|'') return 2 ;; esac
  COL_OUT=$(clutch_open_loops)
  COL_RC=$?
  if [ "$COL_RC" = 1 ]; then
    [ -n "$HOME" ] && [ ! -L "$CLUTCH_WORKLOG" ] || return 2
    if [ -e "$HOME/.clutch" ] || [ -L "$HOME/.clutch" ]; then
      [ -d "$HOME/.clutch" ] && [ -x "$HOME/.clutch" ] || return 2
    else
      [ -d "$HOME" ] && [ -x "$HOME" ] || return 2
    fi
    return 1
  fi
  [ "$COL_RC" = 0 ] || return "$COL_RC"
  [ -n "$COL_OUT" ] || return 0
  printf '%s\n' "$COL_OUT" | LC_ALL=C awk -v t="$1" '$6 == t'
}

# The ops beat's read for tag $1 (record ~/.clutch/watch/<tag8>.beat): the
# open waits no session's tag owns, raw, oldest first; then the newest 20
# moved: lines whose epoch is after the record's last "last <epoch>" line and
# at or before now - 120 s (a grace for lines appended after their stamp),
# and whose fifth field is not the tag, oldest first. With no record, or none
# with a last line, there are no moves. "last <now - 120>" (never below the
# previous last) is appended to an existing record before anything prints;
# the record and ~/.clutch/watch are never created. Returns 2 on a malformed
# tag, a date failure, an unreadable worklog or record, a ~/.clutch or HOME
# that cannot be searched, or a failed append (nothing printed), and 1 only
# with no worklog proven absent (nothing recorded). With a second argument
# peek it prints only the moved: lines and appends nothing; same rc.
clutch_beat_window() {
  # Spelled-out class: a range like A-Z matches é under a UTF-8 /bin/sh.
  case $1 in @????????) ;; *) return 2 ;; esac
  case $1 in @*[!0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-]*) return 2 ;; esac
  CBW_NOW=$(date +%s 2>/dev/null) || return 2
  case $CBW_NOW in '' | *[!0-9]*) return 2 ;; esac
  CBW_W=$(clutch_open_loops)
  CBW_RC=$?
  if [ "$CBW_RC" = 1 ]; then
    [ -n "$HOME" ] && [ ! -L "$CLUTCH_WORKLOG" ] || return 2
    if [ -e "$HOME/.clutch" ] || [ -L "$HOME/.clutch" ]; then
      [ -d "$HOME/.clutch" ] && [ -x "$HOME/.clutch" ] || return 2
    else
      [ -d "$HOME" ] && [ -x "$HOME" ] || return 2
    fi
    return 1
  fi
  [ "$CBW_RC" = 0 ] || return 2
  CBW_F="$HOME/.clutch/watch/${1#@}.beat"
  [ ! -f "$CBW_F" ] || [ -r "$CBW_F" ] || return 2
  # shortcut: a 120 s grace, so a moved: line appended up to 120 s after its stamp is never lost; widen it if a writer lags more
  CBW_E=$((CBW_NOW - 120))
  CBW_S=$(LC_ALL=C sed -n 's/^last \([0-9][0-9]*\)$/\1/p' "$CBW_F" 2>/dev/null | tail -n 1)
  [ -n "$CBW_S" ] || CBW_S=$CBW_E
  [ "$CBW_S" -le "$CBW_E" ] || CBW_E=$CBW_S
  CBW_T=$(tail -n 2000 "$CLUTCH_WORKLOG" 2>/dev/null) || return 2
  # shortcut: newest 20 moves only; upgrade if a beat gap logs more that matter
  CBW_M=$(printf '%s\n' "$CBW_T" | LC_ALL=C awk -v s="$CBW_S" -v n="$CBW_E" -v t="$1" \
    '$1 ~ /^[0-9]+$/ && $3 == "moved:" && $1 + 0 > s + 0 && $1 + 0 <= n + 0 && $5 != t' | tail -n 20) || return 2
  if [ "${2-}" = peek ]; then
    [ -z "$CBW_M" ] || printf '%s\n' "$CBW_M"
    return 0
  fi
  if [ -f "$CBW_F" ]; then
    { printf 'last %s\n' "$CBW_E" >> "$CBW_F"; } 2>/dev/null || return 2
  fi
  [ -z "$CBW_W" ] || printf '%s\n' "$CBW_W" |
    LC_ALL=C awk '$6 !~ /^@[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$/'
  [ -z "$CBW_M" ] || printf '%s\n' "$CBW_M"
  return 0
}

# Is <@tag>'s ops record (~/.clutch/watch/<tag8>.beat) there? 0 yes, 1 surely
# not (the armed beat and sweep stop), 2 cannot tell (they go on). Writes nothing.
clutch_ops_record() {
  # Spelled-out class, the same guard as clutch_beat_window.
  case $1 in @????????) ;; *) return 2 ;; esac
  case $1 in @*[!0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-]*) return 2 ;; esac
  [ -n "$HOME" ] || return 2
  COR_F="$HOME/.clutch/watch/${1#@}.beat"
  if [ -e "$COR_F" ] || [ -L "$COR_F" ]; then return 0; fi
  for COR_D in "$HOME/.clutch/watch" "$HOME/.clutch"; do
    if [ -e "$COR_D" ] || [ -L "$COR_D" ]; then
      [ -d "$COR_D" ] && [ -x "$COR_D" ] && return 1
      return 2
    fi
  done
  [ -d "$HOME" ] && [ -x "$HOME" ] || return 2
  return 1
}

# Is <@tag>'s silent check (~/.clutch/watch/<tag8>.poll, first line "<pid>
# <start epoch>" with an optional third field) alive? 0 alive: the pid runs
# and its full command line (ps -ww; macOS cuts at 80 columns otherwise) ends
# with poll.sh @<tag8>. 1 no .poll (proven absent), 2 cannot tell, 3 ended
# (dead or reused pid, another tag's poller, a malformed line). With a second
# argument beat, a live poller whose line has no third field beat (a 2.18.0
# poller, which never beats) is 4. Writes nothing.
clutch_poll_alive() {
  # Spelled-out class, the same guard as clutch_ops_record.
  case $1 in @????????) ;; *) return 2 ;; esac
  case $1 in @*[!0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-]*) return 2 ;; esac
  [ -n "$HOME" ] || return 2
  CPA_F="$HOME/.clutch/watch/${1#@}.poll"
  if [ -e "$CPA_F" ] || [ -L "$CPA_F" ]; then
    [ -f "$CPA_F" ] && [ -r "$CPA_F" ] || return 2
    CPA_L=$(head -n 1 "$CPA_F" 2>/dev/null) || return 2
    # pid 0 is refused: kill -0 0 signals the caller's own process group.
    CPA_P=$(printf '%s\n' "$CPA_L" | LC_ALL=C awk '(NF == 2 || NF == 3) && $1 ~ /^[1-9][0-9]*$/ && $2 ~ /^[0-9]+$/ { print $1 }')
    [ -n "$CPA_P" ] || return 3
    kill -0 "$CPA_P" 2>/dev/null || return 3
    CPA_C=$(ps -ww -p "$CPA_P" -o command= 2>/dev/null) || return 2
    case $CPA_C in
      *"poll.sh $1")
        [ "${2-}" != beat ] || [ "$(printf '%s\n' "$CPA_L" | LC_ALL=C awk '{ print $3 }')" = beat ] || return 4
        return 0 ;;
    esac
    return 3
  fi
  for CPA_D in "$HOME/.clutch/watch" "$HOME/.clutch"; do
    if [ -e "$CPA_D" ] || [ -L "$CPA_D" ]; then
      [ -d "$CPA_D" ] && [ -x "$CPA_D" ] && return 1
      return 2
    fi
  done
  [ -d "$HOME" ] && [ -x "$HOME" ] || return 2
  return 1
}

# Did <@tag>'s ended silent check die young? 0 when its .poll first line is
# well-formed ("<pid> <start>[ <third>]", start of at most 12 digits), the
# start is under one round ago (poll.sh's sleep: CLUTCH_POLL_SLEEP when 1-5
# digits >= 1, else 600 s; a start after now is not young) and it never woke
# (.woke empty or absent, or .poll newer than .woke; equal mtimes on a
# non-empty .woke count as a wake), say killed by a Bash timeout or a
# headless exit. 1 otherwise, an unreadable .poll or a date failure included.
# Call it only after clutch_poll_alive returned 3. Writes nothing; the caller
# removes .poll.
clutch_poll_young() {
  # Spelled-out class, the same guard as clutch_ops_record.
  case $1 in @????????) ;; *) return 1 ;; esac
  case $1 in @*[!0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-]*) return 1 ;; esac
  [ -n "$HOME" ] || return 1
  CPY_F="$HOME/.clutch/watch/${1#@}"
  # A round is poll.sh's own sleep, read the same way.
  CPY_NAP=${CLUTCH_POLL_SLEEP:-600}
  case $CPY_NAP in [1-9] | [1-9][0-9] | [1-9][0-9][0-9] | [1-9][0-9][0-9][0-9] | [1-9][0-9][0-9][0-9][0-9]) ;; *) CPY_NAP=600 ;; esac
  # clutch_poll_alive's well-formed rule, the start capped at 12 digits: a
  # malformed .poll has no start and is never young.
  CPY_START=$(LC_ALL=C awk 'NR == 1 && (NF == 2 || NF == 3) && $1 ~ /^[1-9][0-9]*$/ && $2 ~ /^[1-9][0-9]*$/ && length($2) <= 12 { print $2 }' "$CPY_F.poll" 2>/dev/null)
  CPY_NOW=$(date +%s 2>/dev/null)
  case $CPY_START.$CPY_NOW in *[!0-9.]* | .* | *.) return 1 ;; esac
  # A start after now (a clock stepped back) is not young.
  CPY_AGE=$((CPY_NOW - CPY_START))
  [ "$CPY_AGE" -ge 0 ] && [ "$CPY_AGE" -lt "$CPY_NAP" ] 2>/dev/null || return 1
  [ ! -s "$CPY_F.woke" ] || [ "$CPY_F.poll" -nt "$CPY_F.woke" ]
}

# The window for the session-start block and the ops sweep: up to 8 lines,
# open waits first, epoch dropped, each cut to 160 bytes.
clutch_worklog_window() { clutch_worklog_scan window; }

# Is the ops day brief ($1 brief) or an approval window ($1 window) due?
# Prints "due" once per local day for brief, once per window for window,
# and stamps ~/.clutch/ops-brief-last or ~/.clutch/ops-window-last. Window
# times come from the "### Windows" section of ~/.clutch/rituals.md
# (24-hour h:mm tokens), default 11:00 and 16:30; the due window is the
# latest at or before now. Never creates ~/.clutch; a failed stamp still
# prints due, so a brief or window may show twice but never fails ops.
# Always returns 0.
clutch_ops_due() {
  DNOW=$(date '+%Y-%m-%d %H%M' 2>/dev/null) || return 0
  case "$DNOW" in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\ [0-9][0-9][0-9][0-9]) ;; *) return 0 ;; esac
  case "$1" in
    brief) DKEY=${DNOW% *}; DMARK="$HOME/.clutch/ops-brief-last" ;;
    window)
      DRIT="$HOME/.clutch/rituals.md"; [ -r "$DRIT" ] || DRIT=/dev/null
      DWIN=$(LC_ALL=C awk -v hm="${DNOW#* }" '
        BEGIN { best = -1 }
        { sub(/\r$/, "") }
        /^[ \t]*#/ { on = ($0 ~ /^###[ \t]+Windows[ \t]*$/); next }
        on { s = $0
             while (match(s, /[0-9]?[0-9]:[0-5][0-9]/)) {
               t = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
               sub(/:/, "", t); t += 0
               if (t < 2400) { any = 1; if (t <= hm + 0 && t > best) best = t }
             } }
        END { if (!any) { if (1100 <= hm + 0) best = 1100; if (1630 <= hm + 0) best = 1630 }
              if (best >= 0) printf "%04d", best }' "$DRIT" 2>/dev/null)
      [ -n "$DWIN" ] || return 0
      DKEY="${DNOW% *} $DWIN"; DMARK="$HOME/.clutch/ops-window-last" ;;
    *) return 0 ;;
  esac
  DLAST=""
  { IFS= read -r DLAST < "$DMARK"; } 2>/dev/null
  [ "$DLAST" = "$DKEY" ] && return 0
  { printf '%s\n' "$DKEY" > "$DMARK"; } 2>/dev/null
  echo due
}

# The last focus declared in this folder, read from ~/.clutch/intents (one
# "<key> <focus>" line per declaration, appended by /clutch:intent). The key
# is the worklog's repo token: the basename of the git toplevel, else of the
# cwd, spaces as hyphens. Only lines with exactly two fields, the key equal
# (an exact compare through ENVIRON, never a pattern) and a focus matching
# CLUTCH_FOCUS_RE (build, ideate, ops, review or investigate; the first four
# under CLUTCH_INVESTIGATE=off) count; the last one wins. rc 0 prints the focus;
# rc 1 means no store or can't stat it, or no valid line for the key; rc 2
# means the store is not a readable regular file, the key is empty, or tail
# or wc fails.
# shortcut: reads the last 64 KiB, dropping its first line when the store is
# larger (it may be cut mid-line); upgrade if a folder's last declaration can sit further back.
clutch_guess_intent() {
  CGI_F="$HOME/.clutch/intents"
  [ -e "$CGI_F" ] || return 1
  [ -f "$CGI_F" ] && [ -r "$CGI_F" ] || return 2
  if [ "$CLUTCH_GIT" = 1 ]; then CGI_K=$ROOT; else CGI_K=$(pwd 2>/dev/null) || return 2; fi
  CGI_K=$(basename "$CGI_K" 2>/dev/null | tr ' ' -)
  [ -n "$CGI_K" ] || return 2
  CGI_T=$(tail -c 65536 "$CGI_F" 2>/dev/null) || return 2
  CGI_N=$(wc -c < "$CGI_F" 2>/dev/null) || return 2
  [ $((CGI_N)) -le 65536 ] || CGI_T=$(printf '%s\n' "$CGI_T" | sed 1d)
  CGI_G=$(printf '%s\n' "$CGI_T" | CGI_K="$CGI_K" CGI_R="$CLUTCH_FOCUS_RE" LC_ALL=C awk '$1 == ENVIRON["CGI_K"] && NF == 2 && $2 ~ ENVIRON["CGI_R"] { g = $2 } END { print g }' 2>/dev/null)
  [ -n "$CGI_G" ] || return 1
  printf '%s\n' "$CGI_G"
}

# This session's state folder from hook input JSON ($1). Sets CLUTCH_TAG8
# (the session tag without @; empty under CLUTCH_PER_SESSION=off or
# CLUTCH_WATCH=off, or with no tag), CLUTCH_SDIR ($CLUTCH_DIR/s/<tag8> when
# it is a directory and neither it nor $CLUTCH_DIR/s is a symlink, else
# $CLUTCH_DIR) and CLUTCH_SREL (.clutch/s/<tag8>/ or .clutch/). Returns 0
# when CLUTCH_SDIR is the session's own folder, else 1. Never creates
# anything. The tag is read from the line holding the first "session_id"
# key, cut there by awk, so a long field before the key stays linear.
clutch_session_paths() {
  CLUTCH_TAG8=""
  CLUTCH_SDIR=$CLUTCH_DIR
  CLUTCH_SREL=.clutch/
  [ "${CLUTCH_PER_SESSION:-}" = off ] && return 1
  [ "${CLUTCH_WATCH:-}" = off ] && return 1
  case $1 in *'"session_id"'*) ;; *) return 1 ;; esac
  CSP_T=$(printf '%s\n' "$1" | LC_ALL=C awk '{ i = index($0, "\"session_id\""); if (i) { print substr($0, i); exit } }' 2>/dev/null)
  CSP_T=$(clutch_session_tag "$CSP_T") || return 1
  CLUTCH_TAG8=${CSP_T#@}
  [ -n "$CLUTCH_DIR" ] && [ ! -L "$CLUTCH_DIR/s" ] && [ ! -L "$CLUTCH_DIR/s/$CLUTCH_TAG8" ] &&
    [ -d "$CLUTCH_DIR/s/$CLUTCH_TAG8" ] || return 1
  CLUTCH_SDIR="$CLUTCH_DIR/s/$CLUTCH_TAG8"
  CLUTCH_SREL=".clutch/s/$CLUTCH_TAG8/"
  return 0
}

# Is <owner>/<repo> ($1) on the merge list: a "- <owner>/<repo>[ <text>]"
# line in the "### Merge" section of ~/.clutch/rituals.md, a section that sits
# under "## Ops" and ends at the next heading? Case is ignored on both sides,
# a CR at line end is dropped. 0 listed; 1 not (no file, no section, a
# malformed argument); 2 the file is there but not a readable regular file.
# Writes nothing, reads no network.
clutch_merge_listed() {
  CML_F="$HOME/.clutch/rituals.md"
  [ -e "$CML_F" ] || [ -L "$CML_F" ] || return 1
  [ -f "$CML_F" ] && [ -r "$CML_F" ] || return 2
  CML_A=$1 LC_ALL=C awk '
    BEGIN { a = tolower(ENVIRON["CML_A"]); if (a !~ /^[a-z0-9._-]+\/[a-z0-9._-]+$/) a = "" }
    { sub(/\r$/, "") }
    /^##[ \t]+Ops[ \t]*$/ { ops = 1; on = 0; next }
    /^##[ \t]/ { ops = 0; on = 0; next }
    /^#/ { on = ops && /^###[ \t]+Merge[ \t]*$/; next }
    on && /^- / && a != "" { split(substr($0, 3), e, " ")
      if (e[1] ~ /^[A-Za-z0-9._-]+\/[A-Za-z0-9._-]+$/ && tolower(e[1]) == a) f = 1 }
    END { exit !f }' "$CML_F" 2>/dev/null || return 1
}

# The open wait lines no live silent check reads, raw, oldest first: those
# with no @tag in field 6 (a session tag, @ plus 8 lowercase hex) and those
# whose tag's clutch_poll_alive is 1 or 3, minus every line whose ref (field
# 4 lowercased, trailing ,;:. and CR dropped) a tag with clutch_poll_alive 0
# or 2 also waits on. rc 1 and 2 as clutch_owned_loops. Writes nothing.
clutch_unwatched_loops() {
  CUL_W=$(clutch_open_loops)
  CUL_RC=$?
  # The same absence proof as clutch_owned_loops (the tag only passes its guard).
  [ "$CUL_RC" != 1 ] || { clutch_owned_loops @unwatchd >/dev/null; return; }
  [ "$CUL_RC" = 0 ] || return "$CUL_RC"
  [ -n "$CUL_W" ] || return 0
  CUL_L=""
  for CUL_T in $(printf '%s\n' "$CUL_W" | LC_ALL=C awk '$6 ~ /^@[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$/ { print $6 }' | sort -u); do
    clutch_poll_alive "$CUL_T"
    case $? in 1 | 3) ;; *) CUL_L="$CUL_L $CUL_T" ;; esac
  done
  printf '%s\n' "$CUL_W" | CUL_L="$CUL_L " LC_ALL=C awk '
    { n++; ln[n] = $0; r = $4; sub(/[,;:.\r]+$/, "", r); k[n] = tolower(r)
      t[n] = ($6 ~ /^@[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$/) ? $6 : ""
      if (t[n] != "" && index(ENVIRON["CUL_L"], " " t[n] " ")) live[k[n]] = 1 }
    END { for (i = 1; i <= n; i++)
      if (!live[k[i]] && (t[i] == "" || !index(ENVIRON["CUL_L"], " " t[i] " "))) print ln[i] }'
}
