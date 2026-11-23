#!/bin/sh
# Beat merge pass (ENG-2126 S4). The pins hold the beat skill's merge pass:
# it runs `sh <scripts>/merge.sh --unwatched` after the record check and
# before the window read, needs no yes because the ### Merge list is the
# user's standing yes, appends each merged line first exactly as printed (tag
# kept), never replies `No change.` after a merge, names the bookkeeping after
# a merge as its one smallest move without doing it, and re-holds an untagged
# held wait that moved (ADR-4). MY1-MY6 run the skill's own merge line, the
# plugin root replaced by a staged tree, against the fake gh of
# tests/merge-fixture.sh, and write its lines with the constitution's snippet.
# BEAT_SKILL, PRELUDE_SH and CONST_FILE override the targets for replay.
# Silent on pass apart from PASS.
set -u
unset CLUTCH_MERGE_WAIT MERGE_SH CLUTCH_WATCH CLUTCH_BEAT CLUTCH_POLL_SLEEP CLAUDE_PLUGIN_ROOT

HERE=$(cd "$(dirname "$0")" && pwd)
BS=${BEAT_SKILL:-$HERE/../skills/beat/SKILL.md}
P=${PRELUDE_SH:-$HERE/../scripts/prelude.sh}
K=${CONST_FILE:-$HERE/../rules/constitution.md}
for f in "$BS" "$P" "$K" "$HERE/../scripts/merge.sh"; do [ -f "$f" ] || { echo "FAIL: missing $f"; exit 1; }; done
[ -x /usr/bin/jq ] || { echo "FAIL: /usr/bin/jq missing"; exit 1; }

T=$(mktemp -d) || exit 1
trap 'mf_stop; chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
HOME=$T/home
export HOME
mkdir -p "$HOME" "$T/scripts" "$T/plain"
cp "$P" "$T/scripts/prelude.sh"
cp "$HERE/../scripts/merge.sh" "$T/scripts/merge.sh"
. "$HERE/merge-fixture.sh"
mf_init || exit 1
fail=0
F() { echo "FAIL: $*"; fail=1; }

# --- pins
fpin() { grep -qF -- "$2" "$BS" || F "$1 -- missing: $2"; }
MCMD='sh "${CLAUDE_PLUGIN_ROOT}/scripts/merge.sh" --unwatched'
fpin "MY-pin intro"     'Then run the merge pass, before the read.'
fpin "MY-pin no yes"    'It needs no yes: the `### Merge` list is the user'"'"'s standing yes for this merge; every other outward action still waits for its usual yes.'
fpin "MY-pin line"      "$MCMD"
fpin "MY-pin merged"    'Append each `merged` line first, exactly as printed, its tag kept when it has one, as the text of a `moved:` line with the constitution'"'"'s worklog snippet: the merge pass'"'"'s lines keep their tag, so a dead tag'"'"'s line closes only that tag'"'"'s wait.'
fpin "MY-pin not merged" 'Name a `did not merge` line once and write nothing for it.'
fpin "MY-pin held"      'Keep the `held` lines in view for the read.'
fpin "MY-pin empty"     'Exit status 0 with no output: nothing merged.'
fpin "MY-pin other"     'Any other outcome: say once that the merge pass cannot run.'
fpin "MY-pin bookkeeping" 'A merged PR is what moved: its one smallest move is the bookkeeping after a merge, such as the ticket, named and not done, since it waits for its usual yes.'
fpin "MY-pin ADR-4"     'The one exception: an untagged wait the merge pass printed `held` for that also moved gets a fresh untagged `wait:` line right after its `moved:` line, text `<kind>:<ref> <new baseline> <text>`.'
grep -F 'means nothing to read: reply `No change.`' "$BS" | grep -qF 'With the merge pass'"'"'s `merged` lines, that is not `No change.`' \
  || F "MY-pin line 33 -- the merge sentence is not on BT7's line"
grep -F 'A beat never holds a wait again and never removes itself while its ops record is there: it ends with the session.' "$BS" | grep -qF 'The one exception: an untagged wait' \
  || F "MY-pin ADR-4 -- the exception is not on BT11's line"
BSJ=$(tr -s '[:space:]' ' ' < "$BS")
case $BSJ in *'clutch_ops_record'*'merge.sh" --unwatched'*'clutch_beat_window'*'means nothing to read'*) ;;
  *) F "MY-order -- want record check, merge line, window line, then the empty-read rule" ;; esac
