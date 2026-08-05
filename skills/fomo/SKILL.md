---
name: fomo
description: Bank a link or a thought in one line, then return. Fired explicitly, a background pass also reads it, cross-references the pool, and hands back the gist; auto-engaged on a mid-task tangent it banks only and never reports back. Use when the user says "fomo", "capture this", "save this link", "note this for later", "oh wait, idea", "tab I can't close", or jumps to an unrelated idea mid-task.
---

# Fomo

The tab you can't close and the leap you can't chase are the same problem: a
pull you cannot act on right now. Fomo takes either one. It banks the line in
one instant, returns you to the work, and sends a background pass to read the
thing, cross-reference the pool, and come back with what you were missing.

The bank is the promise; the background pass is the payment. Banking without a
consumer is how a pool reaches four hundred entries and zero ignitions.

Fomo runs only when you hand it something. It never launches itself, and it
never surfaces what is already banked unless you pull.

## Usage

- `/clutch:fomo <url>` — bank the link, then read it in the background
- `/clutch:fomo <free text>` — a tangent, a leap, a thought with no URL
- `/clutch:fomo <url> #tag` — same, with a loose tag riding along
- `/clutch:fomo --brain <url | thought>` — bank straight to the brain at
  `$HOME/.clutch/captures.md` instead of the repo pool. For a thing that
  belongs to you rather than to this repo, and the only route that works
  outside a work tree at all.
- `/clutch:fomo` — nothing handed over: report one line, count plus the
  newest entry. Never a digest, never a review queue, never "you should
  process these". The user pulls; nothing pushes.
  With a brain at $HOME/.clutch, its captures count in too,
  and a newest entry drawn from the brain carries a [brain] label.
  Brain captures ride the count, but only repo lines get read: the brain's lines are already absorbed knowledge, not a queue.

Everything that is not the URL or the tag is the why-you-think-you-grabbed-it.
It is optional and it is not binding: the real why comes back from the
background pass.

## Procedure

### Step 1: Bank and return

Append exactly one line, then answer in one line and go back to the work in the
same turn. The snippet answers, not you.

```sh
DEST=$(git rev-parse --show-toplevel 2>/dev/null) || DEST=""
[ "<brain>" = yes ] && DEST=$HOME
[ -n "$DEST" ] || { echo MISS no-work-tree; exit 0; }
mkdir -p "$DEST/.clutch" 2>/dev/null || { echo MISS no-write; exit 0; }
printf '%s fomo: %s\n' "$(date +%s)" "<the thing and why, one line>" >> "$DEST/.clutch/captures.md" && echo BANKED || echo MISS no-write
```

Fill `<brain>` with `yes` for `--brain`, anything else otherwise. Outside a work
tree with no `--brain`, the honest answer is still `MISS no-work-tree` — the
brain is a destination you choose, never a silent fallback, because a line that
lands somewhere the user did not name is a line they will not find again.

`BANKED`: acknowledge with one line and nothing more, then launch Step 2 in the
background. `MISS`: say one honest line and repeat the thing back — it lives in
the transcript instead of vanishing behind an ack — and run Step 2 anyway; the
metabolizing does not depend on the bank.

With the uninvited budget spent, on an auto-engaged bank: bank silently, zero
output. The write costs no budget, only the ack does. A user-fired
`/clutch:fomo` always answers — a reply to a command is not an uninvited line,
and the budget never gates it.

**Auto-engaged, fomo banks only.** When the constitution's row-5 dispatch
engages fomo off a tangent the user did not hand over, stop after this step.
Step 2 runs when the user fires fomo, never off a row-5 match: a gist nobody
asked for is a push, and a push lays a brick.

Trace-back, on request only: when the user wants the reasoning behind a leap
they already took, back-fill the ladder from where they were to where they
landed. The jump is licensed first, explained after. Never gatekeep a leap by
demanding its reasoning up front.

### Step 2: Metabolize (background sub-agent)

Launch a background sub-agent and return to the work.
If backgrounding is unavailable, run the same pass in the foreground; same output contract.

<!-- ponytail: concurrent fomos run blind to each other, same isolate-everything
     default as daydream. Cross-agent visibility only if two diggers on one
     pulse ever demonstrably duplicate work. -->

**Content type.** Detected by URL pattern. A wrong guess still works — just a
less optimal read.

