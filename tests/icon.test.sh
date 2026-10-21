#!/bin/sh
# Plugin icon: .claude-plugin/icon.png must be a square PNG, 512-2048 px a
# side, under 2 MB. `claude plugin validate --profile directory` only checks
# that an icon exists, so this test carries the size and shape check.
# ICON_FILE overrides the icon path. Fake PNG headers in $T are the controls:
# the bad ones must fail, a good one must pass (proves the parser reads sizes).
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
ICON_FILE=${ICON_FILE:-$ROOT/.claude-plugin/icon.png}

fail=0

check_icon() {
  [ -s "$1" ] || return 1
  info=$(file -b "$1")
  case $info in 'PNG image data, '*) ;; *) return 1 ;; esac
  set -- "$1" $(printf '%s\n' "$info" | sed -n 's/^PNG image data, \([0-9]*\) x \([0-9]*\),.*/\1 \2/p')
  [ $# -eq 3 ] || return 1
  [ "$2" -eq "$3" ] || return 1
  [ "$2" -ge 512 ] && [ "$2" -le 2048 ] || return 1
  [ "$(wc -c < "$1")" -lt 2000000 ] || return 1
}

T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT

# fake_png <out> <w4> <h4>: a PNG signature + IHDR whose width/height are the
# given 4-byte big-endian octal escapes.
fake_png() {
  printf "\211PNG\r\n\032\n\000\000\000\015IHDR$2$3\010\006\000\000\000" > "$1"
}

# --- (i) the real icon
check_icon "$ICON_FILE" || { echo "FAIL: icon -- $ICON_FILE is not a square PNG of 512-2048 px under 2 MB"; fail=1; }

# --- (ii) negative controls: each must be rejected
fake_png "$T/wide.png" '\000\000\004\000' '\000\000\002\130'   # 1024x600
fake_png "$T/small.png" '\000\000\001\000' '\000\000\001\000'  # 256x256
printf 'not a png\n' > "$T/text.png"
for f in wide small text; do
  if check_icon "$T/$f.png"; then echo "FAIL: control $f.png was accepted"; fail=1; fi
done

# --- (iii) positive control: a 1024x1024 header is accepted
fake_png "$T/good.png" '\000\000\004\000' '\000\000\004\000'
check_icon "$T/good.png" || { echo "FAIL: control good.png (1024x1024) was rejected"; fail=1; }

[ "$fail" -eq 0 ] || exit 1
echo PASS
