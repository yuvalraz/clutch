#!/bin/sh
# The heartbeat renames a session that still carries the clutch auto-title
# ("Clutch intent build") once a real prompt arrives: hookSpecificOutput gains
# sessionTitle "<focus> · <gist> @<tag8>". Every other case (CLUTCH_TITLE=off,
# no session_title key, a user's own title, a slash command, a bare "go")
# leaves the output byte-identical to the hook without the feature.
# python3 validates the JSON here only; the hook itself never uses it.
set -u

T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT
HERE=$(cd "$(dirname "$0")" && pwd)
HB="$HERE/../scripts/heartbeat.sh"

mkdir "$T/repo"
git -C "$T/repo" init -q
mkdir "$T/repo/.clutch"

SID=abcdef12-3456-7890-abcd-ef1234567890
FAILS=0
fail() { echo "FAIL: $*"; FAILS=$((FAILS + 1)); }

# hb <json> [env assignments...]: run the hook in the temp repo.
hb() {
  HB_IN=$1; shift
  (cd "$T/repo" && printf '%s' "$HB_IN" | env "$@" sh "$HB")
}

# title <hook output>: the sessionTitle value, '<none>' when absent,
# '<invalid>' when the output is not valid JSON.
title() {
  printf '%s' "$1" | python3 -c '
import json, sys
try:
    d = json.loads(sys.stdin.buffer.read().decode("utf-8"))
except Exception:
    print("<invalid>"); sys.exit(0)
print(d["hookSpecificOutput"].get("sessionTitle", "<none>"))'
}

# mk <session_title or -> <prompt json-string body>: a hook input; '-' omits the key.
mk() {
  if [ "$1" = - ]; then
    printf '{"session_id":"%s","hook_event_name":"UserPromptSubmit","prompt":"%s"}' "$SID" "$2"
  else
    printf '{"session_id":"%s","hook_event_name":"UserPromptSubmit","session_title":"%s","prompt":"%s"}' "$SID" "$1" "$2"
  fi
}

BASE=$(cd "$T/repo" && sh "$HB" </dev/null)
case $BASE in *sessionTitle*) fail "baseline carries a title" ;; esac

# 1. auto-title + real prompt -> focus, gist, tag
OUT=$(hb "$(mk 'Clutch intent build' 'fix the login redirect bug')")
GOT=$(title "$OUT")
[ "$GOT" = "build · fix the login redirect bug @abcdef12" ] || fail "1 title: '$GOT'"

# 1b. colon shape, key after prompt, investigate focus
OUT=$(hb "{\"session_id\":\"$SID\",\"prompt\":\"why does the bell ring twice\",\"session_title\":\"Clutch:intent investigate focus\"}")
GOT=$(title "$OUT")
[ "$GOT" = "investigate · why does the bell ring twice @abcdef12" ] || fail "1b title: '$GOT'"

# 2. no focus word in the title -> no focus prefix
OUT=$(hb "$(mk 'Clutch intent mode' 'fix the login redirect bug')")
GOT=$(title "$OUT")
[ "$GOT" = "fix the login redirect bug @abcdef12" ] || fail "2 title: '$GOT'"

# 3. CLUTCH_TITLE=off -> byte-identical to baseline
OUT=$(hb "$(mk 'Clutch intent build' 'fix the login redirect bug')" CLUTCH_TITLE=off)
[ "$OUT" = "$BASE" ] || fail "3 CLUTCH_TITLE=off differs from baseline: $OUT"

# 4. no session_title key -> byte-identical
OUT=$(hb "$(mk - 'fix the login redirect bug')")
[ "$OUT" = "$BASE" ] || fail "4 absent session_title differs from baseline: $OUT"

# 5. user's own title -> untouched, byte-identical
OUT=$(hb "$(mk 'My rename' 'fix the login redirect bug')")
[ "$OUT" = "$BASE" ] || fail "5 'My rename' got output change: $OUT"
OUT=$(hb "$(mk 'build · fix the login redirect bug @abcdef12' 'next thing')")
[ "$OUT" = "$BASE" ] || fail "5b already-fixed title changed: $OUT"

