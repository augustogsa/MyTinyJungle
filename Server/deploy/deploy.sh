#!/usr/bin/env bash
# Build a static linux/amd64 binary, ship it with the units, migrate, restart, health-check.
set -euo pipefail
cd "$(dirname "$0")/.."
HOST=${MTJ_HOST:-mdm-ovh}
REL=$(git rev-parse --short HEAD)$(git diff --quiet -- . || echo -dirty)
export PATH=$HOME/.local/go/bin:$PATH
go test ./...
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags "-s -w" -o build/mtj-api ./cmd/mtj-api
scp -q build/mtj-api deploy/*.service deploy/*.timer deploy/mtj-backup.sh deploy/mtj-wal-ship.sh deploy/mtj-postgres-setup.sh deploy/mtj-psql deploy/mtj-restore-check.sh deploy/mtj-alert.sh deploy/mtj-watchdog.sh deploy/mtj-ai-setup.sh deploy/mtj-id-setup.sh deploy/provision.sh deploy/mtj-proxy.conf "$HOST:/tmp/"
scp -qr deploy/mtj-id "$HOST:/tmp/"
ssh "$HOST" "set -e
  install -d /opt/mtj/bin
  install -m 0755 /tmp/mtj-api /opt/mtj/bin/mtj-api.new && mv /opt/mtj/bin/mtj-api.new /opt/mtj/bin/mtj-api
  install -m 0700 /tmp/mtj-backup.sh /opt/mtj/bin/mtj-backup.sh
  install -m 0700 /tmp/mtj-wal-ship.sh /tmp/mtj-postgres-setup.sh /tmp/mtj-psql /tmp/mtj-restore-check.sh /tmp/mtj-alert.sh /tmp/mtj-watchdog.sh /opt/mtj/bin/
  install -m 0644 /tmp/mtj-api.service /tmp/mtj-purge.service /tmp/mtj-purge.timer /tmp/mtj-backup.service /tmp/mtj-backup.timer /tmp/mtj-wal-ship.service /tmp/mtj-wal-ship.timer /tmp/mtj-alert@.service /tmp/mtj-watchdog.service /tmp/mtj-watchdog.timer /etc/systemd/system/
  cp /tmp/mtj-postgres-setup.sh /tmp/mtj-ai-setup.sh /tmp/provision.sh /opt/mtj/bin/ 2>/dev/null; bash /opt/mtj/bin/provision.sh; bash /opt/mtj/bin/mtj-ai-setup.sh; cp /tmp/mtj-id-setup.sh /opt/mtj/bin/; rm -rf /opt/mtj/id; cp -r /tmp/mtj-id /opt/mtj/id; rm -rf /tmp/mtj-id; bash /opt/mtj/bin/mtj-id-setup.sh
  grep -q '^MTJ_RELEASE=' /opt/mtj/secrets/api.env && sed -i 's/^MTJ_RELEASE=.*/MTJ_RELEASE=$REL/' /opt/mtj/secrets/api.env || echo 'MTJ_RELEASE=$REL' >> /opt/mtj/secrets/api.env
  set -a; . /opt/mtj/secrets/owner.env; set +a
  /opt/mtj/bin/mtj-api migrate
  systemctl daemon-reload
  systemctl enable -q --now mtj-purge.timer mtj-backup.timer mtj-wal-ship.timer mtj-watchdog.timer
  systemctl enable -q mtj-api && systemctl restart mtj-api
  for i in 1 2 3 4 5; do curl -fsS --unix-socket /run/mtj/api.sock http://mtj-api/health && break; sleep 1; done
  echo
  W=/home/simpleapps/public_html; install -d -o simpleapps -g simpleapps -m 755 \$W/api.mytinyjungle.com/.well-known && install -o simpleapps -g simpleapps -m 644 \$W/mytinyjungle.com/.well-known/assetlinks.json \$W/api.mytinyjungle.com/.well-known/  # Android app links for /p/<token>
  rm -f /tmp/mtj-api /tmp/mtj-*.service /tmp/mtj-*.timer /tmp/mtj-backup.sh /tmp/mtj-wal-ship.sh /tmp/mtj-postgres-setup.sh /tmp/mtj-psql /tmp/mtj-restore-check.sh /tmp/mtj-alert.sh /tmp/mtj-watchdog.sh /tmp/mtj-ai-setup.sh /tmp/mtj-id-setup.sh /tmp/provision.sh"
