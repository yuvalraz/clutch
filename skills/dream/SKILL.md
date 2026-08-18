---
name: dream
description: A full consolidation pass over the auto-memory brain — read everything, report what holds and what drifted, prune, and hand back a shorter index. Use when the user says "dream", "consolidate the brain", "clean up memory", "dream pass".
disable-model-invocation: true
---

# Dream

A brain that only accumulates stops being a map. Entries pile up, the index
grows past what a session can afford to load, and two files quietly say the
same thing. Dream is the consolidation pass: read the whole brain, report what
holds and what drifted, and leave the index shorter than it was found.

One line of orientation: the daydream and dream-spark skills work the ideation
pool — this skill works the memory brain. Whisper a fragment to
`/clutch:daydream`, cross-reference the pool with `/clutch:dream-spark`, run
`/clutch:dream` when the brain itself needs a deep pass.

Dream runs only when the user fires it. It never launches itself.

## Procedure

### Step 1: Resolve the brain

Read `autoMemoryDirectory` from `~/.claude/settings.json`. That value is the
brain directory. If the key is absent, say so plainly — "no
`autoMemoryDirectory` in `~/.claude/settings.json`; there is no brain to
dream on" — and stop. Never guess a path. Never hardcode one.

### Step 2: Read everything

- The index file at the brain root — the one loaded every session.
- Every file the index links.
- Every file in the brain directory that the index does NOT link — these are
  orphans, and they matter below.
- The `archives/` subdirectory, when one exists. Archives are unindexed by
  design: scan the folder directly, and never add an index line pointing into
  it.

### Step 3: Report

Produce a structured report with these sections:

**Strengths** — patterns the record has repeatedly validated. Name them; they
are the entries earning their keep.

**Stale** — entries the current state contradicts or supersedes. Staleness is
a property of the file, never of the person: the file drifted, the world
moved, a newer entry replaced it. Files whose `last_reviewed` frontmatter is
more than 180 days old surface here as review-due — a flag for
re-confirmation, never a deletion. Files without the field are silently
skipped.

**Orphans** — files in the brain directory with no index line. Each one gets
a disposition below: index it, merge it, or archive it.

**Gaps** — recurring situations the brain has no coverage for. A dream that
only prunes misses half the value.

**Evolutions** — concrete proposed changes, one line each:

- Promote: entry moves up a tier (from a detail file to an index line, or
  from an index line into standing instructions).
- Archive: closed or superseded entry moves to `archives/`, its index line
  removed and never replaced.
- Consolidate cluster: three or more same-topic entries collapse into one hub
  file that links to its siblings; only the hub keeps an index line.
- Merge: two files whose content overlaps more than 70% become one; say in
  one line what the merge would lose.
- Prune: remove an entry that is empty, redundant, or orphaned with no value.

### Validate checks (folded into the report)

Run these while reading; surface each hit in the matching section:

1. **Orphan index links** — index lines pointing at files that do not exist.
2. **Duplicates** — the same topic living under two different names.
3. **Index size** — the index loads every session, so every line costs every
   session. Flag when it passes roughly 50 lines.
4. **Absolute user paths** — any memory file containing a path that begins
   `/Users` or `/home` breaks portability; flag every match.
5. **Pointers, not copies** — entries carrying copied live data instead of a
   pointer (see Conventions). Flag them for rewrite.

### Step 4: Apply

Show the report. The user picks which evolutions to apply — none is a legal
answer.

A pruning and resort pass always runs, whatever was picked: dedup index
entries, fix orphans (index or archive each one), archive closed items,
remove any index line pointing into `archives/`.

**Exit condition:** the index is shorter after dream than before. The report
states both line counts — before and after. A dream that hands back a longer
index did not finish.

## Conventions

Two conventions this skill enforces across the brain:

- **`last_reviewed: YYYY-MM-DD`** — optional frontmatter, set only when a
  human confirms the content is still true. Machine edits never touch it: a
  file being read, appended, or reorganized proves nothing about whether its
  claims still hold. Dream surfaces files past 180 days as review-due;
  files without the field are silently skipped.
- **Pointers, not copies** — memories store pointers (paths, URLs, IDs, how
  to fetch) plus the durable insight, never copied live data: API responses,
  metric values, table rows. A copy goes stale and answers a later question
  with confident wrongness; a pointer stays honest because it makes you look
  again.

## What this skill does NOT do

- Delete anything the user did not pick — review-due is a flag, not a purge
- Index `archives/` — unindexed by design, scanned directly when history
  matters
- Guess or hardcode the brain path — no `autoMemoryDirectory`, no dream
- Run on its own — it is fired, every time
