---
name: ideate
description: Put the session in divergent mode — load the pool, engage ballmer, hold anti-convergence for everything that follows. Use ONLY when the user explicitly asks to ideate ("ideate", "divergent mode", "let's explore") or when /clutch:intent hands off after an "ideate" answer. A passing mention of exploring mid-conversation is not a trigger.
---

# Ideate

Ideate sets the MODE for the whole session: same repo, opposite lens.
Where `/clutch:spark` runs one protocol, ideate configures the session and
persists — the mode side of the gearbox. Within it you might invoke
`/clutch:spark`, `/clutch:daydream`, `/clutch:dream-spark`, or
`/clutch:fomo`, all under the same guardrails.

## Usage

- `/clutch:ideate` — enter divergent mode, load the pool, run the primer
- `/clutch:ideate <anchor>` — same, then go straight into `/clutch:spark`
  with the anchor once the primer has run

## Procedure

### Step 0: Engage the gear

Confirm in one line — "Ballmer engaged — fast divergence, periodic
convergence checkpoints." — then write the marker (POSIX, silent on any
failure):

```sh
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
mkdir -p "$ROOT/.clutch" 2>/dev/null || exit 0
printf '%s\n' "ballmer" 2>/dev/null > "$ROOT/.clutch/tempo" || exit 0
```

This is the existing tempo mechanism — the heartbeat carries the gear to
the model next turn; no new state. If the write fails, the declaration
still governs the live session; only the re-injection is lost. A checkpoint
in this mode is a chain trace-back, never a summary.

### Step 1: Load the pool

Speed over completeness; missing files skip silently:

1. `.clutch/dream-sparks.md` — recent cross-references (tail it if huge)
2. `.clutch/captures.md` — count the unprocessed lines (no `[delved` token)
3. The most recent `.clutch/sparks/` log — the cross-session snowball
4. `.clutch/ideas/` — scan titles
5. The brain: the same files under $HOME/.clutch when a brain exists; a missing brain skips silently.
   Repo items come first; brain items ride behind them, labeled [brain].
   With a brain present, its captures count in too: the unprocessed count in item 2 reads both levels.
   Brain captures ride the count, but only repo lines get read: the brain's lines are already absorbed knowledge, not a queue.

### Step 1.5: Surface what's hot

Score each idea file by recent signal so the primer offers what's ripe.

| Tier | Signal | Weight |
|------|--------|--------|
| Highest | the idea's key terms appear in `.clutch/captures.md` lines | 3x |
| High | a `[dream]`, `[daydream]`, or `[fomo]` entry from the last 7 days references the idea (parse the `(YYYY-MM-DD)` headers) | 2x |
| Medium | idea file modified in the last 7 days | 1x |

Pools written before the fomo merge carry `[delve]` entries; score them exactly
as `[fomo]`. An old tag is old vocabulary, not a weaker signal.

Procedure: glob `.clutch/ideas/*.md` and `$HOME/.clutch/ideas/*.md`; a brain idea keeps its [brain] label through scoring and the primer.
Extract each title (first `#` line)
and 3–5 key terms, count matches per tier, score, sort descending. Top 3
with score > 0 get ONE provocative question each, connecting the idea to
its fresh signal. Anti-convergence rewrite: a question starting "How does"
or "What is" becomes "What breaks if…" or "What happens when…". The
question must work as a `/clutch:spark` anchor.

Score 0 with no touch in 14+ days → dormant. That classification is
internal: the user-facing dormant line names the ideas, never counts days.

### Step 1.7: The bell

If the pool has entries:

1. **Recognition opener.** If the pool or the ideas show one concrete thing
   that survived or shipped — an entry that became an idea file, an idea
   that became a commit — name it in one specific line. An earned fact, no
   praise adjectives, no elapsed-time anchor. If nothing is visible, skip
   the line.
