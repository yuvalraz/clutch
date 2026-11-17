---
name: investigate
description: Put the session in investigate mode. Engage craft, take one pointer, read the evidence read-only, speak findings each tied to evidence, then close by a reply on a yes or a handoff to build.
when_to_use: Use ONLY when the user explicitly asks for investigate mode ("investigate mode", "clutch investigate") or when /clutch:intent hands off after an "investigate" answer. A passing "look into this" or "why is this" mid-session is not a trigger.
argument-hint: "[pointer]"
---

# Investigate

Investigate sets the MODE for the whole session: one pointer comes in (a DM,
a thread, a PR, an error, a claim), the question is why, or whether it is
true, and the session ends in findings, a reply, or a fix handed to build.

Investigate fires when you fire it. Nothing here runs on its own.

## Usage

- `/clutch:investigate` enters investigate mode: engage the gear, then ask
  for the pointer.
- `/clutch:investigate <pointer>` does the same and reads that pointer first.

## Procedure

### Step 0: Engage the gear

Confirm in one line: "Craft engaged: explore, then commit, checkpoint at each finding."
Then write the marker (POSIX, silent on any failure):

```sh
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { [ "${CLUTCH_PLAIN:-}" != off ] && ROOT=$(pwd -P) && [ "$ROOT" != / ] && [ ! "$ROOT" -ef "$HOME" ]; } || exit 0
mkdir -p "$ROOT/.clutch" 2>/dev/null || exit 0
{ printf '%s\n' "craft" > "$ROOT/.clutch/tempo"; } 2>/dev/null || exit 0
```

If the write fails, skip silently: the declaration still governs the live
session; only the re-injection is lost.

### Step 1: The pointer

The pointer is the argument. With none, ask for it in one line: what came
in, and where it lives.

### Step 2: Evidence

Read the pointer and what it points at: the message, the thread, the diff,
the log, the code the claim is about. Read-only until a yes: no edits, no
posts, no writes anywhere outside the marker above.

Work one hypothesis at a time: name it, read what would confirm or break it,
then keep it or drop it before the next. If the pointer is unreachable (a
tool is down, access is missing), say so in one line and ask for it another way:
a paste, a link, an export.

### Step 3: Findings

Speak the findings TL;DR first: the answer in one line, then the rest,
each finding marked verified, with its evidence, or unverified
(a claim nothing read so far confirms). A finding with no evidence behind it
is said to be unverified, never dressed as fact.

### Step 4: Close

One of three:

- **A reply.** If the pointer wants an answer, draft it, show it, send on a yes.
  Once it is sent, log a `wait:` line when a reply back is expected (see
  "Worklog" in the constitution).
- **A fix.** If the findings name a change, name it and hand off with
  `/clutch:intent build` in this same session; the build starts from the
  findings.
- **A bank.** If it can wait, bank it with `/clutch:fomo` in one line.

## Session guardrails

For the rest of the session these rules are HARD and override default
behavior:

- **Read-only until a yes.** No edit, post, reply or write before the user
  says yes. Reading is free.
- **One pointer at a time.** A second pointer is banked with `/clutch:fomo`
  until the first one closes.
- **Evidence before claims.** Every finding names what it rests on, or says
  it is unverified.
- **No counts, no overdue framing.** A pointer is named by what it needs now,
  never as overdue, stale, or waiting long.
- **A pointer that keeps not closing** gets `/clutch:triage`'s question
  before anything else engages. **A pointer that wants a clock** gets
  `/clutch:sprint`.

## Skill interactions

| Skill | In investigate mode |
|-------|---------------------|
| `/clutch:fomo <content>` | a tangent or a second pointer, banked in one line |
| `/clutch:intent build` | findings that name a fix: build in this session |
| `/clutch:triage` | a pointer that keeps not closing: wall or inattention |
| `/clutch:sprint <goal>` | a fixed 20 minutes on one pointer |

## What this skill does NOT do

- Fire on its own, or watch anything in the background
- Edit, post, reply or write anything without a yes
- Open a second pointer before the first closes
- State a finding as verified without its evidence
- Count open, waiting, or overdue anything
- Load tool sources the session cannot already reach

Why this works: see "Tempo / the gearbox", "Intent", and "Point of
performance" in [GLOSSARY.md](../../GLOSSARY.md). The gear is engaged by
invitation, one pointer is read to its end, and each finding carries its
evidence.
