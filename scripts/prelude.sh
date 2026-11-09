# Shared prelude for clutch hook scripts. Sourced, not executed.
# POSIX sh only. Every failure degrades to "do nothing".
#
# Sets: CLUTCH_GIT (1 inside a git work tree, else 0), ROOT, CLUTCH_DIR,
# EXCLUDE_FILE, CLUTCH_WORKLOG. Defines clutch_ensure_dir,
# clutch_last_authored, clutch_worklog_window, clutch_open_loops,
# clutch_ops_due.

CLUTCH_GIT=0
ROOT=""
CLUTCH_DIR=""
EXCLUDE_FILE=""

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

# The cross-session worklog is global, so it is set inside a repo or not.
CLUTCH_WORKLOG="$HOME/.clutch/worklog.md"

# Create .clutch/ on first write and keep it out of git status via the
# repo-local exclude file. Fail-open: any error returns nonzero, caller exits 0.
clutch_ensure_dir() {
  [ "$CLUTCH_GIT" = 1 ] || return 1
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
# ages out after 5 days. Malformed, future-dated and unknown-verb lines are
# skipped. A ref's trailing ,;:. or CR is ignored on both sides, and a
# "moved: L2:" line never closes a wait. Returns 1 when the file does not
# exist (no worklog), 2 when it exists but is not a readable regular file or
# `date` fails; never creates anything.
# shortcut: scans the last 2000 lines and cuts bytes, not characters; upgrade
# if 5 days log more than 2000 lines or a cut splits a glyph.
clutch_worklog_scan() {
  [ -e "$CLUTCH_WORKLOG" ] || return 1
  [ -f "$CLUTCH_WORKLOG" ] && [ -r "$CLUTCH_WORKLOG" ] || return 2
  WNOW=$(date +%s 2>/dev/null) || return 2
  # LC_ALL=C: a UTF-8 awk aborts the whole scan on one invalid byte.
  tail -n 2000 "$CLUTCH_WORKLOG" 2>/dev/null | LC_ALL=C awk -v now="$WNOW" -v mode="$1" '
    $1 ~ /^[0-9]+$/ && NF >= 4 {
      age = now - $1
      if (age < 0) next
      n++; ln[n] = $0; vb[n] = $3; ag[n] = age
      r = $4; sub(/[,;:.\r]+$/, "", r)
      if ($3 == "wait:" && NF >= 6 && r ~ /^[^:]+:./) open[r] = n
      else if ($3 == "moved:" && (r in open)) delete open[r]
    }
    # Live claims are kept first, then open waits, then moves, so neither a
    # burst of moves nor a pile of waits can push a claim out of view; waits
    # still print first.
    END {
      for (r in open) if (ag[open[r]] < 432000) w[open[r]] = 1
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
