# clutch

*The coupling between intention and action.*

Not a gift. Not a deficit. A different transmission.

Clutch is a Claude Code plugin. It catches the stall the moment it happens and
hands you one small move. It banks the idea that pulled you away and turns it
into fuel for later sessions. Both halves are built on the ADHD research, not
productivity folklore.

ADHD is a performance disorder, not a knowledge one. You already know the next
step. The gap opens at the point of performance, the moment you have to act.
Most productivity tools work on knowledge: a better planner, another app, one
more system to remember. Clutch works on performance, in your editor, whether or
not your attention showed up.

It gets your existing intent to the wheels.

## You know these moments

Twenty-one mechanisms ship. Each fires while you can still act, because the
effect degrades with distance from that moment (Barkley). What it says is
recognition, and it says it at most twice a session.

- **You open a project cold.** It greets you with the branch, your last landed
  commit, and the one file to pick back up. The re-orientation tax is gone.
- **A fresh session opens, nothing declared.** The greeting ends with one
  question, the only one of the day: build or ideate? Ignoring it is also an
  answer, and it never asks twice.
- **You say "I don't know where to start."** One smallest next move. Never a
  list.
- **You circle the same two options for three turns without editing anything.**
  It states the move that breaks the loop. Ignorable, no yes required.
- **You dread the boring plumbing.** It recasts the task as something you can
  speed-run.
- **A test goes red and you reach for `git reset --hard`.** One beat lands in
  the way: the red is a heat spike, and the smaller move is to bank what still
  works before you burn it.
- **A test fails, you change nothing, and run it again.** On the second
  identical red with no edit between, the red is the first half of the loop,
  not a verdict. Make the one failing thing pass. It never counts failures out
  loud.
- **You have been heads-down two hours with nothing committed.** It offers,
  once, to bank the work. Ignoring the offer is also a move.
- **You look up after a fast session and cannot tell what you built.**
  `/clutch:retrace` walks it back from git and the capture pool, not memory:
  what landed, what is in flight, what pulled at you, and one move to regain
  control.
- **An idea yanks you sideways mid-task.** `/clutch:fomo` banks it in one
  line and you are back, nothing lost, while a background pass reads it.
  A sprint's deflected ideas bank through the same door.
  When you sit down to explore, the banked lines are the anchors,
  and a retrace hands back the ones from its window.

It never counts days, never mentions a streak, never shames. The anti-nag stance
is a mechanism. A nag lays a brick that raises tomorrow's wall
(Mahan, the Wall of Awful), and streak-shaming apps manufacture the failure they
claim to fix. Clutch fires on zero movement, never on slowness. Slow is legal.
You are allowed to think.

## Same heartbeat, opposite directions

Half of it catches you when work stops moving. Half of it banks what pulls you
and hands it back as ignition. Thirteen commands, split by direction, and one
lever over both: `/clutch:intent` declares whether this is a build session or an
ideate one, and engages the matching gear.

**The catch, the pain side.** `/clutch:smallest-move` names one move you can
finish in one sitting. `/clutch:sprint` puts a fixed 20 minutes on one shippable
and banks whatever the sprint deflects. `/clutch:ignite` frames work you already
understand as a speed-run. `/clutch:triage` asks the one question that separates
a wall from forgetting. `/clutch:retrace` rebuilds a blurred session from git.
`/clutch:tempo` hands you the gearbox. `/clutch:status` reports whether the
hooks are alive.

**The spark, the bliss side.** `/clutch:fomo` takes the tab you cannot close or
the leap you cannot chase, banks it in one line, and sends a background pass to
read it, cross-reference the pool, and hand back a verdict: absorb, park, or
release. `/clutch:spark` runs a
chain reaction: one anchor, ping-pong hops, a trace-back at the end so the
wandering banks. `/clutch:daydream` takes a whispered connection and runs a few
hops in the background while you keep working. `/clutch:dream-spark`
cross-references everything the pool holds. `/clutch:ideate` puts the whole
session in divergent mode and holds anti-convergence until you land it.

