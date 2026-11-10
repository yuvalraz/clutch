---
name: ops
description: Put the session in operations mode. Engage espresso, sweep the reachable integrations once for the live situation, then close loops one at a time with the day's focuses in view.
when_to_use: Use ONLY when the user explicitly asks for operations mode ("ops", "operations mode", "run the day", "re-sweep", "tick") or when /clutch:intent hands off after an "ops" answer. A passing mention of meetings, people, or tasks mid-conversation is not a trigger.
argument-hint: "[re-sweep|tick]"
---

# Ops

Ops sets the MODE for the whole session: the day's operations, not a build.
Meetings, people, threads, tickets, the small loops that hold a company
together. The work here is many short convergences rather than one long one,
and the terrain is whatever tools your day lives in, never a single repo.

Ops fires when you fire it. Nothing here runs on its own.

## Usage

- `/clutch:ops` enters operations mode: engage the gear, sweep once, name
  the situation, end on one loop to close.
- `/clutch:ops re-sweep` runs a fresh sweep mid-day with the same bounds and
  the same close. A re-sweep happens on request only, never on your own read
  that the situation may have moved.
- `/clutch:ops tick` checks only the wait loops, once each, and speaks only
  when one moved. "Anything move?" in an ops session is the same request.
  A tick happens on request only, never on your own read that a loop moved.
  A tick skips Steps 0-4: no gear, no config read, no sweep.
  The Tick section governs the rest, including each moved loop's one
  smallest move.

## Procedure

### Step 0: Engage the gear

Confirm in one line: "Espresso engaged: tight convergence, one divergent
pulse, checkpoint at each closed loop." Then write the marker (POSIX, silent
on any failure):

```sh
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
mkdir -p "$ROOT/.clutch" 2>/dev/null || exit 0
printf '%s\n' "espresso" 2>/dev/null > "$ROOT/.clutch/tempo" || exit 0
```

This is the existing tempo mechanism; the heartbeat carries the gear to the
model next turn, no new state. If the write fails, the declaration still
governs the live session; only the re-injection is lost.

Hopping between loops is the gait in this gear, not a shape mismatch. The
dispatch spine's gear-shift row reads a sustained change in the shape of the
work; the ops rhythm of close, next, close is the shape holding.

### Step 1: Load the config

Read `~/.clutch/rituals.md`. If it is missing: the sweep has no tools to
stand on yet. Say exactly that in one line and hand off to `/clutch:rituals`.
Never scaffold a default config silently; a config the user never wrote is a
config they will not trust.

If the file exists but a key this mode needs is unset, name the gap and ask
for that one value inline, then offer to persist the answer into
`~/.clutch/rituals.md` so it is asked only once. A missing file hands off; a
single missing key does not.

If a state dir is configured but missing on disk, say so and
offer to continue without state.

The tools come from the `integrations:` bullets under Shared, the same ones
the morning and close-of-day anchors read. Today's focuses come from the
focus file when one is set. Ops reads two optional sections of its own,
`### Delegation` and `### Windows` (see Delegation).
Neither is a missing key: never ask for them.

### Step 2: The sweep

This is the one divergent pulse of the gear. For each configured
integration, check it only if it is reachable. If a tool is named but
unavailable, say so and skip it; never stall the sweep on a tool that is not
there.

Read for what is live: the meetings on today's calendar, the threads waiting
on you, the tasks assigned to you, anything a person is waiting on. Read
today's focuses from the focus file when one is set.
For each Auto line, also read your own items it covers (for example your open PRs).

Bounds (HARD):

- The sweep reads; it never writes to any integration; L2 actions and Auto posts run after the reads (see Delegation).
- Today's horizon only: nothing past the next workday.
- It reads each reachable tool once and ends. It never polls, never loops,
  never watches anything in the background.
- No counts: not how many sit unread, not how many wait, not how long
  anything has waited.

Read the worklog window in the same pulse, once;
the tick pass reads the wait loops with its own line (see Tick):

```sh
sh -c '. "${CLAUDE_PLUGIN_ROOT}/scripts/prelude.sh" && clutch_worklog_window'
```

