#!/usr/bin/env python3
"""Ingest ONE book (EPUB) into the ADHD canon: pull the reading-order text, clean
it to markdown with a `## <chapter>` section per spine document, write markdown +
frontmatter to sources/. Sibling to ingest.py (which handles YouTube). Raw book
text stays LOCAL (sources/ is gitignored) — third-party copyrighted material,
never republished; the public repo carries the tool + index + weights only.

Usage:
    .venv/bin/python ingest_book.py path/to/book.epub \
        --author "Russell Barkley" --title "ADHD and the Nature of Self-Control" \
        --resonance high [--source "ISBN 9781572302501"]

# ponytail: EPUB only; add PDF ingest when a canon title has no EPUB edition.
# ponytail: trust boundary — parses LOCAL, operator-owned .epub files only, not
#   untrusted uploads, so stdlib xml parsing is fine for this threat model.
"""
import argparse
import re
import sys
import zipfile
from datetime import date
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote
from xml.etree import ElementTree as ET

from ingest import _build_frontmatter, _stem  # reuse; do not duplicate

SOURCES = Path(__file__).resolve().parents[2] / "sources"

_OPF = "http://www.idpf.org/2007/opf"
_CONTAINER = "urn:oasis:names:tc:opendocument:xmlns:container"


class _TextExtractor(HTMLParser):
    """Collect visible text from one XHTML chapter: drop script/style/head, break
    on block tags, and lift the first in-body heading out as the section title."""
    _BLOCK = {"p", "div", "br", "li", "h1", "h2", "h3", "h4", "h5", "h6",
              "section", "article", "tr", "blockquote"}
    _HEADING = {"h1", "h2", "h3"}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self._skip = 0            # inside script/style/head
        self._in_heading = None   # tag name while capturing the first heading
        self._heading_done = False
        self.heading = ""
        self._out = []

    def handle_starttag(self, tag, attrs):
        if tag in ("script", "style", "head"):
            self._skip += 1
        elif tag in self._HEADING and not self._heading_done and self._in_heading is None:
            self._in_heading = tag
        if tag in self._BLOCK:
            self._out.append("\n")

    def handle_endtag(self, tag):
        if tag in ("script", "style", "head") and self._skip:
            self._skip -= 1
        if tag == self._in_heading:
            self._in_heading = None
            self._heading_done = True
        if tag in self._BLOCK:
            self._out.append("\n")

    def handle_data(self, data):
        if self._skip:
            return
        if self._in_heading is not None:
            self.heading += data   # becomes the ## title; kept OUT of the body
            return
        self._out.append(data)

    def text(self):
        raw = "".join(self._out)
        lines = [re.sub(r"[ \t]+", " ", ln).strip() for ln in raw.splitlines()]
        out, blank = [], False
        for ln in lines:                 # collapse runs of blank lines to one
            if ln:
                out.append(ln)
                blank = False
            elif not blank and out:
                out.append("")
                blank = True
        return "\n".join(out).strip()


def _opf_path(zf):
    """META-INF/container.xml -> the .opf rootfile path."""
    root = ET.fromstring(zf.read("META-INF/container.xml"))
    rf = root.find(f".//{{{_CONTAINER}}}rootfile")
    if rf is None or not rf.get("full-path"):
        raise ValueError("no rootfile in META-INF/container.xml — not a valid EPUB")
    return rf.get("full-path")


def _spine_hrefs(zf, opf_path):
    """Manifest + spine -> content-document zip paths in reading order."""
    opf = ET.fromstring(zf.read(opf_path))
    manifest = {it.get("id"): (it.get("href"), it.get("media-type", ""))
                for it in opf.iterfind(f".//{{{_OPF}}}item")}
    base = opf_path.rsplit("/", 1)[0] if "/" in opf_path else ""
    hrefs = []
    for ref in opf.iterfind(f".//{{{_OPF}}}itemref"):
        if ref.get("linear", "yes") == "no":
            continue
        item = manifest.get(ref.get("idref"))
        if not item:
            continue
        href, mtype = item
        href = unquote(href.split("#", 1)[0])
        if "html" not in mtype and not href.lower().endswith((".xhtml", ".html", ".htm")):
            continue                     # skip css/images/ncx in the spine
        full = f"{base}/{href}" if base else href
        # collapse any ../ so it matches a zip entry name
        hrefs.append(re.sub(r"[^/]+/\.\./", "", full))
    return hrefs


def extract_epub(path):
    """Return (body_markdown, chapter_count): one '## <title>' section per spine
    document with visible text, in reading order. Empty docs (nav/cover) skipped."""
    with zipfile.ZipFile(path) as zf:
        names = set(zf.namelist())
        sections, n = [], 0
        for href in _spine_hrefs(zf, _opf_path(zf)):
            if href not in names:
                print(f"  warn: spine entry not in archive, skipped: {href}", file=sys.stderr)
                continue
            parser = _TextExtractor()
            parser.feed(zf.read(href).decode("utf-8", "replace"))
            body = parser.text()
            if not body:
                continue                 # nav/cover/blank — no empty section
            n += 1
            title = re.sub(r"\s+", " ", parser.heading).strip() or f"Section {n:02d}"
            sections.append(f"## {title}\n\n{body}")
    return "\n\n".join(sections), n


