#!/bin/sh
# clutch merge pass: `sh <scripts dir>/merge.sh @<tag> | --unwatched |
# --ready <ref>`. Only for a gh wait in a repo on the merge list (### Merge
# under ## Ops in ~/.clutch/rituals.md, read by clutch_merge_entries) does it
# call gh: one GraphQL read of the PR, and a merge only when that read shows
# it open, not a draft, the gh user's own, into the default branch or a
# base=<branch> of its list lines, in a repo that allows merge commits, approved
# (no outstanding changes requested, and reviewDecision APPROVED, or none with
# an approval from a user with write access or, with a no-review line, none
# needed) and CLEAN, with exactly
# `gh pr merge <n> --repo <owner>/<repo> --merge --match-head-commit <sha>`.
# @<tag> reads the waits the tag owns, --unwatched the waits no live silent
# check reads (clutch_unwatched_loops); each ref is read once a run, and each
# wait on it gets a line "<ref>[ @<tag>] <what>", its own ref as written:
# merged when a re-read shows MERGED, or the first read shows the gh user's
# own PR MERGED (no merge call; a queue merge, a lost re-read or a cut run);
# did not merge when the merge failed and
# a re-read shows it not merged, once per (ref, head sha), recorded in
# ~/.clutch/watch/merge.failed as "<lowercased ref> <sha>" (a record that
# cannot be written is not reported, so did not merge repeats each run); held
# for an approved PR that is not CLEAN, a recorded failure (or a record or
# watch dir it cannot read), or a merge the re-read does not show merged. No
# line otherwise, and no worklog read with no repo on the list; rc 0.
# --ready <ref> writes nothing: rc 0 prints the head sha, 1 not listed (no gh
# call), 2 cannot tell, 3 not a candidate, 4 held. Bad arguments, an
# unreadable list or worklog: one "merge.sh: <reason>" line on stderr, rc 2.
# It writes nothing but merge.failed, never the worklog. Each gh call runs
# from / and is killed after CLUTCH_MERGE_WAIT seconds (default 60), a kill
# being a gh failure.

MW=${CLUTCH_MERGE_WAIT:-60}
# 1-5 digits, >= 1, as poll.sh reads its nap; else 60.
case $MW in [1-9] | [1-9][0-9] | [1-9][0-9][0-9] | [1-9][0-9][0-9][0-9] | [1-9][0-9][0-9][0-9][0-9]) ;; *) MW=60 ;; esac

die() { printf 'merge.sh: %s\n' "$1" >&2; exit 2; }
USAGE='usage: merge.sh @<tag> | --unwatched | --ready <ref>'
MODE=${1-}
case $MODE in
  --ready) [ "$#" = 2 ] || die "$USAGE" ;;
  --unwatched) [ "$#" = 1 ] || die "$USAGE" ;;
  # Spelled-out class, the same guard as poll.sh.
  @????????)
    [ "$#" = 1 ] || die "$USAGE"
    case $MODE in @*[!0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-]*) die 'bad tag' ;; esac ;;
  *) die "$USAGE" ;;
esac
PRELUDE=$(dirname "$0")/prelude.sh
[ -f "$PRELUDE" ] && . "$PRELUDE" || die 'cannot read prelude.sh'
MFF="$HOME/.clutch/watch/merge.failed"

