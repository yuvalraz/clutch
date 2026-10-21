#!/bin/sh
# Forked passes: daydream and dream-spark run under `context: fork` and
# `background: true`, stay invoked-only, and their bodies are written for a
# pass that sees none of the conversation (daydream's whisper arrives through
# $ARGUMENTS). Positive pins are absent from the pre-fork tree, so a revert
# turns this red; labels starting `guard:` hold today. DAYDREAM_SKILL and
# DREAMSPARK_SKILL override the targets for replay.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
DD=${DAYDREAM_SKILL:-$HERE/../skills/daydream/SKILL.md}
DS=${DREAMSPARK_SKILL:-$HERE/../skills/dream-spark/SKILL.md}

fail=0
for f in "$DD" "$DS"; do
  [ -f "$f" ] || { echo "FAIL: missing $f"; fail=1; }
done
[ "$fail" -eq 0 ] || exit 1

# rc 0 = pin holds, 1 = pattern gone, >=2 = grep itself broke. Only 0 passes.
pin() {
  file=$1; label=$2; pat=$3
  grep -qF -- "$pat" "$file"
  rc=$?
  case $rc in
    0) ;;
    1) echo "FAIL: $label -- pattern not found: $pat"; fail=1 ;;
    *) echo "FAIL: $label -- grep error rc=$rc: $pat"; fail=1 ;;
  esac
}
# rc 1 = pattern absent (passes), 0 = still present, >=2 = grep broke.
absent() {
  file=$1; label=$2; pat=$3
  grep -qF -- "$pat" "$file"
  rc=$?
  case $rc in
    1) ;;
    0) echo "FAIL: $label -- pattern still present: $pat"; fail=1 ;;
    *) echo "FAIL: $label -- grep error rc=$rc: $pat"; fail=1 ;;
  esac
}
# Frontmatter = the lines between the first two `---` lines.
fm() { sed -n '2,/^---$/p' "$1"; }
# fmcount FILE LABEL REGEX WANT: the frontmatter holds WANT lines matching REGEX.
fmcount() {
  n=$(fm "$1" | grep -c -- "$3")
  [ "$n" = "$4" ] || { echo "FAIL: $2 -- frontmatter has $n lines matching $3, want $4"; fail=1; }
}

# --- (i) both skills fork into the background, one key each; (ii) invoked only
for f in "$DD" "$DS"; do
  name=$(basename "$(dirname "$f")")
  fmcount "$f" "$name: forked"                   '^context: fork$'                  1
  fmcount "$f" "$name: backgrounded"             '^background: true$'               1
  fmcount "$f" "$name: one context key"          '^context:'                        1
  fmcount "$f" "$name: one background key"       '^background:'                     1
  fmcount "$f" "guard: $name invoked only"       '^disable-model-invocation: true$' 1
done

# --- (iii) dream-spark names no model, so its pass inherits the session's
fmcount "$DS" "dream-spark: no model key" '^model:' 0

# --- (iv) daydream body: whisper via arguments, written for a blind pass
pin "$DD" "daydream: whisper arrives as arguments" '$ARGUMENTS'
pin "$DD" "daydream: pass sees no conversation"    'sees none of the conversation'
pin "$DD" "daydream: one-line final reply"         'Your final reply is exactly one line'
pin "$DD" "daydream: empty whisper line"           'Daydream: no whisper — nothing banked'
pin "$DD" "daydream: append-failed line on one line" "Daydream couldn't bank — chain:"

# --- (v) daydream launches no sub-agent of its own
absent "$DD" "daydream: no sub-agent wording" 'sub-agent'
absent "$DD" "daydream: scaffold section gone" 'Sub-agent prompt scaffold'

# --- (vi) guards: the notify lines stay verbatim
pin "$DD" "guard: daydream resonant line" 'Daydream landed: "'
pin "$DD" "guard: daydream faint line"    'Daydream: faint signal on "'
pin "$DD" "guard: daydream noise line"    'Daydream: noise on "'

# --- (vii) dream-spark body: blind pass, summary block is the reply
pin "$DS" "dream-spark: pass sees no conversation" 'sees none of the conversation'
pin "$DS" "dream-spark: summary is the reply"      'This block is your final reply'
pin "$DS" "dream-spark: append-failed line on one line" "Dream-spark couldn't bank \"<short title>\" — <item A> × <item B>: <connection>"
pin "$DS" "dream-spark: failure line allowed in the block" 'If any append fails, the block also carries one line per unbanked connection'
pin "$DS" "dream-spark: never report a missing bank" "Never report a bank that didn't land."

[ "$fail" -eq 0 ] || exit 1
echo PASS
