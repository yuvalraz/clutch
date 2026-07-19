#!/bin/sh
# clutch hot-action-pause: PreToolUse ask-gate on a fixed scorched-earth list.
# One asked beat; the user's yes always wins in one keypress. Fires on the
# action, never the emotion, so a calm force-push just gets asked once.
# Deliberately excluded in this version: "deleting a file written this session
# after a failing test" needs the session-state accumulator that does not ship
# yet; adding it here without that state would be guesswork.
IN=$(cat 2>/dev/null) || exit 0
case "$IN" in
  *'"tool_name":"Bash"'* | *'"tool_name": "Bash"'*) ;;
  *) exit 0 ;;
esac

if printf '%s' "$IN" | grep -qE 'git[^&|;]*push[^&|;]*(--force|[[:space:]]-f([^a-zA-Z]|$))|git[^&|;]*reset[^&|;]*--hard|git[^&|;]*branch[^&|;]*[[:space:]]-D[[:space:]]|git[^&|;]*checkout[[:space:]]+--[[:space:]]+\.|git[^&|;]*clean[^&|;]*-f[a-zA-Z]*d|git[^&|;]*clean[^&|;]*-d[a-zA-Z]*f'; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Hot action. One beat: if this follows a red result, the heat is a spike, not a verdict, and the smaller move is banking what still works first. Your call either way."}}\n'
fi
exit 0
