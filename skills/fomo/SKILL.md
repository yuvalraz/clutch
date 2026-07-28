---
name: fomo
description: Capture a link or reference you're afraid to lose, one line, no processing. Use when the user says "fomo", "save this link", "tab I can't close", or hands over a URL with a one-line why.
disable-model-invocation: true
---

# Fomo

The tab you can't close is a capture waiting to happen. Fomo banks it in one
line — the link or thought plus the why — and moves on. No fetching, no
titles, no categories. Reading happens later, at absorption, when
`/clutch:delve` picks it up.

## Usage

- `/clutch:fomo <url>` — bank the link; the why rides in the same line
- `/clutch:fomo <url> #tag` — same, with a loose tag riding along
- `/clutch:fomo <free text>` — a thought or reference without a URL

## Procedure

1. Parse the input: a URL if one is present, a `#tag` if one appears, and
   everything else is the why. Do not fetch the page. Do not look up a
   title. The one line is the whole capture.

2. Append via the capture-shaped snippet, same honesty:

   ```sh
   ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo MISS no-work-tree; exit 0; }
   mkdir -p "$ROOT/.clutch" 2>/dev/null || { echo MISS no-write; exit 0; }
   printf '%s fomo: %s\n' "$(date +%s)" "<content and why, one line>" >> "$ROOT/.clutch/captures.md" && echo BANKED || echo MISS no-write
   ```

3. `BANKED`: acknowledge in one line, nothing more. `MISS`: say one honest
   line and repeat the capture back — it lives in the transcript instead of
   vanishing behind an ack.

Capture catches the leap mid-task; fomo catches the thing from outside — a
link, a reference, a tab. Both land in the same file, and `/clutch:delve`
absorbs both.

Why this works: see "The two doors" in [GLOSSARY.md](../../GLOSSARY.md). One
intake, two doors, zero friction.