| Type | Detection | Read |
|---|---|---|
| Article | default (any URL not matching below) | WebFetch the page, strip the noise |
| Repo | github.com, gitlab.com | WebFetch the README, scan the structure |
| Video | youtube.com, youtu.be, vimeo.com | do NOT WebFetch (returns JS garbage); WebSearch for a transcript or summary |
| Tweet | x.com, twitter.com, threads.net | fetch the post and its thread; the value is the implication, not the text |
| Thought | no URL | skip fetching; the line itself is the content |

If a fetch fails (404, paywall, timeout), degrade to the entry's own text and
keep going.

1. **Extract the core pattern.** Not "what is this about" but the extractable
   trade-off. Write "they chose X over Y because Z", never "they recommend X".
   If the pattern fits in one generic sentence, go deeper: what specific
   choice, for what specific failure mode, at what specific cost. The pattern
   must be transplantable — someone in a different domain could apply the same
   structural insight. If it only makes sense in its original context, that's a
   fact, not a pattern.

2. **Cross-reference.** Grep `.clutch/dream-sparks.md`, `.clutch/ideas/`,
   `.clutch/sparks/`, recent `git log` for the pattern's keywords,
   and the same files under $HOME/.clutch when a brain exists.
   Missing files skip silently; a missing brain skips silently on its own.
   Repo items come first; brain items ride behind them, labeled [brain].

3. **Write the resonance.** Why did YOUR filter flag this, given what you're
   building? Never a summary: if the first sentence could appear in a search
   snippet, rewrite it. The resonance is a question or an assertion — "does
   this break our append-only stance?" or "this inverts the pool's assumption
   about X" — never a description. Lead with what surprised you. If nothing
   surprises you, say so honestly: that IS the verdict, release.

   The why is an OUTPUT, not an input. You rarely know why something grabbed
   you until you have dug in — relevance is discovered, not predicted. The
   one-line why from Step 1 is a guess to be overwritten, never a constraint on
   the read.

4. **Verdict.** One of three. It is a decision, not a label:
   - **absorb** — it enriches the work. Route to `.clutch/ideas/<slug>.md`:
     append to the matching idea file, or create one with the first `#` line
     as its title.
     Slugs are lowercase letters, digits, and hyphens only; nothing else.
     With a brain present, absorb into the brain: the item and its why go up through the door snippet below; the repo ideas route above runs only when no brain exists.
   - **park** — processed, might ignite later.
   - **release** — nothing you were missing. The pull was noise, and the
     fear is resolved.

5. **Write the outputs.** Order matters: the pool append lands first, and the
   `[delved]` marker goes in only after it does. If the append fails, do not
   mark the line — say so in one plain line; an unmarked line gets retried by
   the next fomo on that entry, a marked one without its pool entry is lost.
   - Append to `.clutch/dream-sparks.md` (create it if missing):

     ```markdown
     ### [fomo] <title> (YYYY-MM-DD)
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

     <!-- ponytail: rewriting captures.md in place while another fomo appends
          to the same shared file can race -- the same accepted ceiling as
          tempo's shared gear file. A lock or sidecar done-list only if it
          ever bites. -->
   - Verdict absorb → the ideas route above when no brain exists. With a
     brain at `$HOME/.clutch`, the door snippet runs instead, filling the
     slots from the entry; the `<epoch>` slot is filled only for banked entries.
     A fomo whose Step 1 returned MISS has no captures line: run the door through the heredoc append only, stop before the marker leg, and report its outcome; the marker leg belongs to banked entries alone.

```sh
POOL=$(git rev-parse --show-toplevel 2>/dev/null) || POOL=""
[ "<brain>" = yes ] && POOL=$HOME
[ -n "$POOL" ] || { echo MISS no-work-tree; exit 0; }
[ -d "$HOME/.clutch" ] || { echo SKIP no-brain; exit 0; }
mkdir -p "$HOME/.clutch/ideas" 2>/dev/null || { echo MISS brain-no-write; exit 0; }
cat 2>/dev/null >> "$HOME/.clutch/ideas/<slug>.md" <<'EOF' || { echo MISS brain-no-write; exit 0; }
# <idea title>
**Absorbed:** <YYYY-MM-DD> from <repo name or "direct">
**Why it pulled:** <the resonance>
**Core pattern:** <the extractable trade-off>
EOF
[ -f "$POOL/.clutch/captures.md" ] || { echo ABSORBED; exit 0; }
awk -v e="<epoch>" -v m="[delved <YYYY-MM-DD>]" '!done && $1 == e && index($0, "[delved") == 0 { sub("^" e " ", e " " m " "); done=1; found=1 } !found && $1 == e && index($0, "[delved") > 0 { found=1 } { print } END { if (!found) exit 1 }' "$POOL/.clutch/captures.md" 2>/dev/null > "$POOL/.clutch/.captures.tmp"; rc=$?
[ "$rc" -eq 1 ] && { rm -f "$POOL/.clutch/.captures.tmp" 2>/dev/null; echo MISS marker-no-match; exit 0; }
[ "$rc" -eq 0 ] && mv "$POOL/.clutch/.captures.tmp" "$POOL/.clutch/captures.md" 2>/dev/null && echo ABSORBED || { rm -f "$POOL/.clutch/.captures.tmp" 2>/dev/null; echo MISS marker-no-write; }
```

     The brain append lands before the marker; any MISS leaves the line unmarked, so the entry retries on the next fomo against it.
     SKIP no-brain is not a failure: it means the repo route ran instead.
     MISS marker-no-match means the filled epoch matched no unmarked captures line: the brain append landed, nothing was marked; check the epoch before retrying.
     A retried absorb may append to the brain twice; duplicate-over-lost is
     the direction the ordering law above already chose.

### Step 3: Hand back the gist

One message when the pass completes. This is a reply to something the user
fired, not an uninvited interrupt, so it does not spend budget — but it stays
small: the distilled thing worth knowing, plus where it landed in the pool.

- **absorb**: `Fomo landed: <title> — <the one thing worth knowing>. Resonates with <pool entry>; it's in the pool.`
- **park**: `Fomo: <title> — <the one thing worth knowing>. Parked, nothing it connects to yet.`
- **release**: `Fomo: <title> — nothing you were missing. <one line why>. Released.`
- append failed: relay the sub-agent's line honestly — `Fomo couldn't bank the
  result — <the pattern and resonance>` — the transcript holds what the pool
  could not.

The voice is the friend who read the thing you couldn't and comes back
buzzing. Excitement, not summary: what you found, what connects, why it
matters to this repo. Never an action item; the verdict is the routing.

## Sub-agent prompt scaffold

```
You are a fomo pass — a background metabolizer running while the user works
on something else.

