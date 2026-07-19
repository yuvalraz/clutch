# tools/ingest

This is my private canon-authoring scaffold, not a user surface. It digests one
source at a time into `sources/` and goes dormant between research finds. If
you installed the Clutch plugin, nothing here runs for you and nothing needs to.

## Ingest a source

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt

# a single video:
.venv/bin/python tools/ingest/ingest.py "https://www.youtube.com/watch?v=VIDEO_ID" \
    --author "Author" --title "Talk title" --resonance high

# a whole playlist → ONE digest (a lecture series is a single work):
.venv/bin/python tools/ingest/ingest.py "https://www.youtube.com/playlist?list=PLAYLIST_ID" \
    --author "Russell Barkley" --title "30 Essential Ideas (full series)" --resonance high

# a book (DRM-free EPUB, bought — the file stays local like every source):
.venv/bin/python tools/ingest/ingest_book.py path/to/book.epub \
    --author "Thomas E. Brown" --title "Smart but Stuck" --resonance high
```

Run from the repo root. Output lands in `sources/`, which stays local
(third-party copyrighted text is never published).
