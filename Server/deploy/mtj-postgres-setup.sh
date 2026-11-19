#!/usr/bin/env bash
# My Tiny Jungle's own database: a rootless Postgres container owned by the `mtj` system account,
# data in /var/lib/mtj-db/postgres, reachable only on 127.0.0.1:5433. Nothing shared with other apps.
# Idempotent; run as root.
set -euo pipefail
IMG=docker.io/library/postgres:18.6-alpine
install -d -o root -g root -m 0755 /var/lib/mtj-db
id mtj >/dev/null 2>&1 || useradd --system --create-home --home-dir /var/lib/mtj-db/home --shell /sbin/nologin mtj
install -d -o mtj -g mtj -m 0700 /var/lib/mtj-db/home
uid=$(id -u mtj)
grep -q '^mtj:' /etc/subuid || echo "mtj:300000:65536" >> /etc/subuid
grep -q '^mtj:' /etc/subgid || echo "mtj:300000:65536" >> /etc/subgid
loginctl enable-linger mtj
install -d -o mtj -g mtj -m 0700 /var/lib/mtj-db/postgres /var/lib/mtj-db/home/.config/containers/systemd
pw=/opt/mtj/secrets/pg-superuser
[[ -s $pw ]] || { umask 077; openssl rand -hex 32 > "$pw"; }
install -o mtj -g mtj -m 0400 "$pw" /var/lib/mtj-db/home/.pg-superuser
Q=/var/lib/mtj-db/home/.config/containers/systemd/mtj-postgres.container
cat > $Q.new <<UNIT
[Unit]
Description=My Tiny Jungle Postgres (rootless, own account)

[Container]
ContainerName=mtj-postgres
Image=$IMG
PublishPort=127.0.0.1:5433:5432
Volume=/var/lib/mtj-db/postgres:/var/lib/postgresql/data:Z
Volume=/var/lib/mtj-db/home/.pg-superuser:/run/secrets/pg:ro,Z
Environment=POSTGRES_PASSWORD_FILE=/run/secrets/pg
Environment=PGDATA=/var/lib/postgresql/data/pgdata
UserNS=keep-id:uid=70,gid=70
# cgroups v1 host: rootless containers cannot own a cgroup, so podman runs them without one.
PodmanArgs=--shm-size=256m --cgroups=disabled --runtime=crun
Exec=postgres -c listen_addresses=* -c wal_level=replica -c archive_mode=on -c archive_command='test ! -f /var/lib/postgresql/data/wal/%%f && cp %%p /var/lib/postgresql/data/wal/%%f' -c archive_timeout=900 -c password_encryption=scram-sha-256

[Service]
Restart=always

[Install]
WantedBy=default.target
UNIT
changed=0; cmp -s $Q.new $Q || { mv $Q.new $Q; changed=1; }; rm -f $Q.new
chown -R mtj:mtj /var/lib/mtj-db/home/.config
install -d -o mtj -g mtj -m 0700 /var/lib/mtj-db/postgres/wal
u() { (cd /var/lib/mtj-db/home && sudo -u mtj XDG_RUNTIME_DIR=/run/user/$uid "$@"); }
for i in 1 2 3 4 5; do [[ -d /run/user/$uid ]] && break; sleep 1; done
u podman image exists $IMG || u podman pull -q $IMG >/dev/null
u systemctl --user daemon-reload
if [[ $changed == 1 ]]; then u systemctl --user restart mtj-postgres.service; else u systemctl --user start mtj-postgres.service; fi
for i in $(seq 1 30); do u podman exec mtj-postgres pg_isready -q -U postgres 2>/dev/null && break; sleep 1; done
u podman exec mtj-postgres pg_isready -U postgres
