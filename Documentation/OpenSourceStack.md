# My Tiny Jungle — open source & open data stack

Rule: everything on-device first (free, private, offline), open data second, paid APIs last and always behind our own service so keys never ship in the app.

## Plant identity & taxonomy
| Source | Use | License / cost |
|---|---|---|
| Kew **WCVP / POWO** (World Checklist of Vascular Plants) | Canonical accepted names, synonyms, families | CC-BY |
| **GBIF Backbone** + species API | Name matching, synonyms, vernacular names in many languages, native range | CC0 / CC-BY |
| **Wikidata** | Common names (EN/PT/ES/FR/DE), images, links to every other id | CC0 |
| **Wikipedia / Wikimedia Commons** | Short descriptions, reference photos | CC-BY-SA |
| **Pl@ntNet API** | Photo identification (+ diseases since Dec 2025), 500 ids/day free | Free tier, attribution |
| **PlantNet-300K** dataset | Train/benchmark our own on-device Core ML classifier later | CC-BY |
| **iNaturalist open data** (GBIF export) | Observation photos, regional presence | CC-BY / CC0 per photo |

## Care knowledge
| Source | Use |
|---|---|
| **Verdant Care DB** (Hugging Face) | Structured care for ~50 houseplants, 5 languages — cross-check our seed |
| **Plantbase** (github.com/plant-base) | Open houseplant care data — cross-check, license to verify |
| **Open Plant Book** (Home Assistant) | Min/max light (lux), moisture, temp, EC per species — perfect for sensor thresholds |
| **USDA PLANTS** | Growth habit, pH, drought tolerance, US hardiness (public domain) |
| **RHS / university extension guides** (UMN, NCSU Plant Toolbox) | Editor reference for reviewed profiles (link, never copy) |
| **ASPCA toxic/non-toxic list** | Pet toxicity flags (reference + link; editor-entered) |
| **Practical Plants / OpenFarm archives** (CC-BY-SA) | Edible plants, companion planting, sowing calendars |

Our own `species.json` is the reviewed source of truth; every field carries `source` + `reviewed` in v2.

## Products, scanning, OCR
| Source | Use |
|---|---|
| Apple **VisionKit DataScannerViewController** | Live barcode + text scanning on device, free |
| Apple **Vision VNRecognizeTextRequest** | OCR of back labels from photos (EN/PT/ES/FR/DE) |
| **Open Products Facts** (+ universal `product_type=all` lookup) | Barcode → name/brand for non-food products (ODbL). We contribute scans back. |
| **Open Food Facts** taxonomy tooling | Ingredient normalisation patterns |
| Our parser | NPK, ingredients (peat, coco, perlite, bark, pumice…), category, dilution → normalised product |
| EU Fertilising Products Regulation 2019/1009 labelling rules | Know which label fields legally must exist (NPK as % N, P₂O₅, K₂O) |

## Health / diagnosis
| Source | Use |
|---|---|
| **PlantVillage**, **PlantDoc**, **PlantNet disease** datasets | Benchmark & future on-device symptom classifier |
| Pl@ntNet disease endpoint / multimodal LLM via our server | Hypotheses only, always with confidence + follow-up |
| **IPM guides** (UC IPM, open extension docs) | Pest life cycles, non-chemical first steps |

## Environment
| Source | Use |
|---|---|
| **Open-Meteo** | Free weather, frost/heat alerts, sunrise, UV, no key (CC-BY) |
| Apple **WeatherKit** | Alternative, 500k calls/month included |
| Device **ambient light via camera exposure (AVFoundation)** | Rough lux estimate, labelled as estimate |
| **Open Plant Book** thresholds + BLE sensors (Xiaomi Flower Care / MiFlora protocol is documented openly) | Real moisture/light/EC later |
| **pvlib / NOAA solar position** | Direct-sun hours per window orientation & season |

## Language & intelligence
| Tool | Use |
|---|---|
| Apple **Foundation Models** (on-device LLM, iOS 26+) | Turn free chat into structured events, rewrite plant voice, offline, free |
| **NaturalLanguage** framework | Language detection, lemmatisation, name tagging |
| Our deterministic **CareEngine** | All care decisions. LLM never decides care. |
| Server LLM (Claude) behind our API | Long answers, Doctor explanations, label understanding when OCR is messy |
| **pgvector** | Plant memory retrieval on server |

## Backend (reuse what we run)
Our OVH VPS: Postgres (+pgvector, pg_trgm), Garage S3 media, existing auth + APNs + StoreKit server notifications. One new service `mtj-api`. iOS works fully offline on SwiftData; sync is an outbox of events.
