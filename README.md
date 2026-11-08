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

## How it works

Clutch is five hooks and a set of commands. The hooks fire at fixed moments in
a session, while you can still act, because the effect degrades with distance
from that moment (Barkley). What they say is recognition. Uninvited lines are
capped at two a session; the one ask before a destructive git command and the
session-start question sit outside that cap.

Two layers watch where a stall shows up: your git state, and what you are saying.
When the read is clear, the catch side may step in on its own: one smallest
move, an igniter, the triage question, or a one-line bank of a tangent through
`/clutch:fomo`, which banks only and never reports back. When the shape of the
work has changed and held, it may offer one gear shift, as a single ignorable
line. When the read is unclear, nothing happens. Silence is the default state,
and it is the anti-nag law made visible. A wrong nudge costs more than a missed
one.

The catch may reach first. The spark only answers.
Apart from fomo's silent bank, divergence, the focuses and the upkeep commands
wait until you fire them.

```
 session start --> anchor.sh -------> .clutch/   session clock
 every prompt  --> heartbeat.sh       (writes nothing)
 shell command --> hot-pause.sh       (writes nothing)
               \-> red-moment.sh ---> .clutch/   repeat-red record
 turn end      --> stop.sh ---------> .clutch/   breadcrumb
                           \--------> ~/.clutch/worklog.md
 on a command  --> the skill -------> .clutch/   the pool
                           \--------> ~/.clutch  the brain
```

`.clutch/` is the pool, one per repo. `~/.clutch` is the brain, if you keep
one. `~/.clutch/worklog.md` is the worklog, shared by every repo. The session
clock and the repeat-red record (the hook's record of a repeated red, so a
second identical failure can be told from a first) live in
`.clutch/session-state`.

### When it fires

| When | What fires | What you might see | What it writes |
|------|------------|--------------------|----------------|
| Session start (startup, resume, clear, compact, fork) | `anchor.sh` | This goes to the model, which greets you with it: your thread, last landed commit, captures held, and the smallest move to resume. On a fresh session with no gear set, one question. The model also gets the constitution and the `Worklog:` block. | `.clutch/session-state` on a fresh session |
| Every prompt | `heartbeat.sh` | Nothing. It reminds the model which command fits which stall, how many uninvited lines are left, and the sprint clock. | nothing |
| Before a shell command | `hot-pause.sh` | One ask before a force-push, `reset --hard`, `branch -D`, `checkout -- .` or `clean -fd`. Your yes wins in one keypress. | nothing |
| After a shell command | `red-moment.sh` | Usually nothing. When the same runner command fails again with the tree unchanged, the model may say one line. | `.clutch/session-state` |
| Turn end | `stop.sh` | The bell: `Landed: '<subject>'. Smallest next move: one commit.`, only after 25 minutes and real movement. A live sprint shows `Sprint: N min left on '<goal>'` instead. After a long run with unbanked work, one offer to bank it. | `.clutch/breadcrumb`, and one `moved:` line in `~/.clutch/worklog.md` naming your latest commit, when the turn landed one |
| On a command | the skill you named | What that command does (see Commands at a glance) | Depends on the command: the pool, the brain, `~/.clutch/rituals.md`, your review conventions file, or the auto-memory directory |

### Sessions see each other

Run two sessions at once, or come back after a compaction, and each one learns
what the others did. Every session writes to one shared log,
`~/.clutch/worklog.md`, and reads it at its next start, clear, compaction or
fork, and in an ops sweep. It is not live: a running session sees a peer's line
only at one of those moments.

- Landed commits log themselves: at a turn end that landed one, the turn-end
  hook appends one `moved:` line naming your latest commit and its repo.
- The model adds the rest, silently: a `moved:` line when a loop outside git
  closes, an `on:` line when it starts work a parallel session might take.
- In ops, an action you approve that awaits a reply logs a `wait:` line
  when its ask ends with "(I'll hold this as an open loop)", and so does
  `watch <thing>`. A later `moved:` line that starts with the same ref closes it.
  Open waits show first in the `Worklog:` block and age out after 5 days.
- The next session start shows them in its `Worklog:` block.
  Claims age out after 4 h and moves after 24 h.
  At most eight lines show, and a burst of moves never pushes a claim out.
- The block is context for the model, never a list for you. `/clutch:ops`
  leaves held work out of its sweep, and your explicit ask always wins over a
  claim. `/clutch:status` reports whether the worklog is writable.

### Where state lives

1. **The pool.** A local `.clutch/` folder your repo owns: captures,
   cross-references, spark logs, idea files, the session clock and the
   breadcrumb. Clutch adds it to git's ignore list.
   Pool writes stay repo-scoped by design.
