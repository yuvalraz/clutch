---
name: retrace
description: Walk back a fast session and hand back a map of what actually happened. Use when the user says "what did we just do", "what did we build", "I've lost track", "wait, what just happened", "I'm lost", or "reorient me".
---

# Retrace

A fast session overflows working memory. The conversation is a blur, but the
git state is not. Retrace rebuilds what happened from the durable evidence, not
from the transcript, and hands it back as a map the user can re-enter.

Ground it in what is on disk, never in a memory of the chat:

1. Read the real record. What landed: `git log` since the session began, the
   commits, oldest first. What is still open: `git status` and `git diff
   --stat`, the uncommitted and the unpushed. Which files were touched, and the
   count of `.clutch/` captures held (count only; pulling stays the user's
   move). Then what git cannot see: read `.clutch/captures.md`, and check
   `.clutch/sparks/`, `.clutch/ideas/`, and `.clutch/dream-sparks.md` for
   files new or appended within the traced window. The window is the same
   session boundary the git walk uses; the epoch prefix on each capture line
   makes the filter mechanical, and a malformed line with no epoch prefix
   counts as out-of-window. Read the in-window lines in full. Out-of-window
   captures stay a count only, as above. When the window start is ambiguous (a
   talk-only session with no commits, captures banked before the session's
   first commit, any doubt about where the session began),
   prefer the narrower window: miss a capture rather than hand back a stale
   one. A missed capture is still on disk for the next retrace; a stale one
   read back as fresh is a nag.

2. Walk it back as a breadcrumb path, in order, plain. Each step is one
   concrete deliverable, named for what it is and not for the conversation
   around it: added the parser, rewrote the landing page, fixed the failing
   test. The result, never the process.

3. Sort it into four groups, nothing more:
   - **Landed**: committed and done.
   - **In flight**: changed but not committed, or committed but not pushed.
   - **Be aware of**: a decision made, a large or risky change, something left
     for review, an open thread stopped mid-air.
   - **Pulled at you**: the in-window capture lines, verbatim. Fomo lines keep
     their why, and `[delved ...]` markers ride along. Each in-window divergent
     session is one named step, never reprinted: titled from its file under
     `sparks/` or `ideas/`, or from its `### [tag] title (YYYY-MM-DD)`
     entry heading in dream-sparks.md. Those headings carry dates only, so
     when in-window is ambiguous at the entry level the narrower rule holds:
     omit rather than guess. Where a line or session carries a timestamp, it
     interleaves with the commits in the breadcrumb walk.

   Each pool file that is missing or unreadable skips silently on its own; the
   group is absent and nothing is said about it only when no in-window activity
   remains across all of them. When it does appear it is
   history, never backlog: what pulled at you, not what waits. The capture
   file never becomes an inbox, and that law binds here.

4. End with one grounding move: the smallest thing that regains control. Commit
   the in-flight file, push the landed work, or read the one risky change.

Keep it a map, not a wall. Short lines, scannable. When there is a lot, the job
is to shrink it to something re-enterable. It reorients. It does not
re-overwhelm.

Why this works: see "Point of performance (Barkley)" and "The bricks / Wall of
Awful (Mahan)" in [GLOSSARY.md](../../GLOSSARY.md). A pile of unclear changes is
a wall; the map is the way through it. For the leaps that rode along, see
"Saltatory cognition / feel-first foresight (Dodson)": the capture that pulled
you sideways belongs on the same map as the commit it interrupted.
