---
name: delve
description: Absorb captured links and thoughts into resonance, patterns, and connections. Use when the user says "delve", "process my captures", or "absorb". The absorption layer between the two doors and the pool.
disable-model-invocation: true
---

# Delve

Capture is cheap; absorption is where a capture becomes yours. Delve pulls
unprocessed items out of `.clutch/captures.md`, reads each one for resonance
— why did this pull you — and routes what survives into the pool.

The structural position: the two doors (capture, fomo) → `/clutch:delve`
(absorb) → `/clutch:dream-spark` (cross-reference) → `/clutch:spark`
(ignite). Without absorption, the gap between capture and cross-referencing
is where a capture rots.

## Usage

- `/clutch:delve` — absorb the oldest unprocessed entry (foreground)
- `/clutch:delve <url>` — delve a URL directly; it doesn't need to be
  captured first (skips the marker step)
- `/clutch:delve --batch` — the 3–5 oldest unprocessed entries in a
  background sub-agent; if backgrounding is unavailable, run the same pass
  in the foreground, same output contract
- `/clutch:delve --scan` — a triage pass over everything unprocessed, no
  fetching, ranked by resonance strength; it tells you WHAT to delve, not
  what it contains

Unprocessed means a line in `.clutch/captures.md` without a `[delved` token.
Both doors' lines qualify: capture tangents and fomo items alike.

## Content type

Detected by URL pattern. A wrong guess still works — just a less optimal
read.

| Type | Detection | Read |
|---|---|---|
| Article | default (any URL not matching below) | WebFetch the page, strip the noise |
| Repo | github.com, gitlab.com | WebFetch the README, scan the structure |
| Video | youtube.com, youtu.be, vimeo.com | do NOT WebFetch (returns JS garbage); WebSearch for a transcript or summary |
| Tweet | x.com, twitter.com, threads.net | fetch the post and its thread; the value is the implication, not the text |
| Thought | no URL | skip fetching; the line itself is the content |

If a fetch fails (404, paywall, timeout), degrade to the entry's own text
and keep going.

## Procedure

1. **Extract the core pattern.** Not "what is this about" but the
   extractable trade-off. Write "they chose X over Y because Z", never "they
   recommend X". If the pattern fits in one generic sentence, go deeper:
   what specific choice, for what specific failure mode, at what specific
   cost. The pattern must be transplantable — someone in a different domain
   could apply the same structural insight. If it only makes sense in its
   original context, that's a fact, not a pattern.

2. **Cross-reference.** Grep `.clutch/dream-sparks.md`, `.clutch/ideas/`,
   `.clutch/sparks/`, and recent `git log` for the pattern's keywords.
   Missing files skip silently.

3. **Write the resonance.** Why did YOUR filter flag this, given what you're
   building? Never a summary: if the first sentence could appear in a search
   snippet, rewrite it. The resonance is a question or an assertion —
   "does this break our append-only stance?" or "this inverts the pool's
   assumption about X" — never a description. Lead with what surprised you.
   If nothing surprises you, say so honestly: that IS the verdict, release.

4. **Verdict.** One of three. It is a decision, not a label:
   - **absorb** — it enriches the work. Route to `.clutch/ideas/<slug>.md`:
     append to the matching idea file, or create one with the first `#` line
     as its title.
   - **park** — processed, might ignite later.
   - **release** — nothing you were missing. The pull was noise, and the
     fear is resolved.

5. **Write the outputs.** Order matters: the pool append lands first, and
   the `[delved]` marker goes in only after it does. If the append fails, do
   not mark the line — say so in one plain line; an unmarked capture gets
   retried next delve, a marked one without its pool entry is lost.
   - Append to `.clutch/dream-sparks.md` (create it if missing):

     ```markdown
     ### [delve] <title> (YYYY-MM-DD)
     **Source:** <url or "thought">
     **Type:** <article|repo|video|tweet|thought>
     **Resonance:** <why it pulled you — 1–2 sentences>
     **Core pattern:** <the extractable trade-off — 2–3 sentences>
     **Connects to:** <pool entries, ideas, recent work>
     **Verdict:** <absorb|park|release> — <one-line reason>
     ```

   - Mark the captures line processed: insert `[delved YYYY-MM-DD]` as the
     first token after the epoch.

     <!-- ponytail: rewriting captures.md in place while capture appends to
          the same shared file can race -- the same accepted ceiling as
          tempo's shared gear file. A lock or sidecar done-list only if it
          ever bites. -->
   - Verdict absorb → the ideas route above.

6. **Summary.** Processed count plus verdict counts, one line. Nothing else.

The voice in the foreground pass is the friend who read the thing you
couldn't and comes back buzzing. Excitement, not summary: what you found,
what connects, why it matters to this repo.

## What this skill does NOT do

- Run on its own — you invoke it
- Produce action items (it produces resonance and a verdict; the verdict is
  the routing)
- Touch any file outside the `.clutch/` pool

Why this works: see "Resonance" and "The two doors" in
[GLOSSARY.md](../../GLOSSARY.md). The fear of missing out is resolved by
examining the pull, not by hoarding the tab.
