#!/bin/sh
# clutch silent check: `sh <scripts dir>/poll.sh @<tag>`, started by a
# session with the Bash tool's run_in_background. It reads the gh wait loops
# the tag owns, quietly, once per round (CLUTCH_POLL_SLEEP seconds apart,
# default 600; CLUTCH_POLL_ROUNDS rounds, default 72), from 08:00 to 21:59
# local. Unless CLUTCH_BEAT=off, it also beats while the tag's ops record
# (<tag8>.beat) is there: from 08:00 to 20:59 it peeks the beat window and
# wakes on peer moves, at most once an hour (the newer of the record's newest
# last and the newest beat mark). Its exit is the session's one visible turn,
# so it prints only when it exits: "<ref> <what>" lines and the watch closing
# line when a wait moved or gh failed on it 3 rounds in a row (what =
# unreadable), then the beat closing line "Run /clutch:beat @<tag>." when the
# beat woke; the ended line otherwise, the stopped line when it cannot write.
# It ends once it owns no gh wait and the beat is off or the record is gone.
# Records under ~/.clutch/watch (never creating ~/.clutch): <tag8>.poll
# "<pid> <start epoch>[ beat]" (read by clutch_poll_alive; beat while the
# beat check is on) and <tag8>.woke, append-only "<ref> <stamp>" wake marks,
# so the same evidence wakes once, "unreadable <ref> <wait epoch>" marks, so
# one wait line wakes unreadable at most once, and "beat <epoch>" marks for
# the hourly cap; they never hold back a later move of that ref.
# It never writes the worklog; it writes the record only to seed a missing
# last line once.

TAG=${1-}
# Spelled-out class, the same guard as clutch_ops_record.
case $TAG in @????????) ;; *) echo 'poll.sh: bad tag' >&2; exit 2 ;; esac
case $TAG in @*[!0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-]*) echo 'poll.sh: bad tag' >&2; exit 2 ;; esac
# Any stray stderr would land in the wake's output.
exec 2>/dev/null

ended() { printf 'The silent check for %s ended; end the turn.\n' "$TAG"; exit 0; }
stopped() { printf 'The silent check for %s cannot write ~/.clutch/watch; it stopped.\n' "$TAG"; exit 0; }

[ "${CLUTCH_WATCH:-}" != off ] || ended
BEAT=" beat"
[ "${CLUTCH_BEAT:-}" != off ] || BEAT=""
PRELUDE=$(dirname "$0")/prelude.sh
[ -f "$PRELUDE" ] && . "$PRELUDE" || ended

D="$HOME/.clutch/watch"
PF="$D/${TAG#@}.poll"
WF="$D/${TAG#@}.woke"
BF="$D/${TAG#@}.beat"
[ ! -d "$HOME/.clutch" ] || mkdir -p "$D"
# Without a readable, appendable .woke a wake could repeat on the same evidence.
{ : >> "$WF"; } && [ -r "$WF" ] || stopped
START=$(date +%s)
case $START in '' | *[!0-9]*) ended ;; esac
{ printf '%s %s%s\n' "$$" "$START" "$BEAT" > "$PF.$$" && mv -f "$PF.$$" "$PF"; } || { rm -f "$PF.$$"; stopped; }
# A record with no last line has an empty window: seed one, once.
if [ -n "$BEAT" ] && clutch_ops_record "$TAG"; then
  LC_ALL=C grep -q '^last [0-9][0-9]*$' "$BF"
  [ "$?" != 1 ] || clutch_beat_window "$TAG" >/dev/null
fi

MAX=${CLUTCH_POLL_ROUNDS:-72}
case $MAX in '' | *[!0-9]*) MAX=72 ;; esac
NAP=${CLUTCH_POLL_SLEEP:-600}
# 1-5 digits, >= 1, as stop.sh reads a round; else 600.
case $NAP in [1-9] | [1-9][0-9] | [1-9][0-9][0-9] | [1-9][0-9][0-9][0-9] | [1-9][0-9][0-9][0-9][0-9]) ;; *) NAP=600 ;; esac
ISO='[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z'
Q='query($o:String!,$r:String!,$n:Int!){viewer{login} repository(owner:$o,name:$r){pullRequest(number:$n){state updatedAt comments(last:50){nodes{createdAt author{__typename login}}} reviews(last:50){nodes{state submittedAt author{__typename login}}}}}}'