Ignite is not spark. Ignite recasts dread as a challenge; spark runs divergence.

## The catch may reach first. The spark only answers.

Two layers watch where a stall shows up: your git state, and what you are
saying. When the read is clear, the right mechanism is already there. When it is
unclear, nothing happens.

Silence is the default state, and it is the anti-nag law made visible. A wrong
nudge costs more than a missed one. Two mechanisms stay on manual for the same
reason: triage asks before it guesses, and fomo never surfaces on its own.
The spark side goes further. None of it fires uninvited. Divergence is always
invited.

## Your repo grows a memory

Mid-task, an idea yanks you sideways. One line banks it and you are back,
nothing lost, no tab graveyard. When you sit down to explore, those banked lines
are the anchors: the idea that almost derailed Tuesday becomes Friday's spark
session.

1. **One door, one intake.** `/clutch:fomo` takes the mid-task leap and the tab
   from outside alike, banks the line, and hands you straight back. The split
   by source was always thin; both land in the same file.
2. **It absorbs itself.** The same `/clutch:fomo` sends a background pass that
   reads the thing, cross-references the pool, and returns a verdict — absorb,
   park, or release — plus the one thing worth knowing. Nothing waits on you
   remembering to process a backlog.
3. **The pool holds it.** A local `.clutch/` folder your repo owns:
   cross-references, spark logs, idea files. Writes stay repo-scoped by design.
4. **The brain compounds it.**
   Keep a `~/.clutch` folder and it becomes the brain,
   the second pool level every reader sweeps, across all your repos.
   Nothing enters it ambiently: one door up, the absorb verdict in
   `/clutch:fomo`. The idea a work session almost lost feeds a family-project
   spark next week.
5. **You come back to riff.** `/clutch:spark` and `/clutch:ideate` draw from
   that same pool.

The brain is a plain directory. Point it wherever you like, including inside a
git repo you sync yourself. Clutch never moves it for you.

## The other brain gets maintenance

Two more moves work the assistant's own memory directory — the auto-memory
brain your harness loads every session — not the pool:

- `/clutch:dream` reads that whole brain and hands back a consolidation
  report: what proved out, what went stale, what sits orphaned, what to merge.
  You pick what applies; a pruning pass always runs, and the index leaves
  shorter than it arrived.
- `/clutch:interview` reads the same brain for thin spots and asks a handful
  of concrete questions in one batch. Answers land as memories stamped
  human-confirmed. Ignoring a question is a legal answer.

Both fire only when you fire them.

## Seven sources, a citations file, a quarantine list

The wording carries seven digested sources of ADHD research: Barkley, Brown,
Dodson, Mahan, Hallowell. Each has a hand-assigned weight and an annotated place
in the argument. Nothing reads the corpus at runtime. The judgment is baked into
fixed wording and constants.

- [GLOSSARY.md](GLOSSARY.md): every private term this repo leans on, defined and
  attributed.
- [ANNOTATIONS.md](ANNOTATIONS.md): the editorial layer. What to trust, what is
  quarantined, how the claims connect.

The quarantine list is the part most tools skip. Ego depletion, the idea that
willpower is a fuel tank you refill with glucose and breaks, is in the canon and
kept out of the product. It is a replication-crisis casualty, and a fuel model
inside a performance frame contradicts both Barkley and this tool.

The seven that cleared the bar, plus the one dropped and why:

