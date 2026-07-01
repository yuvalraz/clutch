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
author: Russell Barkley
title: 30 Essential Ideas 1A — Intro
type: lecture          # lecture | book | article | podcast
source: https://...
resonance: high        # high | med | low — how much it maps to MY condition
```

`resonance` is the "weight" — hand-assigned, not learned. No vector DB yet: a
folder of markdown *is* the database (grep + read reason over it directly).

Raw transcripts stay **local** (they're copyrighted third-party text). What's
public is the tool, the index, and the resonance weights — not the source text.

<!-- ponytail: markdown corpus; add embeddings (sqlite-vec) only when grep+read
     measurably falls short — i.e. when the corpus outgrows a context window. -->

## Ingest a source

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python ingest.py "https://www.youtube.com/watch?v=VIDEO_ID" \
    --author "Russell Barkley" --title "30 Essential Ideas 1A — Intro" --resonance high
```

## The canonical spine (ship one at a time — NOT all at once)

- [x] Barkley — *30 Essential Ideas* 1A: Intro / chronic developmental disability
- [ ] Barkley — *30 Essential Ideas* (rest of the 27-part series, one at a time)
- [ ] Barkley — *ADHD and the Nature of Self-Control* (1997)
- [ ] Barkley — *Executive Functions* (2012)
- [ ] Thomas E. Brown — *Smart but Stuck* (the high-IQ coast-to-collapse pattern)
- [ ] Dodson — interest-based nervous system / RSD
- [ ] Hallowell & Ratey — *ADHD 2.0*
- [ ] Mahan — the Wall of Awful

Built in public, with AI assistance (Claude).
