---
name: watch
description: Run one tick of a session's armed watch. Read only the wait loops its tag owns, stay silent when none moved, act on what moved, and remove the watch once none is left.
when_to_use: Use ONLY when the prompt is `/clutch:watch @<tag>`, the line a session's armed watch sends. Any other mention of watching or waiting, "watch <thing>" in ops included, is not a trigger.
argument-hint: "@<tag>"
---

# Watch

`/clutch:watch @<tag>` is the tick a session's armed watch sends. It reads
only the wait loops that tag owns, once each.
It sets no gear, no focus and no mode: the session keeps the rules it had.
It is not an ops tick: no sweep, no config read.

Read the waits with this line, `@<tag>` replaced by the argument:

```sh
sh -c '. "${CLAUDE_PLUGIN_ROOT}/scripts/prelude.sh" && L=$(clutch_owned_loops "@<tag>") || exit; [ -z "$L" ] || printf "%s\n" "$L" | LC_ALL=C cut -c1-300'
```

Each line is `<epoch> <repo> wait: <kind>:<ref> <baseline> @<tag> <text>`.
Exit status 0 with empty output, or exit status 1 with no error text, means no wait is left: delete the recurring task whose prompt is `/clutch:watch @<tag>` and say so in one line.
Any other outcome, error text included, keeps the watch: say once that the waits cannot be read, and stay silent about it on later ticks.

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

A wait that moved: append its `moved:` line first, with the constitution's
worklog snippet, verb `moved:` and text `<kind>:<ref> @<tag> <what moved>`.
Copy the ref exactly from its `wait:` line, as its own token followed by a space.
If the thing is still open after the move, such as approved, commented or changes requested, append a fresh `wait:` line right after that `moved:` line, with the same snippet and text `<kind>:<ref> <new baseline> @<tag> <text>`: the same ref, the new baseline and the same `@<tag>`, so a later merge stays watched.
A thing that merged or closed is not held again.
Only a gh PR is held again this way; a wait of any other kind is not.
Then act on it by the session's own standing rules, such as a fix loop on changes requested or the bookkeeping after a merge.
An outward action still waits for its usual yes.

When nothing moved, print nothing.
A tool that is not reachable keeps its wait open: name it once, then stay silent about it.
Never count waits, never say how long anything has waited, and never name a wait that did not move.
