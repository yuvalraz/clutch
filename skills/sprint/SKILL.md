---
name: sprint
description: Run a fixed 20-minute sprint on one minimal shippable. Use when the user explicitly asks for a timebox: "sprint", "timebox", "just get started", "20 minutes", or "set a clock".
---

# Sprint

Twenty minutes, one shippable. The duration is fixed; there is no parameter.

1. Name the shippable. Force one sentence: "This sprint ships X." One thing,
   small enough to land in 20 minutes, ending in something checkable (a commit,
   a run, a sent thing). Do not start until that sentence exists.

2. Write the start marker (POSIX, silent on any failure). Replace the goal text
   with the shippable in a few words:

   ```sh
   ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
   mkdir -p "$ROOT/.clutch" 2>/dev/null || exit 0
   printf '%s %s\n' "$(date +%s)" "the shippable in a few words" > "$ROOT/.clutch/sprint-start"
   ```

3. Work turn by turn, present tense, on that one shippable only. When scope
   tries to grow, deflect: note the new idea in one line and return. One line,
   then back to the shippable.

4. Close at 20 minutes. The heartbeat carries the clock each turn (sprint
   clock: N min left); when it reads time is up, stop and name what shipped,
   recognition wording: the concrete thing that moved and one smallest next
   move. Then remove the marker:

   ```sh
   ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
   rm -f "$ROOT/.clutch/sprint-start"
   ```

Why this works: see "Point of performance (Barkley)" and "Interest-based
nervous system (Dodson)" in GLOSSARY.md. Urgency without fear.
