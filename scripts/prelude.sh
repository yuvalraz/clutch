# Shared prelude for clutch hook scripts. Sourced, not executed.
# POSIX sh only. Every failure degrades to "do nothing".
#
# Sets: CLUTCH_GIT (1 inside a git work tree, else 0), ROOT, CLUTCH_DIR,
# EXCLUDE_FILE. Defines clutch_ensure_dir, clutch_last_authored.

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
