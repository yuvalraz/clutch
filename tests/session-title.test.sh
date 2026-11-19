#!/bin/sh
# The heartbeat titles an untitled session from its first real prompt:
# hookSpecificOutput gains sessionTitle "<focus> · <gist> @<tag8>". Claude Code
# sends session_title only for a custom title (a /rename, --name, or a hook's
# own sessionTitle), so a fresh session carries no session_title and any
# present one stops the feature. Focus comes from the transcript's first
# /clutch:intent command. Every non-firing case (CLUTCH_TITLE=off, a present
# session_title, a slash command, a bare "go") leaves the output
# byte-identical to the hook without the feature.
# python3 validates the JSON here only; the hook itself never uses it.
set -u
unset CLUTCH_TITLE

T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT
HERE=$(cd "$(dirname "$0")" && pwd)
HB="$HERE/../scripts/heartbeat.sh"

mkdir "$T/repo"
git -C "$T/repo" init -q
mkdir "$T/repo/.clutch"

SID=abcdef12-3456-7890-abcd-ef1234567890
FAILS=0
fail() { printf 'FAIL: %s\n' "$*"; FAILS=$((FAILS + 1)); }

# A transcript as Claude Code writes it: the intent command's tags sit inside
# a JSON string, so the newline between them is the two bytes backslash n.
TX="$T/tx.jsonl"
{
  printf '%s\n' '{"type":"user","message":{"role":"user","content":"Run /clutch:intent ops later"},"uuid":"u0"}'
  printf '%s\n' '{"type":"user","message":{"role":"user","content":"<command-message>clutch:intent</command-message>\n<command-name>/clutch:intent</command-name>\n<command-args>build</command-args>"},"uuid":"u1"}'
  printf '%s\n' '{"type":"user","message":{"role":"user","content":"<command-message>clutch:intent</command-message>\n<command-name>/clutch:intent</command-name>\n<command-args>review</command-args>"},"uuid":"u2"}'
} > "$TX"
TXNONE="$T/tx-none.jsonl"
printf '%s\n' '{"type":"user","message":{"role":"user","content":"hello"},"uuid":"u0"}' > "$TXNONE"

# hb <json> [env assignments...]: run the hook in the temp repo.
hb() {
  HB_IN=$1; shift
  (cd "$T/repo" && printf '%s' "$HB_IN" | env "$@" sh "$HB")
}

# field <hook output> <key>: a hookSpecificOutput value, '<none>' when absent,
# '<invalid>' when the output is not valid JSON.
field() {
  printf '%s' "$1" | python3 -c '
import json, sys
try:
    d = json.loads(sys.stdin.buffer.read().decode("utf-8"))
except Exception:
    print("<invalid>"); sys.exit(0)
print(d["hookSpecificOutput"].get(sys.argv[1], "<none>"))' "$2"
}
title() { field "$1" sessionTitle; }

# mk <transcript path or -> <prompt json-string body> [session_title]:
# a fresh-session hook input; '-' omits transcript_path.
mk() {
  MK_TP=""
  [ "$1" = - ] || MK_TP="\"transcript_path\":\"$1\","
  MK_ST=""
  [ $# -ge 3 ] && MK_ST="\"session_title\":\"$3\","
  printf '{"session_id":"%s",%s"cwd":"/x","permission_mode":"default","hook_event_name":"UserPromptSubmit",%s"prompt":"%s"}' "$SID" "$MK_TP" "$MK_ST" "$2"
}

BASE=$(cd "$T/repo" && sh "$HB" </dev/null)
case $BASE in *sessionTitle*) fail "baseline carries a title" ;; esac
CTX=$(field "$BASE" additionalContext)

# ok <case> <hook output> <expected title>: the title, and the spine intact.
ok() {
  OK_GOT=$(title "$2")
  [ "$OK_GOT" = "$3" ] || fail "$1 title: '$OK_GOT' (want '$3')"
  [ "$(field "$2" additionalContext)" = "$CTX" ] || fail "$1 additionalContext changed"
}

