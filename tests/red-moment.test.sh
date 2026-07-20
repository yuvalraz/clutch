#!/bin/sh
# Fixtures for scripts/red-moment.sh. Pipes mock hook payloads through the script
# in throwaway git repos and asserts the spiral logic. No network, no plugin
# reload: this validates the classification and state machine before the live
# fire-test. Run: sh tests/red-moment.test.sh

TESTDIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SCRIPT="$TESTDIR/../scripts/red-moment.sh"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf 'ok   - %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL - %s\n     expected %s, got: [%s]\n' "$1" "$2" "$3"; }

fresh_repo() {
  REPO=$(mktemp -d)
  ( cd "$REPO" && git init -q && git config user.email t@t.t && git config user.name t \
    && echo v1 > f.txt && git add f.txt && git commit -qm init ) >/dev/null 2>&1
}

# run EVENT COMMAND -> prints the script's stdout, running inside $REPO (or $DIR).
run() {
  _dir=${DIR:-$REPO}
  ( cd "$_dir" && printf '{"hook_event_name":"%s","tool_name":"Bash","tool_input":{"command":"%s"}}' "$1" "$2" | sh "$SCRIPT" )
}

fired() { printf '%s' "$1" | grep -q additionalContext; }

# 1. first red -> silent
fresh_repo
out=$(run PostToolUseFailure "pytest")
[ -z "$out" ] && pass "first red is silent" || fail "first red is silent" "empty" "$out"

# 2. red, edit (diff changes), red -> silent (progress)
fresh_repo
run PostToolUseFailure "pytest" >/dev/null
( cd "$REPO" && echo v2 >> f.txt )
out=$(run PostToolUseFailure "pytest")
[ -z "$out" ] && pass "red then edit then red is silent" || fail "red then edit then red is silent" "empty" "$out"

# 3. red, same red (no edit) -> fires once
fresh_repo
run PostToolUseFailure "pytest" >/dev/null
out=$(run PostToolUseFailure "pytest")
fired "$out" && pass "same red, no edit, fires" || fail "same red, no edit, fires" "additionalContext" "$out"

# 4. after firing, same red again -> silent (redseen dedupe)
out=$(run PostToolUseFailure "pytest")
[ -z "$out" ] && pass "third identical red is silent (dedupe)" || fail "third identical red is silent (dedupe)" "empty" "$out"

# 5. green between reds resets -> next red silent
fresh_repo
run PostToolUseFailure "pytest" >/dev/null
run PostToolUse "pytest" >/dev/null          # green success clears the record
out=$(run PostToolUseFailure "pytest")
[ -z "$out" ] && pass "green resets, next red silent" || fail "green resets, next red silent" "empty" "$out"

# 6. non-runner failure -> silent
fresh_repo
run PostToolUseFailure "grep foo bar.txt" >/dev/null
out=$(run PostToolUseFailure "grep foo bar.txt")
[ -z "$out" ] && pass "non-runner failure is silent" || fail "non-runner failure is silent" "empty" "$out"

# 7. designed-to-fail (|| true) -> silent even when repeated
fresh_repo
run PostToolUseFailure "pytest || true" >/dev/null
out=$(run PostToolUseFailure "pytest || true")
[ -z "$out" ] && pass "pytest || true is silent" || fail "pytest || true is silent" "empty" "$out"

# 8. cap spent (2 emitted lines) -> silent even on a real spiral
fresh_repo
mkdir -p "$REPO/.clutch"
printf 'emit x\nemit y\n' > "$REPO/.clutch/session-state"
run PostToolUseFailure "pytest" >/dev/null
out=$(run PostToolUseFailure "pytest")
[ -z "$out" ] && pass "cap spent stays silent" || fail "cap spent stays silent" "empty" "$out"

# 9. non-git dir -> exit 0 silent
DIR=$(mktemp -d)
out=$(run PostToolUseFailure "pytest")
[ -z "$out" ] && pass "non-git dir is silent" || fail "non-git dir is silent" "empty" "$out"
unset DIR

# 10. malformed payload -> exit 0 silent
fresh_repo
out=$( cd "$REPO" && printf 'not json at all' | sh "$SCRIPT" )
[ -z "$out" ] && pass "malformed payload is silent" || fail "malformed payload is silent" "empty" "$out"

# 11. different targets each failing once -> silent (not one wall)
fresh_repo
run PostToolUseFailure "pytest test_a.py" >/dev/null
out=$(run PostToolUseFailure "pytest test_b.py")
[ -z "$out" ] && pass "two different targets stay silent" || fail "two different targets stay silent" "empty" "$out"

# 12. a new untracked file between reds -> silent (writing a test is progress)
fresh_repo
run PostToolUseFailure "pytest" >/dev/null
( cd "$REPO" && echo "def test_x(): pass" > test_new.py )
out=$(run PostToolUseFailure "pytest")
[ -z "$out" ] && pass "new untracked file resets, silent" || fail "new untracked file resets, silent" "empty" "$out"

# 13. staging the work between reds -> silent (git add is progress)
fresh_repo
run PostToolUseFailure "pytest" >/dev/null
( cd "$REPO" && echo v2 >> f.txt && git add f.txt )
out=$(run PostToolUseFailure "pytest")
[ -z "$out" ] && pass "staged change resets, silent" || fail "staged change resets, silent" "empty" "$out"

# 14. same runner, different quoted arg -> silent (no cmdhash collision)
fresh_repo
Q='\"'
P1='{"hook_event_name":"PostToolUseFailure","tool_name":"Bash","tool_input":{"command":"pytest -k '"$Q"'slow'"$Q"'"}}'
P2='{"hook_event_name":"PostToolUseFailure","tool_name":"Bash","tool_input":{"command":"pytest -k '"$Q"'fast'"$Q"'"}}'
( cd "$REPO" && printf '%s' "$P1" | sh "$SCRIPT" ) >/dev/null
out=$( cd "$REPO" && printf '%s' "$P2" | sh "$SCRIPT" )
[ -z "$out" ] && pass "different quoted arg does not collide, silent" || fail "different quoted arg does not collide, silent" "empty" "$out"

# 15. "go test" inside a non-runner command -> silent
fresh_repo
run PostToolUseFailure "mongo test.js" >/dev/null
out=$(run PostToolUseFailure "mongo test.js")
[ -z "$out" ] && pass "mongo test.js is not a runner, silent" || fail "mongo test.js is not a runner, silent" "empty" "$out"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
