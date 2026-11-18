import Foundation

/// How well a space suits a plant. Rules, not guesses.
enum PlacementEngine {
    enum Fit: Int, Comparable { case poor, okay, good, ideal
        static func < (a: Fit, b: Fit) -> Bool { a.rawValue < b.rawValue }
        var label: String { switch self { case .ideal: String(localized: "Ideal", comment: "Placement fit rating for a plant in a space. Max 12 chars."); case .good: String(localized: "Good", comment: "Placement fit rating. Max 12 chars."); case .okay: String(localized: "Okay", comment: "Placement fit rating. Max 12 chars."); case .poor: String(localized: "Not great", comment: "Placement fit rating. Max 12 chars.") } }
        var symbol: String { switch self { case .ideal: "checkmark.seal.fill"; case .good: "checkmark.circle.fill"; case .okay: "circle.lefthalf.filled"; case .poor: "exclamationmark.circle" } }
    }

    static func lightIndex(_ l: Species.Light) -> Int { switch l { case .low: 0; case .medium: 1; case .bright: 2; case .direct: 3 } }

    static func fit(_ s: Species, in space: Space, now: Date = Date()) -> (fit: Fit, reasons: [String]) {
        var penalty = 0
        var reasons: [String] = []
        let d = lightIndex(space.light) - lightIndex(s.light)
        switch d {
        case 0: reasons.append(String(localized: "Light is just right", comment: "Placement reason, no final period."))
        case 1: reasons.append(s.light == .low || s.light == .medium ? String(localized: "A bit brighter than it needs. Watch for scorched leaves", comment: "Placement reason, no final period.") : String(localized: "Slightly more light than ideal", comment: "Placement reason, no final period.")); penalty += 1
        case -1: reasons.append(String(localized: "A bit dim. Growth will be slower", comment: "Placement reason, no final period.")); penalty += 1
        default: reasons.append(d > 0 ? String(localized: "Too much sun for it", comment: "Placement reason, no final period.") : String(localized: "Too dark for it", comment: "Placement reason, no final period.")); penalty += 3
        }
        if let h = space.humidity {
            if h + 5 < s.humidityMin { reasons.append(String(localized: "Air is drier (\(Int(h))%) than it likes (\(Int(s.humidityMin))%+)", comment: "Placement reason. Args: room humidity percent, minimum humidity percent.")); penalty += h + 15 < s.humidityMin ? 2 : 1 }
            else { reasons.append(String(localized: "Humidity suits it", comment: "Placement reason, no final period.")) }
        } else if s.humidityMin >= 55 {
            reasons.append(String(localized: "Likes humid air. A bathroom or a plant group helps", comment: "Placement reason, no final period."))
        }
        if let t = space.temperature {
            if t < s.tempMin { reasons.append(String(localized: "Too cold (\(Climate.temp(t)))", comment: "Placement reason. %@ = formatted temperature.")); penalty += 3 }
            else if t > s.tempMax { reasons.append(String(localized: "Too hot (\(Climate.temp(t)))", comment: "Placement reason. %@ = formatted temperature.")); penalty += 2 }
        }
        if space.isOutdoor && CareEngine.isWinter(now) && s.tempMin >= 10 {
            reasons.append(String(localized: "Outdoors in winter is too cold. Bring it in", comment: "Placement reason, no final period.")); penalty += 3
        }
        let fit: Fit = penalty == 0 ? .ideal : penalty == 1 ? .good : penalty <= 2 ? .okay : .poor
        return (fit, reasons)
    }

    static func lightLabel(_ l: Species.Light) -> String {
        switch l { case .low: String(localized: "Low light", comment: "Light level label. Max 20 chars."); case .medium: String(localized: "Medium, indirect", comment: "Light level label. Max 20 chars."); case .bright: String(localized: "Bright, indirect", comment: "Light level label. Max 20 chars."); case .direct: String(localized: "Direct sun", comment: "Light level label. Max 20 chars.") }
    }
    static func lightSymbol(_ l: Species.Light) -> String {
        switch l { case .low: "moon"; case .medium: "cloud.sun"; case .bright: "sun.max"; case .direct: "sun.max.fill" }
    }
}

/// Upcoming care predicted from the engine plus the user's tasks.
struct AgendaItem: Identifiable {
    let id: String
    let date: Date
    let plant: Plant?
    let kind: CareKind
    let title: String
    let task: CareTask?
}

enum Agenda {
    static func items(plants: [Plant], tasks: [CareTask], days: Int, now: Date = Date()) -> [AgendaItem] {
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: days, to: now)!
        var out: [AgendaItem] = []
        for p in plants where !p.isArchived {
            // Soil checks, repeating on the learned rhythm.
            let expected = CareEngine.expectedDryDays(for: p, at: now)
            var next = p.lastEvent(.water).map { $0.date.addingTimeInterval(expected * 86_400) } ?? now
            if next < now { next = now }
            while next <= end {
                out.append(.init(id: "\(p.id)-w-\(Int(next.timeIntervalSince1970 / 86_400))", date: next, plant: p, kind: .soilCheck, title: String(localized: "Check \(p.name)'s soil", comment: "Agenda item title. %@ = plant name."), task: nil))
                next = next.addingTimeInterval(max(expected, 1) * 86_400)
            }
            if let s = p.species {
                var feed = p.lastEvent(.feed).map { $0.date.addingTimeInterval(s.feedWeeks * 7 * 86_400) } ?? now
                if feed < now { feed = now }
                while feed <= end {
                    if CareEngine.isGrowingSeason(feed) {
                        out.append(.init(id: "\(p.id)-f-\(Int(feed.timeIntervalSince1970 / 86_400))", date: feed, plant: p, kind: .feed, title: String(localized: "Feed \(p.name)", comment: "Agenda item title: fertilize. %@ = plant name."), task: nil))
                    }
                    feed = feed.addingTimeInterval(s.feedWeeks * 7 * 86_400)
                }
            }
            var rotate = p.lastEvent(.rotate).map { $0.date.addingTimeInterval(14 * 86_400) } ?? now.addingTimeInterval(3 * 86_400)
            while rotate <= end {
                if rotate >= now { out.append(.init(id: "\(p.id)-r-\(Int(rotate.timeIntervalSince1970 / 86_400))", date: rotate, plant: p, kind: .rotate, title: String(localized: "Rotate \(p.name)", comment: "Agenda item title: turn the pot. %@ = plant name."), task: nil)) }
                rotate = rotate.addingTimeInterval(14 * 86_400)
            }
        }
        // Everything else the forecast sees: mist, clean, pests, prune, repot, propagation, seasonal moves, trip prep.
        let extra: Set<ReminderKind> = [.mist, .clean, .pests, .prune, .repot, .seasonal, .travel, .weather, .propagation]
        for f in CareForecast.items(for: plants, days: min(days, CareForecast.horizon), now: now) where extra.contains(f.kind) && f.date <= end {
            out.append(.init(id: f.id, date: f.date, plant: plants.first { $0.id == f.plantID }, kind: f.kind.careKind, title: f.line, task: nil))
        }
        for t in tasks where !t.done && t.due <= end {
            out.append(.init(id: t.id.uuidString, date: max(t.due, cal.startOfDay(for: now)), plant: plants.first { $0.id == t.plantID }, kind: t.kind, title: t.title, task: t))
        }
        return out.sorted { $0.date < $1.date }
    }
}
