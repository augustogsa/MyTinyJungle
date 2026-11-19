# Backend — accounts, sync, admin (2026-11-19)

Goal: one My Tiny Jungle account across iPhone, iPad, Android and web. Same data, same Plus, same shared jungle on every device.

## Lessons carried over from My Digital Magnets
| MDM pain | MTJ rule |
|---|---|
| Supabase → Azure → VPS layers; GoTrue, PostgREST, `anon`/`authenticated` roles still in the wire format (doc 107) | Own API from day one. Own auth, own tokens, own roles. No client-held anon key, no `/rest/v1`. |
| ~140 client call sites hitting raw tables | Clients only call versioned domain routes under `/v1/...`. |
| iOS and Android drifted, fixed later under a parity rule | One API contract; every feature lands on both clients in the same delivery. |
| Keychain/prefs names tied to a vendor, forced session migration | Neutral names: keychain service `com.simpleappscompany.mytinyjungle.session`. |
| Many services (identity, platform, functions, media, postgrest) | One Deno + Hono service, one database. Split only when load says so. |
| Backups added late | Nightly dump from the first day. |

## Shape (live)
- `https://api.mytinyjungle.com` → Cloudflare (Full strict) → OVH VPS Apache proxy → `127.0.0.1:3300` → `mtj-api.service` (Deno + Hono, user `mtj-api`, hardened unit).
- Database `mytinyjungle`, role `mtj_app`, in the shared PostgreSQL 18 container (`mdm-postgres`, loopback 5432). Fully separate from MDM data.
- Secrets: `/opt/mtj/secrets/api.env` (root:mtj-api 0640): `DATABASE_URL`, `MTJ_JWT_SECRET`, `MTJ_RELEASE`, `MTJ_APPLE_AUDIENCES`, `MTJ_GOOGLE_AUDIENCES`.
- Backups: `mtj-backup.timer`, 03:30 daily, `/var/backups/mtj`, 14 kept.
- Source: `Server/`. Deploy: `Server/deploy/deploy.sh` (rsync, cache, migrate, restart, health check). Migrations: `Server/migrations/NNNN_*.sql`, applied once each.

## API v1
| Route | Purpose |
|---|---|
| `GET /health` | service, release, db |
| `POST /v1/auth/signin` | Apple or Google identity token + device → access (1h JWT) + refresh (90d, rotated, stored hashed) |
| `POST /v1/auth/refresh`, `POST /v1/auth/signout` | rotate / end this device's session |
| `POST /v1/auth/link` | add a second provider to the same account (Apple on iPhone + Google on Android = one account) |
| `GET/PATCH/DELETE /v1/me`, `PUT /v1/me/push-token` | profile, devices, Plus status, in-app account deletion (App Review 5.1.1(v)) |
| `GET /v1/sync/bootstrap` | creates the personal jungle, lists jungles the user can reach |
| `GET /v1/sync/pull?since=` | every change after the cursor, across all jungles, paged |
| `POST /v1/sync/push` | batched upserts/tombstones; last writer wins by client time, stale writes come back as `conflict` with the server copy |
| `POST /storekit/notifications`, `POST /play/rtdn` | store events stored raw, then mapped to `entitlements` |
| `/v1/admin/*`, `/admin` | dashboard: stats, users, user detail, store events (admin role only) |

## Data model
`users`, `identities` (provider+subject), `devices`, `sessions`, `jungles` (personal or shared), `jungle_members` (owner/member/sitter + `until`), `invites`, `records` (generic synced rows: `plant`, `care_event`, `chat_message`, `owned_product`, `space`, `care_task`, `observation`; one global version sequence = one cursor), `media` (photos in object storage), `entitlements` (App Store + Play per user), `store_notifications`, `audit_log`.

## Admin
`https://api.mytinyjungle.com/admin`. Sign in with a 12h token: `ssh mdm-ovh 'cd /opt/mtj/api && set -a && . /opt/mtj/secrets/api.env && deno task admin-token <email>'`. The owner's user gets `role = 'admin'` after their first sign-in from the app (`update users set role='admin' where email=...`).

## Rollout
1. Done: server, schema, auth, sync, store intake, admin, backups, deployed and healthy.
2. iOS client: `JungleAPI` (URLSession, keychain session, refresh), Sign in with Apple → `/v1/auth/signin`, sync engine mapping SwiftData models ↔ `records` (photos → `media`). CloudKit backup stays as the offline path until sync is proven, then household moves from CKShare to `jungles` + `invites` so Android members can join.
3. StoreKit: send `appAccountToken = userId` on purchase; verify JWS chain on notifications and upsert `entitlements`.
4. Android client (Kotlin, Compose): same contract, Google sign-in + Play Billing → `/play/rtdn`.
5. Photos: Garage bucket `mtj-media` behind signed upload URLs.
6. Purge job for accounts deleted > 30 days, push via APNs/FCM.
