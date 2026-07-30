---
name: intent
description: Declare the session's focus, build or ideate, and engage the matching gear and posture. Use ONLY when the user answers the session-start intent question (a plain "build" or "ideate" counts as an answer) or explicitly asks to set the session's focus. A passing mention of building or ideating mid-conversation is not a trigger.
---

# Intent

A clutch couples intention to action, and this is where the intention gets
declared. Two focuses exist: build and ideate. There is no third and no config;
new focuses arrive by shipped release, never by settings.

## Usage

- `/clutch:intent build` declares a maker session: engage craft, speak the
  maker posture.
- `/clutch:intent ideate` declares a divergent session: one confirm line, then
  hand off.
- `/clutch:intent` bare: ask one question: build or ideate? Nothing else.

Any other argument gets one line naming the two focuses, no error ceremony.

Invocation scope: this skill fires when the user answers the session-start
question or explicitly asks to set the session's focus, and at no other
moment. A stray "build" mid-conversation invokes nothing.

## Build

Confirm in one line: "Craft engaged: converge-dominant, regular divergent
pulses, checkpoint at each commit point." Then write the marker (POSIX, silent
on any failure):

```sh
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
mkdir -p "$ROOT/.clutch" 2>/dev/null || exit 0
printf '%s\n' "craft" 2>/dev/null > "$ROOT/.clutch/tempo" || exit 0
```

If the write fails, skip silently: the declaration still governs the live
session; only the re-injection is lost.

Then speak the maker posture, once, at declaration, invited because the
declaration invited it:

> This is a maker session: we verify before we claim, and the tests ship with the code. Nothing fails silently; a red speaks the moment it happens. When gold-plating looms, the move is a scope check, not more polish.

That is the whole speech. It is recognition of what a maker session is, not a
rules lecture, and it is never repeated uninvited.

## Ideate

Confirm in one line: "Ideate declared; handing off." Then run /clutch:ideate.
That skill is the machinery: it loads the pool, engages ballmer, and holds
anti-convergence. Duplicate none of it here.

## The once-only law

The session-start ask happens once, in the anchor's greeting, and only when no
gear is declared. Ignoring it and starting to work is an answer that closes
the matter; the skill never re-asks uninvited. Declaring later stays open by
invoking /clutch:intent at any time.
