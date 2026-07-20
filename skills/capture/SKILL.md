---
name: capture
description: Catch a tangent, leap, or shiny thing in one line and return to the current unit. Use when the user says "capture this", "note this for later", "oh wait, idea", or jumps to an unrelated idea mid-task. One line then return; pull-only; never auto-surface or push waiting captures.
---

# Capture

The leap is signal, not defect. The cost is that working memory drops it the
moment focus returns, so the catch must be one line and instant. Capture
never blocks the jump and never becomes an inbox.

Procedure:

1. With a tangent on the table: append exactly one line to the capture file.
   The snippet answers. `BANKED`: the line landed, acknowledge with one word
   and nothing more. `MISS`: there is no file here to hold it (no work tree,
   or the write failed), so say one honest line and repeat the capture back;
   it lives in the transcript instead of vanishing behind an ack. With the
   uninvited budget spent: append silently, zero output; the write costs no
   budget, only the ack does. Then return to the current unit in the same
   turn.

   ```sh
   ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo MISS no-work-tree; exit 0; }
   mkdir -p "$ROOT/.clutch" 2>/dev/null || { echo MISS no-write; exit 0; }
   printf '%s %s\n' "$(date +%s)" "the tangent in one line" >> "$ROOT/.clutch/captures.md" && echo BANKED || echo MISS no-write
   ```

2. Invoked with nothing on the table: read the capture file and report one
   line, count plus the newest entry. Never a digest, never a review queue,
   never "you should process these". The user pulls; nothing pushes.

3. Trace-back, on request only: when the user wants the reasoning behind a
   leap they already took, back-fill the ladder from where they were to where
   they landed. The jump is licensed first, explained after. Never gatekeep a
   leap by demanding its reasoning up front.

The capture file is `.clutch/captures.md`, fixed. No tags, no categories, no
priorities. A captured line that never gets pulled again cost one line.

Why this works: see "Saltatory cognition / feel-first foresight (Dodson)" in
[GLOSSARY.md](../../GLOSSARY.md). Catch the leap, keep the thread.
