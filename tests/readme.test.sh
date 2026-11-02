#!/bin/sh
# README guard: the README names every shipped command as /clutch:<name>,
# names no command that does not ship, and states the command and hook counts
# derived from the repo ("<word N> commands", "<word H> hooks"), with no stale
# count phrase left beside them. Reads only README_FILE; skills/ and
# hooks/hooks.json come from the repo itself, so this passes from any cwd and
# under a scratch HOME.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT="$HERE/.."
R=${README_FILE:-$ROOT/README.md}

[ -f "$R" ] || { echo "FAIL: missing README $R"; exit 1; }

# Command truth: every skills/*/ directory holding a SKILL.md.
NAMES=""
for d in "$ROOT"/skills/*/; do
  [ -f "$d/SKILL.md" ] || continue
  NAMES="$NAMES $(basename "$d")"
done
N=$(printf '%s\n' $NAMES | wc -l | tr -d ' ')
H=$(grep -oE 'scripts/[A-Za-z0-9_.-]+\.sh' "$ROOT/hooks/hooks.json" | sort -u | wc -l | tr -d ' ')

# English word for 1-39.
word() {
  case $1 in
    1) echo one ;; 2) echo two ;; 3) echo three ;; 4) echo four ;;
    5) echo five ;; 6) echo six ;; 7) echo seven ;; 8) echo eight ;;
    9) echo nine ;; 10) echo ten ;; 11) echo eleven ;; 12) echo twelve ;;
    13) echo thirteen ;; 14) echo fourteen ;; 15) echo fifteen ;;
    16) echo sixteen ;; 17) echo seventeen ;; 18) echo eighteen ;;
    19) echo nineteen ;; 20) echo twenty ;; 30) echo thirty ;;
    2[1-9]) echo "twenty-$(word "${1#2}")" ;;
    3[1-9]) echo "thirty-$(word "${1#3}")" ;;
    *) echo "FAIL: no word for count $1" >&2; return 1 ;;
  esac
}
WN=$(word "$N") || exit 1
WH=$(word "$H") || exit 1

# rc 0 = present, 1 = absent, >=2 = grep broke (fails loudly via has's caller).
has() {
  grep -q "$@" 2>/dev/null
  rc=$?
  [ "$rc" -le 1 ] || echo "FAIL: grep error rc=$rc on $*"
  return "$rc"
}

# All README checks on one file. Prints FAIL lines; exit 0 only when clean.
# Run in $(...) so its fail flag never leaks between files.
check_readme() {
  f=$1; fail=0
  # Check 2: every command named, with a trailing boundary so /clutch:dream
  # cannot hide inside /clutch:dream-spark.
  for n in $NAMES; do
    has -E "/clutch:$n([^A-Za-z0-9_-]|\$)" "$f" \
      || { echo "FAIL: README does not name /clutch:$n"; fail=1; }
  done
  # Check 3: no unknown names. Extract case-insensitively and wide, then match
  # exactly, so /Clutch:x, /clutch:fomo2 and /clutch:dream_x are unknown. + not
  # *, so a bare "/clutch:" placeholder is not read as a name.
  for t in $(grep -oiE '/clutch:[A-Za-z0-9_-]+' "$f" | sort -u); do
    case " $NAMES " in
      *" ${t#*:} "*) [ "$t" = "/clutch:${t#*:}" ] && continue ;;
    esac
    echo "FAIL: README names unknown $t"; fail=1
  done
  # Check 4: counts. Presence of the derived phrases...
  has -iF "$WN commands" "$f" \
    || { echo "FAIL: README lacks count phrase '$WN commands'"; fail=1; }
  has -iF "$WH hooks" "$f" \
    || { echo "FAIL: README lacks count phrase '$WH hooks'"; fail=1; }
  # ...and no other count phrase. The install line is excluded first (by
  # line), then the text is flattened to one line with emphasis, &nbsp; and
  # repeated whitespace removed, so a phrase wrapped across lines or split by
  # markdown is still seen. The leading boundary keeps "written commands" from
  # reading as "ten commands". Any digit count is stale: the README uses words.
  flat=$(grep -vE '^(## )?Two commands\. Zero configuration\.$' "$f" \
    | sed 's/&nbsp;/ /g' | tr -d '*_`' | tr -s '[:space:]' ' '; echo)
  got=$(printf '%s\n' "$flat" \
    | grep -oiE '(^|[^a-zA-Z0-9-])((one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty)(-[a-z]+)? (commands|hooks)|[0-9]+ (commands|hooks|mechanisms))' \
    | sed -E 's/^[^a-zA-Z0-9]//' \
    | tr '[:upper:]' '[:lower:]' | sort -u)
  want=$(printf '%s commands\n%s hooks\n' "$WN" "$WH" | sort -u)
  [ "$got" = "$want" ] || {
    echo "FAIL: stale count phrases: got [$(printf '%s' "$got" | tr '\n' ',')] want [$(printf '%s' "$want" | tr '\n' ',')]"
    fail=1; }
  for s in 'mechanisms ship' 'Fifteen commands'; do
    printf '%s\n' "$flat" | has -iF "$s"
    [ $? -eq 1 ] || { echo "FAIL: stale sentence '$s'"; fail=1; }
  done
  return "$fail"
}

fail=0
out=$(check_readme "$R") || fail=1
[ -n "$out" ] && printf '%s\n' "$out"

# Self-checks: mutants run through the same check_readme.
T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT

cnt() { grep -oF "$1" "$2" | wc -l | tr -d ' '; }

# Negative, boundary: drop every /clutch:dream, keep every /clutch:dream-spark
# (placeholder swap; built with awk, not sed).
awk '{ gsub(/\/clutch:dream-spark/, "\001"); gsub(/\/clutch:dream/, "");
       gsub(/\001/, "/clutch:dream-spark"); print }' "$R" > "$T/m-dream"
cmp -s "$R" "$T/m-dream" \
  && { echo "FAIL: self-check dream mutant identical to source"; fail=1; }
[ "$(cnt /clutch:dream-spark "$T/m-dream")" = "$(cnt /clutch:dream-spark "$R")" ] \
  || { echo "FAIL: self-check placeholder lost /clutch:dream-spark"; fail=1; }
[ "$(grep -cE '/clutch:dream([^a-z-]|$)' "$T/m-dream")" = 0 ] \
  || { echo "FAIL: self-check placeholder left /clutch:dream"; fail=1; }
mo=$(check_readme "$T/m-dream") \
  && { echo "FAIL: self-check dream mutant passed"; fail=1; }
printf '%s\n' "$mo" | grep -q 'does not name /clutch:dream$' \
  || { echo "FAIL: self-check dream mutant not caught by name check"; fail=1; }
printf '%s\n' "$mo" | grep -q 'does not name /clutch:dream-spark' \
  && { echo "FAIL: self-check dream mutant wrongly named dream-spark"; fail=1; }

# Negative, unknown name.
awk '{ print } END { print "Run /clutch:capture now." }' "$R" > "$T/m-unknown"
mo=$(check_readme "$T/m-unknown") \
  && { echo "FAIL: self-check unknown mutant passed"; fail=1; }
printf '%s\n' "$mo" | grep -qF 'names unknown /clutch:capture' \
  || { echo "FAIL: self-check unknown mutant not caught"; fail=1; }

# Positive control: synthetic README with every name, the derived count line,
# the install line and the "written commands" probe.
cap=$(printf '%s' "$WN" | awk '{ print toupper(substr($0,1,1)) substr($0,2) }')
{ for n in $NAMES; do echo "/clutch:$n"; done
  echo "$cap commands and $WH hooks."
  echo "Two commands. Zero configuration."
  echo "These are written commands."; } > "$T/pos"
po=$(check_readme "$T/pos") \
  || { echo "FAIL: self-check positive control failed:"; printf '%s\n' "$po"; fail=1; }

# Negative, stale count: positive control plus a stale phrase no other check
# bans, so only the absence pipeline can catch it.
awk '{ print } END { print "Nineteen commands ship." }' "$T/pos" > "$T/m-stale"
mo=$(check_readme "$T/m-stale") \
  && { echo "FAIL: self-check stale mutant passed"; fail=1; }
printf '%s\n' "$mo" | grep -q '^FAIL: stale count phrases: got \[.*nineteen commands' \
  || { echo "FAIL: self-check stale mutant not caught by absence check"; fail=1; }

# Negative, evasions: each must still be caught by its own check.
# stale_caught <label> <pattern the FAIL output must match> <line>...
stale_caught() {
  label=$1; pat=$2; shift 2
  awk 'BEGIN { for (i = 2; i < ARGC; i++) extra[i] = ARGV[i]; n = ARGC; ARGC = 2 }
       { print } END { for (i = 2; i < n; i++) print extra[i] }' "$T/pos" "$@" > "$T/m-$label"
  mo=$(check_readme "$T/m-$label") \
    && { echo "FAIL: self-check $label mutant passed"; fail=1; }
  printf '%s\n' "$mo" | grep -q "$pat" \
    || { echo "FAIL: self-check $label mutant not caught"; fail=1; }
}
stale_caught wrapped '^FAIL: stale count phrases: got \[.*nineteen commands' 'Nineteen' 'commands ship.'
stale_caught bold '^FAIL: stale count phrases: got \[.*nineteen commands' '**Nineteen** commands.'
stale_caught digit '^FAIL: stale count phrases: got \[.*19 commands' 'We ship 19 commands.'
stale_caught wrapped-ban "^FAIL: stale sentence 'mechanisms ship'" 'Twenty-three mechanisms' 'ship.'
stale_caught name-digit '^FAIL: README names unknown /clutch:fomo2$' 'Run /clutch:fomo2 now.'
stale_caught ban-case "^FAIL: stale sentence 'mechanisms ship'" 'Twenty-three Mechanisms ship.'
stale_caught name-case '^FAIL: README names unknown /Clutch:fomo$' 'Run /Clutch:fomo now.'

[ "$fail" -eq 0 ] || exit 1
echo PASS
