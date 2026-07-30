---
name: dream-spark
description: An unfocused cross-referencing pass over everything the pool holds — what connects that nobody's watching. Use when the user says "dream-spark", "cross-reference the pool", or "stock the cellar".
disable-model-invocation: true
---

# Dream-spark

No anchor, no whisper — just "what connects that nobody's watching?" A
cross-referencing pass over the whole pool and the repo's git history,
appending what it finds to `.clutch/dream-sparks.md`. What it writes today
stocks tomorrow's sessions: the cellar, not a recharge.

## Usage

`/clutch:dream-spark` — one mode, invoked.

This is a ferment-gear pass: slow, deliberate wandering. Engaging
`/clutch:tempo ferment` for it fits — a suggestion only; this skill never
changes the gear itself. Run it when you stock the cellar: after a run of
captures, before an ideate session.

<!-- ponytail: unbounded append; add a trim pass only when the pool outgrows one read -->

## Procedure

### Step 1: Load the pool

Read everything; missing files skip silently:

1. `.clutch/dream-sparks.md` — prior entries (don't repeat them)
2. All of `.clutch/ideas/`
3. `.clutch/captures.md` — processed and not
4. Recent `.clutch/sparks/` logs
5. Git history: `git log`, unmerged branches, stashes
6. The brain: the same files under $HOME/.clutch when a brain exists; a missing brain skips silently.
   Repo items come first; brain items ride behind them, labeled [brain].
   Brain sources carry the [brain] label in the Sources line.

Then write a **context anchor** as plain text — long passes evict the
earliest file reads from the model's view, and this block is what the later
passes fall back on. Keep it under 800 tokens: the pool's themes, prior
entry titles to avoid repeating, patterns across the captures.

### Step 2: Cross-referencing passes

Iterative — each pass feeds the next. Up to 5 passes while the signal
holds.

- **Pass 1 — pairwise scan.** For each pair of pool items and ideas: is
  there a non-obvious STRUCTURAL connection? Skip anything already explicit
  (same topic, same thread).
- **Pass 2 — deepen.** For each Pass-1 find: what ELSE connects to both?
  Pull in captures, spark logs, the graveyard. The second pass finds the
  three-way connections the first one missed.
- **Pass 3 — cross-domain injection.** WebSearch a keyword from the
  strongest connection in a completely unrelated domain. Does the outside
  result resonate with anything in the pool?

Anti-convergence enforcement (all passes):

- "Both mention X" is co-occurrence, NOT a connection. Discard it; find HOW
  they relate structurally.
- A connection findable by keyword search alone is search, not
  cross-referencing. Discard it. The connection must require both sources
  in view at once.
- About to write "similarly" or "this also"? Replace with a specific
  structural claim: "X's failure mode is Y applied to a different domain."
- Every connection names the structural pattern that links its sources.

### Step 3: Self-rate

Each connection: `resonant` (non-obvious, structurally real, opens a door),
`faint` (some movement, might ignite later), `noise` (surface-level or
already known).

### Step 4: Append

Per connection, append to `.clutch/dream-sparks.md` (create it if missing):

```markdown
### [dream] <short title> (YYYY-MM-DD)
**Pass:** <1|2|3…>
**Sources:** <item A> × <item B> [× <item C>]
**Chain:** <how the connection was found>
**Signal:** <resonant|faint|noise>
**Connection:** <1–2 sentences>
```

### Step 5: Summary

One block: passes run, connections found by signal, top 3 titles. Nothing
else — no ratios, no counts of what's sitting in the pool.

## Quality guidelines

- **Non-obvious only.** Already explicit → skip.
- **Structural, not superficial.** "Both mention pipeline" is noise; "both
  describe multi-phase processes where handoffs fail" is resonant.
- **Don't repeat prior entries.** Read the pool first; repeat only with a
  meaningfully different angle.
- **2–5 connections per pass is ideal.** Don't force it. Zero is fine.
- **Append only.** Never delete a prior entry.

## What this skill does NOT do

- Run uninvited or on a timer
- Produce action items (it surfaces connections; ignition happens in
  `/clutch:spark`)
- Touch any file but `.clutch/dream-sparks.md`

Why this works: see "Dream-spark" and "The pool" in
[GLOSSARY.md](../../GLOSSARY.md). The cellar stocks later sessions; nothing
here is a recharge.
