import SwiftUI
import SwiftData

/// Screenshot/demo data. Launch with `-demoPhotos <folder of jpgs>` to replace the jungle with real-photo demo plants.
/// `-demoScan` opens the Scan result sheet with a sample fertiliser label.
enum DemoSeeder {
    static var photoDir: String? {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-demoPhotos"), i + 1 < a.count else { return nil }
        return a[i + 1]
    }
    static var wantsScan: Bool { ProcessInfo.processInfo.arguments.contains("-demoScan") }
    static let sampleLabel = "GreenGrow Houseplant Feed, liquid\nNPK 7-3-6\nNitrogen 7%, Phosphorus 3%, Potassium 6%\nWith magnesium and iron\nDilute 5 ml per litre every 2 weeks in spring and summer"

    private struct Spec { let file: String; let name: String; let species: String; let personality: Personality; let room: String; let outdoor: Bool; let days: Int; let lastWater: Int }
    private static let specs: [Spec] = [
        .init(file: "monstera", name: "Monty", species: "monstera-deliciosa", personality: .chatty, room: "Living room", outdoor: false, days: 240, lastWater: 4),
        .init(file: "pothos", name: "Goldie", species: "epipremnum-aureum", personality: .cheerful, room: "Kitchen", outdoor: false, days: 180, lastWater: 9),
        .init(file: "orchid", name: "Pearl", species: "phalaenopsis", personality: .calm, room: "Bedroom", outdoor: false, days: 120, lastWater: 6),
        .init(file: "snake", name: "Sergeant", species: "sansevieria", personality: .independent, room: "Office", outdoor: false, days: 400, lastWater: 15),
        .init(file: "peacelily", name: "Lily", species: "spathiphyllum", personality: .dramatic, room: "Bathroom", outdoor: false, days: 90, lastWater: 8),
        .init(file: "zz", name: "Zeke", species: "zamioculcas", personality: .calm, room: "Living room", outdoor: false, days: 300, lastWater: 5),
        .init(file: "basil", name: "Pesto", species: "ocimum-basilicum", personality: .curious, room: "Kitchen", outdoor: false, days: 40, lastWater: 2),
        .init(file: "echeveria", name: "Rosetta", species: "echeveria", personality: .independent, room: "Balcony", outdoor: true, days: 150, lastWater: 12),
    ]

    @MainActor static func seedIfAsked(_ ctx: ModelContext) {
        guard let dir = photoDir else { return }
        try? ctx.delete(model: ChatMessage.self); try? ctx.delete(model: CareEvent.self); try? ctx.delete(model: CareTask.self); try? ctx.delete(model: Plant.self)
        let cal = Calendar.current
        func ago(_ d: Int, _ h: Int = 10) -> Date { cal.date(byAdding: .day, value: -d, to: cal.date(bySettingHour: h, minute: 0, second: 0, of: Date())!)! }
        for s in specs {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("\(s.file).jpg")
            let photo = (try? Data(contentsOf: url)).map { ImageShrinker.jpeg($0, maxSide: 1200) }
            let p = Plant(name: s.name, speciesID: s.species, personality: s.personality, location: s.room)
            p.isOutdoor = s.outdoor; p.photo = photo; p.acquiredAt = ago(s.days); p.createdAt = ago(s.days)
            ctx.insert(p)
            func ev(_ k: CareKind, _ d: Int, _ note: String = "", value: Double? = nil, photo: Data? = nil) {
                let e = CareEvent(kind: k, date: ago(d), note: note, source: "chat"); e.value = value; e.photo = photo; e.plant = p; ctx.insert(e)
            }
            ev(.photo, s.days, "First photo", photo: photo)
            let rhythm = max(3, (p.species.map { Int(($0.dryMin + $0.dryMax) / 2) }) ?? 7)
            var d = s.lastWater
            while d < s.days { ev(.water, d); d += rhythm }
            for (i, f) in stride(from: 30, to: s.days, by: 28).enumerated() where i < 5 { ev(.feed, f, "Half-strength feed") }
            for (i, m) in stride(from: s.days - 10, to: 0, by: -45).enumerated() { ev(.measure, m, "", value: Double(18 + i * 4)) }
            ev(.newLeaf, max(3, s.lastWater + 6), "A new leaf unfurled")
            if s.days > 200 { ev(.repot, s.days - 60, "Moved to a 2 cm bigger pot") }
            ev(.rotate, 11)
        }
        let talk: [(String, Bool, String?)] = [
            ("Watered Monty and Pesto", true, nil),
            ("Thank you! I'll let my top soil dry before the next drink.", false, "Monty"),
            ("Ahh, fresh water. Pick my top leaves soon so I stay bushy!", false, "Pesto"),
            ("Should I feed Pearl?", true, nil),
            ("Not yet. It's autumn and I'm resting. Orchid feed again in spring.", false, "Pearl"),
        ]
        for (i, t) in talk.enumerated() {
            let m = ChatMessage(text: t.0, fromUser: t.1); m.date = Date().addingTimeInterval(Double(i - talk.count) * 600)
            if let n = t.2 { m.speakerID = (try? ctx.fetch(FetchDescriptor<Plant>()))?.first { $0.name == n }?.id }
            ctx.insert(m)
        }
        try? ctx.save()
    }
}