# mgh <gh args>: one gh call, killed (its own pid only) after MW seconds of
# 1 s naps, no trap: a kill lands on the default TERM action at any point,
# and at most one 1 s nap outlives the call.
mgh() {
  gh "$@" </dev/null 2>/dev/null &
  MGH_P=$!
  ( n=0; while [ "$n" -lt "$MW" ]; do /bin/sleep 1; n=$((n + 1)); done; kill "$MGH_P" 2>/dev/null ) >/dev/null &
  MGH_K=$!
  # 2>/dev/null: bash prints a job notice for a killed job.
  wait "$MGH_P" 2>/dev/null
  MGH_RC=$?
  kill "$MGH_K" 2>/dev/null
  wait "$MGH_K" 2>/dev/null
  return "$MGH_RC"
}
# Both latestOpinionatedReviews before reviewDecision: the other order can
# empty them. All users' reviews veto with CHANGES_REQUESTED; only writers'
# (writersOnly, which defaults to false) approve when reviewDecision is null.
MQ='query($o:String!,$r:String!,$n:Int!){viewer{login} repository(owner:$o,name:$r){mergeCommitAllowed defaultBranchRef{name} pullRequest(number:$n){state isDraft latestOpinionatedReviews(last:100){nodes{state}} writerReviews:latestOpinionatedReviews(writersOnly:true,last:100){nodes{state}} reviewDecision mergeStateStatus headRefOid baseRefName author{login}}}}'
# "ready <sha>", "held <sha>" (approved, not CLEAN), "merged" (the viewer's
# own PR, already merged) or "none".
MF='.data as $d | $d.repository as $rp | $rp.pullRequest as $p | [($p.latestOpinionatedReviews.nodes // [])[].state] as $s
  | [($p.writerReviews.nodes // [])[].state] as $w
  | if $p != null and $p.state == "MERGED" and $d.viewer.login != null and $p.author.login == $d.viewer.login
    then "merged"
    elif $p != null and $p.state == "OPEN" and $p.isDraft == false
      and $d.viewer.login != null and $p.author.login == $d.viewer.login
      and $p.baseRefName != null and ($p.baseRefName == $rp.defaultBranchRef.name or any($xb[]; . == $p.baseRefName))
      and $rp.mergeCommitAllowed == true and (any($s[]; . == "CHANGES_REQUESTED") | not)
      and ($p.reviewDecision == "APPROVED" or ($p.reviewDecision == null and ($nr or any($w[]; . == "APPROVED"))))
    then (if $p.mergeStateStatus == "CLEAN" then "ready " else "held " end) + ($p.headRefOid // "")
    else "none" end'
# rd <owner> <repo> <n> <jq>: one read of the PR.
rd() { (cd / && mgh api graphql -f query="$MQ" -f o="$1" -f r="$2" -F n="$3" --jq "$4"); }
# mopt <owner/repo>: MP, the jq prefix for the options of every LIST line
# naming the repo (options only widen, so their union): $xb its base=
# branches, $nr true with no-review. rc 1 when no line names it.
mopt() {
  MO=$(printf '%s\n' "$LIST" | LC_ALL=C awk -v k="$1" '$1 == k { f = 1; $1 = ""; print } END { exit !f }') || return 1
  MB='' MN=false
  for MOT in $MO; do case $MOT in no-review) MN=true ;; base=*) MB="$MB,\"${MOT#base=}\"" ;; esac; done
  MP="[${MB#,}] as \$xb | $MN as \$nr | "
}
# One line per well-formed gh wait: ref owner repo number lowercased-ref tag
# ("-" for none); the ref loses a trailing ,;:. or CR, as the worklog scan does.
WA='$4 ~ /^gh:/ { r = $4; sub(/[,;:.\r]+$/, "", r); x = substr(r, 4)
  if (x !~ /^[A-Za-z0-9._-]+\/[A-Za-z0-9._-]+#[0-9]+$/) next
  split(x, a, /[\/#]/)
  print r, a[1], a[2], a[3], tolower(r), ($6 ~ /^@[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$/) ? $6 : "-" }'

# gate: the read GOT gives KIND (ready, held, merged, none) and SHA. rc 1
# cannot tell (any other shape, a sha not 40 lowercase hex); rc 2 a ready PR
# with a merge.failed (or a watch dir) that cannot be read. A recorded (LC,
# SHA) is held.
gate() {
  case $GOT in
    none | merged) KIND=$GOT; return 0 ;;
    'ready '* | 'held '*) KIND=${GOT%% *}; SHA=${GOT#* } ;;
    *) return 1 ;;
  esac
  case $SHA in *[!0123456789abcdef]* | '') return 1 ;; esac
  [ "${#SHA}" = 40 ] || return 1
  [ "$KIND" = ready ] || return 0
  # As clutch_poll_alive: an unsearchable dir would read merge.failed as absent.
  if [ -e "${MFF%/*}" ] || [ -L "${MFF%/*}" ]; then
    [ -d "${MFF%/*}" ] && [ -x "${MFF%/*}" ] || return 2
  else
    [ -d "$HOME/.clutch" ] && [ -x "$HOME/.clutch" ] || return 2
  fi
  [ -e "$MFF" ] || [ -L "$MFF" ] || return 0
  [ -f "$MFF" ] && [ -r "$MFF" ] || return 2
  LC_ALL=C grep -qxF "$LC $SHA" "$MFF"
  case $? in 0) KIND=held ;; 1) ;; *) return 2 ;; esac
  return 0
}

