---
name: watch
description: Run one tick of a session's armed watch. Read only the wait loops its tag owns, reply `No change.` when none moved, act on what moved, and remove the watch once none is left.
when_to_use: Use ONLY when the prompt is `/clutch:watch @<tag>`, the line a session's armed watch sends, or when a silent check's output, which arrives when a background task ends, holds the line `Run /clutch:watch @<tag> for the moved waits.` Any other mention of watching or waiting, "watch <thing>" in ops included, is not a trigger.
argument-hint: "@<tag>"
---

# Watch

`/clutch:watch @<tag>` is the tick a session's armed watch sends. It reads only the wait loops that tag owns, once each.
It sets no gear, no focus and no mode: the session keeps the rules it had. It is not an ops tick: no sweep, and no config read beyond the `### Merge` list its merge pass checks.

Read the waits with this line, `@<tag>` replaced by the argument:

```sh
sh -c '. "${CLAUDE_PLUGIN_ROOT}/scripts/prelude.sh" && L=$(clutch_owned_loops "@<tag>") || exit; [ -z "$L" ] || printf "%s\n" "$L" | LC_ALL=C cut -c1-300'
```

Each line is `<epoch> <repo> wait: <kind>:<ref> <baseline> @<tag> <text>`.
Exit status 0 with empty output, or exit status 1 with no error text, means no wait is left: delete the recurring task whose prompt is `/clutch:watch @<tag>` and say so in one line. Any other outcome, error text included, keeps the watch: say once that the waits cannot be read, and stay silent about it on later ticks.

Then run the merge pass. This merge needs no yes: the `### Merge` list is your standing yes for it; every other outward action still waits for its usual yes. Run this line, `@<tag>` replaced by the argument:

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/merge.sh" "@<tag>"
```

It prints at most one line per owned wait: `<ref> @<tag> merged`, `<ref> @<tag> did not merge` or `<ref> @<tag> held`.
A `merged` line is that wait's move: append its `moved:` line first, with the constitution's worklog snippet, verb `moved:` and the line exactly as printed as its text, and do not read that wait again. Being a move, it gets the session's own standing rules like any merge, such as the bookkeeping after a merge; an outward step there still waits for its usual yes.
A `did not merge` line is named once and writes nothing; a `held` line needs nothing. Exit status 0 with no output means nothing merged. Any other outcome: say once that the merge pass cannot run, and stay silent about it on later ticks. A `did not merge` line or the cannot-run line is part of the reply even when nothing else moved, so that reply is not `No change.`

A wake from the session's silent check holds `Run /clutch:watch @<tag> for the moved waits.` after one `<ref> <what>` line per wait, `<what>` being `merged`, `closed`, `review <STATE>`, `comment` or `unreadable` (gh failed on it 3 reads in a row): run this skill once for that tag, reading every owned wait as above.
On a wake where no wait is left and there is no recurring task, say so in one line and delete nothing.
The silent check's ended line, `The silent check for @<tag> ended; end the turn.`, needs no reply beyond ending the turn.

Read each wait once, by its kind, against its baseline. Only this counts as movement:

- gh: `gh pr view <number> --repo <owner>/<repo> --json state,reviews,comments,updatedAt`;
  the PR merged or closed, or a review or comment newer than the baseline;
  the re-held baseline is that PR's `updatedAt` from the same read.
- slack: a reply in the thread newer than the baseline ts.
- linear: an `updatedAt` newer than the baseline with a different state, or a comment newer than the baseline.
- gmail: a message in the thread newer than the baseline id.
- ld: a flag version other than the baseline.
- dd: a monitor state other than the baseline.

A review, comment, reply or message from the user or a bot does not count, except a review that requests changes, which counts from anyone but the user.

A wait that moved: append its `moved:` line first, with the constitution's worklog snippet, verb `moved:` and text `<kind>:<ref> @<tag> <what moved>`. Copy the ref exactly from its `wait:` line, as its own token followed by a space.
If the thing is still open after the move, such as approved, commented or changes requested, append a fresh `wait:` line right after that `moved:` line, with the same snippet and text `<kind>:<ref> <new baseline> @<tag> <text>`: the same ref, the new baseline and the same `@<tag>`, so a later merge stays watched.
A thing that merged or closed is not held again. Only a gh PR is held again this way; a wait of any other kind is not.
Then act on it by the session's own standing rules, such as a fix loop on changes requested or the bookkeeping after a merge. An outward action still waits for its usual yes.

When nothing moved, reply with exactly `No change.` and nothing more: an empty reply gets prompted for one.
Never mention activity that does not count as movement, such as a bot's review or comment.
A tool that is not reachable keeps its wait open: name it once, then stay silent about it.
Never count waits, never say how long anything has waited, and never name a wait that did not move.
