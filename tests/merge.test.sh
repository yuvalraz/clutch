#!/bin/sh
# Merge gate. MG1-MG6 cover the merge list (### Merge under ## Ops in
# ~/.clutch/rituals.md, read by clutch_merge_listed <owner>/<repo>: 0 listed,
# 1 not, 2 unreadable): with no list merge.sh prints nothing, exits 0 and
# calls no gh. MK1-MK22 (with MK3b and MK13b-MK13e) run scripts/merge.sh
# @<tag> against a fake gh that applies the real --jq filter to a per-PR
# GraphQL fixture through /usr/bin/jq: only an approved, CLEAN, open,
# non-draft PR of the viewer's own, into the default branch, in a repo that
# allows merge commits, is merged, with exactly
# "pr merge <n> --repo <o>/<r> --merge --match-head-commit <sha>"; the
# re-read decides merged / did not merge / held; a failure is recorded per
# (lowercased ref, sha) in ~/.clutch/watch/merge.failed and named once; every
# gh call is bounded by a 1 s nap watchdog (CLUTCH_MERGE_WAIT, default 60);
# stderr stays empty on every normal run. MU1-MU8 cover --unwatched and
# clutch_unwatched_loops (untagged waits and waits of tags whose silent check
# is not alive, minus refs a live or unknown tag also waits on). MR1-MR3
# cover --ready's return codes, bad arguments and the watchdog length. MA1
# checks every gh call of the whole suite for forbidden merge flags; ML1 that
# merge.sh writes nothing but merge.failed; MV1 that a ### Merge section
# leaves clutch_ops_due's window read alone. The series runs under sh and
# dash. prelude.sh and merge.sh are staged into a scratch tree and run under a
# scratch HOME. PRELUDE_SH and MERGE_SH override the targets for replay or a
# mutant copy. Silent on pass apart from PASS.
set -u
unset CLUTCH_MERGE_WAIT CLUTCH_WATCH CLUTCH_BEAT CLUTCH_POLL_SLEEP CLAUDE_PLUGIN_ROOT

HERE=$(cd "$(dirname "$0")" && pwd)
P=${PRELUDE_SH:-$HERE/../scripts/prelude.sh}
MS=${MERGE_SH:-$HERE/../scripts/merge.sh}
[ -f "$P" ] || { echo "FAIL: missing $P"; exit 1; }
[ -x /usr/bin/jq ] || { echo "FAIL: /usr/bin/jq missing"; exit 1; }

T=$(mktemp -d) || exit 1
# wdkill: the MK13e watchdog sleeps still running, by their unique path.
wdkill() { for p in $(ps -A -o pid=,args= | awk -v w="$T/wdsleep " 'index($0, w) { print $1 }'); do kill "$p" 2>/dev/null; done; }
trap 'mf_stop; wdkill; chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
HOME=$T/home
export HOME
mkdir -p "$HOME" "$T/scripts" "$T/plain"
cp "$P" "$T/scripts/prelude.sh"
cp "$MS" "$T/scripts/merge.sh" 2>/dev/null
. "$HERE/merge-fixture.sh"
mf_init || exit 1
W="$HOME/.clutch/worklog.md"
MFF="$HOME/.clutch/watch/merge.failed"
S=$MF_SHA
S2=89abcdef0123456789abcdef0123456789abcdef
M7="pr merge 7 --repo acme/web --merge --match-head-commit $S"
fail=0
ROOT=0; [ "$(id -u)" != 0 ] || ROOT=1

