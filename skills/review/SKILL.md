---
name: review
description: Put the session in review mode. Engage espresso, load your review conventions, then close one PR at a time, offering a new convention the moment a call implies one.
when_to_use: Use ONLY when the user explicitly asks for review mode ("review mode", "clutch review") or when /clutch:intent hands off after a "review" answer. A passing "review this" mid-session is not a trigger, and a request to review a named PR outside review mode is not a trigger.
argument-hint: "[PR]"
---

# Review

Review sets the MODE for the whole session: pull requests, read and closed
one at a time, with your written conventions applied to each. The work here
is many short convergences, and each call you make on a finding can teach
the conventions one more rule.

Review fires when you fire it. Nothing here runs on its own.

## Usage

- `/clutch:review` enters review mode: engage the gear, load the
  conventions, then ask which PR comes first.
- `/clutch:review <PR>` does the same and opens that PR first.

## Procedure

### Step 0: Engage the gear

Confirm in one line: "Espresso engaged: tight convergence, one blast-radius
read per PR, checkpoint at each closed PR." Then write the marker (POSIX,
silent on any failure):

```sh
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
mkdir -p "$ROOT/.clutch" 2>/dev/null || exit 0
printf '%s\n' "espresso" 2>/dev/null > "$ROOT/.clutch/tempo" || exit 0
```

This is the existing tempo mechanism; the heartbeat carries the gear to the
model next turn, no new state. If the write fails, the declaration still
governs the live session; only the re-injection is lost.

Moving from one PR to the next is the gait in this gear, not a shape mismatch.
The dispatch spine's gear-shift row reads a sustained change in the shape of
the work; the review rhythm of close, next, close is the shape holding.

### Step 1: Load the config

Read `~/.clutch/rituals.md`. If it is missing: review has no conventions
file to stand on yet. Say exactly that in one line and hand off to
`/clutch:rituals`. Never scaffold a default config silently; a config the
user never wrote is a config they will not trust.

The one key this mode needs is the `review-conventions:` bullet under
Shared: the path to your conventions file. A leading `~` resolves to the
home directory. If the file exists but that key is unset, name the gap and
ask for the path inline, then offer to persist the answer into
`~/.clutch/rituals.md` so it is asked only once. A missing file hands off; a
single missing key does not.

### Step 2: Load the conventions

Read the conventions file before the first PR, once, so every finding can
stand on it. If the file is missing on disk, name the missing file and
offer to create it on a yes, with the `## Conventions` heading and nothing
else. Never create the conventions file silently. On anything other than a
yes, continue without conventions; the session still reviews, it just has
nothing written to cite yet.

### Step 3: The PR loop

If no PR was named, ask which PR to open first, in one line. Then, for that
PR:

1. Read the diff and its description. If `gh` is unreachable, say so and
   ask for the diff another way: a pasted diff, a branch name, a patch file.
2. Make one blast-radius read: what the change touches beyond its own
   lines, the callers, the data, the people who will see it. That read is
   the one divergent pulse of the gear for this PR; it ends.
3. Speak the findings, present tense, each tied to a line of the diff. A
   finding a written convention covers cites the convention it rests on.
4. Draft the review comments, show them, post on a yes. Reading is free.
5. When the PR closes (posted, approved, or set aside by the user),
   checkpoint in one line naming what moved, then ask which PR comes next.

### Step 4: Harvest

When the user's call on a finding implies a rule the conventions do not hold
yet, offer it at that moment as exactly one proposal line: the rule and its reason in one line.
The line states the candidate convention; it is a recognition line, not a
question, and ignoring it writes nothing to the conventions file.

Write nothing before the answer; append it on a yes, at the end of the
`## Conventions` section, in this format, and confirm in one line naming the file:

```markdown
## Conventions
- <rule, imperative, one line>. Why: <the reason the user gave or accepted>.
```

