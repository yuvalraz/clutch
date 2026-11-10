#!/bin/sh
# Run pull.py every minute as a LaunchAgent.
#   launchd.sh install <host> | uninstall | status
# CLUTCH_LAUNCHCTL replaces launchctl (the tests stub it).
set -u

LABEL=com.clutch.aipaper-pull
HERE=$(cd "$(dirname "$0")" && pwd) || exit 1
LAUNCHCTL=${CLUTCH_LAUNCHCTL:-launchctl}
STATE=$HOME/.clutch
PLIST=$HOME/Library/LaunchAgents/$LABEL.plist
DOMAIN=gui/$(id -u)

# Paths go into XML; the host needs no escaping, its characters are checked.
xml() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

loaded() {
  "$LAUNCHCTL" print "$DOMAIN/$LABEL" >/dev/null 2>&1
}

case ${1:-} in
install)
  host=${2:-}
  # A name that never resolves looks like a closed tablet: every run would end silently.
  case $host in
    ''|-*|*[!A-Za-z0-9.:-]*|*..*) bad=1 ;;
    *:*:*) bad= ;;  # an IPv6 address
    *:*)
      echo "aipaper: pass the address without the port (the port is always 8090)" >&2
      exit 2 ;;
    *) bad= ;;
  esac
  case $host in *[A-Za-z0-9]*) ;; *) bad=1 ;; esac
  if [ -n "$bad" ]; then
    echo "aipaper: the host must hold a letter or digit, only [A-Za-z0-9.:-], no '..', and not start with -" >&2
    exit 2
  fi
  # Never created here: its existence switches other tools on.
  [ -d "$STATE" ] || { echo "aipaper: $STATE is missing; not creating it" >&2; exit 2; }
  # launchd does not create the log directory.
  mkdir -p "$STATE/aipaper" "$HOME/Library/LaunchAgents" || exit 1
  log=$(xml "$STATE/aipaper/pull.log")
  cat > "$PLIST" <<EOF || exit 1
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/python3</string>
    <string>$(xml "$HERE/pull.py")</string>
    <string>--host</string>
    <string>$host</string>
  </array>
  <key>StartInterval</key>
  <integer>60</integer>
  <key>StandardOutPath</key>
  <string>$log</string>
  <key>StandardErrorPath</key>
  <string>$log</string>
</dict>
</plist>
EOF
  # Reinstall: drop the old job first. A failure here means it was not loaded.
  "$LAUNCHCTL" bootout "$DOMAIN/$LABEL" >/dev/null 2>&1
  "$LAUNCHCTL" bootstrap "$DOMAIN" "$PLIST" \
    || { echo "aipaper: launchctl bootstrap failed; $PLIST stays and loads at next login unless you run: launchd.sh uninstall" >&2; exit 1; }
  echo "aipaper: installed; pulling from $host every 60 s, log $STATE/aipaper/pull.log"
  ;;
uninstall)
  "$LAUNCHCTL" bootout "$DOMAIN/$LABEL" >/dev/null 2>&1
  rm -f "$PLIST" || exit 1
  if loaded; then
    echo "aipaper: the job is still loaded; check: launchctl print $DOMAIN/$LABEL" >&2
    exit 1
  fi
  ;;
status)
  if [ -f "$PLIST" ]; then
    echo "plist: $PLIST"
    echo "host: $(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:3' "$PLIST" 2>/dev/null)"
  else
    echo "plist: not installed"
  fi
  if loaded; then echo "loaded: yes"; else echo "loaded: no"; fi
  if [ -f "$STATE/aipaper/journal.json" ]; then
    echo "journal: last written $(stat -f '%Sm' "$STATE/aipaper/journal.json")"
  else
    echo "journal: none yet"
  fi
  if [ -s "$STATE/aipaper/pull.log" ]; then
    echo "log: $(tail -n 1 "$STATE/aipaper/pull.log")"
  fi
  ;;
*)
  echo "usage: launchd.sh install <host> | uninstall | status" >&2
  exit 2
  ;;
esac
