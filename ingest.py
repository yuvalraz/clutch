#!/usr/bin/env python3
"""Ingest ONE source into the ADHD canon: fetch a YouTube transcript, clean it,
write a markdown file with frontmatter to sources/.

Usage:
    .venv/bin/python ingest.py <url-or-id> --author "..." --title "..." [--resonance high]

# ponytail: youtube-only; add epub/pdf/article ingest when those sources actually arrive.
"""
import argparse
import re
import sys
from datetime import date
from pathlib import Path

SOURCES = Path(__file__).parent / "sources"


def _extract_id(s: str) -> str:
    """Accept a raw 11-char id or any common YouTube URL form."""
    s = s.strip()
    m = re.search(r"(?:v=|/shorts/|youtu\.be/|/embed/)([A-Za-z0-9_-]{11})", s)
    if m:
        return m.group(1)
    if re.fullmatch(r"[A-Za-z0-9_-]{11}", s):
        return s
    raise ValueError(f"cannot extract a video id from: {s!r}")


def _clean(snippets) -> str:
    text = " ".join(sn.text for sn in snippets)
    text = re.sub(r"\[[^\]]*\]", " ", text)   # drop [Music]/[Applause] caption tags
    text = re.sub(r"\s+", " ", text).strip()  # collapse whitespace + newlines
    return text


def _slug(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def fetch(video_id: str) -> str:
    from youtube_transcript_api import YouTubeTranscriptApi
    api = YouTubeTranscriptApi()
    try:
        tr = api.fetch(video_id, languages=["en", "en-US", "en-GB"])
    except Exception:
        tr = api.fetch(video_id)  # fall back to any available language
    return _clean(tr)


def _selftest() -> None:
    assert _extract_id("https://www.youtube.com/watch?v=BzhbAK1pdPM") == "BzhbAK1pdPM"
    assert _extract_id("https://youtu.be/BzhbAK1pdPM?t=10") == "BzhbAK1pdPM"
    assert _extract_id("BzhbAK1pdPM") == "BzhbAK1pdPM"
    assert _slug("Barkley: 30 Ideas!") == "barkley-30-ideas"
    print("selftest ok")


def main() -> None:
    p = argparse.ArgumentParser(description="Ingest one YouTube source into the ADHD canon.")
    p.add_argument("source", nargs="?", help="YouTube URL or 11-char video id")
    p.add_argument("--author", help="e.g. 'Russell Barkley'")
    p.add_argument("--title", help="e.g. '30 Essential Ideas 1A — Intro'")
    p.add_argument("--type", default="lecture")
    p.add_argument("--resonance", default="med", choices=["high", "med", "low"])
    p.add_argument("--selftest", action="store_true", help=argparse.SUPPRESS)
    args = p.parse_args()

    if args.selftest:
        _selftest()
        return
    if not (args.source and args.author and args.title):
        p.error("source, --author and --title are required")

    vid = _extract_id(args.source)
    body = fetch(vid)
    if not body:
        sys.exit(f"no transcript text for {vid}")

    SOURCES.mkdir(exist_ok=True)
    out = SOURCES / f"{_slug(args.author)}-{_slug(args.title)}.md"
    frontmatter = (
        "---\n"
        f"author: {args.author}\n"
        f"title: {args.title}\n"
        f"type: {args.type}\n"
        f"source: https://www.youtube.com/watch?v={vid}\n"
        f"video_id: {vid}\n"
        f"retrieved: {date.today().isoformat()}\n"
        f"resonance: {args.resonance}\n"
        "---\n\n"
    )
    out.write_text(frontmatter + body + "\n", encoding="utf-8")
    print(f"wrote {out.relative_to(Path(__file__).parent)} ({len(body.split())} words)")


if __name__ == "__main__":
    main()
