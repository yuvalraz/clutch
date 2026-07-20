#!/bin/sh
# clutch status: read-only report. Prints facts; mutates nothing; always exits 0.
SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)

echo "clutch status"

if [ -n "$SELF_DIR" ] && [ -f "$SELF_DIR/../rules/constitution.md" ]; then
  echo "  constitution: present"
else
  echo "  constitution: not found beside this script; reinstall is the one fix"
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
  echo "  git substrate: present ($ROOT)"

  EX=$(git rev-parse --git-path info/exclude 2>/dev/null)
  case "$EX" in /*) ;; *) EX="$ROOT/$EX" ;; esac
  if [ -f "$EX" ] && grep -qxF '.clutch/' "$EX" 2>/dev/null; then
    echo "  exclude: .clutch/ is excluded from git"
  else
    echo "  exclude: not written yet; the first hook write adds it"
  fi

  C="$ROOT/.clutch"
  if [ -d "$C" ]; then
    S="$C/session-state"
    if [ -f "$S" ]; then
      LAST=$(grep '^stop ' "$S" 2>/dev/null | tail -n 1 | cut -d' ' -f2)
      NSTOP=$(grep -c '^stop ' "$S" 2>/dev/null)
      EMITS=$(grep -c '^emit ' "$S" 2>/dev/null)
      case "$LAST" in
        ''|*[!0-9]*) echo "  stop hook: state present but unreadable" ;;
        *) echo "  stop hook: fired in this state (stop events recorded: $NSTOP)" ;;
      esac
      echo "  bell: $EMITS of 2 emissions used this state"
    else
      echo "  stop hook: no session state in this repo yet"
    fi
    if [ -f "$C/sprint-start" ]; then
      SP=$(head -n 1 "$C/sprint-start" 2>/dev/null)
      echo "  sprint: active ('${SP#* }')"
    else
      echo "  sprint: none active"
    fi
    if [ -f "$C/breadcrumb" ]; then
      echo "  thread: $(head -n 1 "$C/breadcrumb" 2>/dev/null)"
    else
      echo "  thread: no breadcrumb yet"
    fi
  else
    echo "  hooks: no .clutch state here. If sessions ran in this repo since install, /plugin list shows whether clutch is enabled"
  fi
else
  echo "  git substrate: absent; the anchor and bell degrade by design here"
fi
exit 0