# one: read, gate and merge the PR REF (O, R, N, LC); RES is merged, did not
# merge, held or empty.
one() {
  RES=""
  GOT=$(rd "$O" "$R" "$N" "$MP$MF") || return 0
  gate
  case $?.$KIND in 0.ready) ;; 0.merged) RES=merged; return 0 ;; 0.held | 2.*) RES=held; return 0 ;; *) return 0 ;; esac
  (cd / && mgh pr merge "$N" --repo "$O/$R" --merge --match-head-commit "$SHA" >/dev/null)
  MRC=$?
  ST=$(rd "$O" "$R" "$N" '.data.repository.pullRequest.state')
  SRC=$?
  if [ "$SRC" = 0 ] && [ "$ST" = MERGED ]; then RES=merged
  elif [ "$MRC" = 0 ]; then RES=held
  elif [ "$SRC" = 0 ]; then
    # Another run may have recorded it since the gate.
    ! { [ -r "$MFF" ] && LC_ALL=C grep -qxF "$LC $SHA" "$MFF"; } || return 0
    [ ! -d "$HOME/.clutch" ] || mkdir -p "$HOME/.clutch/watch" 2>/dev/null
    { printf '%s %s\n' "$LC" "$SHA" >> "$MFF"; } 2>/dev/null
    RES='did not merge'
  fi
  return 0
}

if [ "$MODE" = --ready ]; then
  case $2 in *[[:space:]]*) die 'bad ref' ;; esac
  read -r REF O R N LC TG <<EOF
$(printf '0 x wait: %s\n' "$2" | LC_ALL=C awk "$WA")
EOF
  [ -n "$REF" ] || die 'bad ref'
  LIST=$(clutch_merge_entries)
  case $? in 0) ;; 1) exit 1 ;; *) die 'cannot read ~/.clutch/rituals.md' ;; esac
  K=${LC#gh:}
  mopt "${K%#*}" || exit 1
  GOT=$(rd "$O" "$R" "$N" "$MP$MF") || exit 2
  gate || exit 2
  case $KIND in ready) printf '%s\n' "$SHA"; exit 0 ;; held) exit 4 ;; *) exit 3 ;; esac
fi

# The list, read once before the worklog: no entry, no worklog read.
LIST=$(clutch_merge_entries)
case $? in 0) ;; 1) exit 0 ;; *) die 'cannot read ~/.clutch/rituals.md' ;; esac
[ -n "$LIST" ] || exit 0
if [ "$MODE" = --unwatched ]; then LOOPS=$(clutch_unwatched_loops); else LOOPS=$(clutch_owned_loops "$MODE"); fi
case $? in 0) ;; 1) exit 0 ;; *) die 'cannot read ~/.clutch/worklog.md' ;; esac
WAITS=$(printf '%s\n' "$LOOPS" | LC_ALL=C awk "$WA")
# "<lowercased ref> <what>" per ref read this run, "-" for no line.
DONE=""
while read -r REF O R N LC TG; do
  [ -n "$REF" ] || continue
  [ "$MODE" = --unwatched ] || TG=$MODE
  WHAT=$(printf '%s\n' "$DONE" | LC_ALL=C awk -v k="$LC" '$1 == k { print substr($0, length(k) + 2); exit }')
  if [ -z "$WHAT" ]; then
    K=${LC#gh:}
    if mopt "${K%#*}"; then one; WHAT=${RES:--}; else WHAT=-; fi
    DONE="$DONE
$LC $WHAT"
  fi
  [ "$WHAT" != - ] || continue
  if [ "$TG" = - ]; then printf '%s %s\n' "$REF" "$WHAT"; else printf '%s %s %s\n' "$REF" "$TG" "$WHAT"; fi
done <<EOF
$WAITS
EOF
exit 0