2. **The brain.** Keep a `~/.clutch` folder and it becomes the brain,
   the second pool level every reader sweeps, across all your repos.
   No pool item enters it ambiently: one door up, the absorb verdict in
   `/clutch:fomo`. The idea a work session almost lost feeds a family-project
   spark next week.
3. **The worklog.** `~/.clutch/worklog.md`, one short line per `moved:` note,
   `on:` claim or `wait:` loop, shared by every session in every repo.

The brain is a plain directory. Point it wherever you like, including inside a
git repo you sync yourself. Clutch never moves it for you.

The assistant's own auto-memory directory is a different brain, and it gets
maintenance too. `/clutch:dream` consolidates it and prunes the index, and
`/clutch:interview` asks a short batch of questions about its thin spots.

## Four focuses

A fresh session opens with one question, the only one of the day:
build, ideate, ops, or review? Ignoring it is also an answer, and it never asks twice.
`/clutch:intent` takes the answer and engages the matching gear.

**Build.** A maker session in the craft gear (explore, then commit). The catch
commands are at hand: one smallest move, a sprint, an igniter, a triage, a
retrace.

**Ideate.** `/clutch:ideate` puts the whole session in divergent mode: it loads
the pool, engages ballmer (fast divergence with periodic convergence
checkpoints), and holds anti-convergence until you land it.

**Ops.** `/clutch:ops` puts the session in operations mode for the day that is
meetings, people, and threads rather than a repo: one sweep of the tools you
named, the situation in a few lines, then one loop closed at a time, each
outward step on a yes. Work another session holds stays out of the sweep.
An approved step that awaits a reply is held as a `wait:` loop.
`/clutch:ops tick` checks only those waits, on request, and speaks only when one moved.
It also says so in one line when the waits cannot be read. Entering ops runs
one tick pass as part of the sweep.

**Review.** `/clutch:review` closes one PR at a time with your written
conventions applied. When your call on a finding implies a rule, one line
offers it as a convention, written on a yes. Each post goes out on a yes.

`/clutch:tempo` hands you the gearbox directly: five gears, set or reported.

## You know these moments

- **You open a project cold.** It greets you with the branch, your last landed
  commit, and the one file to pick back up. The re-orientation tax is gone.
- **You say "I don't know where to start."** One smallest next move. Never a
  list.
- **You circle the same two options for three turns without editing anything.**
  It states the move that breaks the loop. Ignorable, no yes required.
- **A test goes red and you reach for `git reset --hard`.** One beat lands in
  the way: the red is a heat spike, and the smaller move is to bank what still
  works before you burn it.
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
claim to fix. Clutch fires on zero movement, never on slowness.
Slow is legal. You are allowed to think.

## Commands at a glance

Twenty commands, same heartbeat, opposite directions. The catch side meets you
when work stops moving. The spark side banks what pulls you and hands it back
as ignition. The rest set the session's focus, run the day, and check on clutch.

| Command | What it does | Use it when |
|---------|--------------|-------------|
| **Catch** | | |
| `/clutch:smallest-move` | Names one move you can finish in one sitting, as an ignorable line | You cannot see where to start |
| `/clutch:sprint` | A fixed 20 minutes on one minimal shippable; deflected ideas bank | You want a timebox |
| `/clutch:ignite` | Recasts work you already understand as a speed-run | You dread the boring plumbing |
| `/clutch:triage` | Asks the one question that separates a wall from forgetting | A task did not happen and you do not know why |
| `/clutch:retrace` | Rebuilds a blurred session from git and the pool | You lost track of what you built |
| **Spark** | | |
| `/clutch:fomo` | Banks a link or a thought in one line; a background pass reads it and returns absorb, park, or release | A tab you cannot close, or an idea mid-task |
| `/clutch:spark` | A chain reaction: one anchor, ping-pong hops, a trace-back at the end | You sit down to explore |
| `/clutch:daydream` | Runs a few associative hops in the background and banks them | A connection whispers while you work |
| `/clutch:dream-spark` | Cross-references everything the pool holds | You want what connects that nobody is watching |
| **Focus and day** | | |
| `/clutch:intent` | Declares the session's focus and engages the gear | The session-start question, or a change of plan |
| `/clutch:ideate` | Divergent mode for the whole session | An ideate session |
| `/clutch:ops` | Operations mode: one sweep, one loop at a time | A day of meetings, people, and threads |
| `/clutch:review` | Review mode: one PR at a time, your conventions applied | A review session |
| `/clutch:tempo` | Sets or reports the gear: espresso, craft, ballmer, freefall, ferment | You want the gearbox itself |
| `/clutch:morning` | Opens the day: focus check, deep ping, one divergent beat, one quick win, the first move | The start of your day |
| `/clutch:eod` | Closes the day: a mini-retro without shame, tomorrow's focuses, one fun slot | The end of your day |
| `/clutch:rituals` | Asks for your day's facts once and writes `~/.clutch/rituals.md` | Before the first morning, or when your days change |
| **Upkeep** | | |
| `/clutch:status` | Reports whether the hooks are alive in this repo and session | Right after install, or when the bell seems silent |
| `/clutch:dream` | Consolidates the auto-memory brain and prunes its index | That brain has grown long or stale |
| `/clutch:interview` | Asks one batch of questions about that brain's thin spots | You want the gaps filled |