OUT=""; RC=0; ERR=""; NGH=0
SHL=sh
is() {
  [ "$RC" = "$2" ] && [ "$OUT" = "$3" ] \
    || { echo "FAIL: $SHL $1 -- rc $RC stdout [$OUT], want rc $2 stdout [$3]"; fail=1; }
}
# tree: every path under ~/.clutch with its checksum, to prove what a run wrote.
tree() { find "$HOME/.clutch" 2>/dev/null | sort | while read -r f; do [ -f "$f" ] && [ "$f" != "$MFF" ] && printf '%s\n' "$(cksum "$f" 2>/dev/null || echo "$f")" || printf '%s\n' "$f"; done; }
# mr <args>: run the staged merge.sh from a non-git dir with the fake gh first
# on PATH; OUT, RC, ERR, NGH. MSH the shell (sh), MWAIT CLUTCH_MERGE_WAIT,
# MPATH another PATH. ML1: nothing under ~/.clutch changes but merge.failed
# (and the watch dir it sits in).
mr() {
  mf_log0
  TB=$(tree)
  OUT=$(cd "$T/plain" && PATH="${MPATH:-$MF_PATH}" CLUTCH_MERGE_WAIT="${MWAIT:-}" "${MSH:-sh}" "$T/scripts/merge.sh" "$@" 2>"$T/err")
  RC=$?
  ERR=$(cat "$T/err")
  NGH=$(mf_ngh)
  TD=$(printf '%s\n--\n%s\n' "$TB" "$(tree)" | awk -v w="$HOME/.clutch/watch" '$0 == "--" { s = 1; next } !s { b[$0] = 1; next } !b[$0] && $0 != w && $0 != w "/merge.failed"')
  [ -z "$TD" ] || { echo "FAIL: $SHL ML1 merge.sh $* -- wrote [$TD]"; fail=1; }
}
# ok <label> <rc> <stdout> <gh calls>: is, plus empty stderr (MK22) and the gh count.
ok() {
  is "$1" "$2" "$3"
  [ -z "$ERR" ] || { echo "FAIL: $SHL $1 -- stderr [$ERR]"; fail=1; }
  [ "$NGH" = "$4" ] || { echo "FAIL: $SHL $1 -- gh called $NGH times, want $4"; fail=1; }
}
# merges <label> <want>: the pr merge calls of the last run, exactly.
merges() { [ "$(mf_merges)" = "$2" ] || { echo "FAIL: $SHL $1 -- merge calls [$(mf_merges)], want [$2]"; fail=1; }; }
# bad <label> <rc>: rc, empty stdout, one "merge.sh: " stderr line, no gh.
bad() {
  [ "$RC" = "$2" ] && [ -z "$OUT" ] && [ "$(printf '%s\n' "$ERR" | grep -c .)" = 1 ] && [ "$NGH" = 0 ] \
    && case $ERR in 'merge.sh: '*) true ;; *) false ;; esac \
    || { echo "FAIL: $SHL $1 -- rc $RC stdout [$OUT] stderr [$ERR] gh $NGH, want rc $2 and one merge.sh: line"; fail=1; }
}
# pf <fn> <args>: a prelude function under the series shell, from a non-git dir.
pf() { OUT=$(cd "$T/plain" && "${MSH:-sh}" -c '. "$1"; f=$2; shift 2; "$f" "$@"' x "$T/scripts/prelude.sh" "$@" 2>&1); RC=$?; }
failed() { cat "$MFF" 2>/dev/null; }
# one <label> <want>: merge.failed holds exactly that.
one() { [ "$(failed)" = "$2" ] || { echo "FAIL: $SHL $1 -- merge.failed [$(failed)], want [$2]"; fail=1; }; }
# base: a listed repo, a ready PR 7 and the tag's wait on it.
base() { mf_reset; mf_list '- acme/web'; mf_pr acme web 7 "$@"; mf_wait 100 'gh:acme/web#7' @0123abcd; }
# none <label> <jq update...>: a candidate check fails: no line, one read, no merge, --ready rc 3.
none() {
  NL=$1; shift
  base "$@"
  mr @0123abcd; ok "$NL" 0 '' 1; merges "$NL" ''
  mr --ready 'gh:acme/web#7'; ok "$NL --ready" 3 '' 1
}

