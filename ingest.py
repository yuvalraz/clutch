#!/usr/bin/env python3
"""Ingest ONE source into the ADHD canon: a single YouTube video, or a whole
playlist digested into ONE file — some sources (a lecture series chopped into
parts) are a single cumulative work and shouldn't be shredded into stubs.
Fetch transcript(s), clean, write markdown + frontmatter to sources/.

Usage:
    .venv/bin/python ingest.py <url-or-id> --author "..." --title "..." [--resonance high]
    # a playlist URL is digested into a single file, one "## Part NN" section per video

# ponytail: youtube only; add epub/pdf/article ingest when those sources actually arrive.
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


def _is_playlist(s: str) -> bool:
    return "/playlist?" in s or ("list=" in s and "v=" not in s)


def _clean(snippets) -> str:
    text = " ".join(sn.text for sn in snippets)
    text = re.sub(r"\[[^\]]*\]", " ", text)   # drop [Music]/[Applause] caption tags
    text = re.sub(r"\s+", " ", text).strip()  # collapse whitespace + newlines
    return text


def _slug(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def _transcript(video_id: str) -> str:
    from youtube_transcript_api import YouTubeTranscriptApi
    api = YouTubeTranscriptApi()
    try:
        tr = api.fetch(video_id, languages=["en", "en-US", "en-GB"])
    except Exception:
        tr = api.fetch(video_id)  # fall back to any available language
    return _clean(tr)


def _playlist_entries(url: str):
    """[(id, title), ...] in playlist order via yt-dlp — enumerate only, no download."""
    import yt_dlp
    opts = {"quiet": True, "extract_flat": True, "skip_download": True}
    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(url, download=False)
    return [(e["id"], e.get("title", e["id"])) for e in info.get("entries", []) if e]


def fetch_playlist(url: str):
    """Concatenate every part into one digest. Returns (body, ok, total)."""
    entries = _playlist_entries(url)
    parts, ok = [], 0
    for i, (vid, title) in enumerate(entries, 1):
        try:
            body = _transcript(vid)
            ok += 1
            status = "ok"
        except Exception as e:
            body = f"_(transcript unavailable: {e})_"
            status = "MISSING"
        parts.append(f"## Part {i:02d} — {title}\n\n{body}")
        print(f"  part {i:02d}/{len(entries)} {vid} {status}")
    return "\n\n".join(parts), ok, len(entries)


def _selftest() -> None:
    assert _extract_id("https://www.youtube.com/watch?v=BzhbAK1pdPM") == "BzhbAK1pdPM"
    assert _extract_id("https://youtu.be/BzhbAK1pdPM?t=10") == "BzhbAK1pdPM"
    assert _extract_id("BzhbAK1pdPM") == "BzhbAK1pdPM"
    assert _slug("Barkley: 30 Ideas!") == "barkley-30-ideas"
    assert _is_playlist("https://www.youtube.com/playlist?list=PLxyz")
    assert not _is_playlist("https://www.youtube.com/watch?v=BzhbAK1pdPM&list=PLxyz")
    print("selftest ok")


def main() -> None:
    p = argparse.ArgumentParser(description="Ingest one YouTube source (video or playlist) into the ADHD canon.")
    p.add_argument("source", nargs="?", help="YouTube video URL/id, or a playlist URL (digested as one file)")
    p.add_argument("--author", help="e.g. 'Russell Barkley'")
    p.add_argument("--title", help="e.g. '30 Essential Ideas (full series)'")
    p.add_argument("--type", default=None, help="default: 'lecture' for a video, 'lecture-series' for a playlist")
    p.add_argument("--resonance", default="med", choices=["high", "med", "low"])
    p.add_argument("--selftest", action="store_true", help=argparse.SUPPRESS)
    args = p.parse_args()

    if args.selftest:
        _selftest()
        return
    if not (args.source and args.author and args.title):
        p.error("source, --author and --title are required")

    if _is_playlist(args.source):
        body, ok, total = fetch_playlist(args.source)
        if ok == 0:
            sys.exit("no transcripts fetched for any part")
        src = args.source
        kind = args.type or "lecture-series"
        parts_line = f"parts: {ok}/{total}\n"
    else:
        vid = _extract_id(args.source)
        body = _transcript(vid)
        if not body:
            sys.exit(f"no transcript text for {vid}")
        src = f"https://www.youtube.com/watch?v={vid}"
        kind = args.type or "lecture"
        parts_line = ""

    SOURCES.mkdir(exist_ok=True)
    out = SOURCES / f"{_slug(args.author)}-{_slug(args.title)}.md"
    frontmatter = (
        "---\n"
        f"author: {args.author}\n"
        f"title: {args.title}\n"
        f"type: {kind}\n"
        f"source: {src}\n"
        f"{parts_line}"
        f"retrieved: {date.today().isoformat()}\n"
        f"resonance: {args.resonance}\n"
        "---\n\n"
    )
    out.write_text(frontmatter + body + "\n", encoding="utf-8")
    print(f"wrote {out.relative_to(Path(__file__).parent)} ({len(body.split())} words)")


if __name__ == "__main__":
    main()