The thing: "<url or thought>"
The user's guess at why: "<the one-line why, or none given>"

1. Read it. Detect the content type and use the matching read; a failed
   fetch degrades to the entry's own text.
2. Extract the core pattern: the extractable trade-off, "they chose X over
   Y because Z", transplantable to another domain.
3. Cross-reference .clutch/dream-sparks.md, .clutch/ideas/, .clutch/sparks/
   and recent git log for the pattern's keywords. Also read the same files
   under $HOME/.clutch when a brain exists; skip silently if missing.
   Label brain finds [brain]; repo items come first.
4. Write the resonance AFTER the read — why this pulled the user given what
   they are building. The user's guess is not binding; overwrite it.
5. Verdict: absorb, park, or release.
6. Append the finding to .clutch/dream-sparks.md in the fomo format, then
   run the absorb door if the verdict is absorb. The pool append lands
   before the [delved] marker. If an append fails, say so and return the
   pattern in your reply — never report a bank that didn't land.
7. Return the gist: the one distilled thing worth knowing, plus where it
   resonated.
```

## Where it sits in the gearbox

| Gear | Shape | This is |
|------|-------|---------|
| espresso, craft | focused work, convergent | the session you're protecting |
| ballmer via `/clutch:ideate` | deliberate divergence | a session-sized spark |
| daydream | ambient, whispered | 3–5 hops against the pool |
| fomo | a thing you hand over | catch, read, absorb, one door |

Daydream takes a fragment and wanders. Fomo takes a thing and digests it.
Whisper a connection to daydream; hand an artifact to fomo.

## What this skill does NOT do

- Run on its own — you hand it something, every time
- Auto-surface what is already banked (pull-only; never push "you have N
  captures"). The bare `/clutch:fomo` report above is the user pulling, which
  is legal; what is barred is volunteering it.
- Interrupt the current session (one-line ack, one gist when done, nothing
  between)
- Produce action items (it produces resonance and a verdict; the verdict is
  the routing)
- Touch any file outside the pool's two levels: the repo `.clutch/` and, when a brain exists, the brain at `$HOME/.clutch`

Why this works: see "Resonance", "The one door", and "Saltatory cognition /
feel-first foresight (Dodson)" in [GLOSSARY.md](../../GLOSSARY.md). Catch the
leap, keep the thread — and let the leap keep walking on its own. The fear of
missing out is resolved by examining the pull, not by hoarding the tab.