series() {
  # --- MG1-MG6: the merge list
  k=0
  for rit in none '# R\n\n### Merge\n- acme/web\n' '## Ops\n\n### Windows\n- 11:00\n- acme/web\n' \
    '## Morning\n\n### Merge\n- acme/web\n\n## Ops\n\n### Windows\n- 11:00\n'; do
    mf_reset; mf_pr acme web 7; mf_wait 100 'gh:acme/web#7' @0123abcd; mf_wait 90 'gh:acme/web#8'
    [ "$rit" = none ] || printf "$rit" > "$HOME/.clutch/rituals.md"
    k=$((k + 1)); L="MG1-MG3 [case $k]"
    mr @0123abcd; ok "$L @tag" 0 '' 0
    mr --unwatched; ok "$L --unwatched" 0 '' 0
    mr --ready 'gh:acme/web#7'; ok "$L --ready" 1 '' 0
    pf clutch_merge_listed acme/web; is "$L listed" 1 ''
  done
  mf_reset; mf_list '- ACME/Web'
  pf clutch_merge_listed acme/web; is "MG4 case" 0 ''
  mf_pr acme web 7; mf_wait 100 'gh:acme/web#7' @0123abcd
  mr @0123abcd; ok "MG4 case run" 0 'gh:acme/web#7 @0123abcd merged' 3
  mf_reset
  printf '## Ops\n\n### Merge\n- acme/web  (no auto-merge here)\n- acme\n- acme/web/x\n- crlf/repo\r\n-  two/space\nfree/text\n### Other\n- after/merge\n## Ops\n- reopen/plain\n' > "$HOME/.clutch/rituals.md"
  for c in 'acme/web 0' 'ACME/WEB 0' 'crlf/repo 0' 'two/space 0' 'acme 1' 'acme/web/x 1' 'free/text 1' \
    'after/merge 1' 'reopen/plain 1' 'x/y 1' '- 1' '/ 1' 'a/ 1' '/b 1' 'a/b/c 1' 'acme/w*b 1' 'acme/we. 1'; do
    pf clutch_merge_listed "${c% *}"; is "MG5 [${c% *}]" "${c##* }" ''
  done
  pf clutch_merge_listed ''; is "MG5 empty" 1 ''
  if [ "$ROOT" = 0 ]; then
    base; chmod 000 "$HOME/.clutch/rituals.md"
    pf clutch_merge_listed acme/web; is "MG6 unreadable list" 2 ''
    mr @0123abcd; bad "MG6 @tag" 2
    mr --ready 'gh:acme/web#7'; bad "MG6 --ready" 2
    mf_wait 50 'gh:acme/web#9'; mr --unwatched; bad "MG6 --unwatched" 2
    chmod 644 "$HOME/.clutch/rituals.md"
    rm -f "$HOME/.clutch/rituals.md"; mkdir "$HOME/.clutch/rituals.md"
    pf clutch_merge_listed acme/web; is "MG6 list is a dir" 2 ''
  fi

  # --- MK: the ready read, the predicate and the merge
  base
  mr @0123abcd; ok "MK1 ready" 0 'gh:acme/web#7 @0123abcd merged' 3; merges "MK1" "$M7"
  R1=$(sed -n 1p "$MFIX/log")
  case $R1 in "api graphql -f query=query("*'latestOpinionatedReviews(last:100){nodes{state}} reviewDecision'*" -f o=acme -f r=web -F n=7 --jq "*) ;;
    *) echo "FAIL: $SHL MK1 -- read [$R1]"; fail=1 ;; esac
  case $R1 in *latestReviews*) echo "FAIL: $SHL MK1 -- read selects latestReviews"; fail=1 ;; esac
  [ "$(sort -u "$MFIX/cwd")" = / ] || { echo "FAIL: $SHL MK1 -- gh ran from [$(sort -u "$MFIX/cwd")], want /"; fail=1; }
  [ ! -e "$MFF" ] || { echo "FAIL: $SHL MK1 -- merge.failed written"; fail=1; }
  base; mr --ready 'gh:acme/web#7'; ok "MR1 ready" 0 "$S" 1
  none "MK2 draft" "$MF_P.isDraft = true"
  none "MK3 bot changes requested" "$MF_P.latestOpinionatedReviews.nodes = [{\"state\":\"APPROVED\"},{\"state\":\"CHANGES_REQUESTED\"}]"
  none "MK3b changes requested, then commented" "$MF_P.reviewDecision = null" \
    "$MF_P.latestOpinionatedReviews.nodes = [{\"state\":\"APPROVED\"},{\"state\":\"CHANGES_REQUESTED\"}]" \
    "$MF_P.latestReviews.nodes = [{\"state\":\"APPROVED\"},{\"state\":\"COMMENTED\"}]"
  base "$MF_P.reviewDecision = null"
  mr @0123abcd; ok "MK4 no review rule, approved" 0 'gh:acme/web#7 @0123abcd merged' 3; merges "MK4" "$M7"
  none "MK5 review required" "$MF_P.reviewDecision = \"REVIEW_REQUIRED\""
  none "MK5 no rule, no approval" "$MF_P.reviewDecision = null" "$MF_P.latestOpinionatedReviews.nodes = []"
  none "MK5 changes requested" "$MF_P.reviewDecision = \"CHANGES_REQUESTED\""
  none "MK6 someone else's PR" "$MF_P.author.login = \"pal\""
  none "MK6 no viewer, no author" '.data.viewer.login = null' "$MF_P.author = null"
  none "MK7 stacked base" "$MF_P.baseRefName = \"feat/parent\""
  none "MK7 no default branch" '.data.repository.defaultBranchRef = null'
  for st in BLOCKED UNSTABLE BEHIND DIRTY UNKNOWN HAS_HOOKS; do
    base "$MF_P.mergeStateStatus = \"$st\""
    mr @0123abcd; ok "MK8 $st" 0 'gh:acme/web#7 @0123abcd held' 1; merges "MK8 $st" ''
    mr --ready 'gh:acme/web#7'; ok "MK8 $st --ready" 4 '' 1
  done
  base; echo 1 > "$MFIX/mergerc"
  mr @0123abcd; ok "MK9 failed merge" 0 'gh:acme/web#7 @0123abcd did not merge' 3; merges "MK9" "$M7"
  one "MK9" "gh:acme/web#7 $S"
  mr @0123abcd; ok "MK9 second run" 0 'gh:acme/web#7 @0123abcd held' 1; merges "MK9 second run" ''
  mr --ready 'gh:acme/web#7'; ok "MK9 --ready" 4 '' 1
  one "MK9 once" "gh:acme/web#7 $S"
  rm -f "$MFIX/mergerc"; mf_pr acme web 7 "$MF_P.headRefOid = \"$S2\""
  mr @0123abcd; ok "MK12 new head" 0 'gh:acme/web#7 @0123abcd merged' 3
  merges "MK12" "pr merge 7 --repo acme/web --merge --match-head-commit $S2"
  base; echo 1 > "$MFIX/mergerc"; : > "$MFIX/raceflip"
  mr @0123abcd; ok "MK10 failed, merged by another" 0 'gh:acme/web#7 @0123abcd merged' 3
  [ ! -e "$MFF" ] || { echo "FAIL: $SHL MK10 -- recorded"; fail=1; }
  base; : > "$MFIX/queue"
  mr @0123abcd; ok "MK11 merge queue" 0 'gh:acme/web#7 @0123abcd held' 3
  [ ! -e "$MFF" ] || { echo "FAIL: $SHL MK11 -- recorded"; fail=1; }
  base; : > "$MFIX/readfail"
  mr @0123abcd; ok "MK13 read fails" 0 '' 1; merges "MK13" ''
  mr --ready 'gh:acme/web#7'; ok "MK13 --ready" 2 '' 1
  base; echo 30 > "$MFIX/hang"
  T0=$(date +%s); MWAIT=1; mr --ready 'gh:acme/web#7'; TE=$(($(date +%s) - T0))
  ok "MK13b hung read --ready" 2 '' 1
  [ "$TE" -lt 10 ] || { echo "FAIL: $SHL MK13b -- took ${TE}s with a 1 s watchdog"; fail=1; }
  ! kill -0 "$(cat "$MFIX/hangpid" 2>/dev/null)" 2>/dev/null || { echo "FAIL: $SHL MK13b -- the hung gh still runs"; fail=1; }
  mr @0123abcd; ok "MK13b hung read @tag" 0 '' 1; merges "MK13b" ''; unset MWAIT
  rm -f "$MFIX/hang"
  base; echo 30 > "$MFIX/hangmerge"
  T0=$(date +%s); MWAIT=1; mr @0123abcd; unset MWAIT; TE=$(($(date +%s) - T0))
  ok "MK13c hung merge" 0 'gh:acme/web#7 @0123abcd did not merge' 3; one "MK13c" "gh:acme/web#7 $S"
  [ "$TE" -lt 10 ] || { echo "FAIL: $SHL MK13c -- took ${TE}s with a 1 s watchdog"; fail=1; }
  ! kill -0 "$(cat "$MFIX/hangpid" 2>/dev/null)" 2>/dev/null || { echo "FAIL: $SHL MK13c -- the hung gh still runs"; fail=1; }
  base; echo 1 > "$MFIX/mergerc"; : > "$MFIX/rereadfail"
  mr @0123abcd; ok "MK13d failed merge, failed re-read" 0 '' 3
  [ ! -e "$MFF" ] || { echo "FAIL: $SHL MK13d -- recorded"; fail=1; }
  base; : > "$MFIX/rereadfail"
  mr @0123abcd; ok "MK13d merged, failed re-read" 0 'gh:acme/web#7 @0123abcd held' 3
  mf_reset; mf_list '- acme/web'; mf_pr acme web 7; mf_wait 100 'gh:acme/web#7.' @0123abcd
  mr @0123abcd; ok "MK14 trailing dot" 0 'gh:acme/web#7 @0123abcd merged' 3
  mr --ready 'gh:acme/web#7.'; ok "MK14 --ready trailing dot" 3 '' 1
  mf_reset; mf_list '- acme/web' '- acme'; mf_pr acme web 7; mf_wait 100 'gh:acme#7' @0123abcd; mf_wait 90 'gh:acme/web' @0123abcd
  mr @0123abcd; ok "MK14 malformed refs" 0 '' 0
  for rf in 'gh:acme#7' 'gh:acme/web' 'slack:C1/123' 'gh:acme/web#7x' 'gh:a/b/c#7' 'gh:acme/web#7 x' 'gh:acme/web#7
