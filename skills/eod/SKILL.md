---
name: eod
description: Close the day at your own anchor — mini-retro over today's focuses, set tomorrow's, one fun slot, close-out — read from ~/.clutch/rituals.md. Use when the user says "/clutch:eod", "run the end-of-day routine", "close the day", or "evening retro".
disable-model-invocation: true
---

# EOD

A day that never closes bleeds into the evening as vague unfinishedness. This
ritual closes it: name what moved, fork what did not, set tomorrow, and end
with one small pull of fun. Your facts come from `~/.clutch/rituals.md`; the
spine is the same for everyone.

EOD fires when you fire it. Nothing here runs on its own.

Dialogue, not report; about thirty minutes end to end.

## The spine

### 1. Load the config

Read `~/.clutch/rituals.md`. If it is missing: say in one line that the
anchor has no facts to stand on yet and hand off to `/clutch:rituals`.
Never scaffold a default config silently.

If the file exists but a key this ritual needs is unset, name the gap and ask
for that one value inline — then offer to persist the answer into
`~/.clutch/rituals.md` so it is asked only once. A missing file hands off; a
single missing key does not.

If a state dir is configured but missing on disk, say so and
offer to continue without state.

### 2. Prep

If an EOD `prep` command is set, run it and read its output. If it fails,
show the failure and continue with direct reads — never a silent fallback.

### 3. Mini-retro

Walk today's focuses, one line each: done, partial, or didn't happen. If the
focus file is missing or empty, say so, retro the day freeform — what moved,
what did not — and move on.
Recognition-shaped throughout — name what moved, no guilt for what did not.

For a didn't-happen, ask `/clutch:triage`'s question: was it
a flinch at the wall versus never entering awareness? The fork matters because the fixes are
opposites — a wall wants a smaller move, an awareness miss wants a surface.
No shame either way; both are mechanics, not character.

Capture ONE tweak from the retro — a single adjustment for tomorrow, not a
process overhaul. The tweak is written next to tomorrow's focuses in the
focus file (step 4), so `/clutch:morning` reads it — a tweak nobody reads
changes nothing.

### 4. Tomorrow's focuses

Set tomorrow's focuses: two critical and one secondary. Tomorrow means the
next workday computed from `workdays` — the last workday of the week
wraps to the first. If `workdays` is unset, ask — never assume a week.
If `state dir` or `focus file` is unset, ask once where tomorrow's focuses
should live and offer to persist the answer into the config — the write
below needs a target. Write the focus file for that day, the ONE tweak from
the retro next to the focuses, so `/clutch:morning` finds both waiting.

### 5. Fun slot

Pull one banked item from the pool (repo `.clutch/` or the `$HOME/.clutch`
brain) and explore it for its own sake. No deliverable, no verdict owed —
the day earns a beat of pure interest before it closes. If the pool is empty
or absent, say so in one line and skip the slot — never invent a banked item.

### 6. Extra steps

Weave in the user's `### Extra steps` lines from the config, in order. If a
step leans on an integration whose tool is unreachable,
say so and skip it — never stall the close on a tool that is not there.

### 7. Close-out

Run the user's `### Close-out` lines, then end by naming tomorrow's focus #1
— so the next day-open starts mid-thought instead of cold.

## What this skill does NOT do

- Fire on its own, remind, or nag — it runs when you run it
- Scaffold config or invent focuses without the user
- Count streaks, missed days, or anything shame-shaped in the retro
- Auto-classify a wall — the triage fork is a question, never a verdict
