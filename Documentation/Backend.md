# Backend — accounts, sync, admin (Go, 2026-11-19)

One My Tiny Jungle account across iPhone, iPad, Android and web: same plants, same Plus, same shared jungle everywhere.

## Lessons from My Digital Magnets
| MDM pain | MTJ rule |
|---|---|
| Supabase → Azure → VPS layers; GoTrue, PostgREST, `anon` roles still in the wire format | Own API, own auth, own tokens, own DB roles, from day one. |
| ~140 client call sites hitting raw tables | Clients only call `/v1` domain routes defined in `Server/openapi.yaml`. |
| iOS and Android drifted | One OpenAPI contract; Swift and Kotlin clients are generated from it. |
| Many services and npm dependency trees | One static Go binary, one third-party library (pgx). |
| Backups added late, not off-site at first | Encrypted nightly backup with restore check and off-site copy from the first day. |

## Shape (live)
`Cloudflare (Full strict + Authenticated Origin Pulls)` → `Apache TLS on the OVH VPS (client cert required)` → `unix socket /run/mtj/api.sock (0660, Apache group only)` → `mtj-api` (Go, ~13 MB RAM) → `PostgreSQL 18 (mdm-postgres container), database mytinyjungle`.

- Direct hits on the origin fail during the TLS handshake; plain HTTP returns 403.
- Source: `Server/` (`cmd/mtj-api`, `internal/api`, `internal/jwt`, `migrations`). Contract: `Server/openapi.yaml`.
- Deploy: `Server/deploy/deploy.sh` (tests, static linux build, ship, provision, migrate, restart, health check). End-to-end: `Server/deploy/integration.sh` (20 checks, run as root on the VPS, cleans up after itself).

## Security
| Layer | What |
|---|---|
| Origin | Cloudflare-only IPs, plus origin pull client certificate (`cloudflare-origin-pull-ca.pem`), unix socket, no TCP port. |
| Admin | `https://api.mytinyjungle.com/admin` sits behind Cloudflare Access (team `simpleappscompany.cloudflareaccess.com`, one-time PIN by email, 12h sessions). The server also checks the Access JWT itself and requires an email in `MTJ_ADMIN_EMAILS` (now `support@simpleappscompany.com`; add more there and in the Access policy "Owners"). |
| Tokens | Ed25519 (EdDSA) access tokens, 30 min, with key id; rotate with `mtj-api keygen kYYYYMM` and set `MTJ_SIGNING_KID` (old keys keep verifying until removed). Refresh tokens are 256-bit, stored only as SHA-256, rotated on every use, one family per device. A reused refresh token revokes every session of the account. |
| Database | Roles `mtj_owner` (migrations), `mtj_auth` (sign-in and store intake, no jungle data), `mtj_app` (row-level security on `mtj.uid`, set per transaction), `mtj_admin` (read-only, bypasses RLS). A code bug can't read another user's jungle. |
| Input | Strict JSON (unknown fields rejected), body limits (2 MB JSON, 8 MB sync batch, 12 MB photo), per-IP and per-account rate limits, security headers. |
| Privacy | Photos are sealed with AES-256-GCM (key in `api.env`, path bound as associated data). Logs record method, route, status and duration only: no IPs, no user ids, no bodies. Co-members only see each other's display names. |
| Service | systemd sandbox: no capabilities, seccomp `@system-service`, read-only system, private /tmp and devices, write access only to `/var/lib/mtj/media`, 512 MB memory cap. |
| Store | App Store JWS verified against the pinned Apple Root CA G3 plus Apple's marker OIDs. Google RTDN needs a verified Google OIDC token from the configured service account, then the Play Developer API is called. |

## Never on this VPS
- `RemoveIPC=yes` in the mtj-api unit. The service's primary group is `nobody` (so it can own the socket), and RemoveIPC deletes every IPC object owned by that group when the service stops, including Apache's accept lock. On 2026-11-19 a restart this way took every site on the box offline for a few minutes (`AH00272 apr_proc_mutex_lock failed`); `/scripts/restartsrv_httpd` brought them back.

## Secrets (VPS, root-only)
`/opt/mtj/secrets/api.env` (DSNs, signing kid, media key, Access team/AUD, admin emails, Play settings), `owner.env` (migration DSN), `keys/*.key` (Ed25519 seeds), `backup.key`. Copies of `backup.key` and the origin certificate are in `~/.config/mydigitalmagnets/mytinyjungle/`.

## Backups and upkeep
- `mtj-backup.timer` 03:30: `pg_dump` plus the photo store, gpg AES-256, decrypt and `pg_restore -l` check, copy to `s3://mdm-prod-media-864145506012-eu3-ls/backups/mytinyjungle/` with a size check, 14 days kept locally.
- `mtj-purge.timer` 04:10: erases accounts deleted 30+ days ago (and their jungles and photos), expired sessions, old invites, and store or audit rows older than 400 days.
- Restore: `gpg -d --passphrase-file backup.key db-….dump.gpg | pg_restore -d mytinyjungle`.

## API v1
See `Server/openapi.yaml`. Auth: `/v1/auth/signin|refresh|signout|link`. Account: `/v1/me` (GET, PATCH, DELETE with a 30-day grace period), `/v1/me/push-token`. Sharing: `/v1/jungles`, invites (member, or sitter until a date), member role and end date, remove or leave. Sync: `/v1/sync/pull?since=` and `/v1/sync/push` (last writer wins by client time; an edit made on the current version always wins; stale writes come back as `conflict` with the server copy). Photos: `/v1/media/{jungle}/{id}`. Store: `/v1/store/apple/transactions`, `/v1/store/play/purchases`, webhooks `/storekit/notifications` (URL already set in ASC) and `/play/rtdn`.

## Client rules
- iOS purchases set `appAccountToken = userId`; Android purchases set `obfuscatedAccountId = userId`.
- Keychain service `com.simpleappscompany.mytinyjungle.session`. A stable `deviceId` (UUID) per install.
- iOS client: swift-openapi-generator with `Server/clients/ios/openapi-generator-config.yaml`. Android: `Server/clients/android/generate.sh`.

## Rollout
1. Done: Go server, contract, roles and RLS, sign-in, sync, sharing, encrypted photos, store verification, admin behind Access, hardened service, origin pulls, encrypted off-site backups, purge, 20/20 end-to-end checks.
2. iOS: generated client, Sign in with Apple, sync engine (SwiftData ↔ records, photos ↔ media), move household from CKShare to jungles and invites, StoreKit `appAccountToken`.
3. Android app on the same contract (Google sign-in → `MTJ_GOOGLE_AUDIENCES`, Play Billing → `MTJ_PLAY_*`).