Each line is a session's, maybe this one's from before a compaction or
clear. A live `on:` line is a loop a session holds; a `moved:` line is one
already closed. Leave both out of the situation and never propose them
uninvited; the user's explicit ask wins over any claim. Empty output
means no peer context, and the sweep goes on. A
`/scripts/prelude.sh` not-found error means clutch is not loaded as a plugin: say so once and go on.

A `wait:` line is a wait loop: someone else's move, pending on something
you did; leave it out of the situation unless the tick finds it moved.
Run one tick pass (see Tick) before the situation, and fold each loop that
moved into the situation as what moved, instead of its own line.
A loop that did not move stays unmentioned. The tick pass is part of this
pulse: one read of the wait loops, then it reads each wait loop once, by its kind.

Check the day brief once, after the tick pass:

```sh
sh -c '. "${CLAUDE_PLUGIN_ROOT}/scripts/prelude.sh" && clutch_ops_due brief'
```

`due` means this is the first sweep today: read `## Critical path` from the focus file and speak the situation as the day brief (Step 3).
Empty output, an error, a missing focus file or no critical path: the situation as usual, with nothing said about a brief.

Then classify what the sweep read (see Delegation).

### Step 3: The situation

Speak the situation in a few lines, present tense, co-working voice. Group
by the next thing that can happen, never by tool. Name a waiting thread by
what it needs now, never as overdue, late, or missed.

The situation is at most seven lines. It is a read of now, not a dashboard
and not a report for later. Nothing from the sweep is written anywhere
except the tick pass's `moved:` lines and the L2 and Auto lines (see Delegation); the rest
lives in the turn, and a fresh sweep replaces it.
The day brief, when due: for each delivery under `## Critical path`, its move (the first step neither done nor blocked), each blocked step with who it waits on, and today's meetings or wait loops that touch a step.
It fits the seven lines, names steps instead of counting them, and never calls anything late.
After the situation, check the approval window (see Delegation).

### Step 4: One smallest move

End on one loop that closes in one sitting: a reply sent, a meeting accepted
or moved, a ticket updated, a decision handed to the person waiting for it.
State it as a recognition line, fully ignorable, no yes required. A different
loop the user names becomes the move; a choice menu never does.

### Step 5: Session guardrails

For the rest of the session these rules are HARD and override default
behavior:

- **One loop at a time.** Close it, checkpoint in one line naming what moved,
  then the next. A checkpoint is the closed loop itself, never a summary.
  Never two loops open at once. A wait loop is someone else's move, not the
  loop you are working, so it never counts against one loop at a time.
  Wait loops are never listed or counted, at the close or anywhere.
- **Outward-facing actions keep a human checkpoint.** Sending a message,
  accepting or moving a meeting, changing a ticket's state, anything another
  person will see: draft it, show it, send on a yes. Reading is free.
  An L2 action or Auto post your delegation policy lists is the one exception (see Delegation).
  L3 is untouchable: a production change, a direct send, a merge or a delete always waits for a yes, whatever the policy says.
- **An outward action that awaits a reply or a state change becomes a wait
  loop.** Its yes ask ends with "(I'll hold this as an open loop)". On the
  yes, once the action succeeds, append its `wait:` line with the snippet
  below, silently,
  instead of its `moved:` line; speak on MISS or an error.
  "don't hold it" or "send, don't watch" sends with no line. "watch <thing>"
  holds a loop with no action: read its baseline now, then append.
  A failed action holds nothing.

  ```sh
  mkdir -p "$HOME/.clutch" 2>/dev/null && printf '%s %s wait: %s %s %.200s\n' "$(date +%s)" "$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" | tr ' ' -)" '<kind>:<ref>' '<baseline>' '<text>' >> "$HOME/.clutch/worklog.md" || echo MISS
  ```

  `<kind>` is one of slack, gh, linear, gmail, ld, dd; `<kind>:<ref>` and
  `<baseline>` are one token each, no spaces; `<text>` names what you are
  waiting for. Escape ' as '\''. The ref and baseline per kind:
  - slack: ref `slack:<channel>/<thread ts>`; baseline, the sent message ts.
  - gh: ref `gh:<owner>/<repo>#<number>`; baseline, the PR `updatedAt`.
  - linear: ref `linear:<issue id>`; baseline, the issue `updatedAt`.
  - gmail: ref `gmail:<thread id>`; baseline, the thread's last message id.
  - ld: ref `ld:<flag key>`; baseline, the flag version.
  - dd: ref `dd:<monitor id>`; baseline, the monitor state.
