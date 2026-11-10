#!/bin/sh
# The tablet inbox helper under scripts/: run its offline unittest suite (temp
# state dirs), then drive the sh wrapper under scratch HOMEs with PATH set to
# scratch dirs, one without python3 and one with a recording stub. Hermetic:
# no real HOME, no real inbox. Silent on success.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE/.." || { echo "FAIL: cannot cd to repo root"; exit 1; }

PYTHONDONTWRITEBYTECODE=1
export PYTHONDONTWRITEBYTECODE

PY=/usr/bin/python3
[ -x "$PY" ] || PY=python3
W=scripts/tablet-inbox.sh

T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT
HOME=$T/home
export HOME
mkdir "$HOME"

fail=0
out=$("$PY" -B tests/tablet_inbox_test.py 2>&1) || { echo "FAIL: tablet inbox unittest"; echo "$out"; fail=1; }

# $T/nopy holds only sh; $T/stubpy also holds a python3 that records its arguments.
mkdir "$T/nopy" "$T/stubpy"
ln -s /bin/sh "$T/nopy/sh"
ln -s /bin/sh "$T/stubpy/sh"
printf '#!/bin/sh\necho "$*" > "%s/py-ran"\n' "$T" > "$T/stubpy/python3"
chmod +x "$T/stubpy/python3"

# wrap <pathdir> <args...>: run the wrapper; rc in $rc, output in $T/out and $T/err,
# the HOME listing before and after in $T/before and $T/after.
wrap() {
  dir=$1; shift
  rm -f "$T/py-ran"
  find "$HOME" | sort > "$T/before"
  PATH=$T/$dir /bin/sh "$W" "$@" > "$T/out" 2> "$T/err"
  rc=$?
  find "$HOME" | sort > "$T/after"
}
# quiet <name>: the last run was rc 0, said nothing, ran no python3 and changed nothing.
quiet() {
  [ "$rc" -eq 0 ] && [ ! -s "$T/out" ] && [ ! -s "$T/err" ] && [ ! -e "$T/py-ran" ] \
    && cmp -s "$T/before" "$T/after" || { echo "FAIL: $1 (rc $rc)"; fail=1; }
}
# ran <name> <text>: the stub ran with arguments holding the text.
ran() {
  grep -qF -- "$2" "$T/py-ran" 2>/dev/null || { echo "FAIL: $1"; fail=1; }
}

wrap stubpy claim
quiet wrapper_no_state_runs_no_python

mkdir "$HOME/.clutch"
for verb in claim release route; do
  wrap stubpy "$verb"
  quiet "wrapper_no_inbox_runs_no_python ($verb)"
done

wrap nopy claim
quiet wrapper_no_python_and_no_inbox_is_silent

mkdir -p "$HOME/.clutch/inbox/aipaper"
wrap stubpy claim
ran wrapper_inbox_runs_the_helper "-B scripts/tablet_inbox.py claim"

wrap nopy claim
[ "$rc" -eq 5 ] && [ ! -s "$T/out" ] && [ "$(wc -l < "$T/err")" -eq 1 ] && grep -q '^tablet: ' "$T/err" \
  && cmp -s "$T/before" "$T/after" || { echo "FAIL: wrapper_inbox_without_python_fails_loud (rc $rc)"; fail=1; }

HOME=$T/home2
mkdir -p "$HOME/.clutch/aipaper/reading"
wrap stubpy release
ran wrapper_reading_runs_the_helper "-B scripts/tablet_inbox.py release"

HOME=$T/home3
mkdir -p "$HOME/.clutch" "$T/d/inbox/aipaper"
wrap stubpy --state-dir "$T/d" claim
ran wrapper_honors_state_dir "-B scripts/tablet_inbox.py --state-dir $T/d claim"

[ -z "$(grep -rE 'curl|wget|/dev/tcp|nc ' scripts/)" ] || { echo "FAIL: readme_network_grep_stays_empty"; fail=1; }

# The puller's README names the reader's state and how to clear held/.
for text in 'the tablet inbox reader holds the lock' '`aipaper/reading/`' '`aipaper/held/`' \
  '`aipaper/ledger.json`' 'renames a directory into `aipaper/reading/`' 'delete its `.claims` file first'; do
  grep -qF -- "$text" tools/aipaper/README.md || { echo "FAIL: puller_readme_names_the_reader -- $text"; fail=1; }
done

exit "$fail"
