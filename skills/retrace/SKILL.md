---
name: retrace
description: Walk back a fast session and hand back a map of what actually happened. Use when the user says "what did we just do", "what did we build", "I've lost track", "wait, what just happened", "I'm lost", "reorient me", or a long session has produced a lot of changes and the thread of it is gone.
---

# Retrace

A fast session overflows working memory. The conversation is a blur, but the
git state is not. Retrace rebuilds what happened from the durable evidence, not
from the transcript, and hands it back as a map the user can re-enter.

Ground it in what is on disk, never in a memory of the chat:

1. Read the real record. What landed: `git log` since the session began, the
   commits, oldest first. What is still open: `git status` and `git diff
   --stat`, the uncommitted and the unpushed. Which files were touched, and any
   `.clutch/` captures waiting to be pulled.

2. Walk it back as a breadcrumb path, in order, plain. Each step is one
   concrete deliverable, named for what it is and not for the conversation
   around it: added the parser, rewrote the landing page, fixed the failing
   test. The result, never the process.

3. Sort it into three groups, nothing more:
   - **Landed**: committed and done.
   - **In flight**: changed but not committed, or committed but not pushed.
   - **Be aware of**: a decision made, a large or risky change, something left
     for review, an open thread stopped mid-air.

4. End with one grounding move: the smallest thing that regains control. Commit
   the in-flight file, push the landed work, or read the one risky change.

Keep it a map, not a wall. Short lines, scannable. When there is a lot, the job
is to shrink it to something re-enterable. It reorients. It does not
re-overwhelm.

Why this works: see "Point of performance (Barkley)" and "The bricks / Wall of
Awful (Mahan)" in [GLOSSARY.md](../../GLOSSARY.md). A pile of unclear changes is
a wall; the map is the way through it.
