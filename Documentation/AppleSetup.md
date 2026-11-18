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
- Category Lifestyle / Education. Age rating: all None/No (4+). Content rights: no third-party content.
- App Privacy: Data Not Collected (photos and scans processed on-device, no tracking), published.
- Price Free (base USA). Availability: all territories except China mainland (needs ICP filing / security assessment), new territories auto-on.
- Copyright "2026 Simple Apps Company". Review contact Augusto Gomes, as on My Digital Magnets; no demo account needed.
- Export compliance: set `ITSAppUsesNonExemptEncryption = NO` in Info.plist (see MyTinyJungle/Info-Permissions.md).
- Screenshots, app icon and build attach with the first upload (main session).

## Subscriptions — "Tiny Jungle Plus"
| Item | Value |
|---|---|
| Subscription group ID | 22591574 (ref. name "Tiny Jungle Plus", localised en-US + pt-PT) |
| Monthly | `com.simpleappscompany.mytinyjungle.plus.monthly`, Apple ID 6836294080, 1 month, €1.99 (PRT base, equalised; US $1.99), level 2 |
| Yearly | `com.simpleappscompany.mytinyjungle.plus.yearly`, Apple ID 6836294184, 1 year, €11.99 (PRT base, equalised; US $9.99), level 1 |

- Display name "Tiny Jungle Plus" + description in en-US and pt-PT; review notes set (scanner, Plant Doctor, memory insights, plant-sitter link, unlimited plants; free = 5 plants).
- Sold in 174 territories (not China mainland); a China price exists because ASC requires one for every territory.
- App Store only, no multiseat, no Family Sharing, no 12-month-commitment plan.
- Review screenshot: plain Forest/Cream placeholder (1290×2796). Replace it with a real paywall screenshot from the first build before submitting for review.
- Both are in the draft submission. They go to review together with version 1.0 once the build is attached.
- App Store Server Notifications V2: production and sandbox URL `https://api.mytinyjungle.com/storekit/notifications` (set in ASC web UI). The API backend on the VPS (127.0.0.1:3300) is not deployed yet; until it is, the route answers 503 and Apple retries.
