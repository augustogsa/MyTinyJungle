#!/usr/bin/env bash
# Ship Server/ to the OVH VPS, cache deps, migrate, restart. Run from repo root or Server/.
set -euo pipefail
cd "$(dirname "$0")/.."
HOST=${MTJ_HOST:-mdm-ovh}
rsync -az --delete --exclude tests ./ "$HOST:/opt/mtj/api/"
ssh "$HOST" 'set -e
  cd /opt/mtj/api
  chown -R root:mtj-api /opt/mtj/api && chmod -R g+rX /opt/mtj/api
  install -m 0644 deploy/mtj-api.service deploy/mtj-backup.service deploy/mtj-backup.timer /etc/systemd/system/
  export DENO_DIR=/var/cache/mtj-api/deno
  deno cache main.ts tools/migrate.ts tools/admin_token.ts
  chown -R mtj-api: /var/cache/mtj-api
  set -a; . /opt/mtj/secrets/api.env; set +a
  deno run --allow-env --allow-net --allow-read tools/migrate.ts
  systemctl daemon-reload && systemctl enable --now mtj-api mtj-backup.timer && systemctl restart mtj-api
  sleep 2; curl -fsS http://127.0.0.1:3300/health; echo'
