# Apple setup — My Tiny Jungle (2026-11-18)

| Item | Value |
|---|---|
| Team ID | JKMB58P38J |
| Bundle ID | com.simpleappscompany.mytinyjungle (portal ID U8X9GR9ZM3) |
| Capabilities | Push, Sign in with Apple, App Groups, iCloud (CloudKit), WeatherKit, In-App Purchase |
| App Group | group.com.simpleappscompany.mytinyjungle |
| iCloud container | iCloud.com.simpleappscompany.mytinyjungle |
| APNs key | 9U98NLQ264, team-scoped (all topics, sandbox+prod), reused. Pointer: ~/.config/mydigitalmagnets/mytinyjungle/apns.json |
| App Apple ID | 6836292367 |
| SKU | mytinyjungle-ios |
| Version | 1.0 (manual release) |
| TestFlight group | Owner (internal, all builds), ID 70ca600c-51b7-48ba-a2a7-8e15688d7a4f, tester Augusto Gomes |

## App Store Connect
- Name "My Tiny Jungle" (available). Locales en-US (primary) + pt-PT: name, subtitle, promo text, description, keywords, URLs filled.
- Support URL https://mytinyjungle.com/support, marketing https://mytinyjungle.com/, privacy https://mytinyjungle.com/privacy (en-US + pt-PT, set via ASC API). Terms: https://mytinyjungle.com/terms. See DomainSetup.md.
- Category Lifestyle / Education. Age rating 4+, with Advertising = Yes. Content rights: no third-party content.
- App Privacy (updated for AdMob, published): Coarse Location, Device ID, Product Interaction and Advertising Data are used for Third-Party Advertising + Analytics, not linked, and used for tracking (ATT). Crash and Performance Data are used for App Functionality + Analytics; Other Diagnostic Data for Advertising + Analytics; none of these are used for tracking. Plant photos, plant data and scans stay on the device.
- Price Free (base USA). Availability: all territories except China mainland (needs ICP filing / security assessment), new territories auto-on.
- Copyright "2026 Simple Apps Company". Review contact Augusto Gomes, as on My Digital Magnets; no demo account needed.
- Export compliance: set `ITSAppUsesNonExemptEncryption = NO` in Info.plist (see MyTinyJungle/Info-Permissions.md).
- Screenshots, app icon and build attach with the first upload (main session).

## Subscriptions — "My Tiny Jungle Plus"
| Item | Value |
|---|---|
| Subscription group ID | 22591574 (ref. name "My Tiny Jungle Plus", localised en-US + pt-PT) |
| Monthly | `com.simpleappscompany.mytinyjungle.plus.monthly`, Apple ID 6836294080, 1 month, €1.99 (PRT base, equalised; US $1.99), level 2 |
| Yearly | `com.simpleappscompany.mytinyjungle.plus.yearly`, Apple ID 6836294184, 1 year, €11.99 (PRT base, equalised; US $9.99), level 1 |

- Display name "My Tiny Jungle Plus" + description in en-US and pt-PT; review notes set (scanner, Plant Doctor, memory insights, plant-sitter link, unlimited plants; free = 5 plants).
- Sold in 174 territories (not China mainland); a China price exists because ASC requires one for every territory.
- App Store only, no multiseat, no Family Sharing, no 12-month-commitment plan.
- Review screenshot: real paywall (Assets/AppStore/paywall-review.png), uploaded 2026-11-19 to both plans.
- pt-BR subscription and group localizations cannot be added while the plans are in their current state; add them after the first approval (pt-PT text serves Brazil meanwhile).
- Both are in the draft submission. They go to review together with version 1.0 once the build is attached.
- App Store Server Notifications V2: production and sandbox URL `https://api.mytinyjungle.com/storekit/notifications` (set in ASC web UI). The API backend on the VPS (127.0.0.1:3300) is not deployed yet; until it is, the route answers 503 and Apple retries.

## Ads (AdMob)
- Free tier shows AdMob native ads between content plus a bottom banner on long read-only pages; no interstitial or app-open ads. My Tiny Jungle Plus removes all ads.
- Consent: Google UMP form (EU/UK), then the ATT prompt after onboarding. Non-personalised ads if consent or tracking is refused.
- ASC description, review notes, age rating (Advertising) and privacy labels updated to match. Site legal pages and app-ads.txt are handled by the domain session.
- AdMob app ID and ad unit IDs: see the "AdMob IDs" line below once signup is verified (test IDs in DEBUG).

## Public TestFlight beta
- Build 1.0 (3), commit d89f0dc, submitted to Beta App Review 2026-11-18.
- External group "Friends & testers" (7d6eed3d-159c-4780-84d6-16ac222e3f51), public link https://testflight.apple.com/join/A8YUuUHj, limit 100.
- Beta review notes: no demo account; sign-in optional (Apple/Google with own account).
- Link is on mytinyjungle.com (hero button + Join the beta section, EN + PT).

## Release readiness (2026-11-19)
- iPhone only (TARGETED_DEVICE_FAMILY 1), portrait only. Build 1.0 (4) archives and exports clean for App Store (aps-environment production, no warnings, iOS 27.2 SDK). Profile refreshed to include Associated Domains.
- App Store screenshots (2026-11-19): iPhone 6.9" (APP_IPHONE_67, 1320×2868, iPhone 18 Pro Max) and iPhone Duo (APP_IPHONE_DUO, 2853×2007, open flat), ten features each, en-US, pt-BR and pt-PT (pt-PT uses pt-BR). Capture: `Tools/appstore/capture.sh <iphone69|duo> <udid> <app>` (Duo: set the posture to open first; inner display is --display=3). Upload: `node Tools/appstore/shots.mjs --apply` (replaces the sets). Sources in Assets/AppStore/screenshots.
- TestFlight build 1.0 (5), uploaded 2026-11-19, in Friends & testers, submitted to Beta App Review. Test info + What to Test in en-US, pt-BR, pt-PT; review notes say sign-in is required (Apple/Google only, no demo account possible). Script: `node Tools/appstore/beta.mjs <build> --apply`.
- Review notes rewritten to match the build (optional sign-in, account deletion, no calendar/contacts, shared jungle, iPhone only).
- In-app: Settings has Privacy Policy, Terms of Use, Help and support links and "Delete account and data". Privacy policy covers sign-in, Open-Meteo weather lookups, camera/photos, shared jungles and LGPD.
- Not submitted. To submit: archive build 4, upload, attach it to version 1.0 with both subscriptions, submit for review.
- Plans are named as on the website, never "Plus": Greenhouse / Estufa (monthly), Jungle / Selva (yearly). App, site, StoreKit config, ASC descriptions and review notes updated 2026-11-19. ASC subscription display names still read "Tiny Jungle Plus" because the plans sit in the draft submission (locked); renaming them and uploading the new Assets/AppStore/paywall-review.png need the plans out of the draft first, which only the owner does.
- Never submit or edit draft submissions; the owner does that.