x' ''; do
    mr --ready "$rf"; bad "MK14 --ready [$rf]" 2
  done
  mf_reset; mf_list '- acme/web'; mf_pr acme web 7; mf_wait 100 'slack:C1/123' @0123abcd
  mr @0123abcd; ok "MK15 non-gh wait" 0 '' 0
  none "MK16 merged" "$MF_P.state = \"MERGED\""
  none "MK16 closed" "$MF_P.state = \"CLOSED\""
  none "MK16 no PR" "$MF_P = null"
  if [ "$ROOT" = 0 ]; then
    base; echo 1 > "$MFIX/mergerc"; mkdir -p "$HOME/.clutch/watch"; : > "$MFF"; chmod 444 "$MFF"
    mr @0123abcd; ok "MK17 record unwritable" 0 'gh:acme/web#7 @0123abcd did not merge' 3
    base; mkdir -p "$HOME/.clutch/watch"; printf 'gh:other/x#1 %s\n' "$S" > "$MFF"; chmod 000 "$MFF"
    mr @0123abcd; ok "MK20 record unreadable" 0 'gh:acme/web#7 @0123abcd held' 1; merges "MK20" ''
    mr --ready 'gh:acme/web#7'; ok "MK20 --ready" 2 '' 1
    chmod 644 "$MFF"
  fi
  mf_reset; mf_list '- acme/web'; mf_pr Acme Web 7; mf_wait 100 'gh:Acme/Web#7.' @0123abcd
  mr @0123abcd; ok "MK18 mixed case" 0 'gh:Acme/Web#7 @0123abcd merged' 3
  merges "MK18" "pr merge 7 --repo Acme/Web --merge --match-head-commit $S"
  case $(sed -n 1p "$MFIX/log") in *' -f o=Acme -f r=Web -F n=7 '*) ;; *) echo "FAIL: $SHL MK18 -- read [$(sed -n 1p "$MFIX/log")]"; fail=1 ;; esac
  mf_pr Acme Web 7; echo 1 > "$MFIX/mergerc"
  mr @0123abcd; ok "MK18 failed" 0 'gh:Acme/Web#7 @0123abcd did not merge' 3; one "MK18" "gh:acme/web#7 $S"
  mr --ready 'gh:ACME/web#7'; ok "MK18 recorded, any case" 4 '' 1
  none "MK19 no merge commits" '.data.repository.mergeCommitAllowed = false'
  for sha in '' abc 0123456789ABCDEF0123456789ABCDEF01234567 "$S$S2" "$S " null; do
    if [ "$sha" = null ]; then base "$MF_P.headRefOid = null"; else base "$MF_P.headRefOid = \"$sha\""; fi
    mr --ready 'gh:acme/web#7'; ok "MK21 head [$sha] --ready" 2 '' 1
    mr @0123abcd; ok "MK21 head [$sha] @tag" 0 '' 1; merges "MK21 [$sha]" ''
  done
  base "$MF_P.mergeStateStatus = \"BLOCKED\""
  mf_wait 90 'gh:acme/web#8' @0123abcd; mf_pr acme web 8
  mf_wait 80 'gh:acme/web#9' @0123abcd; mf_pr acme web 9
  mf_wait 70 'gh:acme/web#10' @ffffffff; mf_pr acme web 10
  mf_wait 60 'gh:other/x#1' @0123abcd; mf_pr other x 1
  mr @0123abcd
  ok "MK22 several waits, one tag" 0 'gh:acme/web#7 @0123abcd held