# The beat's other readers must still find exactly what they find today.
[ "$(grep -cF 'verb `moved:` and text `' "$BS")" = 1 ] || F "MY-guard -- the moved template phrase is not unique"
grep -qF '<kind>:<ref> @<tag>' "$BS" && F "MY-guard -- a tagged moved: or wait: template"
[ "$(grep -cF 'sh -c' "$BS")" = 2 ] || F "MY-guard -- want the two sh -c lines only"
case $BSJ in *'never removes itself: it ends'*) F "MY-guard -- never removes itself: it ends" ;; esac
grep -iqE 'aipaper|launchd|daemon|schedul|cron|nightly|overnight|auto-trigger' "$BS" && F "MY-guard -- a banned word"
[ "$(grep -c '' "$BS")" -lt 60 ] || F "MY-guard -- beat skill is $(grep -c '' "$BS") lines"

# --- execution: the skill's own merge line
LINE=$(grep -F 'scripts/merge.sh" --unwatched' "$BS")
[ "$(printf '%s\n' "$LINE" | grep -c .)" = 1 ] || { F "MY -- want one merge line, got [$LINE]"; echo "FAIL"; exit 1; }
CMD=$(printf '%s\n' "$LINE" | RA='${CLAUDE_PLUGIN_ROOT}' RB="$T" awk '{ i = index($0, ENVIRON["RA"])
  if (i) $0 = substr($0, 1, i - 1) ENVIRON["RB"] substr($0, i + length(ENVIRON["RA"])); print }')
[ "$CMD" != "$LINE" ] || F "MY -- no plugin root to fill in: $LINE"
# run [<shell>]: the line, from a non-git dir, fake gh first; OUT RC NGH.
run() { mf_log0; OUT=$(cd "$T/plain" && PATH=$MF_PATH ${1:-sh} -c "$CMD" 2>&1); RC=$?; NGH=$(mf_ngh); }
# snip <text>: the constitution's snippet writes "moved: <text>".
snip() {
  awk '/```sh/{n++; f=1; next} /```/{f=0} f && n == 1' "$K" | CV='moved:' CX=$1 awk '
    function rl(s, a, b,   i) { i = index(s, a); return i ? substr(s, 1, i - 1) b substr(s, i + length(a)) : s }
    { $0 = rl($0, "<moved:|on:>", ENVIRON["CV"]); print rl($0, "<one line>", ENVIRON["CX"]) }' > "$T/snip.sh"
  (cd "$T/plain" && sh "$T/snip.sh" >/dev/null 2>&1)
}
loops() { (cd "$T/plain" && . "$T/scripts/prelude.sh" && clutch_open_loops); }
# isopen <ref> [<@tag>]: an open wait on the ref, with that tag (or untagged).
isopen() { loops | awk -v r="$1" -v t="${2-}" '$4 == r && (t == "" ? $6 !~ /^@/ : $6 == t) { f = 1 } END { exit !f }'; }
want() { [ "$RC" = 0 ] && [ "$OUT" = "$2" ] || F "$1 -- rc $RC [$OUT], want rc 0 [$2]"; }

# MY1: no merge list, parity with 2.18.2: nothing printed, no gh call.
SHELLS=sh; command -v zsh >/dev/null 2>&1 && SHELLS="sh zsh" || echo "SKIP: MY1 zsh (no zsh)"
for s in $SHELLS; do
  [ "$s" = zsh ] && r='zsh -f' || r=sh
  mf_reset; mf_pr acme web 7; mf_wait 100 'gh:acme/web#7'
  run "$r"; want "MY1 $s no list" ''; [ "$NGH" = 0 ] || F "MY1 $s -- gh called $NGH times"
done

# MY2: an untagged ready wait merges; its line written as moved: closes it.
mf_reset; mf_list '- acme/web'; mf_pr acme web 7; mf_wait 100 'gh:acme/web#7'
run; want "MY2" 'gh:acme/web#7 merged'
isopen 'gh:acme/web#7' || F "MY2 -- the wait was not open before the move"
snip "$OUT"; isopen 'gh:acme/web#7' && F "MY2 -- moved: [$OUT] left the untagged wait open"

