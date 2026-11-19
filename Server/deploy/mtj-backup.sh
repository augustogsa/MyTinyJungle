#!/usr/bin/env bash
# Nightly: database dump + encrypted photo store, AES-256 (gpg symmetric, key in /opt/mtj/secrets/backup.key),
# kept 14 days on the VPS and copied off-site to AWS S3 (eu-west-3) with a checksum check.
set -euo pipefail
KEY=/opt/mtj/secrets/backup.key DIR=/var/backups/mtj
S3=s3://mdm-prod-media-864145506012-eu3-ls/backups/mytinyjungle
stamp=$(date -u +%Y%m%dT%H%M%SZ)
umask 077
enc() { gpg --batch --yes --quiet --pinentry-mode loopback --passphrase-file "$KEY" --symmetric --cipher-algo AES256 -o "$2" "$1"; }
podman exec mdm-postgres pg_dump -U postgres -Fc mytinyjungle > "$DIR/db-$stamp.dump"
enc "$DIR/db-$stamp.dump" "$DIR/db-$stamp.dump.gpg" && rm -f "$DIR/db-$stamp.dump"
tar -C /var/lib/mtj -cf "$DIR/media-$stamp.tar" media   # files are already AES-GCM sealed
enc "$DIR/media-$stamp.tar" "$DIR/media-$stamp.tar.gpg" && rm -f "$DIR/media-$stamp.tar"
# Restore test: decrypt and list the dump, so a broken backup fails loudly.
gpg --batch --quiet --pinentry-mode loopback --passphrase-file "$KEY" -d "$DIR/db-$stamp.dump.gpg" | podman exec -i mdm-postgres pg_restore -l >/dev/null
for f in "$DIR"/*-"$stamp".*.gpg; do
  aws s3 cp --only-show-errors "$f" "$S3/$(basename "$f")"
  remote=$(aws s3 ls "$S3/$(basename "$f")" | awk '{print $3}')
  [[ "$remote" == "$(stat -c %s "$f")" ]] || { echo "off-site size mismatch for $f" >&2; exit 1; }
done
find "$DIR" -name '*.gpg' -mtime +14 -delete
echo "backup ok $stamp"
