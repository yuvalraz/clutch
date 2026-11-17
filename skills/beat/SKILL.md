---
name: beat
description: Run one beat of an ops session. Read the moves other sessions logged since the last beat and the waits no session's tag owns, reply `No change.` when nothing moved, and name what moved with one smallest move.
when_to_use: Use ONLY when the prompt is `/clutch:beat @<tag>`, the line an ops session's armed beat sends. Any other mention of a beat or a check-in is not a trigger.
argument-hint: "@<tag>"
---

# Beat

`/clutch:beat @<tag>` is what an ops session's armed beat sends, every two hours from 08:07 to 20:07 while the session is open.
It sets no gear, no focus and no mode: the session keeps the rules it had.
It is not a sweep or a tick: no sweep, no config read.

Read with this line, `@<tag>` replaced by the argument:

```sh
sh -c '. "${CLAUDE_PLUGIN_ROOT}/scripts/prelude.sh" && L=$(clutch_beat_window "@<tag>") || exit; [ -z "$L" ] || printf "%s\n" "$L" | LC_ALL=C cut -c1-300'
```

Each line is a wait no session's tag owns, `<epoch> <repo> wait: <kind>:<ref> <baseline> <text>`, or a move another session logged since the last beat, `<epoch> <repo> moved: <text>`.
Unlike the session-start Worklog block, the beat's read is for the reply: name a peer's `moved:` line.
Exit status 0 with empty output, or exit status 1 with no error text, means nothing to read: reply `No change.`
Any other outcome, error text included: say once that the beat cannot read the worklog, and stay silent about it on later beats.

A `moved:` line already moved: name it, never read its thing again.
Skip a `moved:` line this session wrote itself, such as a loop it closed or a wait an earlier beat closed.

Read each wait once, by its kind, against its baseline. Only this counts as movement:

- slack: replies in the thread newer than the baseline ts, from someone other than the user.
- gh: `gh pr view <number> --repo <owner>/<repo> --json state,reviewDecision,updatedAt`; a changed state or review decision, or `updatedAt` newer than the baseline.
- linear: `updatedAt` newer than the baseline, or a new comment.
- gmail: a message in the thread newer than the baseline id.
- ld: a flag version other than the baseline.
- dd: a monitor state other than the baseline.

A wait that moved: append its `moved:` line first, with the constitution's worklog snippet, verb `moved:` and text `<kind>:<ref> <what moved>`. Copy the ref exactly from its `wait:` line, as its own token followed by a space, with no tag after it.
A beat never holds a wait again and never removes itself: it ends with the session.

Then reply in at most two lines: what moved, naming at most two movements, the ones nearest the day's work, and one smallest move. An outward action waits for its usual yes.
When nothing moved, reply with exactly `No change.` and nothing more: an empty reply gets prompted for one.
The reply answers the beat's prompt, so it is not an uninvited line.
A tool that is not reachable keeps its wait open: name it once, then stay silent about it.
Never count, never say how long anything has waited, and never name something that did not move.