gh:acme/web#8 @0123abcd merged
gh:acme/web#9 @0123abcd merged' 7

  # --- MU1-MU8: --unwatched
  mf_reset; mf_list '- acme/web'; mf_pr acme web 7; mf_wait 100 'gh:acme/web#7'
  mr --unwatched; ok "MU1 untagged" 0 'gh:acme/web#7 merged' 3; merges "MU1" "$M7"
  pf clutch_unwatched_loops; [ "$RC" = 0 ] && [ "$(printf '%s\n' "$OUT" | cut -d' ' -f2-)" = 'proj wait: gh:acme/web#7 b1 pr' ] \
    || { echo "FAIL: $SHL MU1 unit -- rc $RC [$OUT]"; fail=1; }
  mf_reset; mf_list '- acme/web'; mf_pr acme web 7; mf_wait 100 'gh:acme/web#7' @0123abcd; mf_dead @0123abcd
  mr --unwatched; ok "MU2 dead tag" 0 'gh:acme/web#7 @0123abcd merged' 3
  mf_reset; mf_list '- acme/web'; mf_pr acme web 7; mf_wait 100 'gh:acme/web#7' @0123abcd
  mr --unwatched; ok "MU3 no .poll" 0 'gh:acme/web#7 @0123abcd merged' 3
  mf_reset; mf_list '- acme/web'; mf_pr acme web 7; mf_wait 100 'gh:acme/web#7' @0123abcd; mf_live @0123abcd
  mr --unwatched; ok "MU4 live tag" 0 '' 0
  pf clutch_unwatched_loops; is "MU4 unit" 0 ''
  if [ "$ROOT" = 0 ]; then
    mf_reset; mf_list '- acme/web'; mf_pr acme web 7; mf_wait 100 'gh:acme/web#7' @0123abcd; mf_dead @0123abcd
    chmod 000 "$HOME/.clutch/watch/0123abcd.poll"
    mr --unwatched; ok "MU5 cannot tell" 0 '' 0
    chmod 644 "$HOME/.clutch/watch/0123abcd.poll"
    chmod 000 "$W"; mr --unwatched; bad "MU5 unreadable worklog" 2; mr @0123abcd; bad "MU5 unreadable worklog @tag" 2
    pf clutch_unwatched_loops; is "MU5 unit unreadable" 2 ''; chmod 644 "$W"
  fi
  rm -f "$W"; pf clutch_unwatched_loops; is "MU5 unit no worklog" 1 ''
  mr --unwatched; ok "MU5 no worklog" 0 '' 0
  mf_reset; mf_list '- acme/web'; mf_pr acme web 7; mf_wait 100 'gh:acme/web#7'; mf_wait 90 'gh:acme/web#7,' @0123abcd
  mr --unwatched; ok "MU6 two waits, one ref" 0 'gh:acme/web#7 merged
