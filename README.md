# clutch

*The coupling between intention and action.*

Clutch is a Claude Code plugin that catches you at the moment a task stalls and
hands back the next small move.

ADHD is a performance disorder, not a knowledge one. The gap is execution at the
point of performance, the moment you actually have to act. Most productivity
tools work on knowledge: a better planner, another app, one more system to
remember. Clutch works on performance. It moves the intervention into the moment
you are at the machine, in your editor, where it can act on you whether or not
your attention showed up.

It is a transmission. It gets your existing intent to the wheels.

## What it does on a normal day

Every mechanism fires at the point of performance, while you are working and
could act, because the effect degrades with distance from that moment (Barkley).
It speaks at most twice a session, and what it says is recognition. Thirteen
mechanisms ship. Here are eight of the moments they catch.

- **You open a project cold.** It greets you with the branch, your last landed
  commit, and the one file to pick back up. The re-orientation tax is gone.
- **You circle the same two options for three turns without editing anything.**
  It states one move that breaks the loop. Ignorable, no yes required.
- **You say "I don't know where to start."** It hands back exactly one smallest
  next move. Never a list.
- **You dread the boring plumbing.** It reframes the task as something you can
  speed-run.
- **A test goes red and you reach for `git reset --hard`.** It puts one beat in
  the way: the red is a heat spike, and the smaller move is to bank what still
  works before you burn it.
- **You have been heads-down two hours with nothing committed.** It offers,
  once, to bank the work. Ignoring the offer is also a move.
- **You look up after a fast session and cannot tell what you built.**
  `/clutch:retrace` walks it back from git, not memory: what landed, what is in
  flight, what to be aware of, and one move to regain control.
- **A test fails, you change nothing, and run it again.** On the second
  identical red with no edit between, it puts one line in front of you: the red
  is the first half of the loop, not a verdict, and the smaller move is to make
  just the one failing thing pass. It never counts the failures out loud.

It never counts days, never mentions a streak, never shames. The anti-nag stance
is a mechanism. A nag lays a brick that raises tomorrow's wall (Mahan, the Wall
of Awful), and streak-shaming apps manufacture the failure they claim to fix.
Clutch fires on zero movement, never on slowness. Slow is legal. You are allowed
to think.

## It engages itself now

Older versions were a manual transmission. The mechanisms were all there, but you
had to remember to reach for them, and remembering is the exact part that is
broken.

v1.3 is automatic. It reads the session and engages the right mechanism itself,
and it stays silent when it is not sure. The silence is the design. A wrong nudge
is worse than no nudge, so when the read is ambiguous it says nothing.

## Install

Two commands inside Claude Code:

```
/plugin marketplace add yuvalraz/clutch
/plugin install clutch@clutch
```

No settings, no env vars, no modes. Zero configuration. The opinions are the
product.

## Where it runs

Clutch is a Claude Code plugin, so it runs in any Claude Code session: a personal
side project, a family project, or a work repo.

It carries nothing personal and reads nothing but your git state and the
conversation in front of it. It writes a local `.clutch/` folder and adds that
folder to git's ignore list. Nothing leaves your machine, and you can verify
that: no script in it makes a network call
(`grep -rE 'curl|wget|/dev/tcp|nc ' scripts/` returns nothing).

It is read-mostly and fails open, so it sits underneath whatever else you run. On
a repo with stricter guardrails, the strictest rule wins: Clutch's
pause-before-force-push defers to a hard block if your setup has one. It
composes. It does not fight.

## Who it's for

The smart-but-stuck profile Brown calls coast-to-collapse. Intelligence masks the
deficit until the wall, and makes the crash more shame-laden, because "you're so
smart" was the standing explanation the whole way down. If launching is easy and
finishing is where your projects die, it is aimed at you.

## The canon underneath

The wording carries seven digested sources of ADHD research (Barkley, Brown,
Dodson, Mahan, Hallowell), weighted and annotated. Nothing reads the corpus at
runtime: the judgment is baked into the mechanisms as fixed wording and
constants.

- [GLOSSARY.md](GLOSSARY.md): every private term this repo leans on, defined and
  attributed.
- [ANNOTATIONS.md](ANNOTATIONS.md): the editorial layer over the canon. What to
  trust, what to quarantine, how the claims connect.

**Why the library looks empty.** `sources/` carries no text on GitHub. The
transcripts and book texts are third-party copyrighted material and stay local by
design. What is public is the editorial layer (the resonance weights,
ANNOTATIONS, GLOSSARY) and the harness built on it. The authoring scaffold is
documented in [tools/ingest/](tools/ingest/README.md); it is not part of the
plugin.

**How it was built.** One source, one clean file, one commit, in public. Never
"ingest everything, ship when done." If the tool meant to help me finish things
could not finish itself, it would not work. This repo was its first test. Plain
markdown, one file per source in `sources/`, hand-assigned resonance weight, no
vector DB.

<!-- ponytail: markdown corpus; add embeddings (sqlite-vec) only when grep+read
     measurably falls short, i.e. when the corpus outgrows a context window. -->

The seven that cleared the bar, plus the one I dropped and why:

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

**Is this abandoned?** Finished is a deliberate state for an opinionated tool. No
news is stability. The version bumps for exactly three reasons: new research
clears the bar, wording fails in the wild, or the plugin API drifts.

**Some things stay manual on purpose.** When a task did not happen, it asks
whether you flinched or forgot, because guessing wrong there does harm. It will
not pretend to read your mind.

Built in public, with AI assistance (Claude). I have ADHD and built this by making
it ship itself one commit at a time. It runs in my own development sessions, so if
it breaks, I am the first it bites. That is the warranty.
