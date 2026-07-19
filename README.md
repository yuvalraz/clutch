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

## What it will actually do

Nothing yet. The harness is not built; this section is the design commitment,
already fixed in [ANNOTATIONS.md](ANNOTATIONS.md). One worked example of a
future intervention:

A side project has had zero forward movement for five days. Zero, and only
zero: the trigger never fires on slowness, because slow is legal and decay is
the signal (Mahan's forward-movement sensor, the biggest product yield in the
canon). It fires at the point of performance, while I'm at the machine and
could act, because intervention effect degrades with distance from that moment
(Barkley). And what it says is recognition, never a demand:

> Day 12 on the parser. It ran clean on Tuesday; that shipped. The smallest
> legal move is one commit.

It names what moved and the smallest next step. It never asks for the finish:
demanding the far side of the wall lays a brick (Mahan again), and the bell's
whole job is to prevent one.

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

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt

# a single video:
.venv/bin/python ingest.py "https://www.youtube.com/watch?v=VIDEO_ID" \
    --author "Author" --title "Talk title" --resonance high

# a whole playlist → ONE digest (a lecture series is a single work):
.venv/bin/python ingest.py "https://www.youtube.com/playlist?list=PLAYLIST_ID" \
    --author "Russell Barkley" --title "30 Essential Ideas (full series)" --resonance high

# a book (DRM-free EPUB, bought — the file stays local like every source):
.venv/bin/python ingest_book.py path/to/book.epub \
    --author "Thomas E. Brown" --title "Smart but Stuck" --resonance high
```

## Why the library looks empty

`sources/` carries no text on GitHub. The transcripts and book texts are
third-party copyrighted material and stay local by design. What's public is
the editorial layer (the resonance weights, [ANNOTATIONS.md](ANNOTATIONS.md),
[GLOSSARY.md](GLOSSARY.md)) and the tool. Anyone can rebuild the corpus
locally by re-running the ingester against the same public sources.

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

The weighted corpus is the knowledge layer under a runtime harness, neither a
planner nor a tracker. The harness will consume it at the point of
performance: decay-triggered interventions that cite the canon while an
executive-function breakdown is actually happening, not while I'm planning
ahead. Just-in-time recall, never a dashboard reviewed later.

Built in public, with AI assistance (Claude).
