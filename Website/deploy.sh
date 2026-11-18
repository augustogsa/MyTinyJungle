#!/usr/bin/env bash
# Builds and deploys mytinyjungle.com to the OVH VPS (cPanel account simpleapps, addon docroot).
# Keeps the cPanel-generated .htaccess block and appends the site rules.
set -euo pipefail
cd "$(dirname "$0")"
python3 build.py
HOST=${HOST:-mdm-ovh}
D=/home/simpleapps/public_html/mytinyjungle.com
TMP=$(mktemp)
ssh "$HOST" "sed '/^# BEGIN mytinyjungle/,\$d' $D/.htaccess" > "$TMP"
{ cat "$TMP"; echo "# BEGIN mytinyjungle"; cat dist/.htaccess; } > "$TMP.new"
rsync -rlt --exclude .htaccess dist/ "$HOST:$D/"
scp -q "$TMP.new" "$HOST:$D/.htaccess"
ssh "$HOST" "chown -R simpleapps:simpleapps $D; find $D -type d -exec chmod 755 {} +; find $D -type f -exec chmod 644 {} +"
echo "deployed"