gh:acme/web#7 @0123abcd merged' 3; merges "MU6" "$M7"
  mf_reset; mf_list '- acme/web'; mf_pr Acme Web 7; mf_wait 100 'gh:Acme/Web#7'; mf_wait 90 'gh:acme/web#7' @0123abcd; mf_dead @0123abcd
  echo 1 > "$MFIX/mergerc"
  mr --unwatched; ok "MU7 one ref, two spellings" 0 'gh:Acme/Web#7 did not merge
gh:acme/web#7 @0123abcd did not merge' 3; one "MU7" "gh:acme/web#7 $S"
  mf_reset; mf_list '- acme/web'; mf_pr acme web 7; mf_wait 100 'gh:acme/web#7'; mf_wait 90 'gh:acme/web#7' @0123abcd
  mf_wait 80 'gh:ACME/web#7.' @ffffffff; mf_live @ffffffff
  mr --unwatched; ok "MU8 a live tag waits on the ref" 0 '' 0
  pf clutch_unwatched_loops; is "MU8 unit" 0 ''
  mf_wait 70 'gh:acme/web#8'; mf_pr acme web 8
  mr --unwatched; ok "MU8 the other ref still merges" 0 'gh:acme/web#8 merged' 3

  # --- MR2: bad arguments
  base
  mr; bad "MR2 no argument" 2
  for a in '@bad' '@0123abc' '@0123abcd/' '@../0123ab' '--ready' '--bogus' '0123abcd'; do
    mr "$a"; bad "MR2 [$a]" 2
  done
  mr --ready 'gh:acme/web#7' extra; bad "MR2 --ready two refs" 2
  mr --unwatched extra; bad "MR2 --unwatched extra" 2
  mr @0123abcd extra; bad "MR2 @tag extra" 2
}

