#!/bin/sh
# The watch skill's merge pass (ENG-2126 S3). Pins: the merge pass intro
# with its no-yes sentence (the ### Merge list is the user's standing yes for
# this merge only), the one merge.sh line, the outcome lines (a merged line
# is the wait's move, W6's bookkeeping applies) and the line-13 text. MW1-MW4
# run the skill's own merge line, the plugin root replaced by a staged tree
# and @<tag> filled, against the fake gh of tests/merge-fixture.sh: MW1 with
# no merge list prints nothing, exits 0 and calls no gh (under sh and zsh
# -f); MW2 merged and held; MW3 the merged line, written through the
# constitution's snippet as moved: text, closes that tag's wait only, also
# for a mixed-case ref; MW4 a failed merge is named once over two runs.
# WATCH_SKILL and CONST_FILE override the targets for replay. Silent on pass
# apart from PASS.
set -u
unset CLUTCH_MERGE_WAIT MERGE_SH CLUTCH_WATCH CLUTCH_BEAT CLUTCH_POLL_SLEEP CLAUDE_PLUGIN_ROOT

HERE=$(cd "$(dirname "$0")" && pwd)
WS=${WATCH_SKILL:-$HERE/../skills/watch/SKILL.md}
K=${CONST_FILE:-$HERE/../rules/constitution.md}
[ -f "$WS" ] || { echo "FAIL: missing $WS"; exit 1; }
[ -x /usr/bin/jq ] || { echo "FAIL: /usr/bin/jq missing"; exit 1; }

T=$(mktemp -d) || exit 1
trap 'mf_stop; chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
HOME=$T/home
export HOME
mkdir -p "$HOME" "$T/scripts" "$T/plain"
cp "$HERE/../scripts/prelude.sh" "$HERE/../scripts/merge.sh" "$T/scripts/" || exit 1
. "$HERE/merge-fixture.sh"
mf_init || exit 1
fail=0

# fpin <file> <label> <fixed string>: rc 0 passes, 1 is a missing pin, >=2 a grep error.
fpin() {
  grep -qF -- "$3" "$1"
  case $? in
    0) ;;
    1) echo "FAIL: $2 -- text not found: $3"; fail=1 ;;
    *) echo "FAIL: $2 -- grep error: $3"; fail=1 ;;
  esac
}

fpin "$WS" "MWP1 merge pass intro"    'Then run the merge pass. This merge needs no yes: the `### Merge` list is your standing yes for it; every other outward action still waits for its usual yes. Run this line, `@<tag>` replaced by the argument:'
fpin "$WS" "MWP2 no-yes sentence"     'This merge needs no yes: the `### Merge` list is your standing yes for it; every other outward action still waits for its usual yes.'
fpin "$WS" "MWP3 merge line"          'sh "${CLAUDE_PLUGIN_ROOT}/scripts/merge.sh" "@<tag>"'
fpin "$WS" "MWP4 outcome lines"       'It prints at most one line per owned wait: `<ref> @<tag> merged`, `<ref> @<tag> did not merge` or `<ref> @<tag> held`.'
fpin "$WS" "MWP5 merged is a move"    "A \`merged\` line is that wait's move: append its \`moved:\` line first, with the constitution's worklog snippet, verb \`moved:\` and the line exactly as printed as its text, and do not read that wait again."
fpin "$WS" "MWP6 W6 bookkeeping"      "Being a move, it gets the session's own standing rules like any merge, such as the bookkeeping after a merge; an outward step there still waits for its usual yes."
fpin "$WS" "MWP7 did not merge, held" 'A `did not merge` line is named once and writes nothing; a `held` line needs nothing.'
MWP7B='A `did not merge` line or the cannot-run line is part of the reply even when nothing else moved, so that reply is not `No change.`'
fpin "$WS" "MWP7b reply is not No change" "$MWP7B"
MWP8='Exit status 0 with no output means nothing merged. Any other outcome: say once that the merge pass cannot run, and stay silent about it on later ticks.'
fpin "$WS" "MWP8 cannot run"          "$MWP8"
# MWP7c: the did-not-merge rule, the cannot-run rule and the reply rule share one physical line.
A='A `did not merge` line is named once and writes nothing' B=$MWP8 C=$MWP7B awk '
  index($0, ENVIRON["A"]) && index($0, ENVIRON["B"]) && index($0, ENVIRON["C"]) { f = 1 }
  END { exit !f }' "$WS" || { echo "FAIL: MWP7c did-not-merge, cannot-run and reply rules not on one line"; fail=1; }
fpin "$WS" "MWP9 line 13"             'It is not an ops tick: no sweep, and no config read beyond the `### Merge` list its merge pass checks.'

# rl1 <string> <from> <to>: the first <from> replaced by <to>, literally.
rl1() {
  printf '%s\n' "$1" | RA=$2 RB=$3 awk '{ i = index($0, ENVIRON["RA"])
    if (i) $0 = substr($0, 1, i - 1) ENVIRON["RB"] substr($0, i + length(ENVIRON["RA"]))
    print }'
}
# csnip <verb> <text> <out>: the constitution's worklog snippet filled.
csnip() {
  awk '/```sh/{n++; f=1; next} /```/{f=0} f && n == 1' "$K" | CV=$1 CX=$2 awk '
    function rl(s, a, b,   i) { i = index(s, a); return i ? substr(s, 1, i - 1) b substr(s, i + length(a)) : s }
    { $0 = rl($0, "<moved:|on:>", ENVIRON["CV"]); print rl($0, "<one line>", ENVIRON["CX"]) }' > "$3"
}
# owned <@tag>: that tag's open waits.
owned() { (cd "$T/plain" && . "$T/scripts/prelude.sh" && clutch_owned_loops "$1"); }