R=0
# One line per in-window gh failure; an answer drops the ref's lines.
FAILS=""
while [ "$R" -lt "$MAX" ]; do
  [ "$R" = 0 ] || sleep "$NAP"
  R=$((R + 1))
  # A newer poller for this tag rewrote .poll: this one is superseded.
  case $(head -n 1 "$PF") in "$$ "*) ;; *) ended ;; esac
  OWN=$(clutch_owned_loops "$TAG")
  case $? in 0 | 1) ;; *) continue ;; esac
  # No owned gh wait: end, unless the beat check is on and the record may be there.
  if ! printf '%s\n' "$OWN" | LC_ALL=C awk '$4 ~ /^gh:/ { f = 1 } END { exit !f }'; then
    [ -n "$BEAT" ] || ended
    clutch_ops_record "$TAG"
    [ "$?" != 1 ] || ended
  fi
  HR=$(date +%H)
  case $HR in 0[89] | 1[0-9] | 2[01]) ;; *) continue ;; esac
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
    # A baseline written with hyphens in the time (HH-MM-SS) reads as ISO.
    case $BASE in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]-[0-9][0-9]-[0-9][0-9]Z) BASE=$(printf '%s' "$BASE" | sed 's/T\(..\)-\(..\)-/T\1:\2:/') ;; esac
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
    if ! GOT=$(gh api graphql -f query="$Q" -f o="$OWNER" -f r="$REPO" -F n="$NUM" --jq "$F" </dev/null); then
      FAILS="$FAILS
$REF"
      [ "$(printf '%s\n' "$FAILS" | LC_ALL=C awk -v r="$REF" '$0 == r { n++ } END { print n + 0 }')" -ge 3 ] || continue
      # 0 = no unreadable mark for this wait line yet; an unreadable .woke prints nothing.
      [ "$(LC_ALL=C awk -v r="$REF" -v e="$EPOCH" '$1 == "unreadable" && $2 == r && $3 == e { f = 1 } END { print f + 0 }' "$WF")" = 0 ] || continue
      WAKE="$WAKE$REF unreadable
"
      MARKS="${MARKS}unreadable $REF $EPOCH
"
      continue
    fi
    FAILS=$(printf '%s\n' "$FAILS" | LC_ALL=C awk -v r="$REF" '$0 != r')
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
  # The beat, 08:00-20:59: peer moves in the window and the hourly cap open
  # (no M, or now - 120 - M >= 3600, M the newer of the newest last and the
  # newest beat mark). An unreadable record or .woke means no beat wake.
  BW=""
  case $BEAT$HR in
    ' beat'0[89] | ' beat'1[0-9] | ' beat'20)
      BN=$(date +%s)
      case $BN in '' | *[!0-9]*) ;; *)
        if clutch_ops_record "$TAG" && MV=$(clutch_beat_window "$TAG" peek) && [ -n "$MV" ] &&
          [ -r "$BF" ] && [ -r "$WF" ] &&
          [ "$(LC_ALL=C awk -v n="$BN" -v bf="$BF" '
            FILENAME == bf && /^last [0-9]+$/ && (m == "" || $2 + 0 > m + 0) { m = $2 }
            FILENAME != bf && /^beat [0-9]+$/ && (m == "" || $2 + 0 > m + 0) { m = $2 }
            END { if (m == "" || n - 120 - m >= 3600) print "open" }' "$BF" "$WF")" = open ]; then
          BW=1
          MARKS="${MARKS}beat $((BN - 120))
"
        fi ;;
      esac ;;
  esac
  [ -n "$WAKE$BW" ] || continue
  # Mark before waking; with no mark the restarted check would wake again.
  { printf '%s' "$MARKS" >> "$WF"; } || stopped
  printf '%s' "$WAKE"
  [ -z "$WAKE" ] || printf 'Run /clutch:watch %s for the moved waits.\n' "$TAG"
  [ -z "$BW" ] || printf 'Run /clutch:beat %s.\n' "$TAG"
  exit 0
done
ended
