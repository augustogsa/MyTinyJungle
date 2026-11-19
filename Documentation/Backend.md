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

## Isolation
MTJ shares nothing with other apps on the VPS: own system users (`mtj-api` for the service, `mtj` for the database), own Postgres (rootless podman `mtj-postgres`, quadlet under `/var/lib/mtj-db/home/.config/containers/systemd/`, data in `/var/lib/mtj-db/postgres`, 127.0.0.1:5433, set up by `mtj-postgres-setup.sh`), own backups, own secrets. `/opt/mtj/bin/mtj-psql` runs psql inside the container.

## Backups and upkeep (on the VPS)
- `mtj-backup.timer` 03:30: `pg_dump`, `pg_basebackup` tar and photo store, gpg AES-256 into `/var/backups/mtj`, 14 days kept, then `mtj-restore-check.sh`: a throwaway container restores the base backup, replays WAL to now and counts users.
- `mtj-wal-ship.timer` every 15 min: archived WAL, encrypted, into `/var/backups/mtj/wal`. Point-in-time restore to any moment in the last 14 days.
- `mtj-purge.timer` 04:10: erases accounts deleted 30+ days ago, expired sessions, old invites, diagnostics older than 90 days, store or audit rows older than 400 days.
- `mtj-watchdog.timer` every 5 min: local and public health (restarts the API once), disk, backup age, WAL age, API errors. Any failure, and any failed unit (`OnFailure=mtj-alert@%n`), mails support@simpleappscompany.com, once an hour per subject.
- Crash and hang reports: iOS MetricKit and Android posts go to `POST /v1/diagnostics` (no user id), visible in the admin at `/v1/admin/diagnostics`.

## Rebuild runbook (VPS lost)
1. New host with Apache, podman, crun, gpg; point `MTJ_HOST` at it.
2. Put back `/opt/mtj/secrets` (api.env, owner.env, keys/, backup.key, pg-superuser) from `~/.config/mydigitalmagnets/mytinyjungle/` and the Cloudflare origin certificate.
3. `Server/deploy/deploy.sh`: creates users, Postgres, units and timers, runs migrations.
4. Restore data: `gpg -d --passphrase-file backup.key base-….tar.gpg | tar -x` into `/var/lib/mtj-db/postgres`, copy `wal/` decrypted into the archive, set `restore_command` and `recovery_target_time`, touch `recovery.signal`, start `mtj-postgres`. Or logical: `gpg -d … db-….dump.gpg | mtj-psql pg_restore -d mytinyjungle`. Photos: decrypt and untar `media-….tar.gpg` into `/var/lib/mtj/media`.
5. `Server/deploy/integration.sh` (30 checks), then point Cloudflare DNS at the new host.
Keep copies of the latest `/var/backups/mtj` on the Mac with `rsync -a mdm-ovh:/var/backups/mtj/ ~/Backups/mtj/` when the owner wants a second place.

## App Attest
iOS attests a Secure Enclave key once per install and account (`AppAttest.swift`): `POST /v1/attest/challenge`, then `POST /v1/attest`. The server checks Apple's chain (App Attestation Root CA, embedded), the nonce, app ID `JKMB58P38J.com.simpleappscompany.mytinyjungle`, counter 0 and key ID, and stores the key on the device row (`attested_at`). Android uses Play Integrity in its own client.

## Referrals
`GET /v1/me/referral` gives each user a code and link (mytinyjungle.com/r/<code>, in the AASA file). A new account (7 days or younger) redeems one code with `POST /v1/referrals/{code}/redeem`; both people get 30 days of Plus as a `referral` entitlement (stacking), the sender at most 12 times a year.

## AI plant doctor (Plus)
`POST /v1/diagnose` sends one JPEG plus species and note to Claude (`claude-opus-5-5`) and returns problem, confidence, why, up to 4 steps and urgency, in the app's language. Plus only, 20 a day per user (`ai_usage`), photos never stored. Enabled by `MTJ_AI_KEY` in `api.env` (MyTinyJungle's own Anthropic key); without it the endpoint answers 503 and the app shows "unavailable".

## Analytics (privacy-first)
`POST /v1/events` (no auth, IP rate limited) adds daily counts per event name, platform and app version. No user, device, IP or time finer than a day is stored. Admin: `GET /v1/admin/events`.

