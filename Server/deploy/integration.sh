#!/usr/bin/env bash
# End-to-end checks against the live socket with two throwaway users; cleans up after itself. Run as root on the VPS.
set -euo pipefail
set -a; . /opt/mtj/secrets/api.env; set +a
S=/run/mtj/api.sock; pass=0
c() { curl -sS --unix-socket $S -H "Authorization: Bearer $1" -H 'Content-Type: application/json' "${@:2}"; }
ok() { pass=$((pass+1)); echo "ok  $1"; }
die() { echo "FAIL $1"; exit 1; }
psqlq() { /opt/mtj/bin/mtj-psql -d mytinyjungle -Atq -c "$1" </dev/null; }
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
hv=$(c $A -X PUT http://x/v1/jungles/$JA/house -d '{"data":{"name":"Home"},"baseVersion":null}' | python3 -c 'import json,sys;print(json.load(sys.stdin)["version"])') && ok "owner writes house state"
st=$(c $B -o /tmp/itest.h -w '%{http_code}' -X PUT http://x/v1/jungles/$JA/house -d '{"data":{"name":"Stale"},"baseVersion":1}'); [[ $st == 409 ]] && grep -q '"Home"' /tmp/itest.h && ok "stale house write gets 409 with current copy"
st=$(c $B -o /dev/null -w '%{http_code}' -X PUT http://x/v1/jungles/$JA/house -d "{\"data\":{\"name\":\"Home 2\"},\"baseVersion\":$hv}"); [[ $st == 200 ]] && ok "member writes on current version"
n=$(c $A http://x/v1/jungles/$JA/house | python3 -c 'import json,sys;print(json.load(sys.stdin)["data"]["name"])'); [[ $n == "Home 2" ]] && ok "owner reads merged house"
st=$(c $B -o /dev/null -w '%{http_code}' http://x/v1/jungles/$JB/house); [[ $st == 404 ]] && ok "house of a jungle with no state is 404"
JS=$(c $A http://x/v1/jungles -d '{"name":"Shared"}' | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])')
st=$(c $B -o /dev/null -w '%{http_code}' -X DELETE http://x/v1/jungles/$JS); [[ $st == 404 ]] && ok "only the owner ends a shared jungle"
st=$(c $A -o /dev/null -w '%{http_code}' -X DELETE http://x/v1/jungles/$JS); [[ $st == 200 ]] && ok "owner ends a shared jungle"
st=$(c $A -o /dev/null -w '%{http_code}' -X DELETE http://x/v1/jungles/$JA); [[ $st == 404 ]] && ok "personal jungle cannot be deleted"
ex=$(c $A http://x/v1/me/export | python3 -c 'import json,sys;d=json.load(sys.stdin);print(len(d["records"]),len(d["account"]),len(d["signIns"]))'); [[ $ex == "2 1 0" || $ex == "2 1 1" ]] && ok "data export ($ex)"
rm -f /tmp/itest.h

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

RC=$(c $A http://x/v1/me/referral | python3 -c 'import json,sys;print(json.load(sys.stdin)["code"])') && ok "referral code issued"
st=$(c $A -o /dev/null -w '%{http_code}' -X POST http://x/v1/referrals/$RC/redeem); [[ $st == 403 ]] && ok "own referral code refused"
st=$(c $B -o /dev/null -w '%{http_code}' -X POST http://x/v1/referrals/$RC/redeem); [[ $st == 200 ]] && ok "friend redeems referral"
pa=$(c $A http://x/v1/me | python3 -c 'import json,sys;print(json.load(sys.stdin)["plus"])'); pb=$(c $B http://x/v1/me | python3 -c 'import json,sys;print(json.load(sys.stdin)["plus"])'); [[ $pa == True && $pb == True ]] && ok "both get Plus from referral"
st=$(c $B -o /dev/null -w '%{http_code}' -X POST http://x/v1/referrals/$RC/redeem); [[ $st == 409 ]] && ok "referral redeemed once"
st=$(c $A -o /dev/null -w '%{http_code}' http://x/v1/attest/challenge -X POST); [[ $st == 200 ]] && ok "attest challenge"
st=$(c $A -o /dev/null -w '%{http_code}' http://x/v1/attest -d '{"keyId":"'$(head -c32 /dev/urandom|base64)'","attestation":"oA=="}'); [[ $st == 400 ]] && ok "bogus attestation refused"
st=$(c x -o /dev/null -w '%{http_code}' http://x/v1/events -d '{"platform":"ios","appVersion":"itest","counts":{"itest_event":2,"BAD NAME":1}}'); [[ $st == 200 ]] && [[ $(psqlq "select sum(n) from event_counts where app_version='itest'") == 2 ]] && ok "anonymous event counts"
psqlq "delete from event_counts where app_version='itest'" >/dev/null
leaf=$(python3 -c 'import json;m=json.load(open("/var/lib/mtj/content/manifest.json"));print(m["files"]["art/signin-leaves.jpg"]["h"])')
python3 -c 'import base64,json,sys;print(json.dumps({"photo":base64.b64encode(open(sys.argv[1],"rb").read()).decode(),"species":"Monstera","note":"fine webbing and tiny moving dots under the leaves, dusty speckles","lang":"es"}))' /var/lib/mtj/content/b/$leaf > /tmp/mtj-dx.json
dx=$(c $A -m 120 http://x/v1/diagnose -d @/tmp/mtj-dx.json); rm -f /tmp/mtj-dx.json
echo "$dx" | python3 -c 'import json,sys;d=json.load(sys.stdin);assert d["source"] in ("internal","library") and d["problem"] and d["steps"],d' && ok "brain answers internally ($(echo "$dx" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["source"],"·",d["problem"])'))"
ref=$(echo "$dx" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("ref",""))'); [[ $(c $A -o /dev/null -w '%{http_code}' http://x/v1/diagnose/feedback -d "{\"ref\":\"$ref\",\"helped\":true}") == 200 ]] && ok "diagnosis feedback"
ask=$(c $A http://x/v1/brain/ask -d '{"q":"how do I root a cutting in water?","lang":"pt-BR","situation":{"room":["heater"],"season":["winter"]}}'); echo "$ask" | python3 -c 'import json,sys;a=json.load(sys.stdin)["answers"];assert a,a' && ok "brain answers questions ($(echo "$ask" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)["answers"]))') answers)"
did=$(c $A http://x/v1/me | python3 -c 'import json,sys;print([d["id"] for d in json.load(sys.stdin)["devices"]][0])'); [[ $(c $A -X PUT -o /dev/null -w '%{http_code}' http://x/v1/me/weather-watch -d "{\"lat\":-23.55,\"lon\":-46.63,\"lang\":\"pt-BR\",\"on\":true,\"deviceId\":\"$did\"}") == 200 ]] && ok "weather watch on"
cp=$(c $A http://x/v1/brain/care-plan -d '{"species":"costela de adão","lang":"pt-BR","situation":{"room":["heater"],"humidity":["low"],"season":["winter"],"pot":["terracotta"]}}'); echo "$cp" | python3 -c 'import json,sys;d=json.load(sys.stdin);assert d["species"]=="monstera-deliciosa" and d["warnings"] and d["waterEveryDays"][0]>0,d' && ok "care plan for real conditions ($(echo "$cp" | python3 -c 'import json,sys;print(json.load(sys.stdin)["waterEveryDays"])') days)"
for sp in aloe-vera chlorophytum zamioculcas monstera-deliciosa; do
  python3 -c 'import base64,json,sys;print(json.dumps({"photo":base64.b64encode(open(sys.argv[1],"rb").read()).decode(),"lang":"en"}))' /tmp/idcheck/$sp.jpg > /tmp/mtj-id.json
  idr=$(c $A -m 90 http://x/v1/brain/identify -d @/tmp/mtj-id.json)
  echo "$idr" | python3 -c 'import json,sys;d=json.load(sys.stdin);assert sys.argv[1] in [c["id"] for c in d["candidates"]],d' $sp || die "identify $sp: $idr"
done; rm -f /tmp/mtj-id.json; ok "identify from photo (4 species, own model)"
# Weekly digest, daily limits, photo retention.
E=33333333-3333-4333-8333-$(openssl rand -hex 6); T=44444444-4444-4444-8444-$(openssl rand -hex 6); ep=$(date -u +%s)
c $A http://x/v1/sync/push -d "{\"changes\":[{\"jungleId\":\"$JA\",\"entity\":\"care_event\",\"id\":\"$E\",\"data\":{\"kind\":\"newLeaf\",\"date\":$ep,\"plantID\":\"$P\",\"photo\":\"h1\"},\"baseVersion\":null,\"clientUpdatedAt\":\"$now\"},{\"jungleId\":\"$JA\",\"entity\":\"care_task\",\"id\":\"$T\",\"data\":{\"title\":\"Repot\",\"kind\":\"repot\",\"plantID\":\"$P\",\"due\":$((ep+86400)),\"done\":false},\"baseVersion\":null,\"clientUpdatedAt\":\"$now\"}]}" >/dev/null
dg=$(c $A http://x/v1/me/digest); echo "$dg" | python3 -c 'import json,sys;d=json.load(sys.stdin);assert [i["kind"] for i in d["grew"]]==["newLeaf"] and any(i["kind"]=="task" and i["title"]=="Repot" for i in d["due"]) and d["photos"][0]["media"].endswith(sys.argv[1]) and d["watch"]==[],d' $E && ok "weekly digest (due, grew, photos)"
[[ $(c $B http://x/v1/me/digest | python3 -c 'import json,sys;d=json.load(sys.stdin);print(len(d["due"])+len(d["grew"]))') == 0 ]] && ok "digest only covers your jungles"
[[ $(c $A -X PUT -o /dev/null -w '%{http_code}' http://x/v1/me/digest -d "{\"on\":false,\"deviceId\":\"$did\",\"lang\":\"pt-BR\"}") == 200 && $(psqlq "select digest_on, digest_lang from devices where id='$did'") == "f|pt-BR" ]] && ok "digest opt-out per device"
[[ $(c $A -X PUT -o /dev/null -w '%{http_code}' http://x/v1/me/digest -d "{\"on\":true,\"deviceId\":\"$(cat /proc/sys/kernel/random/uuid)\"}") == 404 ]] && ok "digest toggle refuses another device"
psqlq "insert into api_quota (subject, kind, n) values ('u:$UA', 'ask', 300) on conflict (day, subject, kind) do update set n = 300" >/dev/null
r=$(c $A -w ' %{http_code}' http://x/v1/brain/ask -d '{"q":"water?","lang":"en"}'); [[ $r == '{"error":"daily_limit"}'*429 ]] && ok "daily limit 429 on ask"
psqlq "delete from api_quota where subject in ('u:$UA', 'd:$did')" >/dev/null
[[ $(c $A -o /dev/null -w '%{http_code}' http://x/v1/brain/ask -d '{"q":"water?","lang":"en"}') == 200 && $(psqlq "select n from api_quota where subject='d:$did' and kind='ask' and day=current_date") == 1 ]] && ok "quota counted per device"
psqlq "delete from api_quota where subject in ('u:$UA', 'd:$did')" >/dev/null
[[ $(psqlq "select count(*) from information_schema.tables where table_name='ai_spend'") == 1 ]] && ok "paid spend guard table"
O=55555555-5555-4555-8555-$(openssl rand -hex 6)
psqlq "insert into media (jungle_id, id, content_type, bytes, created_at) values ('$JA', '$O', 'image/jpeg', 1, now() - interval '31 days')" >/dev/null
install -o mtj-api -m 600 /dev/null /var/lib/mtj/media/$JA/$O
systemctl start mtj-purge.service
[[ $(psqlq "select count(*) from media where id='$O'") == 0 && ! -e /var/lib/mtj/media/$JA/$O && -e /var/lib/mtj/media/$JA/$M ]] && ok "unattached photo older than 30 days purged, new one kept"
# Moisture calibration, next week in the digest, households, plant passport, supplies, batch identify, metrics.
UB=$(c $B http://x/v1/me | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])')
jq1() { python3 -c "import json,sys;d=json.load(sys.stdin);print($1)"; }
pushone() { c $1 http://x/v1/sync/push -d "{\"changes\":[{\"jungleId\":\"$2\",\"entity\":\"$3\",\"id\":\"$4\",\"data\":$5,\"baseVersion\":null,\"clientUpdatedAt\":\"$now\"}]}" | jq1 'd["results"][0]["status"]'; }
[[ $(pushone $A $JA care_event 66666666-6666-4666-8666-$(openssl rand -hex 6) "{\"kind\":\"soilCheck\",\"date\":$ep,\"plantID\":\"$P\",\"moisture\":{\"method\":\"finger\",\"value\":5}}") == invalid ]] && ok "bad moisture reading refused"
[[ $(pushone $A $JA care_event 66666666-6666-4666-8666-$(openssl rand -hex 6) "{\"kind\":\"soilCheck\",\"date\":$ep,\"plantID\":\"$P\",\"moisture\":{\"method\":\"meter\",\"value\":2}}") == ok ]] && \
  c $A http://x/v1/me/digest | python3 -c 'import json,sys;d=json.load(sys.stdin);n=d["next"];assert n["week"]>d["week"] and isinstance(n["weather"],list) and any(i["kind"]=="water" and i["plantId"]==sys.argv[1] and i["date"][:10]<=__import__("datetime").datetime.utcnow().strftime("%Y-%m-%d") for i in d["due"]),d' $P && ok "dry meter reading makes water due now; digest has next week"
H=$(c $A http://x/v1/households -d "{\"name\":\"Flat\",\"jungleId\":\"$JA\"}" | jq1 'd["id"]') && ok "household created on own jungle"
[[ $(c $B -o /dev/null -w '%{http_code}' http://x/v1/households -d "{\"name\":\"X\",\"jungleId\":\"$JA\"}") == 403 ]] && ok "household only on a jungle you own"
hc=$(c $A http://x/v1/households/$H/invites -d '{}' | jq1 'd["code"]')
[[ $(c $B -X POST http://x/v1/invites/$hc/redeem | jq1 'd.get("householdId","")') == "$H" ]] && ok "carer joins household with the jungle join link"
[[ $(c $B "http://x/v1/sync/pull?since=0" | jq1 'len([x for x in d["changes"] if x["entity"]=="plant"])') -ge 1 ]] && ok "carer syncs the household plants"
[[ $(c $B http://x/v1/households | jq1 'd["households"][0]["role"]+str(len(d["households"][0]["members"]))') == carer2 ]] && ok "household members and roles"
[[ $(c $B -o /dev/null -w '%{http_code}' -X PUT http://x/v1/households/$H/assignments -d "{\"plantId\":\"$P\",\"userId\":\"$UB\"}") == 403 ]] && ok "carer cannot assign plants"
[[ $(c $A -o /dev/null -w '%{http_code}' -X PUT http://x/v1/households/$H/assignments -d "{\"plantId\":\"$P\",\"userId\":\"$UB\"}") == 200 ]] && \
  c $A "http://x/v1/households/$H/rotation?days=14" | python3 -c 'import json,sys;d=json.load(sys.stdin);t=[x for x in d["turns"] if x["plantId"]==sys.argv[1]];assert t and all(x["userId"]==sys.argv[2] and x["assigned"] for x in t) and len(d["members"])==2,d' $P $UB && ok "rotation gives the assigned plant to its carer"
[[ $(c $B -o /dev/null -w '%{http_code}' -X DELETE http://x/v1/households/$H/members/$UB) == 200 && $(c $B http://x/v1/households | jq1 'len(d["households"])') == 0 && $(c $B "http://x/v1/sync/pull?since=0" | jq1 'len(d["changes"])') == 0 ]] && ok "carer leaves household and its jungle"
P2=77777777-7777-4777-8777-$(openssl rand -hex 6)
pushone $A $JA plant $P2 "{\"name\":\"Bob the Monstera\",\"speciesID\":\"monstera-deliciosa\",\"learnedDryDays\":9,\"potDiameterCm\":17,\"potMaterial\":\"plastic\",\"createdAt\":$ep}" >/dev/null
pp=$(c $A http://x/v1/plants/$P2/passport -d '{"notes":"Likes a moss pole"}')
TK=$(echo "$pp" | jq1 'd["token"]'); echo "$pp" | python3 -c 'import json,sys;d=json.load(sys.stdin);assert d["url"].startswith("https://") and d["url"].endswith(d["token"]),d' && ok "plant passport link"
pub=$(curl -sS --unix-socket $S "http://x/v1/passports/$TK?lang=pt-BR")
echo "$pub" | python3 -c 'import json,sys;d=json.load(sys.stdin);assert d["species"]["id"]=="monstera-deliciosa" and d["waterEveryDays"]==9 and d["notes"]=="Likes a moss pole",d' && ! grep -q "Bob" <<<"$pub" && ok "public card has care, no personal name"
[[ $(curl -sS --unix-socket $S -o /tmp/itest.p -w '%{http_code}' http://x/p/$TK) == 200 ]] && grep -q "Monstera" /tmp/itest.p && ! grep -q "Bob" /tmp/itest.p && ok "public passport page"; rm -f /tmp/itest.p
ip=$(c $B http://x/v1/passports/$TK/import -d '{"lang":"en"}' | jq1 'd["plantId"]')
[[ $(c $B "http://x/v1/sync/pull?since=0" | python3 -c 'import json,sys;print([x["data"]["speciesID"] for x in json.load(sys.stdin)["changes"] if x["id"]==sys.argv[1]][0])' $ip) == monstera-deliciosa ]] && ok "passport imported into another account"
c $A -X DELETE http://x/v1/plants/$P2/passport >/dev/null; [[ $(curl -sS --unix-socket $S -o /dev/null -w '%{http_code}' http://x/v1/passports/$TK) == 404 ]] && ok "unshared passport is gone"
c $A "http://x/v1/plants/$P2/supplies?lang=pt-BR" | python3 -c 'import json,sys;d=json.load(sys.stdin);assert d["soil"]["code"]=="aroid" and d["pot"]["diameterCm"]==20 and len(d["items"])==3 and all(i["affiliate"] is None for i in d["items"]),d' && ok "supplies for the species"
SU=88888888-8888-4888-8888-$(openssl rand -hex 6)
[[ $(c $A -X PUT http://x/v1/me/supplies/$SU -d '{"kind":"soil","name":"Aroid mix","qty":1,"unit":"L","lowAt":2}' | jq1 'd["low"]') == True && $(c $A http://x/v1/me/supplies | jq1 'len(d["supplies"])') == 1 ]] && ok "supply stock with low mark"
[[ $(c $B -o /dev/null -w '%{http_code}' -X PUT http://x/v1/me/supplies/$SU -d '{"kind":"soil","name":"Mine","qty":5}') != 200 && $(c $A http://x/v1/me/supplies | jq1 'd["supplies"][0]["name"]') == "Aroid mix" ]] && ok "supplies are private"
python3 -c 'import base64,json,sys;print(json.dumps({"photo":base64.b64encode(open(sys.argv[1],"rb").read()).decode(),"lang":"en"}))' /tmp/idcheck/monstera-deliciosa.jpg > /tmp/mtj-id.json
c $A -m 100 http://x/v1/brain/identify-batch -d @/tmp/mtj-id.json | python3 -c 'import json,sys;d=json.load(sys.stdin);assert d["items"] and d["charged"]>=1 and any("monstera-deliciosa" in [c["id"] for c in i["candidates"]] for i in d["items"]),d' && ok "batch identify finds the plant"
psqlq "update api_quota set n = 59 where subject = 'u:$UA' and kind = 'identify' and day = current_date" >/dev/null
[[ $(c $A -m 100 http://x/v1/brain/identify-batch -d @/tmp/mtj-id.json | jq1 'd["charged"]') == 1 ]] && ok "batch identify stops at the daily limit"; rm -f /tmp/mtj-id.json
psqlq "delete from api_quota where subject in ('u:$UA', 'd:$did')" >/dev/null
[[ $(c $A http://x/v1/brain/identify/feedback -d '{"suggested":"monstera-deliciosa","chosen":"philodendron-hederaceum"}' | jq1 'd["outcome"]') == corrected ]] && ok "identify correction counted"
st=$(c x -o /dev/null -w '%{http_code}' http://x/v1/admin/metrics); [[ $st == 403 ]] && ok "admin metrics refuses without Access"
[[ $(psqlq "select count(*) from information_schema.tables where table_name='weather_pattern_sent'") == 1 ]] && ok "weather pattern dedupe table"
cpw=$(c $A http://x/v1/brain/care-plan -d '{"species":"pothos","lang":"en","medium":"water","weather":{"lat":-23.5,"month":1,"rain7":40,"rainToday":12,"max16":31,"min16":20,"hasNormals":false}}'); echo "$cpw" | python3 -c 'import json,sys;d=json.load(sys.stdin);assert d["medium"]=="water" and d["waterStyle"]=="refresh" and d["followUps"],d' && ok "water culture plan refreshes, never waters"
python3 -c 'import base64,json,sys;print(json.dumps({"photo":base64.b64encode(open(sys.argv[1],"rb").read()).decode(),"lang":"en"}))' /tmp/idcheck/aloe-vera.jpg > /tmp/mtj-sc.json
sc=$(c $A -m 120 http://x/v1/brain/scene -d @/tmp/mtj-sc.json); rm -f /tmp/mtj-sc.json
echo "$sc" | python3 -c 'import json,sys;s=json.load(sys.stdin)["scene"];assert all(k in s for k in ("plant","pot","soil","light","surroundings")) and "conf" in s["soil"]["medium"],s' && ok "whole scene from photo (medium $(echo "$sc" | python3 -c 'import json,sys;print(json.load(sys.stdin)["scene"]["soil"]["medium"]["value"])'))"
[[ $(c $A -o /dev/null -w '%{http_code}' http://x/v1/brain/feedback -d '{"kind":"species","predicted":"aloe-vera","corrected":"haworthia","lang":"en"}') == 200 ]] && [[ $(c $A -o /dev/null -w '%{http_code}' http://x/v1/brain/feedback -d '{"kind":"nope"}') == 400 ]] && ok "brain feedback"
st=$(c x -o /dev/null -w '%{http_code}' http://x/v1/admin/stats); [[ $st == 403 ]] && ok "admin API refuses without Access"
st=$(c x -o /dev/null -w '%{http_code}' http://x/v1/admin/limits); [[ $st == 403 ]] && ok "admin limits refuses without Access"
st=$(c $A -o /dev/null -w '%{http_code}' -X DELETE http://x/v1/me); [[ $st == 200 ]] && ok "account deletion"
if [[ -f /tmp/eval/run.py ]]; then python3 /tmp/eval/run.py --quick || die "brain eval below thresholds"; ok "brain eval (quick) passes thresholds"; fi
echo "passed $pass checks"
