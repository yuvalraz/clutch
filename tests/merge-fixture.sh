# Sourced helper for the merge suites (tests/merge*.test.sh); not a suite.
# Needs T (a scratch dir) and HOME (a scratch HOME) set before mf_init.
# Nothing here contacts the network: the fake gh reads fixtures only, and
# mf_init points GH_CONFIG_DIR at an empty dir so a real gh would hold no login.
#
# mf_init: writes the fake gh to $T/mfbin/gh, sets MFIX ($T/mfix), MF_PATH
#   (the fake bin dir first on PATH), MF_SHA (the default head) and MF_PIDS,
#   and fails when the fake gh is not the first gh on MF_PATH.
# mf_reset: a fresh ~/.clutch (empty worklog), no fixtures, no gh switches.
# mf_pr <owner> <repo> <n> [<jq update> ...]: the PR's GraphQL fixture,
#   ready by default (OPEN, not a draft, the viewer's own, approved, CLEAN,
#   into the default branch main, merge commits allowed, head MF_SHA); each
#   update is applied in turn, e.g. "$MF_P.isDraft = true".
# mf_list [<line> ...]: ~/.clutch/rituals.md holding "## Ops", "### Merge"
#   and the lines.
# mf_wait <age s> <ref> [<@tag>]: appends "<epoch> proj wait: <ref> b1 [<@tag>] pr".
# mf_live <@tag>: a live stub poller for the tag and its .poll (pid in MF_PIDS).
# mf_dead <@tag>: a .poll whose pid has ended.
# mf_ngh: the gh calls (each one's cwd goes to $MFIX/cwd) since the last mf_reset or mf_log0.
# mf_merges: those calls that are "pr merge" calls.
# mf_log0: empties the per-run log.
# mf_stop: kills the pids in MF_PIDS (the suite's EXIT trap calls it).
#
# Fake gh switches, files in $MFIX: hang <s> (every call sleeps, as its own
# pid, recorded in ${MF_HANGPID:-$MFIX/hangpid}); hangmerge <s> (only pr
# merge); readfail (api calls fail); rereadfail (api calls fail after a
# merge call); mergerc <rc> (default 0); queue (a merge with rc 0 leaves the
# PR OPEN); raceflip (a failed merge still leaves it MERGED).

MF_P='.data.repository.pullRequest'
MF_SHA=0123456789abcdef0123456789abcdef01234567

mf_init() {
  MFIX=$T/mfix
  export MFIX
  MF_PIDS=""
  mkdir -p "$T/mfbin" "$MFIX" "$T/mfghconf" || return 1
  GH_CONFIG_DIR=$T/mfghconf
  export GH_CONFIG_DIR
  cat > "$T/mfbin/gh" <<'EOF'
#!/bin/sh
F=$MFIX
# One log line per call, a multi-line --jq filter folded.
L=$(printf '%s' "$*" | tr '\n' ' ')
printf '%s\n' "$L" >> "$F/log"
printf '%s\n' "$L" >> "$F/all.log"
pwd >> "$F/cwd"
case $1.${2-} in
  pr.merge)
    [ -f "$F/hangmerge" ] && { echo $$ > "${MF_HANGPID:-$F/hangpid}"; exec /bin/sleep "$(cat "$F/hangmerge")"; } ;;