# MY3: two dead tags on one ref: one merge, a line each; the first closes only its tag's wait.
mf_reset; mf_list '- acme/web'; mf_pr acme web 7
mf_wait 100 'gh:acme/web#7' @0123abcd; mf_wait 90 'gh:acme/web#7' @4567cdef; mf_dead @0123abcd; mf_dead @4567cdef
run; want "MY3" 'gh:acme/web#7 @0123abcd merged
gh:acme/web#7 @4567cdef merged'
[ "$(mf_merges | grep -c .)" = 1 ] || F "MY3 -- merge calls [$(mf_merges)]"
snip "$(printf '%s\n' "$OUT" | head -n 1)"
isopen 'gh:acme/web#7' @0123abcd && F "MY3 -- @0123abcd's wait still open"
isopen 'gh:acme/web#7' @4567cdef || F "MY3 -- @4567cdef's wait closed by the other tag's line"

# MY3b: a live tag waits on the same ref: no line, no gh; the live wait stays open.
mf_reset; mf_list '- acme/web'; mf_pr acme web 7
mf_wait 100 'gh:acme/web#7' @0123abcd; mf_wait 90 'gh:acme/web#7' @89ab0123; mf_dead @0123abcd; mf_live @89ab0123
run; want "MY3b" ''; [ "$NGH" = 0 ] || F "MY3b -- gh called $NGH times"
isopen 'gh:acme/web#7' @89ab0123 || F "MY3b -- the live tag's wait is not open"

# MY4: an untagged held wait that moved: moved:, then the skill's re-hold wait:, keeps it open.
mf_reset; mf_list '- acme/web'; mf_pr acme web 7 "$MF_P.mergeStateStatus = \"BLOCKED\""; mf_wait 100 'gh:acme/web#7'
run; want "MY4" 'gh:acme/web#7 held'
WT=$(sed -n 's/.*fresh untagged `wait:` line.*text `\([^`]*\)`.*/\1/p' "$BS" | head -n 1)
[ -n "$WT" ] || F "MY4 -- no re-hold wait: template"
WF=$(printf '%s\n' "$WT" | sed 's|<kind>:<ref>|gh:acme/web#7|; s|<new baseline>|2026-11-23T10:00:00Z|; s|<text>|pr|')
snip 'gh:acme/web#7 approved'
isopen 'gh:acme/web#7' && F "MY4 -- the moved: line left the wait open"
awk '/```sh/{n++; f=1; next} /```/{f=0} f && n == 1' "$K" | CX=$WF awk '
  function rl(s, a, b,   i) { i = index(s, a); return i ? substr(s, 1, i - 1) b substr(s, i + length(a)) : s }
  { $0 = rl($0, "<moved:|on:>", "wait:"); print rl($0, "<one line>", ENVIRON["CX"]) }' > "$T/wsnip.sh"
(cd "$T/plain" && sh "$T/wsnip.sh" >/dev/null 2>&1)
isopen 'gh:acme/web#7' || F "MY4 -- the re-hold [$WF] does not keep an untagged wait open"

# MY5: a failed merge is named once over two runs.
mf_reset; mf_list '- acme/web'; mf_pr acme web 7; mf_wait 100 'gh:acme/web#7'; echo 1 > "$MFIX/mergerc"
run; O1=$OUT; run; O2=$OUT
[ "$(printf '%s\n%s\n' "$O1" "$O2" | grep -c 'did not merge$')" = 1 ] && [ "$O1" = 'gh:acme/web#7 did not merge' ] \
  || F "MY5 -- runs [$O1] [$O2], want did not merge once"

# MY6: only a dead tag's ready wait, the beat's own record there: merged, then the read is empty.
mf_reset; mf_list '- acme/web'; mf_pr acme web 7; mf_wait 100 'gh:acme/web#7' @0123abcd; mf_dead @0123abcd
printf 'last %s\n' "$(($(date +%s) - 3600))" > "$HOME/.clutch/watch/fedc9876.beat"
run; want "MY6 merge" 'gh:acme/web#7 @0123abcd merged'
snip "$OUT"
RL=$(grep -F 'sh -c' "$BS" | grep -F 'clutch_beat_window')
RC2=$(printf '%s\n' "$RL" | RA='${CLAUDE_PLUGIN_ROOT}' RB="$T" awk '{ i = index($0, ENVIRON["RA"])
  if (i) $0 = substr($0, 1, i - 1) ENVIRON["RB"] substr($0, i + length(ENVIRON["RA"])); print }' | sed 's/@<tag>/@fedc9876/')
OUT=$(cd "$T/plain" && sh -c "$RC2" 2>&1); RC=$?
want "MY6 read" ''

[ "$fail" -eq 0 ] || exit 1
echo PASS