for sh in sh /bin/dash; do
  if [ "$sh" = /bin/dash ] && [ ! -x /bin/dash ]; then echo "SKIP: dash (not installed)"; continue; fi
  MSH=$sh; SHL=$sh
  series
done
MSH=sh; SHL=sh

# --- MR3: the watchdog length. 1-5 digits, no leading zero, else 60 s: each
# case's --ready against a gh that hangs 30 s still runs after 3 s; once its
# gh is killed by pid it ends rc 2 within 3 s. 2 gives a 2 s watchdog.
base; echo 30 > "$MFIX/hang"
i=0
for v in unset abc 0 007 123456; do
  i=$((i + 1))
  (
    [ "$v" = unset ] && unset CLUTCH_MERGE_WAIT || CLUTCH_MERGE_WAIT=$v
    [ "$v" = unset ] || export CLUTCH_MERGE_WAIT
    cd "$T/plain" && PATH=$MF_PATH MF_HANGPID="$T/hp.$i" sh "$T/scripts/merge.sh" --ready 'gh:acme/web#7' >/dev/null 2>&1
    echo $? > "$T/rc.$i"
  ) &
done
/bin/sleep 3
i=0
for v in unset abc 0 007 123456; do
  i=$((i + 1))
  [ ! -f "$T/rc.$i" ] || { echo "FAIL: MR3 [$v] -- ended in under 3 s, want the 60 s watchdog"; fail=1; }
  kill "$(cat "$T/hp.$i" 2>/dev/null)" 2>/dev/null || { echo "FAIL: MR3 [$v] -- no hung gh to kill"; fail=1; }
done
/bin/sleep 3
i=0
for v in unset abc 0 007 123456; do
  i=$((i + 1))
  [ "$(cat "$T/rc.$i" 2>/dev/null)" = 2 ] || { echo "FAIL: MR3 [$v] -- rc [$(cat "$T/rc.$i" 2>/dev/null)] 3 s after its gh was killed, want 2"; fail=1; }
done
wait
T0=$(date +%s); MWAIT=2; mr --ready 'gh:acme/web#7'; unset MWAIT; TE=$(($(date +%s) - T0))
ok "MR3 [2]" 2 '' 1
[ "$TE" -lt 6 ] || { echo "FAIL: MR3 [2] -- took ${TE}s, want the 2 s watchdog"; fail=1; }
kill "$(cat "$MFIX/hangpid" 2>/dev/null)" 2>/dev/null
rm -f "$MFIX/hang"

