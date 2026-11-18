# My Tiny Jungle

Plants that talk to their owner. iOS (SwiftUI + SwiftData), offline first, chat first.

- `MyTinyJungle/Intelligence`: ChatParser (EN/PT rules), CareEngine (deterministic care, learns drying days), PlantVoice (personalities), Answerer, ProductAnalyzer (label OCR → compatibility), JungleBrain (orchestration)
- `MyTinyJungle/Knowledge/species.json`: reviewed species seed (44 species)
- `MyTinyJungle/Store`: My Tiny Jungle Plus (€1.99/month, €11.99/year), StoreKit 2; `MyTinyJungle.storekit` for local testing
- `Documentation/`: OpenSourceStack, Roadmap, Architecture

Build: open `MyTinyJungle.xcodeproj`, scheme MyTinyJungle. Tests: `xcodebuild test -scheme MyTinyJungle -parallel-testing-enabled NO`.