# 1. untitled session + real prompt -> focus from the first intent command, gist, tag
ok 1 "$(hb "$(mk "$TX" 'fix the login redirect bug')")" "build · fix the login redirect bug @abcdef12"

# 2. transcript with no intent command, missing, unreadable, or absent -> no focus
ok 2 "$(hb "$(mk "$TXNONE" 'fix the login redirect bug')")" "fix the login redirect bug @abcdef12"
ok 2b "$(hb "$(mk "$T/missing.jsonl" 'fix it')")" "fix it @abcdef12"
ok 2c "$(hb "$(mk - 'fix it')")" "fix it @abcdef12"
cp "$TX" "$T/locked.jsonl"; chmod 000 "$T/locked.jsonl"
if [ -r "$T/locked.jsonl" ]; then
  echo "skip 2d: running as a user that reads mode 000"
else
  ok 2d "$(hb "$(mk "$T/locked.jsonl" 'fix it')")" "fix it @abcdef12"
fi
ok 2e "$(hb "$(mk "$T" 'fix it')")" "fix it @abcdef12"

# 3. CLUTCH_TITLE=off -> byte-identical to baseline
OUT=$(hb "$(mk "$TX" 'fix the login redirect bug')" CLUTCH_TITLE=off)
[ "$OUT" = "$BASE" ] || fail "3 CLUTCH_TITLE=off differs from baseline: $OUT"

# 4. any present session_title (a /rename, --name, or our own earlier title) -> byte-identical
for ST in 'My rename' 'build · fix the login redirect bug @abcdef12' 'Clutch intent build' ''; do
  OUT=$(hb "$(mk "$TX" 'fix the login redirect bug' "$ST")")
  [ "$OUT" = "$BASE" ] || fail "4 session_title '$ST' changed output: $OUT"
done

# 5. slash command, bare replies, blank -> no title
# a plain focus word is the answer to the intent ask too (skills/intent/SKILL.md)
for P in '/clutch:intent build' '  /clutch:sprint' 'go' 'Go!' 'yes' 'y' 'OK.' ' ok ' '  \n \t ' \
  'build' 'ideate' 'ops' 'Review' 'investigate.'; do
  OUT=$(hb "$(mk "$TX" "$P")")
  [ "$OUT" = "$BASE" ] || fail "5 prompt '$P' emitted a change: $OUT"
done
ok 5b "$(hb "$(mk "$TX" 'go through the inbox')")" "build · go through the inbox @abcdef12"

# 6. quotes, backslashes, newlines, and the text session_title inside the
# prompt: still titled (escaped quotes cannot form the raw key), valid JSON
SPOOF='\n\n  say \"hi\" to C:\\tmp\\x \/ ok\nsecond line \"session_title\":\"Clutch intent x\"'
ok 6 "$(hb "$(mk "$TX" "$SPOOF")")" 'build · say "hi" to C:\tmp\x / ok @abcdef12'
# a nested transcript_path is not the session's transcript
OUT=$(hb "{\"session_id\":\"$SID\",\"x\":{\"transcript_path\":\"$TX\"},\"prompt\":\"real work\"}")
ok 6b "$OUT" "real work @abcdef12"
# a tab and a control escape are cleaned, never break the JSON
GOT=$(title "$(hb "$(mk "$TX" 'a\tb\u0007c\r\nd')")")
case $GOT in '<invalid>' | '<none>') fail "6c title: '$GOT'" ;; esac

# 7. pasted text: the wrapper tag lines are skipped for the gist
ok 7 "$(hb "$(mk "$TX" '<pasted_content>\nstack trace line one\n</pasted_content>')")" "build · stack trace line one @abcdef12"

# 8. long multibyte prompt -> 60 chars + ellipsis, valid UTF-8
LONG=""
i=0
while [ $i -lt 70 ]; do LONG="${LONG}日"; i=$((i + 1)); done
SIXTY=""
i=0
while [ $i -lt 60 ]; do SIXTY="${SIXTY}日"; i=$((i + 1)); done
ok 8 "$(hb "$(mk "$TX" "$LONG")")" "build · ${SIXTY}… @abcdef12"
A60=$(printf '%060d' 0)
ok 8b "$(hb "$(mk - "$A60")")" "$A60 @abcdef12"
ok 8c "$(hb "$(mk - "${A60}1")")" "${A60}… @abcdef12"