# 6. slash command and bare replies -> no title
for P in '/clutch:intent build' '  /clutch:sprint' 'go' 'Go!' 'yes' 'y' 'OK.' ' ok '; do
  OUT=$(hb "$(mk 'Clutch intent ops' "$P")")
  [ "$OUT" = "$BASE" ] || fail "6 prompt '$P' emitted a change: $OUT"
done
# but a reply that is more than a bare word is a real prompt
OUT=$(hb "$(mk 'Clutch intent ops' 'go through the inbox')")
GOT=$(title "$OUT")
[ "$GOT" = "ops · go through the inbox @abcdef12" ] || fail "6b title: '$GOT'"

# 7. quotes, backslashes, newlines, and a spoofed key inside the prompt
SPOOF='\n\n  say \"hi\" to C:\\tmp\\x \/ ok\nsecond line \"session_title\":\"Clutch intent x\"'
OUT=$(hb "$(mk 'Clutch intent build' "$SPOOF")")
GOT=$(title "$OUT")
[ "$GOT" = 'build · say "hi" to C:\tmp\x / ok @abcdef12' ] || fail "7 title: '$GOT'"
OUT=$(hb "$(mk - "$SPOOF")")
[ "$OUT" = "$BASE" ] || fail "7b spoofed key with no real one changed output: $OUT"
OUT=$(hb "$(mk 'My rename' "$SPOOF")")
[ "$OUT" = "$BASE" ] || fail "7c spoofed key beat a real user title: $OUT"
# a nested (non-top-level) session_title is not the session's title
OUT=$(hb "{\"session_id\":\"$SID\",\"x\":{\"session_title\":\"Clutch intent build\"},\"prompt\":\"real work\"}")
[ "$OUT" = "$BASE" ] || fail "7d nested key was read as top-level: $OUT"
# a tab and a control escape are cleaned, never break the JSON
OUT=$(hb "$(mk 'Clutch intent build' 'a\tb\u0007c\r\nd')")
GOT=$(title "$OUT")
case $GOT in '<invalid>' | '<none>') fail "7e title: '$GOT'" ;; esac

# 8. long multibyte prompt -> 60 chars + ellipsis, valid UTF-8
LONG=""
i=0
while [ $i -lt 70 ]; do LONG="${LONG}日"; i=$((i + 1)); done
SIXTY=""
i=0
while [ $i -lt 60 ]; do SIXTY="${SIXTY}日"; i=$((i + 1)); done
OUT=$(hb "$(mk 'Clutch intent build' "$LONG")")
GOT=$(title "$OUT")
[ "$GOT" = "build · ${SIXTY}… @abcdef12" ] || fail "8 multibyte cut: '$GOT'"
# exactly 60 ASCII chars -> no ellipsis; 61 -> cut
A60=$(printf '%060d' 0)
OUT=$(hb "$(mk 'Clutch intent mode' "$A60")")
[ "$(title "$OUT")" = "$A60 @abcdef12" ] || fail "8b 60 chars: '$(title "$OUT")'"
OUT=$(hb "$(mk 'Clutch intent mode' "${A60}1")")
[ "$(title "$OUT")" = "${A60}… @abcdef12" ] || fail "8c 61 chars: '$(title "$OUT")'"

# 9. no session_id -> no tag
OUT=$(hb '{"session_title":"Clutch intent review","prompt":"read PR 12"}')
[ "$(title "$OUT")" = "review · read PR 12" ] || fail "9 no tag: '$(title "$OUT")'"

# 10. a blank prompt -> no title
OUT=$(hb "$(mk 'Clutch intent build' '  \n \t ')")
[ "$OUT" = "$BASE" ] || fail "10 blank prompt changed output: $OUT"

# every output above must be JSON with the spine intact
[ "$(title "$BASE")" = "<none>" ] || fail "baseline is not valid JSON"

[ "$FAILS" = 0 ] || { echo "FAILED: $FAILS"; exit 1; }
echo PASS
