---
name: morning
description: Open the day at your own anchor — focus check, deep ping, one divergent beat, one quick win, day prep — read from ~/.clutch/rituals.md. Use when the user says "/clutch:morning", "run the morning routine", "open the day", or "morning ritual".
disable-model-invocation: true
---

# Morning

A day that opens without an anchor opens wherever the first ping lands. This
ritual is the anchor: a fixed spine of small beats that ends on one concrete
first move. Your facts — workdays, focus file, prep command, integrations —
come from `~/.clutch/rituals.md`; the spine is the same for everyone.

Morning fires when you fire it. Nothing here runs on its own.

This is a dialogue, not a report: short beats, one question at a time where a
question is needed, and the whole thing fits inside about thirty minutes.

## The spine

### 1. Load the config

Read `~/.clutch/rituals.md`. If it is missing: the anchor has no facts to
stand on yet — say exactly that in one line and hand off to
`/clutch:rituals`. Never scaffold a default config silently; a config the
user never wrote is a config they will not trust.

If the file exists but a key this ritual needs is unset, name the gap and ask
for that one value inline — then offer to persist the answer into
`~/.clutch/rituals.md` so it is asked only once. A missing file hands off; a
single missing key does not.

If a state dir is configured but missing on disk, say so and
offer to continue without state.

### 2. Prep

If a morning `prep` command is set, run it and read its output before
anything else. If it fails, show the failure and continue with direct reads —
never a silent fallback, never a stall.

### 3. Focus check

Read today's focuses from the focus file. If `state dir` or `focus file` is
unset, resolve the path first: ask once where today's focuses should live,
and offer to persist the answer into the config. If the file is missing or empty,
set today's focuses with the user now and write the file — the day does not
start focusless.

### 4. Deep ping

What changed since the last close-of-day? Read whatever the config and state
carry — prep output, notes, anything that moved. Then answer explicitly:
do these signals change today's focuses? If yes, edit the focus file —
after the user confirms, never before.

On a first run — no prior close exists — say so and read only what the
config and state actually carry. Never confabulate a yesterday.

### 5. One divergent beat

One banked-item write-off from the pool: pull one entry from the repo
`.clutch/` pool or the `$HOME/.clutch` brain (the same conventions
`/clutch:fomo` banks into), give it one beat of attention, and let it go or
let it land. One item, not a review queue. If the pool is empty or absent,
say so in one line and skip the beat — never invent a banked item.

### 6. One quick win

Name one quick win for today — something small, finishable, energizing.
Not a third focus; a first domino.

### 7. Day prep

For each configured integration, check it only if it is reachable. If a tool
is named but unavailable, say so and skip it — never stall the ritual on a
tool that is not there.

### 8. Extra steps

Weave in the user's `### Extra steps` lines from the config, in order.

### 9. Close-out

Run the user's `### Close-out` lines, then end on the single
first move on focus #1 — named concretely, small enough to start now.

## What this skill does NOT do

- Fire on its own, remind, or nag — it runs when you run it
- Scaffold config, guess paths, or invent focuses without the user
- Turn the deep ping into a report — it is a dialogue that ends in a move
- Push the pool — one banked item gets a beat, the rest stay banked