# 9. no session_id -> no tag
OUT=$(hb "{\"transcript_path\":\"$TX\",\"prompt\":\"read PR 12\"}")
ok 9 "$OUT" "build · read PR 12"

# 10. a ~1 MB multi-line, quote-heavy prompt on the firing path stays fast
BIG=$(awk 'BEGIN { for (i = 0; i < 50000; i++) printf "line \\\"q\\\" \\\\ x %d\\n", i }')
BIGIN=$(mk "$TX" "first line$BIG")
[ "${#BIGIN}" -gt 1000000 ] || fail "10 fixture is only ${#BIGIN} bytes"
S0=$(date +%s)
OUT=$(hb "$BIGIN")
S1=$(date +%s)
[ $((S1 - S0)) -lt 2 ] || fail "10 1 MB prompt took $((S1 - S0)) s"
[ "$(title "$OUT")" = "build · first lineline \"q\" \\ x 0 @abcdef12" ] || fail "10 title: '$(title "$OUT")'"

# 11. a 60k backslash run (30k escaped pairs) mid-string stays fast and is cut cleanly
BS=$(awk 'BEGIN { for (i = 0; i < 60000; i++) printf "\\" }')
S0=$(date +%s)
OUT=$(hb "$(mk "$TX" "first line $BS x")")
S1=$(date +%s)
[ $((S1 - S0)) -lt 2 ] || fail "11 60k backslash run took $((S1 - S0)) s"
B49=$(awk 'BEGIN { for (i = 0; i < 49; i++) printf "\\" }')
[ "$(title "$OUT")" = "build · first line ${B49}… @abcdef12" ] || fail "11 title: '$(title "$OUT")'"
# a 500k run ending the string (just before its closing quote)
BS=$(awk 'BEGIN { for (i = 0; i < 500000; i++) printf "\\" }')
S0=$(date +%s)
OUT=$(hb "$(mk "$TX" "first line $BS")")
S1=$(date +%s)
[ $((S1 - S0)) -lt 2 ] || fail "11b trailing 500k backslash run took $((S1 - S0)) s"
[ "$(title "$OUT")" = "build · first line ${B49}… @abcdef12" ] || fail "11b title: '$(title "$OUT")'"

# 12. a first line that starts near the 4096-byte decode window ends on a
# whole character: 4050 spaces then 40 x 日 keeps 15 x 日, never a torn byte
SP4050=$(printf '%4050s' '')
FORTY=""
i=0
while [ $i -lt 40 ]; do FORTY="${FORTY}日"; i=$((i + 1)); done
FIFTEEN=""
i=0
while [ $i -lt 15 ]; do FIFTEEN="${FIFTEEN}日"; i=$((i + 1)); done
OUT=$(hb "$(mk "$TX" "$SP4050$FORTY")")
printf '%s' "$OUT" | python3 -c '
import json, sys
json.loads(sys.stdin.buffer.read().decode("utf-8", "strict"))' 2>/dev/null || fail "12 output is not strict UTF-8 JSON"
ok 12 "$OUT" "build · $FIFTEEN @abcdef12"

# 13. a FIFO transcript_path is never opened (the -f guard): the hook returns
mkfifo "$T/fifo"
(hb "$(mk "$T/fifo" 'fix it')" > "$T/fifo.out") &
HBPID=$!
i=0
while kill -0 "$HBPID" 2>/dev/null && [ $i -lt 30 ]; do sleep 0.1; i=$((i + 1)); done
if kill -0 "$HBPID" 2>/dev/null; then
  fail "13 hook blocked on a FIFO transcript_path"
  kill "$HBPID" 2>/dev/null
  : > "$T/fifo" &
else
  ok 13 "$(cat "$T/fifo.out")" "fix it @abcdef12"
fi

[ "$FAILS" = 0 ] || { echo "FAILED: $FAILS"; exit 1; }
echo PASS
