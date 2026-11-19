#!/usr/bin/env bash
# Nightly, My Tiny Jungle only: logical dump + base backup of its own Postgres + the (already sealed) photo store,
# AES-256 (gpg, key /opt/mtj/secrets/backup.key), kept 14 days in /var/backups/mtj on the VPS. With the WAL archived every
# 15 minutes by mtj-wal-ship this gives point-in-time restore; mtj-restore-check proves it daily.
set -euo pipefail
KEY=/opt/mtj/secrets/backup.key DIR=/var/backups/mtj
stamp=$(date -u +%Y%m%dT%H%M%SZ)
umask 077; mkdir -p "$DIR"
enc() { gpg --batch --yes --quiet --pinentry-mode loopback --passphrase-file "$KEY" --symmetric --cipher-algo AES256 -o "$2" "$1"; }
MTJ_PG_BIN=pg_dump /opt/mtj/bin/mtj-psql -Fc mytinyjungle </dev/null > "$DIR/db-$stamp.dump"
enc "$DIR/db-$stamp.dump" "$DIR/db-$stamp.dump.gpg" && rm -f "$DIR/db-$stamp.dump"
MTJ_PG_BIN=pg_basebackup /opt/mtj/bin/mtj-psql -D - -Ft -X none -c fast </dev/null > "$DIR/base-$stamp.tar"
enc "$DIR/base-$stamp.tar" "$DIR/base-$stamp.tar.gpg" && rm -f "$DIR/base-$stamp.tar"
tar -C /var/lib/mtj -cf "$DIR/media-$stamp.tar" media
enc "$DIR/media-$stamp.tar" "$DIR/media-$stamp.tar.gpg" && rm -f "$DIR/media-$stamp.tar"
gpg --batch --quiet --pinentry-mode loopback --passphrase-file "$KEY" -d "$DIR/db-$stamp.dump.gpg" | MTJ_PG_BIN=pg_restore /opt/mtj/bin/mtj-psql -l >/dev/null
find "$DIR" -maxdepth 1 -name '*.gpg' -mtime +14 -delete
/opt/mtj/bin/mtj-restore-check.sh
echo "backup ok $stamp"