ML=$(grep -F 'scripts/merge.sh' "$WS" | grep '^sh ')
if [ "$(printf '%s\n' "$ML" | grep -c .)" != 1 ]; then
  echo "FAIL: MW1-MW4 want exactly one sh line running scripts/merge.sh in the watch skill, got: $ML"
  exit 1
fi
MCMD=$(rl1 "$(rl1 "$ML" '${CLAUDE_PLUGIN_ROOT}' "$T")" '@<tag>' '@0123abcd')
[ "$MCMD" != "$ML" ] || { echo "FAIL: MW -- nothing to fill in: $ML"; exit 1; }

# wm [shell]: the skill's merge line from a plain dir, the fake gh first on
# PATH; OUT (stdout), ERR, RC, NGH.
wm() {
  mf_log0
  OUT=$(cd "$T/plain" && PATH=$MF_PATH ${1:-sh} -c "$MCMD" 2>"$T/err"); RC=$?
  ERR=$(cat "$T/err"); NGH=$(mf_ngh)
}
# is <label> <rc> <stdout> <gh calls>
is() {
  [ "$RC" = "$2" ] && [ "$OUT" = "$3" ] && [ -z "$ERR" ] && [ "$NGH" = "$4" ] \
    || { echo "FAIL: $1 -- rc $RC stdout [$OUT] stderr [$ERR] gh $NGH, want rc $2 stdout [$3] gh $4"; fail=1; }
}

# --- MW1: no merge list, an owned gh wait in a repo with a ready PR: rc 0,
# nothing printed, no gh call (2.18.2 parity).
SHELLS=sh
if command -v zsh >/dev/null 2>&1; then SHELLS="sh zsh"; else echo "SKIP: MW1 zsh (no zsh)"; fi
for sh in $SHELLS; do
  [ "$sh" = zsh ] && run="zsh -f" || run=sh
  mf_reset; mf_pr acme web 7; mf_wait 500 'gh:acme/web#7' '@0123abcd'
  wm "$run"; is "MW1 $sh no rituals.md" 0 '' 0
  printf '## Ops\n\n### Windows\n- 9:00\n' > "$HOME/.clutch/rituals.md"
  wm "$run"; is "MW1 $sh no ### Merge" 0 '' 0
done

# --- MW2: listed and ready merges; listed and not CLEAN is held.
mf_reset; mf_list '- acme/web'; mf_pr acme web 7; mf_wait 500 'gh:acme/web#7' '@0123abcd'
wm; is "MW2 ready" 0 'gh:acme/web#7 @0123abcd merged' 3
mf_reset; mf_list '- acme/web'; mf_pr acme web 7 "$MF_P.mergeStateStatus = \"BLOCKED\""; mf_wait 500 'gh:acme/web#7' '@0123abcd'
WB=$(cat "$HOME/.clutch/worklog.md")
wm; is "MW2 not CLEAN" 0 'gh:acme/web#7 @0123abcd held' 1
[ "$(cat "$HOME/.clutch/worklog.md")" = "$WB" ] || { echo "FAIL: MW2 held -- the worklog changed"; fail=1; }

# --- MW3: the merged line, as printed, written as moved: text through the
# constitution's snippet, closes that tag's wait and leaves another tag's wait
# on the same ref open; the same for a mixed-case ref.
for ref in 'gh:acme/web#7' 'gh:Acme/Web#7'; do
  o=${ref#gh:}; o=${o%%/*}; r=${ref#*/}; r=${r%%#*}
  mf_reset; mf_list '- acme/web'; mf_pr "$o" "$r" 7
  mf_wait 500 "$ref" '@0123abcd'; mf_wait 400 "$ref" '@89abcdef'
  wm; is "MW3 $ref merge" 0 "$ref @0123abcd merged" 3
  [ -n "$OUT" ] || continue
  csnip 'moved:' "$OUT" "$T/mw3.sh"
  (cd "$T/plain" && sh "$T/mw3.sh" >/dev/null 2>&1)
  grep -qF "moved: $ref @0123abcd merged" "$HOME/.clutch/worklog.md" || { echo "FAIL: MW3 $ref -- no moved: line written"; fail=1; }
  [ -z "$(owned '@0123abcd')" ] || { echo "FAIL: MW3 $ref -- the merged line left the tag's wait open: $(owned '@0123abcd')"; fail=1; }
  owned '@89abcdef' | grep -qF " $ref " || { echo "FAIL: MW3 $ref -- the other tag's wait was closed"; fail=1; }
done

# --- MW4: a failed merge is named once over two runs.
mf_reset; mf_list '- acme/web'; mf_pr acme web 7; mf_wait 500 'gh:acme/web#7' '@0123abcd'
echo 1 > "$MFIX/mergerc"
wm; is "MW4 first run" 0 'gh:acme/web#7 @0123abcd did not merge' 3
wm; is "MW4 second run" 0 'gh:acme/web#7 @0123abcd held' 1

[ "$fail" -eq 0 ] || exit 1
echo PASS
