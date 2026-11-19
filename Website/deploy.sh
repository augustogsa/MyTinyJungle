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
# tell Bing/Yandex/Naver/Seznam (IndexNow) every URL in the sitemap
python3 -c "import json,re;u=re.findall(r'<loc>(.*?)</loc>',open('dist/sitemap.xml').read());import seo;print(json.dumps({'host':'mytinyjungle.com','key':seo.INDEXNOW_KEY,'keyLocation':'https://mytinyjungle.com/'+seo.INDEXNOW_KEY+'.txt','urlList':u}))" \
  | curl -s -o /dev/null -w "indexnow %{http_code}\n" -H "Content-Type: application/json; charset=utf-8" --data @- https://api.indexnow.org/indexnow || true
echo "deployed"

# Purge Cloudflare cache so new pages and assets show right away.
if [ -f "$HOME/.config/mydigitalmagnets/cloudflare.env" ]; then
  . "$HOME/.config/mydigitalmagnets/cloudflare.env"
  curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID_MYTINYJUNGLE/purge_cache" \
    -H "Authorization: Bearer $(cat "$CLOUDFLARE_API_TOKEN_FILE")" -H "Content-Type: application/json" \
    --data '{"purge_everything":true}' | grep -o '"success":[a-z]*' | head -1
fi
