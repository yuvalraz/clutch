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

Pass the address alone, without the port: `192.0.2.10:8090` is refused, and so
is a name with `..` or with no letter or digit. A name that never resolves
would look like a closed tablet, so every run would end silently.

If `launchctl bootstrap` fails, `install` exits 1 and the plist stays: it loads
at the next login unless you run `uninstall`. `uninstall` exits 1 when the job
is still loaded afterwards.

`status` prints the plist path and its host, `loaded: yes` or `loaded: no`,
when the journal was last written, and the last line of `pull.log`.

By hand:

```bash
/usr/bin/python3 tools/aipaper/pull.py --host 192.0.2.10
```

`--host` wins over the env var `CLUTCH_AIPAPER_HOST`. `--state-dir <dir>`
replaces `~/.clutch`.

## What a run does

The first run that reaches the tablet is the baseline: it records every note's
`updateTime` and downloads nothing. It prints
`aipaper: baseline recorded for N notes`. A baseline that could not list every
section says so on stderr and runs again next time; a note keeps the
`updateTime` first recorded for it, so an edit made meanwhile is pulled once
the baseline completes. Later runs pull only notes whose `updateTime` moved,
and only the pages that changed. A run that wrote pages prints
`aipaper: N notes, M pages -> <inbox>`.

Sections walked: Paper, Daily, Meeting, Memo, Knowledge base.

| Exit | Meaning |
| --- | --- |
| 0 | done, or the tablet is not serving, or another run or the tablet inbox reader holds the lock |
| 1 | the lock, the journal or a page could not be written; one line on stderr |
| 2 | no host, or the state directory is missing |
| 3 | the tablet stopped serving mid-run; the journal keeps what was done |
| 4 | the journal does not parse or has an unknown version; it is left untouched |

A note that cannot be pulled is recorded as skipped with one line on stderr,
and tried again when its `updateTime` moves. The reasons: `encrypted` (a locked
note), `not a ZIP`, `unsupported` (an unknown archive), `bad archive`,
`no page images` (page records but no image: likely a format change),
`device error: ...` and `download failed`.

A skip loses nothing: the entry keeps the page hashes and the time of the last
good state, so the next good pull delivers every page edited since then.

A download that fails while the tablet still answers is tried again on the
next run, with one line on stderr each time. After three failed runs in a row
the note is skipped as `download failed`.

A section that lists no notes while the journal holds notes for it is not
pruned: an empty answer is not proof of deletion. The run prints one line on
stderr each time, until the section lists a note again.

The journal is saved after every pulled or skipped note, so a run that is
killed keeps what it did.

## State

Under `~/.clutch`:

- `aipaper/journal.json`: per note, the last `updateTime` and a hash per page;
  for a skipped note also `skipped`, `since` and, while a download is being
  retried, `failures`.
- `aipaper/lock`: one run at a time; the tablet inbox reader
  (`scripts/tablet_inbox.py`) takes it too.
- `aipaper/pull.log`: the LaunchAgent's output.
- `inbox/aipaper/`: the pulled pages.
- `aipaper/reading/`: captures the reader claimed, each with a `.claims` count.
- `aipaper/held/`: captures the reader gave up on when it claimed them: `not read`
  (claimed five times without filing) or `unreadable` (no usable `note.json`). A
  capture that fails while being filed stays in `aipaper/reading/`; the next sweep
  retries it, and after five claims it moves here as `not read`.
- `aipaper/ledger.json`: what the reader filed.

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
directory deletes it afterwards: the tablet inbox reader renames a directory into `aipaper/reading/`
and deletes it once every item in it is filed.

To retry a folder in `aipaper/held/`, delete its `.claims` file first, then move
the folder into `aipaper/reading/`; the next sweep that starts ten minutes or
more later picks it up (the delete gives the folder a fresh ten-minute lease).
A folder held as `unreadable` needs its `note.json` repaired first, or it returns
to `held/` on the next sweep that takes it. To drop it, delete it.

## Limits

- A note edited without its `updateTime` moving is missed until the next edit
  that moves it.
- The tablet's address must be stable (a DHCP reservation).
- The Learning section and locked (encrypted) notes are not pulled.
- The tablet is not authenticated, so what it sends is bounded: a response over
  256 MiB is a device error, an archive member over 64 MiB makes the note a
  `bad archive`, and folders more than 16 levels deep are not walked.
- When you delete the last note of a section, its journal entries stay and
  each run prints one line about it.
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
