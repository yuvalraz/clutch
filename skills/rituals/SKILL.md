---
name: rituals
description: One batch interview that captures your day's facts — workdays, focus file, prep commands, integrations — and writes ~/.clutch/rituals.md for the morning and close-of-day anchors. Use when the user says "/clutch:rituals", "set up my rituals", "set up my morning", or "change my ritual config".
disable-model-invocation: true
---

# Rituals

The morning and close-of-day anchors carry fixed opinions about how a day
opens and closes. What they cannot carry is your facts: which days you work,
where your focus file lives, what to read before anything else. This skill
asks for those facts once, in one batch, and writes them to
`~/.clutch/rituals.md`. After that, `/clutch:morning` and `/clutch:eod` stand
on them without asking again.

Rituals runs only when you fire it. Never runs unbidden, and nothing it
writes makes anything else fire on its own — the anchors fire when you fire
them.

## Procedure

### Step 1: Load what exists

Read `~/.clutch/rituals.md` if it is there. On a re-run this is the whole
point: show current values as defaults, ask only what the user wants to
change, and edit it in place. Never start from blank when a config exists.

### Step 2: Ask in one batch

Same batch-not-drip rule as `/clutch:interview`: ask everything at once,
never a drip of one question at a time. Ignoring a question is a legal
answer — an ignored question keeps its current value or stays unset.

The batch covers:

- **Workdays** — which days count. The close-of-day anchor uses this to pick
  the next workday.
- **State dir** — an optional directory the rituals read and write (notes,
  focus files, whatever holds your day). Skippable.
- **Focus file** — where the day's focuses live, relative to the state dir.
- **Per ritual (morning and close-of-day)** — the anchor time (display
  only; nothing fires on its own), an optional prep command to run and read
  first, any extra steps to weave in, and any close-out steps to end on.
- **Integrations** — freeform: a calendar tool, a task board, anything the
  day prep should check when reachable.

### Step 3: Write the config

Write `~/.clutch/rituals.md` in this shape. The section names are fixed;
everything inside is loose — the reader is the ritual itself, not a parser.
Placeholder values below; yours replace them:

```markdown
# Rituals

## Shared
- workdays: <your work week>
- state dir: <a directory your day lives in>
- focus file: <path to the day's focuses, relative to state dir>
- integrations: <a calendar tool, a task board — freeform bullets>

## Morning
- time: <your anchor time — display only>
- prep: <a command to run and read first>
### Extra steps
- <your own lines, woven in before the close>
### Close-out
- <your own sync or commit steps>

## EOD
- time: <your anchor time>
- prep: <a command to run and read first>
### Extra steps
### Close-out
```

Recognized keys: `workdays`, `state dir`, `focus file`, `time`, `prep`, plus
freeform `integrations:` bullets under Shared. Anything else you write in the
file is carried into the ritual as context, never treated as an error. The
file is yours: hand-edit it any time, and a re-run of this skill respects
what it finds. Keys you leave unset stay unset — the rituals ask once when they first need it
and offer to write the answer back here, so nothing is asked twice.

### Step 4: Confirm

Show the written file, then name the next thing: resume the ritual that sent you here,
or fire `/clutch:morning` at your next day-open.

## What this skill does NOT do

- Run on its own, or write config nobody asked for
- Make any ritual fire by itself — the anchors are pull-only
- Enforce a strict format — unrecognized lines are context, not errors
- Drip questions one at a time — one batch, then write