| Source | Resonance | Status |
|--------|-----------|--------|
| Barkley, *30 Essential Ideas You Should Know about ADHD* (27-part lecture, one digest) | high | done |
| Thomas E. Brown, *Emotions and Motivation in ADHD* (CHADD lecture) | high | done |
| Hallowell & Ratey, *ADHD 2.0* webinar | med | done |
| Barkley, *ADHD and the Nature of Self-Control* (1997 book) | n/a | dropped: no e-book edition exists; its model matured into *Executive Functions* (2012), already digested |
| Barkley, *Executive Functions* (2012 book, Guilford DRM-free ePub) | high | done |
| Thomas E. Brown, *Smart but Stuck* (Burnett Seminar lecture, 2014: the high-IQ coast-to-collapse pattern) | high | done: the lecture stands in for the book, which has no DRM-free edition |
| Dodson, *Defining Features of ADHD* (ADDitude lecture: interest-based nervous system, RSD, hyperarousal) | high | done |
| Mahan, *the Wall of Awful* (StudyPro "Unlocking ADHD" webinar) | high | done |

**Why the library looks empty.** `sources/` carries no text on GitHub. The
transcripts and book texts are third-party copyrighted material and stay local
by design. What is public is the editorial layer and the harness built on it.

## Install it on a work repo without a second thought

Clutch runs in any Claude Code session: a side project, a family project, or a
work repo.

It carries nothing personal. It reads your git state, its own `.clutch/` folder,
your `~/.clutch` brain if you keep one, and the conversation in front of it. One
thing to know before you mix contexts: a brain entry banked at home surfaces in
whatever repo you run these skills in, a work repo included. Whether that is
fine is your call.

It writes the local `.clutch/` folder, plus your brain on an absorb verdict, and
adds the local folder to git's ignore list. The divergent skills can reach out
(`/clutch:fomo` fetches a banked link, and a spark, daydream, dream-spark, or
ideate pass may run a web search) but only when you invoke them. Nothing here
touches the network on its own, and you can verify it:

```
grep -rE 'curl|wget|/dev/tcp|nc ' scripts/
```

That returns nothing.

It is read-mostly and fails open, so it sits underneath whatever else you run.
On a repo with stricter guardrails, the strictest rule wins: the
pause-before-force-push defers to a hard block if your setup has one. It
composes. It does not fight.

## Two commands. Zero configuration.

```
/plugin marketplace add yuvalraz/clutch
/plugin install clutch@clutch
```

No settings, no env vars, no modes. The opinions are the product.

One exception, and it is deliberate: the two day anchors below. The core
carries opinions; your day carries facts — which days you work, where your
focuses live, what to read first. `/clutch:rituals` asks for them once and
writes `~/.clutch/rituals.md`. Everything else stays zero-config.

## Two anchors for the day

`/clutch:morning` opens the day: a focus check, a deep ping over what changed,
one divergent beat from the pool, one quick win, then the single first move on
focus #1. `/clutch:eod` closes it: a mini-retro that names what moved without
shame, tomorrow's focuses set before you stop, and one banked item explored
for fun. Both are user-fired anchors — they fire when you fire them, at
whatever anchor time your config names. Set up once with `/clutch:rituals`,
which asks for your day's facts in one batch and writes `~/.clutch/rituals.md`;
run it again any time to change them.

## Who it's for

The smart-but-stuck profile Brown calls coast-to-collapse. Intelligence masks
the deficit until the wall, and makes the crash more shame-laden, because
"you're so smart" was the standing explanation the whole way down. If launching
is easy and finishing is where your projects die, it is aimed at you.

## How it was built

One source, one clean file, one commit, in public. Never "ingest everything,
ship when done." If the tool meant to help me finish things could not finish
itself, it would not work. This repo was its first test. Plain markdown, one
file per source, hand-assigned resonance weight, no vector DB.

<!-- ponytail: markdown corpus; add embeddings (sqlite-vec) only when grep+read
     measurably falls short, i.e. when the corpus outgrows a context window. -->

**Is this abandoned?** Finished is a deliberate state for an opinionated tool.
No news is stability. The version bumps for exactly three reasons: new research
clears the bar, wording fails in the wild, or the plugin API drifts.

**Some things stay manual on purpose.** When a task did not happen, it asks
whether you flinched or forgot, because guessing wrong there does harm. It will
not pretend to read your mind.

Built in public, with AI assistance. It runs in my own development sessions, so
if it breaks, I am the first it bites. That is the warranty.