esac
[ -f "$F/hang" ] && { echo $$ > "${MF_HANGPID:-$F/hangpid}"; exec /bin/sleep "$(cat "$F/hang")"; }
# flip <fixture> <state>
flip() { /usr/bin/jq ".data.repository.pullRequest.state = \"$2\"" "$1" > "$1.t" && mv "$1.t" "$1"; }
case $1.${2-} in
  pr.merge)
    n=$3 rp=''
    while [ $# -gt 0 ]; do case $1 in --repo) rp=$2; shift ;; esac; shift; done
    fx="$F/${rp%%/*}_${rp#*/}_$n.json"
    : > "$F/merge.called"
    rc=$(cat "$F/mergerc" 2>/dev/null || echo 0)
    if [ "$rc" = 0 ]; then
      [ -f "$F/queue" ] || flip "$fx" MERGED
    else
      [ ! -f "$F/raceflip" ] || flip "$fx" MERGED
    fi
    exit "$rc" ;;
  api.graphql)
    [ -f "$F/readfail" ] && exit 1
    [ -f "$F/rereadfail" ] && [ -f "$F/merge.called" ] && exit 1
    o='' r='' n='' q=''
    while [ $# -gt 0 ]; do
      case $1 in
        --jq) q=$2; shift ;;
        -f | -F) case $2 in o=*) o=${2#o=} ;; r=*) r=${2#r=} ;; n=*) n=${2#n=} ;; esac; shift ;;
      esac
      shift
    done
    [ -f "$F/${o}_${r}_${n}.json" ] || exit 1
    /usr/bin/jq -r "$q" "$F/${o}_${r}_${n}.json" ;;
  *) exit 1 ;;
esac
EOF
  chmod 755 "$T/mfbin/gh" || return 1
  MF_PATH="$T/mfbin:$PATH"
  # No real gh may ever run: the fake must be the first gh on MF_PATH.
  [ "$(PATH=$MF_PATH command -v gh)" = "$T/mfbin/gh" ] || { echo "FAIL: the fake gh is not first on PATH"; return 1; }
}

mf_reset() {
  chmod -R u+rwx "$HOME/.clutch" 2>/dev/null
  rm -rf "$HOME/.clutch"
  find "$MFIX" -mindepth 1 ! -name all.log -exec rm -rf {} + 2>/dev/null
  mkdir -p "$HOME/.clutch" && : > "$HOME/.clutch/worklog.md" && : > "$MFIX/log"
}

mf_log0() { : > "$MFIX/log"; rm -f "$MFIX/merge.called" "$MFIX/cwd"; }

mf_pr() {
  MFX="$MFIX/$1_$2_$3.json"
  printf '{"data":{"viewer":{"login":"me"},"repository":{"mergeCommitAllowed":true,"defaultBranchRef":{"name":"main"},"pullRequest":{"state":"OPEN","isDraft":false,"latestOpinionatedReviews":{"nodes":[{"state":"APPROVED"}]},"latestReviews":{"nodes":[{"state":"APPROVED"}]},"reviewDecision":"APPROVED","mergeStateStatus":"CLEAN","headRefOid":"%s","baseRefName":"main","author":{"login":"me"}}}}}\n' "$MF_SHA" > "$MFX"
  shift 3
  for u in "$@"; do
    /usr/bin/jq "$u" "$MFX" > "$MFX.t" && mv "$MFX.t" "$MFX" || return 1
  done
}

mf_list() {
  { printf '# Rituals\n\n## Ops\n\n### Merge\n'; [ $# = 0 ] || printf '%s\n' "$@"; } > "$HOME/.clutch/rituals.md"
}

mf_wait() {
  printf '%s proj wait: %s b1 %s%s\n' "$(($(date +%s) - $1))" "$2" "${3:+$3 }" pr >> "$HOME/.clutch/worklog.md"
}

mf_live() {
  mkdir -p "$T/mfstub" "$HOME/.clutch/watch"
  printf 'sleep 60\n' > "$T/mfstub/poll.sh"
  MF_LP=$( (sh "$T/mfstub/poll.sh" "$1" </dev/null >/dev/null 2>&1 & echo $!) )
  MF_PIDS="$MF_PIDS $MF_LP"
  printf '%s %s beat\n' "$MF_LP" "$(date +%s)" > "$HOME/.clutch/watch/${1#@}.poll"
}

mf_dead() {
  mkdir -p "$HOME/.clutch/watch"
  MF_DP=$( (true </dev/null >/dev/null 2>&1 & echo $!) )
  /bin/sleep 0.2
  printf '%s %s beat\n' "$MF_DP" "$(date +%s)" > "$HOME/.clutch/watch/${1#@}.poll"
}

mf_ngh() { grep -c '' "$MFIX/log"; }
mf_merges() { grep '^pr merge' "$MFIX/log"; }
mf_stop() { for p in $MF_PIDS; do kill "$p" 2>/dev/null; done; }
