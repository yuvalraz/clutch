---
name: daydream
description: Whisper a fragment mid-focus; a background pass runs 3–5 associative hops and banks the result without breaking your flow.
when_to_use: Use when the user says "daydream", "hold this thought", or "something connects".
argument-hint: "<whisper>"
disable-model-invocation: true
context: fork
background: true
---

# Daydream

Something pings a pattern mid-session, but breaking focus to chase it would
cost the thread. Whisper it to a daydream: a background pass runs 3–5 hops
against the pool and banks the result. You check it later. Your session
never stops.

Daydream runs only when you whisper to it — it never launches itself.
Wandering you didn't whisper is fomo's territory, untouched.

## Usage

`/clutch:daydream <whisper>`

The whisper is a fragment — a connection you noticed, a half-formed "this
reminds me of", a URL that pinged something. Keep it short. The daydream
does the rest.

## Procedure

### Step 1: The whisper

The harness runs this skill as a forked pass, in the background on the
session's model, and the session keeps going. Where backgrounding is off (a
non-interactive run or an older Claude Code), the same pass runs in the
foreground with the same final reply.
The pass sees none of the conversation, only this file and the whisper.

The whisper: "$ARGUMENTS"

An empty whisper banks nothing, and the final reply is `Daydream: no whisper — nothing banked`.

### Step 2: The micro-spark

Be fast. Be loose. This is a wandering pass, not a research report.

1. **Lightweight sweep** (speed over depth; missing files skip silently):
   `.clutch/dream-sparks.md`, `.clutch/captures.md`, grep `.clutch/ideas/`
   for whisper keywords, recent `git log` for related work.
   The brain: the same files under $HOME/.clutch when a brain exists; a missing brain skips silently.
   Repo items come first; brain items ride behind them, labeled [brain].
   Also read $HOME/.clutch/dream-sparks.md and grep $HOME/.clutch/ideas/ when a brain exists; skip silently if missing.
   Label brain finds [brain].

2. **3–5 associative hops**, starting from the whisper. Each hop pulls from
   the sweep, a web search, or prior work in the repo. Stop at five — this
   is a micro-spark, not a session.

   Mechanical rules (not optional):
   - A hop that restates the whisper in different words doesn't count. Make
     a DIFFERENT connection.
   - Two consecutive hops in the same domain → the next hop MUST cross
     domains.
   - About to write "this relates to"? Replace it with a specific structural
     claim: "X uses the same failure mode as Y" or "X inverts Y's assumption
     about Z."
   - Every hop names a specific file, concept, or entity — no abstract
     references.

3. **Self-rate the chain:** `resonant` (at least one non-obvious connection
   worth surfacing), `faint` (some movement, nothing surprising), `noise`
   (hops didn't connect to anything real).

4. **Append to `.clutch/dream-sparks.md`** (create it if missing):

   ```markdown
   ### [daydream] <short title> (YYYY-MM-DD)
   **Whisper:** "<original whisper>"
   **Chain:** <hop 1> → <hop 2> → <hop 3> [→ 4 → 5]
   **Signal:** <resonant|faint|noise>
   **Connection:** <1–2 sentences, or "No clear connection">
   ```

   Noise still writes — prefix the title with `[noise]`. Noise today might
   resonate with something tomorrow. If a hop used `.clutch/ideas/` or git
   history, add `[prior-work]` to the title.

### Step 3: Your final reply

Your final reply is exactly one line, and it is all the session sees.
Signal-dependent, never interrupting:

- `resonant`: `Daydream landed: "<short title>" — it's in the pool`
- `faint`: `Daydream: faint signal on "<whisper>" — banked`
- `noise`: `Daydream: noise on "<whisper>" — banked anyway`
- append failed: `Daydream couldn't bank — chain: <the hops>` — the transcript holds what the pool couldn't

Never report a bank that didn't land.

## Where it sits in the gearbox

| Gear | Shape | This is |
|------|-------|---------|
| espresso, craft | focused work, convergent | the session you're protecting |
| ballmer via `/clutch:ideate` | deliberate divergence | a session-sized spark |
| daydream | ambient, whispered | 3–5 hops in the background |

## What this skill does NOT do

- Interrupt the current session (the harness's launch notice, the one-line
  final reply, nothing between)
- Run a full chain reaction (3–5 hops max; that's `/clutch:spark`)
- Converge or produce action items (it surfaces connections, nothing more)
- Launch without a whisper — it is invoked, every time

Why this works: see "Saltatory cognition / feel-first foresight (Dodson)"
and "The pool" in [GLOSSARY.md](../../GLOSSARY.md). Catch the leap without
losing the thread — and let the leap keep walking on its own.
