#!/bin/sh
# clutch silent check: `sh <scripts dir>/poll.sh @<tag>`, started by a
# session with the Bash tool's run_in_background. It reads the gh wait loops
# the tag owns, quietly, once per round (CLUTCH_POLL_SLEEP seconds apart,
# default 600; CLUTCH_POLL_ROUNDS rounds, default 72), from 08:00 to 21:59
# local. Its exit is the session's one visible turn, so it prints only when
# it exits: "<ref> <what>" lines and the closing line when a wait moved, the
# ended line otherwise, the stopped line when it cannot write.
# Records under ~/.clutch/watch (never creating ~/.clutch): <tag8>.poll
# "<pid> <start epoch>" (read by clutch_poll_alive) and <tag8>.woke,
# append-only "<ref> <stamp>" wake marks, so the same evidence wakes once.
# It never writes the worklog.

TAG=${1-}
# Spelled-out class, the same guard as clutch_ops_record.
case $TAG in @????????) ;; *) echo 'poll.sh: bad tag' >&2; exit 2 ;; esac
case $TAG in @*[!0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-]*) echo 'poll.sh: bad tag' >&2; exit 2 ;; esac
# Any stray stderr would land in the wake's output.
exec 2>/dev/null

ended() { printf 'The silent check for %s ended; end the turn.\n' "$TAG"; exit 0; }
stopped() { printf 'The silent check for %s cannot write ~/.clutch/watch; it stopped.\n' "$TAG"; exit 0; }

[ "${CLUTCH_WATCH:-}" != off ] || ended
PRELUDE=$(dirname "$0")/prelude.sh
[ -f "$PRELUDE" ] && . "$PRELUDE" || ended

D="$HOME/.clutch/watch"
PF="$D/${TAG#@}.poll"
WF="$D/${TAG#@}.woke"
[ ! -d "$HOME/.clutch" ] || mkdir -p "$D"
# Without a readable, appendable .woke a wake could repeat on the same evidence.
{ : >> "$WF"; } && [ -r "$WF" ] || stopped
START=$(date +%s)
case $START in '' | *[!0-9]*) stopped ;; esac
{ printf '%s %s\n' "$$" "$START" > "$PF.$$" && mv -f "$PF.$$" "$PF"; } || { rm -f "$PF.$$"; stopped; }

MAX=${CLUTCH_POLL_ROUNDS:-72}
case $MAX in '' | *[!0-9]*) MAX=72 ;; esac
NAP=${CLUTCH_POLL_SLEEP:-600}
case $NAP in '' | *[!0-9]*) NAP=600 ;; esac
ISO='[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z'
Q='query($o:String!,$r:String!,$n:Int!){viewer{login} repository(owner:$o,name:$r){pullRequest(number:$n){state updatedAt comments(last:50){nodes{createdAt author{__typename login}}} reviews(last:50){nodes{state submittedAt author{__typename login}}}}}}'

R=0
while [ "$R" -lt "$MAX" ]; do
  [ "$R" = 0 ] || sleep "$NAP"
  R=$((R + 1))
  # A newer poller for this tag rewrote .poll: this one is superseded.
  case $(head -n 1 "$PF") in "$$ "*) ;; *) ended ;; esac
  OWN=$(clutch_owned_loops "$TAG")
  case $? in 0) ;; 1) ended ;; *) continue ;; esac
  printf '%s\n' "$OWN" | LC_ALL=C awk '$4 ~ /^gh:/ { f = 1 } END { exit !f }' || ended
  case $(date +%H) in 0[89] | 1[0-9] | 2[01]) ;; *) continue ;; esac
  # One line per well-formed gh wait: ref owner repo number baseline epoch;
  # the ref loses a trailing ,;:. or CR as the worklog scan does.
  WAITS=$(printf '%s\n' "$OWN" | LC_ALL=C awk '$4 ~ /^gh:/ {
    r = $4; sub(/[,;:.\r]+$/, "", r); x = substr(r, 4)
    if (x !~ /^[A-Za-z0-9._-]+\/[A-Za-z0-9._-]+#[0-9]+$/) next
    split(x, a, /[\/#]/); print r, a[1], a[2], a[3], $5, $1 }')
  WAKE=""
  MARKS=""
  while read -r REF OWNER REPO NUM BASE EPOCH; do
    [ -n "$REF" ] || continue
    case $BASE in $ISO) ;; *) BASE=$(date -u -r "$EPOCH" +%Y-%m-%dT%H:%M:%SZ || date -u -d "@$EPOCH" +%Y-%m-%dT%H:%M:%SZ) ;; esac
    case $BASE in $ISO) ;; *) continue ;; esac
    # Beff: the later of the baseline and this ref's newest wake mark (field 1
    # equals the ref, so other line kinds never count). An unreadable .woke
    # skips the wait this round: "no marks" would wake on old evidence.
    BEFF=$(LC_ALL=C awk -v r="$REF" -v b="$BASE" '$1 == r && NF == 2 && $2 > m { m = $2 } END { print (m > b) ? m : b }' "$WF") || continue
    case $BEFF in $ISO) ;; *) continue ;; esac
    F='.data.viewer.login as $me | .data.repository.pullRequest as $p | "'"$BEFF"'" as $b
      | [($p.reviews.nodes // [])[] | select((.submittedAt // "") > $b and .author.login != $me
          and (.author.__typename != "Bot" or .state == "CHANGES_REQUESTED"))] | sort_by(.submittedAt) | . as $rv
      | [($p.comments.nodes // [])[] | select((.createdAt // "") > $b and .author.login != $me
          and .author.__typename != "Bot")] | . as $cm
      | ([$p.updatedAt // "", $rv[].submittedAt, $cm[].createdAt] | max) as $t
      | if (($p.state == "MERGED" or $p.state == "CLOSED") and ($p.updatedAt // "") > $b) then "\($p.state | ascii_downcase) \($t)"
        elif ($rv | length) > 0 then "review \($rv[-1].state) \($t)"
        elif ($cm | length) > 0 then "comment \($t)"
        else empty end'
    GOT=$(gh api graphql -f query="$Q" -f o="$OWNER" -f r="$REPO" -F n="$NUM" --jq "$F" </dev/null) || continue
    GOT=$(printf '%s\n' "$GOT" | head -n 1)
    STAMP=${GOT##* }
    WHAT=${GOT% *}
    case $STAMP in $ISO) ;; *) continue ;; esac
    case $WHAT in merged | closed | comment | review\ [A-Z]*) ;; *) continue ;; esac
    WAKE="$WAKE$REF $WHAT
"
    MARKS="$MARKS$REF $STAMP
"
  done <<EOF
$WAITS
EOF
  [ -n "$WAKE" ] || continue
  # Mark before waking; with no mark the restarted check would wake again.
  { printf '%s' "$MARKS" >> "$WF"; } || stopped
  printf '%s' "$WAKE"
  printf 'Run /clutch:watch %s for the moved waits.\n' "$TAG"
  exit 0
done
ended