- **Interruptions are the gait.** A new ping mid-loop gets one line, bank it
  or close it now, then back to the open loop.
- **A tangent banks.** An idea that pulls sideways goes to `/clutch:fomo` in
  one line, bank only, then return.
- **A loop that turns into a build leaves ops.** Code, a design, a document
  longer than a reply: name it, bank it as a focus or an idea, and stay in
  ops. Building it is a fresh session declared with `/clutch:intent build`.
- **No counts, no overdue framing, no backlog totals.** The sweep names what
  needs a move now; the rest stays where it is, unmentioned.
- **A loop that keeps not closing** gets `/clutch:triage`'s question, a
  flinch at the wall versus never entering awareness, before anything else
  engages. **A loop that wants a clock** gets `/clutch:sprint`.
- **Re-sweep on request only.** `/clutch:ops re-sweep` is the only path to a
  second sweep.
- **A closed loop logs one line.** Append its `moved:` line with the
  constitution's worklog snippet, silently; speak on MISS or an error.
  That line is the only thing a closed loop writes; the sweep itself still writes nothing beyond its L2 and Auto lines.
  A tick's `moved:` line, the sweep's tick pass included, is the closed loop's one line.

### Tick

A tick reads only the wait loops, once each, and writes only their `moved:` lines.
It runs on `/clutch:ops tick`, on "anything move?" in an ops session, and
as the sweep's tick pass. Read the wait loops with this line, once:

```sh
sh -c '. "${CLAUDE_PLUGIN_ROOT}/scripts/prelude.sh" && L=$(clutch_open_loops) || exit; [ -z "$L" ] || printf "%s\n" "$L" | LC_ALL=C cut -c1-300'
```

Each line is `<epoch> <repo> wait: <kind>:<ref> <baseline> <text>`, oldest
first, cut to 300 bytes. Empty output, or exit status 1 with no error
text (no worklog): no wait loops; say nothing about loops.
Any other exit status means the wait loops are unreadable: say so in one line, never that nothing moved.
Exit status 1 with error text on stderr means the same: the wait loops are unreadable.
A `/scripts/prelude.sh` not-found error means clutch is not loaded as a
plugin: say so once and go on.

Read each wait loop once, by its kind, against its baseline:

- slack: replies in the thread newer than the baseline ts, from someone
  other than the user.
- gh: `gh pr view <number> --repo <owner>/<repo> --json state,reviewDecision,updatedAt`;
  a changed state or review decision, or `updatedAt` newer than the baseline.
- linear: `updatedAt` newer than the baseline, or a new comment.
- gmail: a message in the thread newer than the baseline id.
- ld: a flag version other than the baseline.
- dd: a monitor state other than the baseline.

A loop that moved: append its `moved:` line first (record, then speak),
with the constitution's worklog snippet, verb `moved:` and text
`<kind>:<ref> <what moved>`. Copy the ref exactly from its `wait:` line,
as its own token followed by a space, with no comma or colon after it.
Then speak one line naming at most two movements and one smallest move.
When nothing moved, a tick prints nothing.
A tool that is not reachable gets one line naming it, and that loop stays open.
A tick never re-arms a loop, never names one that did not move, and never says how long anything has waited.
In the sweep's tick pass, moved loops fold into the situation instead of their own lines.

### Delegation

A delegation policy lets ops do the chores you allowed, draft the rest, and
show only what touches your critical path. It lives in two optional sections
of `~/.clutch/rituals.md`: `### Delegation`, one `- <level>: <what it covers>`
line each, and `### Windows`, the approval window times (see `/clutch:rituals`).
With no `### Delegation` section, nothing here applies and every outward action waits for a yes.

Classify every inbound item the sweep reads against the policy:

- L3: the yes gate, exactly as in Step 5.
- L2: do it without a yes, then append one `moved:` line with the
  constitution's worklog snippet, verb `moved:`, text `L2: <what was done>`,
  and name it once as what moved.
