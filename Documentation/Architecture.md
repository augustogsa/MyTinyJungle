# Architecture (v0.1)

```
Chat text / chips / scanner / photos
        │
  ChatParser (rules, EN+PT)  ──(unsure)──▶ Foundation Models extraction (v0.2)
        │  ParsedIntent[]
        ▼
  JungleStore (SwiftData) ── CareEvent / Observation / ChatMessage
        │
  CareEngine (deterministic) ── SpeciesLibrary (reviewed JSON)
        │  PlantRequest[] + Answer facts
        ▼
  PlantVoice (personality templates) ──▶ plant messages, Today digest
```

- Every record is an event (append-only). Profile fields (pot, substrate, location) are current values plus history events.
- Watering: never "thirsty" without evidence. Engine predicts a check date from learned drying days (EWMA of observed dry intervals, bounded by species range). Plant asks for a soil check; "dry" → water request; "wet" → pushes estimate later and learns.
- Product compatibility: product property vector (retention, aeration, organic, pH hint, NPK, category) vs species requirement profile → verdict + reasons + confidence. Unknown composition → "Not enough info", never "Suitable".
