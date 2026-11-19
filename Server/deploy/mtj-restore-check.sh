#!/usr/bin/env bash
# Daily proof that point-in-time restore works: newest encrypted base backup + encrypted WAL are restored
# into a throwaway Postgres (mtj account, no network) and replayed to the end; the data must be readable.
set -euo pipefail
KEY=/opt/mtj/secrets/backup.key DIR=/var/backups/mtj
W=/var/lib/mtj-db/restore-check; rm -rf "$W"; install -d -o mtj -g mtj -m 0700 "$W" "$W/data" "$W/wal"
base=$(ls -t "$DIR"/base-*.tar.gpg | head -1)
dec() { gpg --batch --quiet --pinentry-mode loopback --passphrase-file "$KEY" -d "$1"; }
dec "$base" | tar -C "$W/data" -xf -
for f in "$DIR"/wal/*.gpg; do [[ -e $f ]] && dec "$f" > "$W/wal/$(basename "$f" .gpg)"; done
touch "$W/data/recovery.signal"
echo "restore_command = 'cp /wal/%f %p'" >> "$W/data/postgresql.auto.conf"
echo "recovery_target_action = 'promote'" >> "$W/data/postgresql.auto.conf"
chown -R mtj:mtj "$W"; chmod 0700 "$W/data"
u() { (cd /var/lib/mtj-db/home && sudo -u mtj XDG_RUNTIME_DIR=/run/user/$(id -u mtj) "$@"); }
u podman rm -f mtj-restore-check >/dev/null 2>&1 || true
u podman run -d --name mtj-restore-check --network none --cgroups=disabled --runtime=crun --userns=keep-id:uid=70,gid=70 \
  -v "$W/data:/var/lib/postgresql/data:Z" -v "$W/wal:/wal:ro,Z" -e PGDATA=/var/lib/postgresql/data \
  docker.io/library/postgres:18.6-alpine postgres -c archive_mode=off >/dev/null
ok=""
for i in $(seq 1 60); do
  if u podman exec mtj-restore-check psql -U postgres -d mytinyjungle -Atc "select pg_is_in_recovery()" 2>/dev/null | grep -q f; then ok=1; break; fi
  sleep 2
done
n=$(u podman exec mtj-restore-check psql -U postgres -d mytinyjungle -Atc "select count(*) from users" 2>/dev/null || echo x)
u podman rm -f mtj-restore-check >/dev/null; rm -rf "$W"
[[ -n $ok && $n =~ ^[0-9]+$ ]] || { echo "restore check FAILED" >&2; exit 1; }
echo "restore check ok: $(basename "$base") + WAL replayed, $n users"