When the heading is absent, create it at the end of the file, then add the
bullet under it. The harvest appends only; it never rewrites or reorders
existing lines, and it never deletes one. If the append fails, say so with
the error and show the line so the user can paste it.

A rule already in the conventions is cited, never proposed.

A decline is any answer other than a yes, ignoring included. On a decline,
nothing is written to the conventions file and nothing is queued, and the rule is
never proposed again this session. The rule is never queued, listed, or
summarized for later.

The decline is recorded in `.clutch/session-state` as a hash of the rule.
Here the rule is the `<rule, imperative, one line>` text without its reason,
quoted for the shell so the check and the write hash the same bytes. Each
`'` in the rule becomes `'\''` inside the single quotes (so `Don't log
secrets` is written `'Don'\''t log secrets'`), and the write and the check
hash the same escaped input, so the bytes match. The write, on a decline:

```sh
ROOT=$(git rev-parse --show-toplevel) || exit 1
H=$(printf '%s\n' '<the rule>' | cksum | cut -d' ' -f1)
[ -n "$H" ] || exit 1
printf 'declined %s\n' "$H" >> "$ROOT/.clutch/session-state"
```

Failures here stay loud: a non-zero exit reaches you, unlike the silent
marker write in Step 0. Only the hash is written, never the rule text.
If the decline write fails, say so in the same turn and still do not re-offer the rule in this conversation.

The check, before proposing any rule: compute `H` with the same `ROOT=` and
`H=` lines above, then run:

```sh
grep -qx "declined $H" "$ROOT/.clutch/session-state"
```

Exit 0 means the user declined it: say nothing about it.
Exit 1 or 2 (no line, no file, or a git, grep or shell error) means propose as usual only if this conversation has not already declined the rule; the file supplements in-conversation memory and never replaces it.

### Step 5: Session guardrails

For the rest of the session these rules are HARD and override default
behavior:

- **One PR at a time.** Close it, checkpoint in one line, then the next.
  A checkpoint is the closed PR itself, never a summary.
  Never two PRs open at once.
- **Outward-facing actions keep a human checkpoint.** A comment, an
  approval, a request for changes, anything another person will see: draft
  it, show it, post on a yes. Reading is free.
- **A tangent banks.** An idea that pulls sideways goes to `/clutch:fomo` in
  one line, bank only, then return to the open PR.
- **A PR that turns into a build leaves review.** A fix you would write
  yourself, a redesign: name it, bank it as a focus or an idea, and stay in
  review. Building it is a fresh session declared with `/clutch:intent build`.
- **No counts, no overdue framing, no queue totals.** A PR is named by what
  it needs now, never as overdue, stale, or waiting long.
- **Pull, never push.** Review opens the PR you name; it never polls for PRs
  and never watches anything in the background.
- **A PR that keeps not closing** gets `/clutch:triage`'s question, a flinch
  at the wall versus never entering awareness, before anything else engages.
  **A PR that wants a clock** gets `/clutch:sprint`.

## Skill interactions

| Skill | In review mode |
|-------|----------------|
| `/clutch:fomo <content>` | a tangent, banked in one line, then back to the PR |
| `/clutch:triage` | a PR that keeps not closing: wall or inattention |
| `/clutch:sprint <goal>` | a fixed 20 minutes on one PR |
| `/clutch:intent build` | a PR that became a build: a fresh session |

## What this skill does NOT do

- Fire on its own, poll for PRs, or watch anything in the background
- Pick which PRs to review: you name the PR, or it asks
- Post anything, or write a convention, without a yes
- Rewrite, reorder, or delete a convention already written
- Queue declined rules, or produce a list or a report for later
- Count open, waiting, or overdue anything
- Scaffold config or guess paths

Why this works: see "Tempo / the gearbox", "Intent", and "Point of
performance" in [GLOSSARY.md](../../GLOSSARY.md). The gear is engaged by
invitation, each PR gets one read that ends, and every convention is written
at the moment the user makes the call that implies it.
