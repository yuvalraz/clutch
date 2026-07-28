---
name: spark
description: Run the divergent chain-reaction protocol — ignition, ping-pong hops, cool-down with trace-back. Use when the user says "spark", "riff on this", or "chain reaction".
disable-model-invocation: true
---

# Spark

Three phases: ignition, chain reaction, cool-down. The chain is
collaborative divergent thinking — hops, not findings — and the trace-back
at the end is what makes the wandering bankable.

## Usage

`/clutch:spark` or `/clutch:spark <anchor>`

If no anchor is given, ask: "What's surfacing? (A thought, a captured line,
a pool item, a word — anything.)"

## Phase 1: Ignition

**Context sweep.** Pull from the pool looking for anything that resonates
with the anchor. Associative search, not structured search. Missing files
skip silently.

Quick sweep (default):

1. `.clutch/dream-sparks.md` — any entry that connects
2. `.clutch/captures.md` — unprocessed lines (no `[delved` token)
3. `.clutch/ideas/` — scan titles; a parked idea that resonates gets named
   in the opening volley
4. The most recent `.clutch/sparks/` log — the last chain's loose ends
5. **The git graveyard** — recent `git log`, `git branch --no-merged`,
   `git stash list`, and dirty uncommitted files. Abandoned work is ignition
   stock: the branch that died mid-thought is an anchor nobody else has.
   Read-only, always fail-open.

Deep sweep (for a dedicated session) adds: grep the pool for anchor
keywords, and WebSearch the anchor topic.

**Anchor the context (compaction survival).** Long sessions silently evict
the oldest tool results, and the sweep is the first thing to go. After the
sweep, before the volley, write a context anchor as plain text — anchor,
pool highlights, idea threads, capture lines, graveyard finds. Keep it under
500 tokens. If everything else is evicted, the chain can still reference
this block.

**Open the volley.** Present 2–3 unexpected connections from the sweep as
hops, not findings: "your anchor reminds me of X, which connects to Y
because…". Never a structured summary. The first volley sets the tone.

## Phase 2: Chain Reaction

The core loop. The rules are HARD.

**Ping-pong rules:**

1. **When the user throws** a fragment — add a hop. Never ask "what do you
   mean?" Add your own associative leap. "Yes AND", not "did you mean?"
2. **Either side can fork** — "wait, that branches" is valid. Track both
   branches.
3. **Either side can trace back** — "how did we get here from X?" triggers a
   chain walkback.
4. **Neither side converges** — no "so the takeaway is". That comes in
   Phase 3 only.
5. **No judgment** — never "that's not practical". Every hop is valid.

**Chain capture.** Maintain a running chain silently:

```
[N] <speaker>: "<hop content>"
    +-- fork: [Na] "<fork description>"
```

Don't show it during Phase 2 unless asked to trace back.

**Anti-convergence mechanics.** Monitor your own output:

- **Semantic narrowing** (last 3 hops in one domain) → inject a
  cross-domain jump: nature, music, architecture, game design, cooking,
  physics — anything unrelated.
- **Summary impulse** (about to say "so," "in summary") → suppress it, make
  one more hop.
- **Clarification impulse** (about to ask "do you mean X or Y?") → replace
  with an assertion: "X reminds me of Y", keep moving.
- **Energy drop** (shorter hops, less surprise) → a stock draw.

**Stock draw.** When the chain thins, draw from the cellar:

1. Pick a keyword from 3+ hops back (go back for distance)
2. One action: grep `.clutch/dream-sparks.md` or `.clutch/ideas/` for it,
   read a random unprocessed line from `.clutch/captures.md`, WebSearch the
   keyword plus a random domain word, or pull a graveyard item
3. Present the find as a new hop: "<keyword> led me to <find>, which
   connects because…"

**Prior-work queries** (opt-in, hop-triggered): "have we circled this
before?" → grep `.clutch/ideas/` and `git log --oneline` for the topic.
A prior hit doesn't end the chain — it adds a hop: "we've ALREADY circled
this; what connects the old framing to what we just sparked?" Tag such hops
in the chain capture with a `[source: .clutch/ideas/<file>]` note.

## Phase 3: Cool-down

Triggered when the user says "let's land this", "cool down", "wrap up" — or
on sustained energy drop (5+ hops without forks or direction changes).

1. **Present the chain**, all forks included. Anti-flattening rule: do NOT
   digest it into a narrative. Present the hops. The chain IS the artifact.

2. **Session rating**, gut-level:

   ```
   fire  — genuine new ground
   warm  — useful connections, nothing paradigm-shifting
   smoke — felt like movement but didn't land anywhere real
   cold  — noise, word association cosplaying as insight
   ```

   The rating stays in the session log. It is a gut read, not a score —
   nothing downstream consumes it.

3. **Output routing, consent-gated.** Quick sparks stay inline in the
   session log. Formed ideas → `.clutch/ideas/YYYY-MM-DD-<slug>.md`.
   Propose the routing; the user approves or edits. Nothing files without
   approval.

4. **Save the session log** to `.clutch/sparks/YYYY-MM-DD-<slug>.md`:
   anchor, full chain, rating, routing decisions, formed ideas inline.
   Create the directory fail-open, house shape (`mkdir -p … 2>/dev/null`).
   If the mkdir or the write fails, say so in one plain line: the log could
   not be written, and the chain presented in step 1 is the record. The user
   just approved this save — a miss is said, never skipped.

## What this skill does NOT do

- Judge ideas ("that's not practical" — never)
- Converge prematurely ("so the actionable takeaway is" — Phase 3 only)
- Ask clarifying questions when a hop would be better
- Break flow for structure
- Write code — a "build this" spark routes to an idea file; shifting to
  espresso or craft and building it is a fresh unit
- Route outputs without consent

Why this works: see "Saltatory cognition / feel-first foresight (Dodson)"
and "Spark" in [GLOSSARY.md](../../GLOSSARY.md). The jump is the native
gait; the protocol gives it a track and a trace-back.
