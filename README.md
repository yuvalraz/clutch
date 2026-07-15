# clutch

*The coupling between intention and action.*

Clutch is an execution harness for ADHD. Barkley's frame: the problem isn't
knowing what to do or wanting to — it's the wiring between intention and action
at the point of performance. So Clutch isn't a motivation supply. It's a
transmission: it gets your existing intent to the wheels.

Its foundation, and the first thing built here, is a weighted, queryable library
of the ADHD research that actually resonates — **one source at a time, in
public**. The point isn't the finished library; it's that it *can't be
abandoned*: each source is small, self-contained, and shipped the day it's
added. If the tool meant to help me finish things can't finish *itself*, it
doesn't work. This repo is that first test.

## The one rule (walking-pace floor)

**One source → one clean file → one commit.** Never "ingest everything, ship
when done." The streak can't hit zero: the smallest legal move is adding a
single source. Add the next one when the streak needs feeding — not before.

## How it's stored

Plain markdown, one file per source in `sources/`, with frontmatter:

```yaml
author: "Russell Barkley"
title: "30 Essential Ideas — full series"
type: lecture          # lecture | lecture-series | book | article | podcast
source: https://...
resonance: high        # high | med | low — how much it maps to MY condition
```

`resonance` is the "weight" — hand-assigned, not learned. No vector DB yet: a
folder of markdown *is* the database — an agent or LLM greps and reads it
directly, reasoning over it without a query layer in between.

The reasoning behind the weights, plus what to *distrust* in the canon, lives in
[`ANNOTATIONS.md`](ANNOTATIONS.md): a quarantine ledger (claims that are in the
corpus but must not drive the product) and a typed-edge map of how the sources
connect. The transcripts stay local; the annotations are the public part.

Raw transcripts stay **local** (they're copyrighted third-party text). What's
public is the tool, the index, and the resonance weights — not the source text.

<!-- ponytail: markdown corpus; add embeddings (sqlite-vec) only when grep+read
     measurably falls short — i.e. when the corpus outgrows a context window. -->

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

## The canonical spine (ship one coherent source at a time — NOT all at once)

A *source* is a whole work. A lecture series chopped into parts is one source —
digest it as one file, not N stubs.

| Source | Resonance | Status |
|--------|-----------|--------|
| Barkley — *30 Essential Ideas You Should Know about ADHD* (full 27-part lecture → one digest) | high | done |
| Thomas E. Brown — *Emotions and Motivation in ADHD* (CHADD lecture) | high | done |
| Hallowell & Ratey — *ADHD 2.0* webinar | med | done |
| Barkley — *ADHD and the Nature of Self-Control* (1997 book) | — | dropped — no e-book edition exists; its model matured into *Executive Functions* (2012), already digested |
| Barkley — *Executive Functions* (2012 book, Guilford DRM-free ePub) | high | done |
| Thomas E. Brown — *Smart but Stuck* (Burnett Seminar lecture, 2014 — the high-IQ coast-to-collapse pattern) | high | done — lecture stands in for the book, which has no DRM-free edition |
| Dodson — *Defining Features of ADHD* (ADDitude lecture: interest-based nervous system, RSD, hyperarousal) | high | done |
| Mahan — *the Wall of Awful* (StudyPro "Unlocking ADHD" webinar) | high | done |

## Where this goes

The weighted corpus is the knowledge layer under a runtime harness — not a
planner or a tracker. The harness will consume it at the point of performance:
decay-triggered interventions that cite the canon when an executive-function
breakdown is actually happening, not when I'm planning ahead. The library isn't
a dashboard to review; it's the substrate that makes just-in-time recall
possible.

Built in public, with AI assistance (Claude).
