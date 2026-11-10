# tools/aipaper

A developer tool beside the plugin, not a plugin surface. If you installed the
Clutch plugin, nothing here runs for you until you install it by hand.

A Viwoods AiPaper tablet serves its notes over HTTP on port 8090 while its LAN
Transfer app is in the foreground. `pull.py` copies the page images of notes
that changed since the last run into `~/.clutch/inbox/aipaper/`. When the
tablet is not serving, a run ends at once and says nothing. Reading the pages
is not part of this tool.

Python standard library only; runs on the system `/usr/bin/python3`.

## Install

`~/.clutch` must already exist; this tool never creates it.

```bash
sh tools/aipaper/launchd.sh install 192.0.2.10   # the tablet's address
sh tools/aipaper/launchd.sh status
sh tools/aipaper/launchd.sh uninstall
```

`install` writes `~/Library/LaunchAgents/com.clutch.aipaper-pull.plist` and
loads it: one run a minute, output in `~/.clutch/aipaper/pull.log`. The plist
points at this checkout, so reinstall after moving it.

By hand:

```bash
/usr/bin/python3 tools/aipaper/pull.py --host 192.0.2.10
```

`--host` wins over the env var `CLUTCH_AIPAPER_HOST`. `--state-dir <dir>`
replaces `~/.clutch`.

## What a run does

The first run that reaches the tablet is the baseline: it records every note's
`updateTime` and downloads nothing. It prints
`aipaper: baseline recorded for N notes`. Later runs pull only notes whose
`updateTime` moved, and only the pages that changed. A run that wrote pages
prints `aipaper: N notes, M pages -> <inbox>`.

Sections walked: Paper, Daily, Meeting, Memo, Knowledge base.

| Exit | Meaning |
| --- | --- |
| 0 | done, or the tablet is not serving, or another run holds the lock |
| 2 | no host, or the state directory is missing |
| 3 | the tablet stopped serving mid-run; the journal keeps what was done |
| 4 | the journal does not parse or has an unknown version; it is left untouched |

A note that cannot be pulled (locked, an unknown archive, a failed download) is
recorded as skipped with one line on stderr, and tried again when its
`updateTime` moves.

## State

Under `~/.clutch`:

- `aipaper/journal.json`: per note, the last `updateTime` and a hash per page.
- `aipaper/lock`: one run at a time.
- `aipaper/pull.log`: the LaunchAgent's output.
- `inbox/aipaper/`: the pulled pages.

## Inbox layout

One directory per pulled note:

```text
inbox/aipaper/<section>/<note name>--<first 8 of the note id>/
  p<NN>-<first 8 of the page id>.png   one per changed page, NN is the page order
  note.json
```

Names keep `[A-Za-z0-9._-]`; every other character becomes `_`.

`note.json` holds `appType`, `noteId`, `fileName`, `folder` (folder names from
the section root), `updateTime`, `pulledAt`, `format` (`notebook` or `daily`),
`pages` (`file`, `pageId`, `order`, `lastModifiedTime`, and `isNote` for
Daily) and, for a Daily note, `todos`.

A later pull of the same note overwrites files with the same name; `pages`
then lists what is still in the directory plus the new pages. Whoever reads a
directory deletes it afterwards.

## Limits

- A note edited without its `updateTime` moving is missed until the next edit
  that moves it.
- The tablet's address must be stable (a DHCP reservation).
- The Learning section and locked (encrypted) notes are not pulled.
- The tablet has no delete: each pulled note leaves one packaged copy on the
  tablet, overwritten on the next pull of that note. Clearing the LAN Transfer
  app's storage removes them.
- After a first install, check the job once:
  `launchctl print gui/$(id -u)/com.clutch.aipaper-pull`.
- macOS may ask for Local Network permission for `python3` the first time the
  job runs. Until it is granted the job behaves as if the tablet were closed.

## Tests

```bash
sh tests/aipaper-pull.test.sh
```

Offline: a fake device on `127.0.0.1`, temp state directories, a scratch
`HOME` and a stubbed `launchctl`.
