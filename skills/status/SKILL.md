---
name: status
description: Report whether the Clutch hooks are alive in this repo and this session.
when_to_use: Use when the user asks "is clutch working", "did the hooks fire", "why is the bell silent", "why no anchor", or as a check right after installing.
---

# Status

Fail-open hooks degrade to silence on purpose, which means a broken install
and a quiet healthy one look identical from the transcript. This report makes
them distinguishable: it prints facts and changes nothing.

Procedure:

1. Run the status script that ships with this plugin; the harness substitutes its path when it loads this skill:

   ```sh
   sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"
   ```

   Never locate it with \$0 or $BASH_SOURCE; under a harness Bash tool those
   name the shell binary, not this file.

   If the command fails because the path did not resolve (`/scripts/status.sh` not found),
   show the error verbatim, say clutch is not loaded as a plugin in this session,
   and stop: do not search for the script.

2. Show the report verbatim. Do not summarize it away; the lines are the
   evidence.

3. If a line names a missing piece, name the one smallest fix and stop:
   reinstall for a missing constitution, open a git repo for an absent
   substrate, nothing at all for a healthy quiet state. Quiet is not broken;
   the report now says which one it is. For the state lines:

   - `.clutch present but not readable` or `.clutch not writable`: `chmod u+rwx .clutch` lets the hooks back in.
   - `state present but not writable`, or `unreadable` when the file's mode blocks reading: `chmod u+rw .clutch/session-state` lets the hooks back in.
   - `.clutch present but not a directory`: removing that `.clutch` file or link lets the next hook make the directory.
   - `session-state present but not a file`: moving `.clutch/session-state` aside lets the next hook start a fresh one.

Why this works: silence is the pack's designed degrade direction, so health
must be checkable on demand rather than inferred from absence. See
"Prosthesis is permanent" in [GLOSSARY.md](../../GLOSSARY.md): a prosthesis
you cannot inspect is one you stop trusting.
