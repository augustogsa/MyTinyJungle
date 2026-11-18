# My Tiny Jungle — roadmap

## Principles
- Solid base first: offline, fast, never loses data, never gives unsafe care advice.
- Chat first: people say what they did ("watered Milo and Luna this morning"). The app turns it into records. Fields still exist, filled by chat, editable by tap.
- Shortcuts stay: Water · Feed · Soil check · Photo · Mist chips everywhere.
- The care engine decides. Language (templates / on-device LLM) only speaks.

## v0.1 — Foundation (this build)
- SwiftData store: plants, events, observations, chat, products.
- Reviewed species seed (≈40 common houseplants, EN/PT names, water/light/humidity/temp/substrate/feeding/toxicity).
- CareEngine: moisture-first watering (asks for soil check, learns each plant's drying days from answers), seasonal feeding by hemisphere, repot age, pet-safety warnings.
- Chat parser (EN + PT): watered / fed / misted / repotted / moved / soil dry-moist-wet / height / new leaf / questions; multi-plant, relative dates ("yesterday", "2 days ago", "ontem").
- Plant voices: 6 personalities, consistent per plant.
- Today: requests digest from plants + jungle chat + quick chips.
- Plant chat per plant, profile with fields, photo timeline from real photos.
- Add plant by chat: photo + name + species search.
- Scanner: live barcode + label OCR → NPK / ingredients / category → compatibility per plant (Suitable / With conditions / Not recommended / Not enough info), with reasons.

## v0.2 — Intelligence hardening
- Foundation Models structured extraction as second pass when the rules parser is unsure.
- Pl@ntNet identification through mtj-api (keys server-side).
- Open Products Facts barcode lookup + contribute back.
- Open-Meteo frost/heat alerts for outdoor plants.
- Repotting assessment flow (root photo, pot size suggestion, substrate suggestion).
- Doctor v1: photo + questions → ranked hypotheses with confidence, reassessment task.
- Local notifications: one daily digest + urgent only.
- Unit tests for parser & engine on 200 real sentences.

## v0.3 — Sync & accounts
- mtj-api on the VPS (Postgres, Garage photos, Sign in with Apple), event outbox sync, household sharing.
- Plant-sitter web link (no app needed).
- Export (JSON + photos).

## v0.4 — Premium
- StoreKit 2 subscription: Doctor, scanner compatibility, memory insights, sitter link.
- Growth baseline + anomaly detection ("slower than your usual 30 days per leaf").
- Monthly portrait with ghost overlay.
- Light estimate by camera exposure (labelled estimate).

## Later — the "gimmicks" (after the base is flawless)
- Widgets (plant faces, today's requests), Live Activities (repot recovery), Control Center water button.
- Siri / App Intents ("I watered Milo"), Shortcuts, Apple Watch quick log.
- Voice notes → chat.
- BLE sensors (MiFlora protocol), Open Plant Book thresholds.
- Garden planner, companion planting, propagation lineage, QR plant tags.
- Community, plant swaps.
- Android (backend stays neutral).