## CI
`.github/workflows/ci.yml` on every push and PR: Go vet, race tests, linux build, OpenAPI lint, shell syntax; iOS simulator build unsigned.

## Load test
`Server/deploy/loadtest.sh`: concurrent public reads (health, content manifest) with parallel curl workers; every request opens a new TLS connection, so the bar is p95 under 800 ms and zero 5xx (2026-11-19: 600 requests, 30 workers, p95 368 ms, 0 errors).

## API v1
See `Server/openapi.yaml`. Auth: `/v1/auth/signin|refresh|signout|link`. Account: `/v1/me` (GET, PATCH, DELETE with a 30-day grace period), `/v1/me/push-token`. Sharing: `/v1/jungles`, invites (member, or sitter until a date), member role and end date, remove or leave. Sync: `/v1/sync/pull?since=` and `/v1/sync/push` (last writer wins by client time; an edit made on the current version always wins; stale writes come back as `conflict` with the server copy). Photos: `/v1/media/{jungle}/{id}`. Store: `/v1/store/apple/transactions`, `/v1/store/play/purchases`, webhooks `/storekit/notifications` (URL already set in ASC) and `/play/rtdn`.

## Client rules
- iOS purchases set `appAccountToken = userId`; Android purchases set `obfuscatedAccountId = userId`.
- Keychain service `com.simpleappscompany.mytinyjungle.session`. A stable `deviceId` (UUID) per install.
- iOS client: swift-openapi-generator with `Server/clients/ios/openapi-generator-config.yaml`. Android: `Server/clients/android/generate.sh`.

## Rollout
1. Done: Go server, contract, roles and RLS, sign-in, sync, sharing, encrypted photos, store verification, admin behind Access, hardened service, origin pulls, encrypted off-site backups, purge, 20/20 end-to-end checks.
2. iOS: done. Sign in with Apple/Google, sync engine (SwiftData ↔ records, photos ↔ media), shared jungle on server jungles and invites, StoreKit `appAccountToken`, server content, remote config, data export.
3. Android app on the same contract (Google sign-in → `MTJ_GOOGLE_AUDIENCES`, Play Billing → `MTJ_PLAY_*`).

## Content from the server (species, knowledge, translations, Erty, icons, artwork)

What the app knows that isn't the user's lives in `Content/` and is served by the API, so it changes without an app update.

- Publish: edit `Content/`, then `Server/content/publish.py --apply`. Each file goes to `/var/lib/mtj/content/b/<sha256[:32]>.<ext>` (immutable, never overwritten, old ones kept for older app versions); `manifest.json` (logical path → hash) goes up last, atomically. The script also refreshes the app's bundled seeds, so commit those with the content change.
- API (public, no auth): `GET /v1/content/manifest` (ETag, `max-age=300`, 304 when unchanged) and `GET /v1/content/b/{hash}.{ext}` (`immutable`, one year; Cloudflare edge-caches images).
- App: `ContentStore` (MyTinyJungle/Content) revalidates the manifest at launch and on foreground, downloads missing blobs (4 at a time, SHA-256 checked), adopts the manifest only when every file is present, prunes unreferenced blobs. Files live in Application Support/Content, excluded from backup.
- Mini floor in the bundle: data files as lzfse seeds (~260 KB instead of 1.5 MB), icons at 72 px, Erty stills at 128 px, sign-in art at 836 px. Erty loops are server-only; the still shows until they land.
- Images swap to full quality live; species/knowledge/translations apply on the next launch (they are read once at startup).
- Engines (care, diagnosis, chat, forecast) stay on the device and run on this server-fed data: instant, offline and private, no plant data leaves the phone to get an answer.
- Stays bundled on purpose: alternate app icons (iOS requires them in the bundle), AppMark (share cards render synchronously), tab icons, Google mark.

## Shared jungle (household) on the server

