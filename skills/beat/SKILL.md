---
name: beat
description: Run one beat of an ops session. Read the moves other sessions logged since the last beat and the waits no session's tag owns, reply `No change.` when nothing moved, and name what moved with one smallest move.
when_to_use: Use ONLY when the prompt is `/clutch:beat @<tag>`, the line an ops session's armed beat sends, or when a silent check's output, which arrives when a background task ends, holds the line `Run /clutch:beat @<tag>.` Any other mention of a beat or a check-in is not a trigger.
argument-hint: "@<tag>"
---

# Beat

`/clutch:beat @<tag>` is what an ops session's armed beat sends: the session's silent check, at most once an hour from 08:00 to 20:59 when another session moved, or an older hourly task.
It sets no gear, no focus and no mode: the session keeps the rules it had.
It is not a sweep or a tick: no sweep, no config read.

A wake from the session's silent check holds `Run /clutch:beat @<tag>.`, alone or after the watch's lines: run this skill once for that tag.

First check that this session is still an ops session, `@<tag>` replaced by the argument:

```sh
sh -c '. "${CLAUDE_PLUGIN_ROOT}/scripts/prelude.sh" && clutch_ops_record "@<tag>"'
```

Exit status 1 with no error text means its ops record is gone: cancel the recurring task in this session's own task list whose prompt is exactly `/clutch:beat @<tag>`, reply with exactly `Not an ops session now; the beat stopped.` and write nothing. Any other outcome goes on to the read; the check never writes.

Then run the merge pass, before the read. It needs no yes: the `### Merge` list is the user's standing yes for this merge; every other outward action still waits for its usual yes.

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/merge.sh" --unwatched
```

Append each `merged` line first, exactly as printed, its tag kept when it has one, as the text of a `moved:` line with the constitution's worklog snippet: the merge pass's lines keep their tag, so a dead tag's line closes only that tag's wait. Name a `did not merge` line once and write nothing for it. Keep the `held` lines in view for the read. Exit status 0 with no output: nothing merged. Any other outcome: say once that the merge pass cannot run, and stay silent about it on later beats. A merged PR is what moved: its one smallest move is the bookkeeping after a merge, such as the ticket, named and not done, since it waits for its usual yes. A `did not merge` line or the cannot-run line is part of the reply even when nothing else moved, so that reply is not `No change.`

Read with this line, `@<tag>` replaced by the argument:

```sh
sh -c '. "${CLAUDE_PLUGIN_ROOT}/scripts/prelude.sh" && L=$(clutch_beat_window "@<tag>") || exit; [ -z "$L" ] || printf "%s\n" "$L" | LC_ALL=C cut -c1-300; R=$?; [ ! -f "$HOME/.clutch/opsview.json" ] || echo "OPS VIEW: on"; exit $R'
```

Each line is a wait no session's tag owns, `<epoch> <repo> wait: <kind>:<ref> <baseline> <text>`, or a move another session logged since the last beat, `<epoch> <repo> moved: <text>`. Unlike the session-start Worklog block, the beat's read is for the reply: name a peer's `moved:` line.
Exit status 0 with empty output, or exit status 1 with no error text, means nothing to read: reply `No change.` With the merge pass's `merged` lines, that is not `No change.` Any other outcome, error text included: say once that the beat cannot read the worklog, and stay silent about it on later beats.
A last line `OPS VIEW: on` is never a move, a wait or a worklog line, and output that holds only it is empty output; with it, after any `moved:` lines and before the reply, run the ops view push once: the steps between the `<!-- opsview push -->` markers in the ops skill's `### Ops view`, which, when not in view, you find by those markers under the plugin's skills folder.

A `moved:` line already moved: name it, never read its thing again. Skip a `moved:` line this session wrote itself, such as a loop it closed or a wait an earlier beat closed.

Read each wait once, by its kind, against its baseline. Only this counts as movement:

- slack: replies in the thread newer than the baseline ts, from someone other than the user.
- gh: `gh pr view <number> --repo <owner>/<repo> --json state,reviewDecision,updatedAt`; a changed state or review decision, or `updatedAt` newer than the baseline.
- linear: `updatedAt` newer than the baseline, or a new comment.
- gmail: a message in the thread newer than the baseline id.
- ld: a flag version other than the baseline.
- dd: a monitor state other than the baseline.

A wait that moved: append its `moved:` line first, with the constitution's worklog snippet, verb `moved:` and text `<kind>:<ref> <what moved>`. Copy the ref exactly from its `wait:` line, as its own token followed by a space, with no tag after it.
A beat never holds a wait again and never removes itself while its ops record is there: it ends with the session. The one exception: an untagged wait the merge pass printed `held` for that also moved gets a fresh untagged `wait:` line right after its `moved:` line, text `<kind>:<ref> <new baseline> <text>`.

Then reply in at most two lines, plus the drift line when it applies: what moved, naming at most two movements, the ones nearest the day's work, and one smallest move. An outward action waits for its usual yes.
When what moved sits off the day's focuses, one more line names what moved and the focus it sits beside, such as `<what moved> sits beside <focus>.` When what moved converges with the focuses, nothing more. The focuses are the ones this ops session's sweep read from today's focus file; with none in view, nothing more. With nothing moved there is no drift line: `No change.` stays the whole reply.
When nothing moved, reply with exactly `No change.` and nothing more: an empty reply gets prompted for one. The reply answers the beat's prompt, so it is not an uninvited line.
A tool that is not reachable keeps its wait open: name it once, then stay silent about it. Never count, never say how long anything has waited, and never name something that did not move.
