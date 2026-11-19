#!/usr/bin/env bash
# Email an alert to support@ (My Tiny Jungle's own alerts; nothing shared with other apps).
# Usage: mtj-alert.sh "<subject>" [body]   or as OnFailure: mtj-alert.sh unit <unit-name>
set -euo pipefail
TO=support@simpleappscompany.com
if [[ ${1:-} == unit ]]; then
  subj="My Tiny Jungle: $2 failed"
  body=$(journalctl -u "$2" -n 30 --no-pager -o cat 2>&1 | grep -v -i sss | tail -30)
else
  subj="My Tiny Jungle: $1"; body=${2:-}
fi
# At most one identical alert per hour.
stamp=/run/mtj-alert-$(echo "$subj" | md5sum | cut -c1-12)
[[ -e $stamp && $(( $(date +%s) - $(stat -c %Y "$stamp") )) -lt 3600 ]] && exit 0
touch "$stamp"
printf 'From: My Tiny Jungle ops <noreply@mytinyjungle.com>\nTo: %s\nSubject: %s\n\n%s\n\nHost: %s, %s\n' "$TO" "$subj" "$body" "$(hostname)" "$(date -u)" | /usr/sbin/sendmail -t
