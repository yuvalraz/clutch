# sources/

Raw transcripts and extracted source text live here **locally only** — they're
third-party copyrighted material (lectures, books) and aren't republished.

What's public is the *tool* (`../ingest.py`), the *index* (the spine table
in the top-level README), and the hand-assigned `resonance` weights.

For YouTube lectures: re-run the ingester against the same URLs to populate
this folder:

```bash
.venv/bin/python ingest.py "https://www.youtube.com/watch?v=VIDEO_ID" \
    --author "..." --title "..." --resonance high
```

Book and article ingest is future work — the tool is YouTube-only for now.
