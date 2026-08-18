---
name: interview
description: Batch-interview the user to fill the gaps the auto-memory brain doesn't know it has, then route the answers into memory. Use when the user says "interview me", "fill the gaps", "what don't you know about me".
disable-model-invocation: true
---

# Interview

The brain records what sessions happened to touch. What no session touched is
invisible — a recurring task with no captured method, a tool named once with
no pointer, a preference implied but never written down. Interview surfaces
that missing knowledge by asking for it directly, in one batch, and routing
the answers home.

Where `/clutch:dream` consolidates what the brain already holds, interview
fills what it never held.

Interview runs only when the user fires it. It never launches itself.

## Procedure

### Step 1: Resolve the brain

Same resolution as `/clutch:dream`: read `autoMemoryDirectory` from
`~/.claude/settings.json`. If the key is absent, say so and stop. Never guess
a path. Never hardcode one.

### Step 2: Find the gaps

Read the index at the brain root and skim the file names and their one-line
descriptions — not every file body. Look for thin or missing coverage:

- Recurring task types with no captured method or gotcha
- Systems, tools, or people named once with no pointer
- Roles and preferences the record implies but never states
- Areas the brain's own structure suggests but barely covers

Rank the gaps, most valuable first.

### Step 3: Ask in one batch

Ask 3–6 concrete questions at once — never a drip of one at a time. Prefer
answerable specifics ("where does X actually live?", "what's the gotcha when
Y?") over open prompts. If the session already answers one, state the
assumption for confirmation instead of asking.

Ignoring a question is a legal answer. An unanswered question is dropped, not
repeated.

### Step 4: Route each answer

For each answer, write it into the brain following the brain's existing
conventions:

- Append to the existing memory file that covers the topic, or create a new
  one shaped like its neighbors.
- Stamp `last_reviewed` with today's date — an interview answer is
  human-confirmed by definition.
- Add or update the index line pointing at the file, matching the index's
  existing format.
- Pointers, not copies: an answer that hands over live data gets stored as
  the pointer plus the insight, per the convention in `/clutch:dream`.

### Step 5: Stop

Stop when the user signals done, or when the high-value gaps are covered —
whichever comes first. Never interrogate. A second batch happens only if the
user asks for one.

## What this skill does NOT do

- Read every file body — the index and file names are the gap map
- Drip questions one at a time — one batch, then route
- Press for answers — silence on a question closes it
- Guess or hardcode the brain path — no `autoMemoryDirectory`, no interview