# --- MK13e: no gh on PATH (rc 127 at once, the kill race widest): 30 --ready
# calls under sh and dash each return rc 2 at once, and 2 s after the last no
# watchdog sleep is alive. The staged copy runs the watchdog's sleep through
# $T/wdsleep, counted by that path (a single long sleeper is counted too).
ln -s /bin/sleep "$T/wdsleep"
mkdir -p "$T/sq"; cp "$T/scripts/prelude.sh" "$T/sq/prelude.sh"
sed "s|/bin/sleep|$T/wdsleep|" "$T/scripts/merge.sh" > "$T/sq/merge.sh"
[ "$(grep -c "$T/wdsleep" "$T/sq/merge.sh")" = 1 ] || { echo "FAIL: MK13e -- the staged copy names the watchdog sleep on [$(grep -c "$T/wdsleep" "$T/sq/merge.sh")] lines, want 1"; fail=1; }
NOGH=/usr/bin:/bin:/usr/sbin:/sbin
if [ -n "$(PATH=$NOGH command -v gh)" ]; then
  echo "FAIL: MK13e -- a gh is on $NOGH"; fail=1
else
  base
  for sh in /bin/sh /bin/dash; do
    [ -x "$sh" ] || { echo "SKIP: MK13e $sh (not installed)"; continue; }
    T0=$(date +%s)
    i=0
    while [ "$i" -lt 30 ]; do
      OUT=$(cd "$T/plain" && PATH=$NOGH "$sh" "$T/sq/merge.sh" --ready 'gh:acme/web#7' 2>"$T/err"); RC=$?
      ERR=$(cat "$T/err"); NGH=0; SHL=$sh
      ok "MK13e no gh [$i]" 2 '' 0
      i=$((i + 1))
    done
    TE=$(($(date +%s) - T0))
    [ "$TE" -lt 20 ] || { echo "FAIL: MK13e $sh -- 30 calls with no gh took ${TE}s"; fail=1; }
  done
  SHL=sh
  /bin/sleep 2
  WL=$(ps -A -o args= | grep -c "^$T/wdsleep ")
  [ "$WL" = 0 ] || { echo "FAIL: MK13e -- $WL watchdog sleeps outlived their call by 2 s"; fail=1; }
fi

# --- MV1: a ### Merge section leaves clutch_ops_due's window read alone.
mf_reset
printf '## Ops\n\n### Windows\n- 0:00\n\n### Merge\n- acme/web 0:01 23:58\n' > "$HOME/.clutch/rituals.md"
OUT=$(cd "$T/plain" && sh -c '. "$1"; clutch_ops_due window' x "$T/scripts/prelude.sh"); RC=$?
is "MV1 window due" 0 due
[ "$(cut -d' ' -f2 "$HOME/.clutch/ops-window-last")" = 0000 ] || { echo "FAIL: MV1 -- window [$(cat "$HOME/.clutch/ops-window-last")], want 0000"; fail=1; }

# --- MA1: every merge call of the whole suite is the one exact form; no call
# carries a forbidden flag.
AL="$MFIX/all.log"
grep -q '^pr merge ' "$AL" || { echo "FAIL: MA1 -- no merge call logged"; fail=1; }
BADM=$(grep '^pr merge ' "$AL" | grep -Ev '^pr merge [0-9]+ --repo [A-Za-z0-9._-]+/[A-Za-z0-9._-]+ --merge --match-head-commit [0-9a-f]{40}$')
[ -z "$BADM" ] || { echo "FAIL: MA1 -- merge calls [$BADM]"; fail=1; }
BADF=$(grep -E -e '--(admin|auto|delete-branch|squash|rebase|force)' "$AL")
[ -z "$BADF" ] || { echo "FAIL: MA1 -- forbidden flags [$BADF]"; fail=1; }
grep -Ev '^(api graphql -f query=query\(|pr merge )' "$AL" | grep -q . && { echo "FAIL: MA1 -- other gh calls [$(grep -Ev '^(api graphql|pr merge )' "$AL")]"; fail=1; }

[ "$fail" -eq 0 ] && echo PASS
exit "$fail"
