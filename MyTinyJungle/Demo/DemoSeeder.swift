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
    /// `-demoDue N`: exactly N plants overdue for water (0 = everyone happy). Above 8, plants are duplicated.
    static var dueCount: Int? {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-demoDue"), i + 1 < a.count else { return nil }
        return Int(a[i + 1])
    }
    static var wantsScan: Bool { ProcessInfo.processInfo.arguments.contains("-demoScan") }
    static let sampleLabel = String(localized: "GreenGrow Houseplant Feed, liquid\nNPK 7-3-6\nNitrogen 7%, Phosphorus 3%, Potassium 6%\nWith magnesium and iron\nDilute 5 ml per litre every 2 weeks in spring and summer", comment: "Demo product label text read by the scanner; write it like a real local fertilizer label, keep the NPK numbers and line breaks")

    private struct Spec { let file: String; let name: String; let species: String; let personality: Personality; let room: String; let outdoor: Bool; let days: Int; let lastWater: Int }
    private static var specs: [Spec] { [
        .init(file: "monstera", name: String(localized: "Monty", comment: "Demo plant nickname; pt-BR: a cute Brazilian nickname"), species: "monstera-deliciosa", personality: .chatty, room: String(localized: "Living room", comment: "Demo plant room name"), outdoor: false, days: 240, lastWater: 4),
        .init(file: "pothos", name: String(localized: "Goldie", comment: "Demo plant nickname; pt-BR: a cute Brazilian nickname"), species: "epipremnum-aureum", personality: .cheerful, room: String(localized: "Kitchen", comment: "Demo plant room name"), outdoor: false, days: 180, lastWater: 9),
        .init(file: "orchid", name: String(localized: "Pearl", comment: "Demo plant nickname; pt-BR: a cute Brazilian nickname"), species: "phalaenopsis", personality: .calm, room: String(localized: "Bedroom", comment: "Demo plant room name"), outdoor: false, days: 120, lastWater: 6),
        .init(file: "snake", name: String(localized: "Sergeant", comment: "Demo plant nickname; pt-BR: a cute Brazilian nickname"), species: "sansevieria", personality: .independent, room: String(localized: "Office", comment: "Demo plant room name"), outdoor: false, days: 400, lastWater: 15),
        .init(file: "peacelily", name: String(localized: "Lily", comment: "Demo plant nickname; pt-BR: a cute Brazilian nickname"), species: "spathiphyllum", personality: .dramatic, room: String(localized: "Bathroom", comment: "Demo plant room name"), outdoor: false, days: 90, lastWater: 8),
        .init(file: "zz", name: String(localized: "Zeke", comment: "Demo plant nickname; pt-BR: a cute Brazilian nickname"), species: "zamioculcas", personality: .calm, room: String(localized: "Living room", comment: "Demo plant room name"), outdoor: false, days: 300, lastWater: 5),
        .init(file: "basil", name: String(localized: "Pesto", comment: "Demo plant nickname; pt-BR: a cute Brazilian nickname"), species: "ocimum-basilicum", personality: .curious, room: String(localized: "Kitchen", comment: "Demo plant room name"), outdoor: false, days: 40, lastWater: 2),
        .init(file: "echeveria", name: String(localized: "Rosetta", comment: "Demo plant nickname; pt-BR: a cute Brazilian nickname"), species: "echeveria", personality: .independent, room: String(localized: "Balcony", comment: "Demo plant room name"), outdoor: true, days: 150, lastWater: 12),
    ] }

    @MainActor static func seedIfAsked(_ ctx: ModelContext) {
        guard let dir = photoDir else { return }
        try? ctx.delete(model: ChatMessage.self); try? ctx.delete(model: CareEvent.self); try? ctx.delete(model: CareTask.self); try? ctx.delete(model: Plant.self)
        let cal = Calendar.current
        func ago(_ d: Int, _ h: Int = 10) -> Date { cal.date(byAdding: .day, value: -d, to: cal.date(bySettingHour: h, minute: 0, second: 0, of: Date())!)! }
        var list = specs
        if let n = dueCount {
            while list.count < n { list += specs.map { Spec(file: $0.file, name: $0.name + " II", species: $0.species, personality: $0.personality, room: $0.room, outdoor: $0.outdoor, days: $0.days, lastWater: $0.lastWater) } }
            list = list.enumerated().map { i, x in Spec(file: x.file, name: x.name, species: x.species, personality: x.personality, room: x.room, outdoor: x.outdoor, days: x.days, lastWater: i < n ? 45 : 1) }
        }
        for s in list {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("\(s.file).jpg")
            let photo = (try? Data(contentsOf: url)).map { ImageShrinker.jpeg($0, maxSide: 1200) }
            let p = Plant(name: s.name, speciesID: s.species, personality: s.personality, location: s.room)
            p.isOutdoor = s.outdoor; p.photo = photo; p.acquiredAt = ago(s.days); p.createdAt = ago(s.days)
            ctx.insert(p)
            func ev(_ k: CareKind, _ d: Int, _ note: String = "", value: Double? = nil, photo: Data? = nil) {
                let e = CareEvent(kind: k, date: ago(d), note: note, source: "chat"); e.value = value; e.photo = photo; e.plant = p; ctx.insert(e)
            }
            ev(.photo, s.days, String(localized: "First photo", comment: "Demo care log note"), photo: photo)
            let rhythm = max(3, (p.species.map { Int(($0.dryMin + $0.dryMax) / 2) }) ?? 7)
            var d = s.lastWater
            while d < s.days { ev(.water, d); d += rhythm }
            for (i, f) in stride(from: 30, to: s.days, by: 28).enumerated() where i < 5 { ev(.feed, f, String(localized: "Half-strength feed", comment: "Demo care log note")) }
            for (i, m) in stride(from: s.days - 10, to: 0, by: -45).enumerated() { ev(.measure, m, "", value: Double(18 + i * 4)) }
            ev(.newLeaf, max(3, s.lastWater + 6), String(localized: "A new leaf unfurled", comment: "Demo care log note"))
            if s.days > 200 { ev(.repot, s.days - 60, String(localized: "Moved to a 2 cm bigger pot", comment: "Demo care log note")) }
            ev(.rotate, 11)
        }
        let monty = String(localized: "Monty", comment: "Demo plant nickname; pt-BR: a cute Brazilian nickname"), pesto = String(localized: "Pesto", comment: "Demo plant nickname; pt-BR: a cute Brazilian nickname"), pearl = String(localized: "Pearl", comment: "Demo plant nickname; pt-BR: a cute Brazilian nickname")
        let talk: [(String, Bool, String?)] = [
            (String(localized: "Watered \(monty) and \(pesto)", comment: "Demo chat message from the user; two plant nicknames"), true, nil),
            (String(localized: "Thank you! I'll let my top soil dry before the next drink.", comment: "Demo chat reply from a chatty plant"), false, monty),
            (String(localized: "Ahh, fresh water. Pick my top leaves soon so I stay bushy!", comment: "Demo chat reply from a basil plant"), false, pesto),
            (String(localized: "Should I feed \(pearl)?", comment: "Demo chat question from the user; plant nickname"), true, nil),
            (String(localized: "Not yet. It's autumn and I'm resting. Orchid feed again in spring.", comment: "Demo chat reply from an orchid; pt-BR may avoid naming the season"), false, pearl),
        ]
        for (i, t) in talk.enumerated() {
            let m = ChatMessage(text: t.0, fromUser: t.1); m.date = Date().addingTimeInterval(Double(i - talk.count) * 600)
            if let n = t.2 { m.speakerID = (try? ctx.fetch(FetchDescriptor<Plant>()))?.first { $0.name == n }?.id }
            ctx.insert(m)
        }
        try? ctx.save()
    }
}