- The household is a non-personal jungle. Its state (members' turns, cover asks, travel, activity, plant roster with small thumbnails) is one JSON document: `GET/PUT /v1/jungles/{id}/house`, compare-and-swap on `version`. A stale write gets 409 with the current copy; the device merges (`HouseState.merge`) and retries. Up to 1 MB.
- Invites: `POST /v1/jungles/{id}/invites` makes a single-use code (7 days) at `https://mytinyjungle.com/join/<code>`. A sitter invite stores the end date on the server; the joiner becomes a sitter until then. The link opens the app (universal link, AASA `/join/*`); without the app it lands on `/join` with a "get the app" page. An invite opened before signing in is kept and redeemed right after sign-in.
- Members: the owner removes someone with `DELETE /v1/jungles/{id}/members/{uid}` (access ends at once, photos included); a member leaves the same way with their own id; the owner ends the jungle with `DELETE /v1/jungles/{id}` (records and photos erased). A device that finds itself no longer a member drops the local copy.
- Member ids are server user ids, so iPhone and Android share one household. Beta households made on iCloud are moved up by the owner on first sync; members join again with a new link.

## Push

- `PUT /v1/me/push-token` per device. After every accepted house write the server wakes the other members' devices: iOS gets a silent `content-available` push (collapse id per jungle) and the app syncs and writes its own local notification in the user's language; Android gets an FCM data message `{jungle}`. Pushes carry no names or plant data.
- APNs: team key `9U98NLQ264` (team `JKMB58P38J`) at `/opt/mtj/secrets/apns.p8`, env `MTJ_APNS_*`. Tries production, then sandbox (development builds). `410` or `BadDeviceToken` on both clears the token.
- FCM: set `MTJ_FCM_SA_FILE` to the My Tiny Jungle Firebase service account when the Android app's Firebase project exists (the MyDigitalMagnets one must not be reused). Until then Android devices simply get no push.

## Remote config

- `Content/config.json`, published with the content pack, live after the next manifest check (launch and foreground): `minVersion` (older builds get a full-screen "Time for an update" with the App Store link) and `flags` (unknown flags default to on). `ads` turns native ad cards off everywhere.

## Data export

- `GET /v1/me/export`: account, sign-in providers, devices, entitlements, jungles and roles, every record you wrote or own, and the photo list with paths. Settings > Account > Download my data saves it as JSON through the share sheet. Account deletion was already there (`DELETE /v1/me`).

## Brain (plant intelligence, mostly internal)
Cheapest first; paid models only when our own can't answer.
1. **Library** (`ai_library`): answers already given, keyed by species + top knowledge matches + language. Text only. Owners rate answers (`POST /v1/diagnose/feedback`); poorly rated ones are dropped.
2. **Own model + knowledge base**: llama.cpp + SmolVLM2 2.2B (Apache-2.0) on 127.0.0.1:8091 (`mtj-ai`, rootless podman as `mtj`, 2.5 GB cap, set up by `deploy/mtj-ai-setup.sh`, restarted by the watchdog). It describes the photo; negated clauses are dropped; the owner's note weighs more. Evidence is ranked against `knowledge.json` (symptoms, pests, diseases, deficiencies) plus the species' own problems from `species.json`, boosted by **scenarios** (room, season, weather, soil, pot, care events), by **clashes** between the plant's needs and its situation, and by pests the species is known for. Answers come from our vetted fixes, translated with the content locale tables.
3. **Free model**: Gemini free tier when `MTJ_GEMINI_KEY` is set.
4. **Claude** (`MTJ_AI_KEY`), last resort, given our candidates; saved to the library. With no key, our best guess is returned with low confidence.
- Weather: Open-Meteo (free, no key), coordinates rounded to ~10 km, cached an hour, never stored.
- `POST /v1/brain/ask` care Q&A (problems, topics, glossary, soils, scenarios), free, never paid.
- `POST /v1/brain/identify` names a plant from a photo with our model, matched to our 600+ species.
- `POST /v1/brain/care-plan` watering rhythm, feeding, light, repotting, toxicity and warnings for the plant's real conditions.
- `PUT /v1/me/weather-watch` frost/heatwave alert push per ~10 km cell, once a day max.
- Gaps (`brain_gaps`): daily counts of knowledge words we couldn't answer, nothing personal; `GET /v1/admin/brain` shows them with library stats so content grows where owners ask.
- Think time is capped at 90 s (Apache 100 s, Cloudflare 100 s).
