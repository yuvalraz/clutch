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
   `.clutch/sparks/`, recent `git log` for the pattern's keywords,
   and the same files under $HOME/.clutch when a brain exists.
   Missing files skip silently; a missing brain skips silently on its own.
   Repo items come first; brain items ride behind them, labeled [brain].

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
     Slugs are lowercase letters, digits, and hyphens only; nothing else.
     With a brain present, absorb into the brain: the item and its why go up through the door snippet below; the repo ideas route above runs only when no brain exists.
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
     When the brain door runs, it performs this marker itself; never mark by hand alongside it.

     <!-- ponytail: rewriting captures.md in place while capture appends to
          the same shared file can race -- the same accepted ceiling as
          tempo's shared gear file. A lock or sidecar done-list only if it
          ever bites. -->
   - Verdict absorb → the ideas route above when no brain exists. With a
     brain at `$HOME/.clutch`, the door snippet runs instead, filling the
     slots from the entry; the `<epoch>` slot is filled only for captured entries.
     A direct-URL delve has no captures line: run the door through the heredoc append only, stop before the marker leg, and report its outcome; the marker leg belongs to captured entries alone.

```sh
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo MISS no-work-tree; exit 0; }
[ -d "$HOME/.clutch" ] || { echo SKIP no-brain; exit 0; }
mkdir -p "$HOME/.clutch/ideas" 2>/dev/null || { echo MISS brain-no-write; exit 0; }
cat 2>/dev/null >> "$HOME/.clutch/ideas/<slug>.md" <<'EOF' || { echo MISS brain-no-write; exit 0; }
# <idea title>
**Absorbed:** <YYYY-MM-DD> from <repo name or "direct">
**Why it pulled:** <the resonance>
**Core pattern:** <the extractable trade-off>
EOF
[ -f "$ROOT/.clutch/captures.md" ] || { echo ABSORBED; exit 0; }
awk -v e="<epoch>" -v m="[delved <YYYY-MM-DD>]" '!done && $1 == e && index($0, "[delved") == 0 { sub("^" e " ", e " " m " "); done=1; found=1 } !found && $1 == e && index($0, "[delved") > 0 { found=1 } { print } END { if (!found) exit 1 }' "$ROOT/.clutch/captures.md" 2>/dev/null > "$ROOT/.clutch/.captures.tmp"; rc=$?
[ "$rc" -eq 1 ] && { rm -f "$ROOT/.clutch/.captures.tmp" 2>/dev/null; echo MISS marker-no-match; exit 0; }
[ "$rc" -eq 0 ] && mv "$ROOT/.clutch/.captures.tmp" "$ROOT/.clutch/captures.md" 2>/dev/null && echo ABSORBED || { rm -f "$ROOT/.clutch/.captures.tmp" 2>/dev/null; echo MISS marker-no-write; }
```

     The brain append lands before the marker; any MISS leaves the line unmarked, so the capture retries next delve.
     SKIP no-brain is not a failure: it means the repo route ran instead.
     MISS marker-no-match means the filled epoch matched no unmarked captures line: the brain append landed, nothing was marked; check the epoch before retrying.
     A retried absorb may append to the brain twice; duplicate-over-lost is
     the direction the ordering law above already chose.

6. **Summary.** Processed count plus verdict counts, one line. Nothing else.

The voice in the foreground pass is the friend who read the thing you
couldn't and comes back buzzing. Excitement, not summary: what you found,
what connects, why it matters to this repo.

## What this skill does NOT do

- Run on its own — you invoke it
- Produce action items (it produces resonance and a verdict; the verdict is
  the routing)
- Touch any file outside the pool's two levels: the repo `.clutch/` and, when a brain exists, the brain at `$HOME/.clutch`

Why this works: see "Resonance" and "The two doors" in
[GLOSSARY.md](../../GLOSSARY.md). The fear of missing out is resolved by
examining the pull, not by hoarding the tab.
