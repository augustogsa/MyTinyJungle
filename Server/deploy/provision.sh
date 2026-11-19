#!/usr/bin/env bash
# One-time (idempotent) VPS setup for mtj-api. Run as root on the VPS: bash provision.sh
set -euo pipefail
# My Tiny Jungle's own Postgres (rootless container of the mtj account; nothing shared with other apps).
bash "$(dirname "$0")/mtj-postgres-setup.sh" >/dev/null
psql() { /opt/mtj/bin/mtj-psql -v ON_ERROR_STOP=1 -Atq "$@" </dev/null; }
S=/opt/mtj/secrets
id mtj-api >/dev/null 2>&1 || useradd --system --no-create-home --shell /sbin/nologin mtj-api
install -d -m 0750 -o root -g mtj-api $S $S/keys
install -d -m 0700 -o mtj-api -g mtj-api /var/lib/mtj /var/lib/mtj/media
install -d -m 0755 /opt/mtj/bin
install -d -m 0700 /var/backups/mtj

if [[ ! -f $S/api.env ]]; then
  declare -A PW
  for r in mtj_owner mtj_auth mtj_app mtj_admin; do
    PW[$r]=$(openssl rand -hex 24)
    if [[ $(psql -c "select 1 from pg_roles where rolname='$r'") == 1 ]]; then
      psql -c "alter role $r login password '${PW[$r]}'"
    else
      psql -c "create role $r login password '${PW[$r]}'"
    fi
  done
  psql -c "alter role mtj_admin bypassrls"
  psql -c "alter role mtj_app nobypassrls" -c "alter role mtj_auth nobypassrls"
  psql -c "drop database if exists mytinyjungle"
  psql -c "create database mytinyjungle owner mtj_owner"
  psql -c "revoke all on database mytinyjungle from public"
  psql -c "grant connect on database mytinyjungle to mtj_auth, mtj_app, mtj_admin"
  psql -c "drop role if exists mtj_app_legacy"
  dsn() { echo "postgres://$1:${PW[$1]}@127.0.0.1:5433/mytinyjungle?sslmode=disable"; }
  umask 027
  cat > $S/api.env <<ENV
MTJ_SOCKET=/run/mtj/api.sock
MTJ_AUTH_DSN=$(dsn mtj_auth)
MTJ_APP_DSN=$(dsn mtj_app)
MTJ_ADMIN_DSN=$(dsn mtj_admin)
MTJ_SIGNING_KID=k$(date +%Y%m)
MTJ_MEDIA_KEY=$(openssl rand -hex 32)
MTJ_APPLE_AUDIENCES=com.simpleappscompany.mytinyjungle
MTJ_GOOGLE_AUDIENCES=
MTJ_ACCESS_TEAM=
MTJ_ACCESS_AUD=
MTJ_ADMIN_EMAILS=
MTJ_PLAY_PACKAGE=
MTJ_PLAY_SA_FILE=
MTJ_PLAY_RTDN_AUDIENCE=
MTJ_PLAY_RTDN_EMAIL=
ENV
  echo "MTJ_OWNER_DSN=$(dsn mtj_owner)" > $S/owner.env
  openssl rand -hex 32 > $S/backup.key
  chown root:mtj-api $S/api.env; chmod 0640 $S/api.env
  chmod 0600 $S/owner.env $S/backup.key
fi
set -a; . $S/api.env; set +a
[[ -f $S/keys/$MTJ_SIGNING_KID.key ]] || { MTJ_KEYS_DIR=$S/keys /opt/mtj/bin/mtj-api keygen "$MTJ_SIGNING_KID"; }
chown root:mtj-api $S/keys/*.key; chmod 0640 $S/keys/*.key
echo provisioned