- Auto: post into a channel the policy names as automated, an intake queue
  a process reads, exactly as its policy line describes, without a yes;
  then append one `moved:` line the same way, text `Auto: <what was posted where>`, and name it once as what moved.
  An Auto post of an item that awaits a review or a reply is also held as a wait loop, with the Step 5 snippet.
- L1: draft it. A draft that touches the critical path shows now;
  any other draft waits for the next approval window, unmentioned until then.
- L0: one line, only when it touches the critical path.
- Noise: never shown.

The critical path is the focus file's `## Critical path` steps, or today's focuses when it has none.
With no focuses set, each L0 item shows as one line instead of being hidden.
An L1 item whose deadline falls before the next approval window touches the critical path, so its draft shows now.
Anything the policy does not name is L3.
When an item matches two levels, the stricter one wins, in this order: L3, L1, L0, Noise, Auto/L2.
An item runs at L2 or Auto only when that level is its only match.
An item that matches both Auto and L2 is L3.
A direct send is any message, email, channel post, thread reply or comment a person receives, except an Auto post as its policy line describes; no policy line makes one L2.
An @-mention in an Auto post makes it a direct send, so L3, unless its policy line names the person mentioned.
A channel the policy does not name stays L3.
Auto posts only to a channel whose name matches the policy line exactly and resolves to one channel; a near match, more than one match, no match or a DM is L3, named in one line.
The sweep reads each Auto channel the policy names once, looking back 5 days, for the item's link in any message there whoever posted it, and never posts an item already there nor proposes a direct ask for one.
An open `wait:` line or a `moved: Auto:` line for the same item also blocks a new post.
An Auto channel read that fails or cannot be read holds every item it covers at L3, named in one line.
An L2 action or Auto post that rests on a link or a state, such as a ticket linked to a PR you authored, reads it first and acts only when it holds.
A state the line names that ops cannot confirm (for example ready while checks are pending, failing or unreadable, or a draft PR) holds the item at L3.
A failed L2 action or Auto post gets one line naming it; it logs nothing and is not retried.
L2 actions and Auto posts run after the sweep's reads end, never inside them.

Check the approval window once per sweep, after the situation:

```sh
sh -c '. "${CLAUDE_PLUGIN_ROOT}/scripts/prelude.sh" && clutch_ops_due window'
```

`due` means a window time has passed since the last window (`### Windows`,
default 11:00 and 16:30). Draft every L1 item that does not touch the
critical path, from the sweep's fresh read, and show the drafts in one
screen, numbered, approved with one yes or "all but N".
Empty output or an error: no window is due; say nothing about drafts.
A due window with nothing to draft says nothing either.
No draft is kept between windows: each window reads fresh, so there is no pending list.
In the sweep, the window screen follows the situation, and approving it is the one smallest move.
A tick never runs the window.
An approved window draft that awaits a reply or a state change is held as a wait loop, as in Step 5.

### Session close

`/clutch:eod` owns the day's close: the retro, tomorrow's focuses, the fun
slot. Ops ends by naming the loops that closed this session, one line each,
and the one open loop with its next move. Nothing else is written.

## Skill interactions

| Skill | In ops mode |
|-------|-------------|
| `/clutch:morning` | opens the day; ops runs the day it opened |
| `/clutch:eod` | closes the day; ops hands off there |
| `/clutch:fomo <content>` | a tangent, banked in one line, then back to the loop |
| `/clutch:triage` | a loop that keeps not closing: wall or inattention |
| `/clutch:sprint <goal>` | a fixed 20 minutes on one loop |
| `/clutch:intent build` | a loop that became a build: a fresh session |

## What this skill does NOT do

- Fire on its own, re-sweep on its own, or watch anything in the background
- Send anything without a yes, or write to any integration without one beyond the L2 actions and Auto posts your policy lists
- Produce a dashboard, a report, or a list for later
- Count unread, waiting, overdue, or missed anything
- Write code or design anything: that is a build session
- Scaffold config, guess paths, or invent integrations

Why this works: see "Tempo / the gearbox", "Intent", and "Point of
performance" in [GLOSSARY.md](../../GLOSSARY.md). The gear is engaged by
invitation, the sweep is one pulse that ends, and every loop closes at the
moment the user can act on it.