Ignite is not spark. Ignite recasts dread as a challenge; spark runs divergence.

The day anchors fire when you fire them, at whatever anchor time your
`~/.clutch/rituals.md` names. Run `/clutch:rituals` again any time to change it.

## The research

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

## Safe on a work repo

Clutch runs in any Claude Code session: a side project, a family project, or a
work repo.

It carries nothing personal. It reads your git state, its own `.clutch/` folder,
your `~/.clutch` brain if you keep one, and the conversation in front of it.
Some commands read more, and only when you fire them: `/clutch:dream` and
`/clutch:interview` read the assistant's auto-memory directory, and
`/clutch:review` reads your conventions file and the PR in front of it.
`/clutch:morning`, `/clutch:eod`, `/clutch:ops` and `/clutch:review` read
`~/.clutch/rituals.md` for your day's facts, integrations and conventions path.
Morning and eod also read the state dir it names and your focus files.

One thing to know before you mix contexts: a brain entry banked at home surfaces in
whatever repo you run these skills in, a work repo included. Whether that is
fine is your call.

It writes the local `.clutch/` folder, plus your brain on an absorb verdict, and
adds the local folder to git's ignore list. Sessions also append one-line notes
of what moved to `~/.clutch/worklog.md`, so parallel sessions can see each
other. That log is not pool stock: it is the one thing sessions write to
`~/.clutch` without a command or a verdict. The log is global: its lines,
commit subjects and repo names included, reach sessions in every repo, a work
repo included. If you keep no `~/.clutch` yet, the first note creates it, and
that folder is the brain: from then on an absorb verdict in `/clutch:fomo`
files ideas into `~/.clutch/ideas/`, which sessions in every repo read,
instead of the repo's `.clutch/ideas/`.

Every other write comes from a command you fire. `/clutch:fomo --brain` banks
straight to the brain. `/clutch:rituals` writes `~/.clutch/rituals.md`.
`/clutch:review` appends a convention to your conventions file on a yes.
`/clutch:dream` and `/clutch:interview` write the auto-memory directory.
`/clutch:morning` writes today's focus file when it is missing, and
`/clutch:eod` writes tomorrow's, in the state dir your `~/.clutch/rituals.md`
names, which can sit outside both `.clutch/` and `~/.clutch`. When a key they
need is unset, morning, eod, ops and review ask for it, and most of the time
offer to save a missing key into `~/.clutch/rituals.md`, on a yes.

Some commands reach out, and only when you invoke them. `/clutch:fomo` fetches
a banked link, and a spark, daydream, dream-spark, or ideate pass may run a web
search. `/clutch:ops` and `/clutch:morning` check the integrations you named.
`/clutch:morning` and `/clutch:eod` run the prep command you set, and the
extra and close-out steps you wrote can use your integrations.
`/clutch:review` reads PRs and posts to one only on a yes. Nothing here
touches the network on its own, and you can verify it:

```
grep -rE 'curl|wget|/dev/tcp|nc ' scripts/
```

That returns nothing.

It is read-mostly and fails open, so it sits underneath whatever else you run.
On a repo with stricter guardrails, the strictest rule wins: the
pause-before-force-push defers to a hard block if your setup has one. It
composes. It does not fight.

## Install

Two commands. Zero configuration.

```
/plugin marketplace add yuvalraz/clutch
/plugin install clutch@clutch
```

No settings, no env vars. The opinions are the product.

One exception, and it is deliberate: one optional file holds your day's facts
and tool names. The core carries opinions; your day carries facts: which days
you work, where your focuses live, what to read first, which integrations ops
checks, where your review conventions live. `/clutch:rituals` asks for them
once and writes `~/.clutch/rituals.md`. Most commands that find a key missing
ask for that one value and offer to save it; say no, and they may ask again.

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
not pretend to read your mind. Fomo never surfaces on its own.

**It is tested two ways.** `tests/` pins the wording and the hook behavior in
plain sh. `evals/` checks the routing itself: each case runs once with clutch
and once without, and the score is the difference. A stall that gets one move
with clutch and a numbered plan without it is the whole point, measured.
`claude plugin eval .` runs it.

Built in public, with AI assistance. It runs in my own development sessions, so
if it breaks, I am the first it bites. That is the warranty.