2. **Draw exactly ONE pre-warmed item** from the pool and offer it as the
   session anchor.
   The draw may hand back a brain item, labeled [brain]; ties go to the repo item, nearest context wins.

Constraints (HARD): the offer is an invitation the user can freely ignore —
never a demand. Exactly one item, never a digest. The offer never mentions
how many other items the pool holds, how long anything has sat there, or
anything about the pool's state beyond the one item. Missing or empty file
→ skip silently, no mention of the absence.

The drawn item surfaces as one of Step 2's options — the re-entry anchor
slot. No separate pre-primer prompt.

### Step 2: Primer

Output the pool summary:

```
Pool: <N> connections / Captures: <N> unprocessed / Last spark: <date + anchor> / Tempo: ballmer engaged
```

Then present the choices via `AskUserQuestion`:

- The bell item, when Step 1.7 drew one — labeled with its title, described
  as drawn from the pool
- The hot-idea questions from Step 1.5
- "Just explore" — no anchor, see what connects

**Option budget (HARD): max 4 options total.** With a bell item, hot ideas
cap at 2 (bell + 2 hot + "Just explore"). Without one, up to 3 hot ideas +
"Just explore". Fewer exist → present fewer; never pad. No hot ideas and no
bell → "Just explore" only.

On selection: the bell item or a hot question → invoke `/clutch:spark` with
it as the anchor. Free text via the built-in "Other" → that text is the
anchor. "Just explore" → "Ready. What's surfacing?" After the question,
list dormant ideas if any — names only.

### Step 3: Session guardrails

For the rest of the session these rules are HARD — they override default
behavior:

- **Don't converge early.** No summarizing, no "the key takeaway is", no
  action items until asked. Catch yourself converging → one more hop.
- **Follow tangents.** If something reminds you of something, say it.
  Relevance is discovered retroactively, not predicted.
- **Ping-pong is the protocol.** A fragment thrown gets a hop added.
  Neither side leads — both riff.
- **Trace the chain.** Keep the association chain in the background so the
  path can be walked back at any time.
- **Exploration IS the work in this gear.** No productivity guilt, no "is
  this the best use of time?" checks.
- **Routing at close, not during.** Don't stop to categorize mid-flow.
  Capture everything, sort at session close.
- **No code.** A "build this" spark becomes an idea file. Building it is a
  fresh espresso or craft unit.

Chain-sustaining mechanics: when hops spiral inward, make a stock draw —
grep the pool for a keyword from 3 hops back, read a random unprocessed
capture, WebSearch something tangential. Cross-session snowball: reference
the pool and prior `.clutch/sparks/` logs throughout; each session enriches
the next.

### Session close

When the user says "let's land this", "wrap up", "done" — or energy drops
for 5+ exchanges:

1. Trace back the chain if one ran
2. Collect a rating (fire/warm/smoke/cold) if a spark ran
3. Propose routing — consent-gated, nothing files without approval
4. Save the session log to `.clutch/sparks/YYYY-MM-DD-<slug>.md`

## Skill interactions

| Skill | In ideate mode |
|-------|----------------|
| `/clutch:spark <anchor>` | full protocol: ignition, chain, cool-down |
| `/clutch:daydream <whisper>` | background micro-spark |
| `/clutch:dream-spark` | cross-referencing pass over the pool |
| `/clutch:fomo <content>` | banked in one line, read and absorbed in the background |

All outputs accumulate; routing happens at session close.

## What this skill does NOT do

- Replace `/clutch:spark` (ideate sets the mode; spark runs the protocol)
- Write code or switch to implementation
- Converge prematurely or produce action items mid-session
- Save anything without consent
- Judge ideas for practicality — that belongs to the convergent gears

Why this works: see "Tempo / the gearbox", "The pool", and "Prevent-a-brick
/ the recognition bell" in [GLOSSARY.md](../../GLOSSARY.md). The gear is
engaged by invitation, the pool is drawn one item at a time, and the mode
holds so the wandering is licensed, not stolen.