def _selftest():
    import tempfile
    opf = (f'<?xml version="1.0"?>\n<package xmlns="{_OPF}" version="3.0" unique-identifier="id">'
           '<metadata/><manifest>'
           '<item id="c1" href="ch1.xhtml" media-type="application/xhtml+xml"/>'
           '<item id="c2" href="ch2.xhtml" media-type="application/xhtml+xml"/>'
           '<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml"/>'
           '</manifest><spine>'
           '<itemref idref="c1"/><itemref idref="c2"/><itemref idref="nav"/>'
           '</spine></package>')
    container = (f'<?xml version="1.0"?>\n<container xmlns="{_CONTAINER}" version="1.0">'
                 '<rootfiles><rootfile full-path="content.opf" '
                 'media-type="application/oebps-package+xml"/></rootfiles></container>')
    ch1 = ("<html><head><title>ignore me</title></head><body><h1>First Wall</h1>"
           "<p>Alpha one.</p><p>Alpha two.</p><script>bad()</script></body></html>")
    ch2 = "<html><body><h2>Second Wall</h2><p>Beta &amp; gamma.</p></body></html>"
    nav = "<html><body></body></html>"   # empty -> must be skipped

    with tempfile.TemporaryDirectory() as d:
        epub = Path(d) / "t.epub"
        with zipfile.ZipFile(epub, "w") as zf:
            zf.writestr("mimetype", "application/epub+zip")
            zf.writestr("META-INF/container.xml", container)
            zf.writestr("content.opf", opf)
            zf.writestr("ch1.xhtml", ch1)
            zf.writestr("ch2.xhtml", ch2)
            zf.writestr("nav.xhtml", nav)
        body, chapters = extract_epub(epub)

    assert chapters == 2, f"expected 2 chapters (empty nav skipped), got {chapters}"
    assert "## First Wall" in body and "## Second Wall" in body, f"headings lost: {body!r}"
    assert body.index("First Wall") < body.index("Second Wall"), "spine order not preserved"
    assert "Alpha one." in body and "Alpha two." in body, "ch1 paragraphs lost"
    assert body.count("First Wall") == 1, f"heading duplicated into body: {body!r}"
    assert "Beta & gamma." in body, f"entity not decoded: {body!r}"
    assert "bad()" not in body, "script content leaked into body"
    assert "ignore me" not in body, "head/title leaked into body"

    fm = _build_frontmatter("Russell Barkley", "ADHD: Nature of Self-Control", "book",
                            "book: test", "chapters: 2\n", "2026-07-09", "high")
    assert '"ADHD: Nature of Self-Control"' in fm, f"title quoting broken: {fm!r}"
    assert 'type: "book"' in fm and "chapters: 2" in fm, f"frontmatter shape: {fm!r}"
    assert _stem("Russell Barkley", "Executive Functions") == "russell-barkley-executive-functions"
    print("selftest ok")


def main():
    p = argparse.ArgumentParser(description="Ingest one EPUB book into the ADHD canon.")
    p.add_argument("epub", nargs="?", help="path to a local .epub file")
    p.add_argument("--author", help="e.g. 'Russell Barkley'")
    p.add_argument("--title", help="e.g. 'ADHD and the Nature of Self-Control'")
    p.add_argument("--type", default="book")
    p.add_argument("--source", default="", help="citation kept in frontmatter: ISBN, publisher URL, etc.")
    p.add_argument("--resonance", default="med", choices=["high", "med", "low"])
    p.add_argument("--selftest", action="store_true", help=argparse.SUPPRESS)
    args = p.parse_args()

    if args.selftest:
        _selftest()
        return
    if not (args.epub and args.author and args.title):
        p.error("epub, --author and --title are required")

    epub = Path(args.epub)
    if not epub.is_file():
        sys.exit(f"error: no such file: {epub}")

    stem = _stem(args.author, args.title)
    if not stem:
        sys.exit(f"error: author '{args.author}' + title '{args.title}' produce an empty slug "
                 "(non-Latin characters are stripped). Use ASCII author/title values.")

    try:
        body, chapters = extract_epub(epub)
    except (zipfile.BadZipFile, ET.ParseError, ValueError, KeyError) as e:
        sys.exit(f"error: could not parse EPUB {epub}: {type(e).__name__}: {e}")
    if not body:
        sys.exit(f"error: no text extracted from {epub} (DRM/encrypted, or no linear content?)")

    SOURCES.mkdir(exist_ok=True)
    out = SOURCES / f"{stem}.md"
    frontmatter = _build_frontmatter(
        args.author, args.title, args.type,
        args.source or f"book: {args.author}, {args.title}",
        f"chapters: {chapters}\n", date.today().isoformat(), args.resonance,
    )
    out.write_text(frontmatter + body + "\n", encoding="utf-8")
    print(f"wrote {out.relative_to(SOURCES.parent)} ({len(body.split())} words, {chapters} chapters)")


if __name__ == "__main__":
    main()
