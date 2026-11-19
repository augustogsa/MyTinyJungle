#!/usr/bin/env bash
# Every 15 minutes: encrypt archived WAL segments of My Tiny Jungle's own Postgres into /var/backups/mtj/wal (kept 14 days, matching the base backups).
set -euo pipefail
KEY=/opt/mtj/secrets/backup.key
SRC=/var/lib/mtj-db/postgres/wal OUT=/var/backups/mtj/wal
umask 077; mkdir -p "$OUT"
for f in "$SRC"/0*; do
  [[ -f "$f" ]] || continue
  n=$(basename "$f"); [[ -e "$OUT/$n.gpg" ]] && continue
  gpg --batch --yes --quiet --pinentry-mode loopback --passphrase-file "$KEY" --symmetric --cipher-algo AES256 --compress-algo zlib -o "$OUT/$n.gpg" "$f"
done
find "$SRC" -maxdepth 1 -type f -mmin +2880 -delete
find "$OUT" -maxdepth 1 -name '*.gpg' -mtime +14 -delete
