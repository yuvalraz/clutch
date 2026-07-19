---
name: status
description: Report whether the Clutch hooks are alive in this repo and this session. Use when the user asks "is clutch working", "did the hooks fire", "why is the bell silent", "why no anchor", or as a check right after installing.
---

# Status

Fail-open hooks degrade to silence on purpose, which means a broken install
and a quiet healthy one look identical from the transcript. This report makes
them distinguishable: it prints facts and changes nothing.

Procedure:

1. Run the status script that ships with this plugin. From this skill's base
   directory it lives two levels up:

   ```sh
   sh "$(dirname "$0" 2>/dev/null || echo .)/../../scripts/status.sh"
   ```

   If the shell substitution is awkward in context, resolve the path from the
   base directory shown when this skill loads and run
   `sh <plugin-root>/scripts/status.sh` directly.

2. Show the report verbatim. Do not summarize it away; the lines are the
   evidence.

3. If a line names a missing piece, name the one smallest fix and stop:
   reinstall for a missing constitution, open a git repo for an absent
   substrate, nothing at all for a healthy quiet state. Quiet is not broken;
   the report now says which one it is.

Why this works: silence is the pack's designed degrade direction, so health
must be checkable on demand rather than inferred from absence. See
"Prosthesis is permanent" in [GLOSSARY.md](../../GLOSSARY.md): a prosthesis
you cannot inspect is one you stop trusting.
