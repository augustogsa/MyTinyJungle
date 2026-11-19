#!/usr/bin/env bash
# Every 5 minutes: API health (incl. database), own Postgres, disk, backup age, and new errors in the API log.
set -uo pipefail
A=/opt/mtj/bin/mtj-alert.sh
h=$(curl -s -m 5 --unix-socket /run/mtj/api.sock http://x/health || true)
if [[ $h != *'"db":true'* ]]; then
  systemctl restart mtj-api; sleep 5
  h2=$(curl -s -m 5 --unix-socket /run/mtj/api.sock http://x/health || true)
  [[ $h2 == *'"db":true'* ]] && $A "API restarted after a failed health check" "Before: ${h:-no answer}" || $A "API is DOWN" "Health: ${h2:-no answer}. Check mtj-api and mtj-postgres (sudo -u mtj podman ps)."
fi
code=$(curl -s -o /dev/null -m 10 -w '%{http_code}' https://api.mytinyjungle.com/health || echo 000)
[[ $code == 200 ]] || $A "public API returns $code" "https://api.mytinyjungle.com/health via Cloudflare"
use=$(df --output=pcent / | tail -1 | tr -dc 0-9); (( use < 90 )) || $A "disk at ${use}%" "$(df -h / | tail -1)"
last=$(ls -t /var/backups/mtj/db-*.gpg 2>/dev/null | head -1)
[[ -n $last && $(( $(date +%s) - $(stat -c %Y "$last") )) -lt 108000 ]] || $A "no backup in the last 30 hours" "Newest: ${last:-none}"
wal=$(ls -t /var/backups/mtj/wal/*.gpg 2>/dev/null | head -1)
[[ -n $wal && $(( $(date +%s) - $(stat -c %Y "$wal") )) -lt 3600 ]] || $A "WAL shipping stalled" "Newest: ${wal:-none}"
errs=$(journalctl -u mtj-api --since "-5min" -o cat --no-pager 2>/dev/null | grep '"level":"ERROR"' | tail -20)
[[ -z $errs ]] || $A "API errors in the last 5 minutes" "$errs"
ai=$(curl -s -m 5 http://127.0.0.1:8091/health || true)
if [[ $ai != *'"ok"'* ]]; then
  (cd /var/lib/mtj-db/home && sudo -u mtj XDG_RUNTIME_DIR=/run/user/$(id -u mtj) systemctl --user restart mtj-ai) || true
  $A "plant vision model restarted" "Health: ${ai:-no answer}. Diagnoses fall back to the knowledge base meanwhile."
fi
exit 0
