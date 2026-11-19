#!/usr/bin/env bash
# End-to-end checks against the live socket with two throwaway users; cleans up after itself. Run as root on the VPS.
set -euo pipefail
set -a; . /opt/mtj/secrets/api.env; set +a
S=/run/mtj/api.sock; pass=0
c() { curl -sS --unix-socket $S -H "Authorization: Bearer $1" -H 'Content-Type: application/json' "${@:2}"; }
ok() { pass=$((pass+1)); echo "ok  $1"; }
die() { echo "FAIL $1"; exit 1; }
psqlq() { podman exec -i mdm-postgres psql -U postgres -d mytinyjungle -Atq -c "$1"; }
A=$(runuser -u mtj-api -g nobody -G mtj-api -- /opt/mtj/bin/mtj-api test-token itest-a@mytinyjungle.test)
B=$(runuser -u mtj-api -g nobody -G mtj-api -- /opt/mtj/bin/mtj-api test-token itest-b@mytinyjungle.test)
trap 'psqlq "delete from users where email like '"'"'itest-%@mytinyjungle.test'"'"'"; rm -rf /var/lib/mtj/media/$JA' EXIT

JA=$(c $A http://x/v1/jungles | python3 -c 'import json,sys;print(json.load(sys.stdin)["jungles"][0]["id"])')
JB=$(c $B http://x/v1/jungles | python3 -c 'import json,sys;print(json.load(sys.stdin)["jungles"][0]["id"])')
[[ $JA != "$JB" ]] && ok "personal jungles created"

P=11111111-1111-4111-8111-$(openssl rand -hex 6)
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
r=$(c $A http://x/v1/sync/push -d "{\"changes\":[{\"jungleId\":\"$JA\",\"entity\":\"plant\",\"id\":\"$P\",\"data\":{\"name\":\"Fern\"},\"baseVersion\":null,\"clientUpdatedAt\":\"$now\"}]}")
V=$(echo "$r" | python3 -c 'import json,sys;x=json.load(sys.stdin)["results"][0];assert x["status"]=="ok",x;print(x["version"])') && ok "push plant"
n=$(c $A "http://x/v1/sync/pull?since=0" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)["changes"]))'); [[ $n == 1 ]] && ok "owner pulls it"
n=$(c $B "http://x/v1/sync/pull?since=0" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)["changes"]))'); [[ $n == 0 ]] || die "RLS leak on pull"; ok "other user cannot see it (RLS)"
s=$(c $B http://x/v1/sync/push -d "{\"changes\":[{\"jungleId\":\"$JA\",\"entity\":\"plant\",\"id\":\"$P\",\"data\":{\"name\":\"Hacked\"},\"baseVersion\":null,\"clientUpdatedAt\":\"$now\"}]}" | python3 -c 'import json,sys;print(json.load(sys.stdin)["results"][0]["status"])')
[[ $s == forbidden ]] || die "foreign write: $s"; ok "other user cannot write it"
old=$(date -u -d '-1 hour' +%Y-%m-%dT%H:%M:%SZ)
s=$(c $A http://x/v1/sync/push -d "{\"changes\":[{\"jungleId\":\"$JA\",\"entity\":\"plant\",\"id\":\"$P\",\"data\":{\"name\":\"Stale\"},\"baseVersion\":0,\"clientUpdatedAt\":\"$old\"}]}" | python3 -c 'import json,sys;print(json.load(sys.stdin)["results"][0]["status"])')
[[ $s == conflict ]] && ok "stale edit returns conflict"
s=$(c $A http://x/v1/sync/push -d "{\"changes\":[{\"jungleId\":\"$JA\",\"entity\":\"plant\",\"id\":\"$P\",\"data\":{\"name\":\"Fern 2\"},\"baseVersion\":$V,\"clientUpdatedAt\":\"$old\"}]}" | python3 -c 'import json,sys;print(json.load(sys.stdin)["results"][0]["status"])')
[[ $s == ok ]] && ok "edit on current version wins"

code=$(c $A http://x/v1/jungles/$JA/invites -d "{\"role\":\"sitter\",\"until\":\"$(date -u -d '+7 days' +%Y-%m-%dT%H:%M:%SZ)\"}" | python3 -c 'import json,sys;print(json.load(sys.stdin)["code"])') && ok "owner creates sitter invite"
c $B -X POST http://x/v1/invites/$code/redeem >/dev/null
n=$(c $B "http://x/v1/sync/pull?since=0" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)["changes"]))'); [[ $n == 1 ]] && ok "sitter joins and sees the plant"
st=$(c $B -o /dev/null -w '%{http_code}' -X POST http://x/v1/invites/$code/redeem); [[ $st == 404 ]] && ok "invite is single use"
names=$(c $B http://x/v1/jungles | python3 -c 'import json,sys;j=[x for x in json.load(sys.stdin)["jungles"] if x["id"]=="'$JA'"][0];print(len(j["members"]))'); [[ $names == 2 ]] && ok "sitter sees members"

M=22222222-2222-4222-8222-$(openssl rand -hex 6)
head -c 2048 /dev/urandom > /tmp/itest.jpg
st=$(curl -sS --unix-socket $S -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $A" -H 'Content-Type: image/jpeg' --data-binary @/tmp/itest.jpg -X PUT http://x/v1/media/$JA/$M)
[[ $st == 201 ]] && ok "photo upload"
grep -qF "$(head -c 64 /tmp/itest.jpg | od -An -tx1 | tr -d ' \n')" <(od -An -tx1 /var/lib/mtj/media/$JA/$M | tr -d ' \n') && die "photo stored in plaintext"; ok "photo encrypted at rest"
curl -sS --unix-socket $S -H "Authorization: Bearer $B" http://x/v1/media/$JA/$M -o /tmp/itest.out; cmp -s /tmp/itest.jpg /tmp/itest.out && ok "member downloads photo intact"
c $A -X DELETE http://x/v1/jungles/$JA/members/$(c $B http://x/v1/me | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])') >/dev/null
st=$(curl -sS --unix-socket $S -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $B" http://x/v1/media/$JA/$M); [[ $st == 404 ]] && ok "removed member loses photo access"
rm -f /tmp/itest.jpg /tmp/itest.out

# Refresh rotation and reuse detection.
UA=$(c $A http://x/v1/me | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])')
R1=itest-refresh-$(openssl rand -hex 16)
H=$(printf %s "$R1" | sha256sum | cut -d' ' -f1)
psqlq "insert into sessions (token_hash, family_id, user_id, device_id, expires_at) values (decode('$H','hex'), gen_random_uuid(), '$UA', gen_random_uuid(), now() + interval '1 day')"
R2=$(c x http://x/v1/auth/refresh -d "{\"refreshToken\":\"$R1\"}" | python3 -c 'import json,sys;print(json.load(sys.stdin)["refreshToken"])') && ok "refresh rotates"
st=$(c x -o /dev/null -w '%{http_code}' http://x/v1/auth/refresh -d "{\"refreshToken\":\"$R1\"}"); [[ $st == 200 ]] && ok "immediate retry of a refresh is tolerated"
psqlq "update sessions set used_at = now() - interval '1 minute' where token_hash = decode('$H','hex')"
st=$(c x -o /dev/null -w '%{http_code}' http://x/v1/auth/refresh -d "{\"refreshToken\":\"$R1\"}"); [[ $st == 401 ]] && ok "reused refresh token refused"
st=$(c x -o /dev/null -w '%{http_code}' http://x/v1/auth/refresh -d "{\"refreshToken\":\"$R2\"}"); [[ $st == 401 ]] && ok "reuse revoked the whole account"

st=$(c x -o /dev/null -w '%{http_code}' http://x/v1/admin/stats); [[ $st == 403 ]] && ok "admin API refuses without Access"
st=$(c $A -o /dev/null -w '%{http_code}' -X DELETE http://x/v1/me); [[ $st == 200 ]] && ok "account deletion"
echo "passed $pass checks"
