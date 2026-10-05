---
name: ops
description: Put the session in operations mode. Engage espresso, sweep the reachable integrations once for the live situation, then close loops one at a time with the day's focuses in view.
when_to_use: Use ONLY when the user explicitly asks for operations mode ("ops", "operations mode", "run the day", "re-sweep") or when /clutch:intent hands off after an "ops" answer. A passing mention of meetings, people, or tasks mid-conversation is not a trigger.
argument-hint: "[re-sweep]"
---

# Ops

Ops sets the MODE for the whole session: the day's operations, not a build.
Meetings, people, threads, tickets, the small loops that hold a company
together. The work here is many short convergences rather than one long one,
and the terrain is whatever tools your day lives in, never a single repo.

Ops fires when you fire it. Nothing here runs on its own.

## Usage

- `/clutch:ops` enters operations mode: engage the gear, sweep once, name
  the situation, end on one loop to close.
- `/clutch:ops re-sweep` runs a fresh sweep mid-day with the same bounds and
  the same close. A re-sweep happens on request only, never on your own read
  that the situation may have moved.

## Procedure

### Step 0: Engage the gear

Confirm in one line: "Espresso engaged: tight convergence, one divergent
pulse, checkpoint at each closed loop." Then write the marker (POSIX, silent
on any failure):

```sh
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
mkdir -p "$ROOT/.clutch" 2>/dev/null || exit 0
printf '%s\n' "espresso" 2>/dev/null > "$ROOT/.clutch/tempo" || exit 0
```

This is the existing tempo mechanism; the heartbeat carries the gear to the
model next turn, no new state. If the write fails, the declaration still
governs the live session; only the re-injection is lost.

Hopping between loops is the gait in this gear, not a shape mismatch. The
dispatch spine's gear-shift row reads a sustained change in the shape of the
work; the ops rhythm of close, next, close is the shape holding.

### Step 1: Load the config

Read `~/.clutch/rituals.md`. If it is missing: the sweep has no tools to
stand on yet. Say exactly that in one line and hand off to `/clutch:rituals`.
Never scaffold a default config silently; a config the user never wrote is a
config they will not trust.

If the file exists but a key this mode needs is unset, name the gap and ask
for that one value inline, then offer to persist the answer into
`~/.clutch/rituals.md` so it is asked only once. A missing file hands off; a
single missing key does not.

If a state dir is configured but missing on disk, say so and
offer to continue without state.

The tools come from the `integrations:` bullets under Shared, the same ones
the morning and close-of-day anchors read. Today's focuses come from the
focus file when one is set. Ops adds no keys of its own.

### Step 2: The sweep

This is the one divergent pulse of the gear. For each configured
integration, check it only if it is reachable. If a tool is named but
unavailable, say so and skip it; never stall the sweep on a tool that is not
there.

Read for what is live: the meetings on today's calendar, the threads waiting
on you, the tasks assigned to you, anything a person is waiting on. Read
today's focuses from the focus file when one is set.

Bounds (HARD):

- The sweep reads; it never writes to any integration.
- Today's horizon only: nothing past the next workday.
- It reads each reachable tool once and ends. It never polls, never loops,
  never watches anything in the background.
- No counts: not how many sit unread, not how many wait, not how long
  anything has waited.

### Step 3: The situation

Speak the situation in a few lines, present tense, co-working voice. Group
by the next thing that can happen, never by tool. Name a waiting thread by
what it needs now, never as overdue, late, or missed.

The situation is at most seven lines. It is a read of now, not a dashboard
and not a report for later. Nothing from the sweep is written anywhere; it
lives in the turn, and a fresh sweep replaces it.

### Step 4: One smallest move

End on one loop that closes in one sitting: a reply sent, a meeting accepted
or moved, a ticket updated, a decision handed to the person waiting for it.
State it as a recognition line, fully ignorable, no yes required. A different
loop the user names becomes the move; a choice menu never does.

### Step 5: Session guardrails

For the rest of the session these rules are HARD and override default
behavior:

- **One loop at a time.** Close it, checkpoint in one line naming what moved,
  then the next. A checkpoint is the closed loop itself, never a summary.
  Never two loops open at once.
- **Outward-facing actions keep a human checkpoint.** Sending a message,
  accepting or moving a meeting, changing a ticket's state, anything another
  person will see: draft it, show it, send on a yes. Reading is free.
- **Interruptions are the gait.** A new ping mid-loop gets one line, bank it
  or close it now, then back to the open loop.
- **A tangent banks.** An idea that pulls sideways goes to `/clutch:fomo` in
  one line, bank only, then return.
- **A loop that turns into a build leaves ops.** Code, a design, a document
  longer than a reply: name it, bank it as a focus or an idea, and stay in
  ops. Building it is a fresh session declared with `/clutch:intent build`.
- **No counts, no overdue framing, no backlog totals.** The sweep names what
  needs a move now; the rest stays where it is, unmentioned.
- **A loop that keeps not closing** gets `/clutch:triage`'s question, a
  flinch at the wall versus never entering awareness, before anything else
  engages. **A loop that wants a clock** gets `/clutch:sprint`.
- **Re-sweep on request only.** `/clutch:ops re-sweep` is the only path to a
  second sweep.

### Session close

`/clutch:eod` owns the day's close: the retro, tomorrow's focuses, the fun
slot. Ops ends by naming the loops that closed this session, one line each,
and the one open loop with its next move. Nothing else is written.

## Skill interactions

| Skill | In ops mode |
|-------|-------------|
| `/clutch:morning` | opens the day; ops runs the day it opened |
| `/clutch:eod` | closes the day; ops hands off there |
| `/clutch:fomo <content>` | a tangent, banked in one line, then back to the loop |
| `/clutch:triage` | a loop that keeps not closing: wall or inattention |
| `/clutch:sprint <goal>` | a fixed 20 minutes on one loop |
| `/clutch:intent build` | a loop that became a build: a fresh session |

## What this skill does NOT do

- Fire on its own, re-sweep on its own, or watch anything in the background
- Write to any integration, or send anything, without a yes
- Produce a dashboard, a report, or a list for later
- Count unread, waiting, overdue, or missed anything
- Write code or design anything: that is a build session
- Scaffold config, guess paths, or invent integrations

Why this works: see "Tempo / the gearbox", "Intent", and "Point of
performance" in [GLOSSARY.md](../../GLOSSARY.md). The gear is engaged by
invitation, the sweep is one pulse that ends, and every loop closes at the
moment the user can act on it.
