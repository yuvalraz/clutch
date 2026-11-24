---
name: intent
description: Declare the session's focus, build, ideate, ops, review, or investigate, and engage the matching gear and posture.
when_to_use: Use ONLY when the user answers the session-start intent question (a plain "build", "ideate", "ops", "review", or "investigate" counts as an answer, and so does a plain "go" or "yes" when the question named a likely focus) or explicitly asks to set the session's focus. A passing mention of building, ideating, operations, reviewing, or investigating mid-conversation is not a trigger.
argument-hint: "[build | ideate | ops | review | investigate]"
---

# Intent

A clutch couples intention to action, and this is where the intention gets
declared. Five focuses exist: build, ideate, ops, review, and investigate.
There is no sixth and no config; new focuses arrive by shipped release,
never by settings.

## Usage

- `/clutch:intent build` declares a maker session: engage craft, speak the
  maker posture.
- `/clutch:intent ideate` declares a divergent session: one confirm line, then
  hand off.
- `/clutch:intent ops` declares an operations session: one confirm line, then
  hand off.
- `/clutch:intent review` declares a review session: one confirm line, then
  hand off.
- `/clutch:intent investigate` declares an investigate session: one confirm
  line, then hand off.
- `/clutch:intent` bare: a pick list through the AskUserQuestion tool (see Pick list).
  Its text fallback: ask one question: build, ideate, ops, review, or investigate?
  Nothing else, unless a guess is in context (see Guessed focus).

Any other argument gets one line naming the five focuses, no error ceremony,
except a plain go or yes when a guess is in context (see Guessed focus).

Invocation scope: this skill fires when the user answers the session-start
question or explicitly asks to set the session's focus, and at no other
moment. A stray "build" mid-conversation invokes nothing.

## Pick list

The bare form asks its one question through the AskUserQuestion tool:
one question, header "Focus", `multiSelect: false`, four options.
AskUserQuestion takes two to four options and adds Other on its own, so one of five focuses cannot be an option; the question names it as typeable under Other.
With a guess in context (see Guessed focus), option 1 is `<focus> (Recommended)`, its description naming <thread>, or "Your last focus in this folder." with no thread.
The rest follow in the order build, ideate, ops, review, investigate until there are four.
With no guess, the options are build, ideate, ops, and review, and the question says investigate can be typed under Other.
When the session-start ask in context offers only four focuses (its list lacks investigate), never offer or mention investigate: the four, the guess first when present, are exactly the options.
Each option carries a one-line description: build "Maker session: craft gear, tests ship with the code.",
ideate "Divergent session: explore wide before landing.", ops "Operations: sweep the tools, close loops one at a time.",
review "Review session: one PR at a time.", investigate "Read-only evidence: every finding tied to evidence.".

A picked option declares that focus: run it exactly as `/clutch:intent <focus>`, record included.
Under Other, naming a focus declares it; a plain go or yes declares the guessed focus; anything else is an ignored ask, and the once-only law holds.
When AskUserQuestion is not available, is denied, or errors (as in -p or SDK runs), ask the text question instead, unchanged.

## Guessed focus

When the session-start ask in context reads `looks like <focus> again`,
a guess is in context: the pick list offers it first, and the text fallback
asks this one question instead:
"Looks like <focus> on <thread>, go?"
<thread> is a few words naming the work, from the first of these in
context: the Thread line, the Last landed line, this folder's newest
Worklog line. With none of them, ask "Looks like <focus>, go?".

A plain go or yes declares <focus>, as the reply to that question or to the session-start ask, or as the argument.
Then run it exactly as `/clutch:intent <focus>`, record included.
Naming another focus declares that one. Any other reply is an ignored
ask, and the once-only law holds. Without that line in context, there is
no guess: the pick list has no Recommended option, and the text fallback
asks the five-way question as before.

## Record

Every declaration, in a repo or not, first appends one line so the next
fresh session in this folder can guess the focus. Run it once with
<focus> filled in, before the focus's own steps. It is silent on any
failure, and writes nothing when there is no `~/.clutch` folder or the
folder name holds a newline:

```sh
k=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" | tr ' ' -); case $k in *'
'*) ;; *) [ -d "$HOME/.clutch" ] && { printf '%s %s\n' "$k" '<focus>' >> "$HOME/.clutch/intents"; } 2>/dev/null ;; esac || :
```

## Build

Confirm in one line: "Craft engaged: converge-dominant, regular divergent
pulses, checkpoint at each commit point." Then write the marker (POSIX, silent
on any failure). Replace `@<tag>` with the latest `Session tag:` line; with no `Session tag:` line, leave it as is:

```sh
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { [ "${CLUTCH_PLAIN:-}" != off ] && ROOT=$(pwd -P) && [ "$ROOT" != / ] && [ ! "$ROOT" -ef "$HOME" ]; } || exit 0
mkdir -p "$ROOT/.clutch" 2>/dev/null || exit 0
T='@<tag>'; F="$ROOT/.clutch/tempo"; case $T in '' | @ | *[./]*) ;; *) [ "${CLUTCH_PER_SESSION:-}" = off ] || [ "${CLUTCH_WATCH:-}" = off ] || [ -L "$ROOT/.clutch/s" ] || [ -L "$ROOT/.clutch/s/${T#@}" ] || [ ! -d "$ROOT/.clutch/s/${T#@}" ] || F="$ROOT/.clutch/s/${T#@}/tempo" ;; esac
{ printf '%s\n' "craft" > "$F"; } 2>/dev/null || exit 0
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

## Ops

Confirm in one line: "Ops declared; handing off." Then run /clutch:ops. That
skill is the machinery: it engages espresso, sweeps the reachable tools once,
and holds the one-loop-at-a-time rhythm. Duplicate none of it here.

## Review

Confirm in one line: "Review declared; handing off." Then run /clutch:review. That
skill is the machinery: it engages espresso, loads your conventions, and
holds the one-PR-at-a-time rhythm. Duplicate none of it here.

## Investigate

Confirm in one line: "Investigate declared; handing off." Then run /clutch:investigate. That skill is the machinery: it engages craft, takes the pointer, and holds the read-only evidence rhythm. Duplicate none of it here.

## When a handoff fails

For ideate, ops, review, and investigate alike: if the handoff fails, say so in one line; no new gear is engaged; any earlier gear still holds.

## The once-only law

The session-start ask happens once, in the anchor's greeting, and only when no
gear is declared. Ignoring it and starting to work is an answer that closes
the matter; the skill never re-asks uninvited. Declaring later stays open by
invoking /clutch:intent at any time.

The gear is session-scoped: a new session (startup or /clear) opens in
neutral, so the ask fires at every fresh start; resume and compaction inherit
the declared gear. A fork inherits the declared gear too.
