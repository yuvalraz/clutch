# clutch

*The coupling between intention and action.*

Clutch is an execution harness for ADHD: software that catches a project at
the exact moment it stops moving and answers with recognition instead of a nag.

It stands on Barkley's frame: ADHD is a performance disorder. The knowledge is
there, the intent is there, and the coupling between intention and action
fails at the point of performance. So Clutch isn't a motivation supply. It's a
transmission: it gets your existing intent to the wheels.

## Who it's for

The smart-but-stuck profile Brown calls coast-to-collapse: intelligence masks
the executive-function deficit, delays the wall, and makes the crash more
shame-laden, because "you're so smart" was the standing explanation the whole
way down. For me, launching was always cheap. Projects die around day ten,
when novelty drains and the boring plumbing starts. That day is what Clutch
instruments.

## What it does

The harness exists. It ships as a Claude Code plugin in this repo, four
mechanisms, zero configuration. Each fires at the point of performance, while
you are at the machine and could act, because intervention effect degrades
with distance from that moment (Barkley). What it says is recognition, never
a demand. The design commitments behind it are fixed in
[ANNOTATIONS.md](ANNOTATIONS.md).

- **The thread.** Every session opens with an anchor: the branch you were on,
  the last commit you authored, what was mid-change. Picking a project back
  up stops costing a re-orientation tax.
- **The recognition bell.** Silent by default; the gate is the point. When a
  commit of yours lands mid-session, it says one line, at most twice a
  session:

  > Landed: 'parser runs clean'. Smallest next move: one commit.

  It names what moved and the smallest next step. It never asks for the
  finish: demanding the far side of the wall lays a brick (Mahan), and the
  bell's whole job is to prevent one. No day-counts, no streak language, no
  nag, ever.
- **smallest-move.** A skill that triggers on "stuck", "too big", "where do I
  even start" and returns exactly one named smallest legal move. Never a list.
- **sprint.** A fixed 20-minute timebox on one named shippable, with the bell
  surfacing the remaining time.

## Install

Two commands inside Claude Code:

```
/plugin marketplace add yuvalraz/clutch
/plugin install clutch@clutch
```

No settings, no env vars, no modes. The opinions are the product.

Two known limits. Concurrent sessions on the same repo share `.clutch/` state, last writer wins.
The hooks emit at most two visible lines per session by design.

## The library so far

7 sources digested, weighted, and annotated. Its foundation is a weighted,
queryable library of the ADHD research that actually resonates, built [one
coherent source at a time](#the-canonical-spine-one-coherent-source-at-a-time-not-all-at-once),
in public.

- [GLOSSARY.md](GLOSSARY.md): every private term this repo leans on, defined
  and attributed.
- [ANNOTATIONS.md](ANNOTATIONS.md): the editorial layer over the canon. What
  to trust, what to quarantine, how the claims connect.

The library ships one source at a time because the corpus can't be abandoned
that way: each source is small, self-contained, and committed the day it's
added. If the tool meant to help me finish things can't finish itself, it
doesn't work. This repo is the product's first test.

## The one rule (walking-pace floor)

**One source → one clean file → one commit.** Never "ingest everything, ship
when done." The streak can't hit zero: the smallest legal move is adding a
single source. Add the next one when the streak needs feeding, not before.

## How it's stored

Plain markdown, one file per source in `sources/`, with frontmatter:

```yaml
author: "Russell Barkley"
title: "30 Essential Ideas — full series"
type: lecture          # lecture | lecture-series | book | article | podcast
source: https://...
resonance: high        # high | med | low — how much it maps to MY condition
```

`resonance` is the "weight": hand-assigned, not learned. No vector DB yet. A
folder of markdown *is* the database; an agent or LLM greps and reads it
directly, reasoning over it without a query layer in between.

<!-- ponytail: markdown corpus; add embeddings (sqlite-vec) only when grep+read
     measurably falls short, i.e. when the corpus outgrows a context window. -->

## Ingest a source

Moved to [tools/ingest/](tools/ingest/README.md). The ingester is the
authoring scaffold behind the library, not part of the plugin.

## Why the library looks empty

`sources/` carries no text on GitHub. The transcripts and book texts are
third-party copyrighted material and stay local by design. What's public is
the editorial layer (the resonance weights, [ANNOTATIONS.md](ANNOTATIONS.md),
[GLOSSARY.md](GLOSSARY.md)) and the harness built on it. The ingester is my
private canon-authoring scaffold, documented in [tools/ingest/](tools/ingest/);
the public layer is the editorial one.

## The canonical spine (one coherent source at a time, not all at once)

A *source* is a whole work. A lecture series chopped into parts is one source:
digest it as one file, not N stubs.

| Source | Resonance | Status |
|--------|-----------|--------|
| Barkley, *30 Essential Ideas You Should Know about ADHD* (full 27-part lecture → one digest) | high | done |
| Thomas E. Brown, *Emotions and Motivation in ADHD* (CHADD lecture) | high | done |
| Hallowell & Ratey, *ADHD 2.0* webinar | med | done |
| Barkley, *ADHD and the Nature of Self-Control* (1997 book) | n/a | dropped: no e-book edition exists; its model matured into *Executive Functions* (2012), already digested |
| Barkley, *Executive Functions* (2012 book, Guilford DRM-free ePub) | high | done |
| Thomas E. Brown, *Smart but Stuck* (Burnett Seminar lecture, 2014: the high-IQ coast-to-collapse pattern) | high | done: lecture stands in for the book, which has no DRM-free edition |
| Dodson, *Defining Features of ADHD* (ADDitude lecture: interest-based nervous system, RSD, hyperarousal) | high | done |
| Mahan, *the Wall of Awful* (StudyPro "Unlocking ADHD" webinar) | high | done |

## Where this goes

It already went. The harness is the plugin shipping in this repo, neither a
planner nor a tracker. The mechanisms carry the canon's distilled judgment in
fixed wording and baked constants; nothing reads the corpus at runtime. The
weighted library stays as the authoring substrate: when new research clears
the bar, its yield gets distilled into the next wording. Just-in-time
recognition, never a dashboard reviewed later.

## Is this abandoned?

Finished is a deliberate state for an opinionated tool. No news is stability.
The version bumps for exactly three reasons: new research clears the bar,
wording fails in the wild, or the plugin API drifts.

No script makes a network call. Verify:
`grep -rE 'curl|wget|/dev/tcp|nc ' scripts/` returns nothing.

Built in public, with AI assistance (Claude).
