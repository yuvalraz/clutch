# sources/

This folder is empty on GitHub by design. The transcripts and book texts are
third-party copyrighted material and stay local; what's public is the
editorial layer (the resonance weights, [ANNOTATIONS.md](../ANNOTATIONS.md),
[GLOSSARY.md](../GLOSSARY.md)) and the tool. Anyone can rebuild the corpus
locally by re-running the ingester against the same public sources.

For YouTube lectures: re-run the ingester against the same URLs to populate
this folder:

```bash
.venv/bin/python ingest.py "https://www.youtube.com/watch?v=VIDEO_ID" \
    --author "..." --title "..." --resonance high
```

Books: `../ingest_book.py` digests a bought, DRM-free EPUB the same way. The
file stays local like every source. Article ingest is future work.
