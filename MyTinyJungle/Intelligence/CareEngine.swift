import Foundation

struct PlantRequest: Identifiable, Hashable {
    enum Kind: String { case water, checkSoil, feed, checkRoots, portrait, safety, pauseFeeding }
    let plantID: UUID
    let kind: Kind
    let priority: Int   // 0 urgent … 3 low
    let reason: String  // plain fact, shown under the plant's voice
    var id: String { "\(plantID)-\(kind.rawValue)" }
}

/// Deterministic care decisions. The language layer never decides care.
enum CareEngine {
    static let calendar = Calendar.current

    static func isGrowingSeason(_ date: Date = Date(), south: Bool = JungleSettings.shared.southernHemisphere) -> Bool {
        var month = calendar.component(.month, from: date)
        if south { month = (month + 5) % 12 + 1 }
        return (3...9).contains(month)
    }

    static func isWinter(_ date: Date = Date(), south: Bool = JungleSettings.shared.southernHemisphere) -> Bool {
        var month = calendar.component(.month, from: date)
        if south { month = (month + 5) % 12 + 1 }
        return [11, 12, 1, 2].contains(month)
    }

    static func days(from a: Date, to b: Date = Date()) -> Double { b.timeIntervalSince(a) / 86_400 }

    /// Expected days for this plant's substrate to dry to its watering point.
    static func expectedDryDays(for plant: Plant, at date: Date = Date()) -> Double {
        let s = plant.species
        var base = plant.learnedDryDays ?? ((s?.dryMin ?? 7) + (s?.dryMax ?? 12)) / 2
        base *= plant.potMaterial?.dryingFactor ?? 1
        if let d = plant.potDiameterCm {
            if d < 12 { base *= 0.85 } else if d > 30 { base *= 1.2 }
        }
        if !plant.potHasDrainage { base *= 1.25 }
        if plant.isOutdoor { base *= isWinter(date) ? 1.2 : 0.75 }
        else if isWinter(date) { base *= 1.35 }
        return max(1, base)
    }

    /// Learn from a soil check: how long the substrate really took.
    static func learn(from soil: SoilState, plant: Plant, at date: Date = Date()) {
        guard let lastWater = plant.lastEvent(.water)?.date, lastWater < date else { return }
        let elapsed = days(from: lastWater, to: date)
        guard elapsed > 0.5 else { return }
        let s = plant.species
        let current = plant.learnedDryDays ?? ((s?.dryMin ?? 7) + (s?.dryMax ?? 12)) / 2
        let observed: Double
        switch soil {
        case .dry: observed = min(current, elapsed)
        case .slightlyMoist: observed = max(current, elapsed * 1.2)
        case .wet: observed = max(current, elapsed * 1.6)
        }
        let blended = current * 0.6 + observed * 0.4
        let lower = (s?.dryMin ?? 2) * 0.5
        let upper = (s?.dryMax ?? 30) * 1.8
        plant.learnedDryDays = min(max(blended, lower), upper)
    }

    static func requests(for plant: Plant, now: Date = Date(), settings: JungleSettings = .shared) -> [PlantRequest] {
        guard !plant.isArchived else { return [] }
        var out: [PlantRequest] = []
        let s = plant.species
        let lastWater = plant.lastEvent(.water)?.date
        let lastCheck = plant.lastEvent(.soilCheck)
        let expected = expectedDryDays(for: plant, at: now)

        // Water: evidence first.
        if let check = lastCheck, check.date > (lastWater ?? .distantPast), days(from: check.date, to: now) < 1.5 {
            if check.soil == .dry {
                out.append(.init(plantID: plant.id, kind: .water, priority: 0, reason: "You felt dry soil \(relative(check.date, now))."))
            }
        } else if let lastWater {
            let since = days(from: lastWater, to: now)
            if since >= expected * 0.9 {
                let urgent = since >= expected * 1.5 && s?.waterStyle == .moist
                out.append(.init(plantID: plant.id, kind: .checkSoil, priority: urgent ? 0 : 1,
                                 reason: "Watered \(relative(lastWater, now)). It usually dries in about \(Int(expected.rounded())) days."))
            }
        } else {
            out.append(.init(plantID: plant.id, kind: .checkSoil, priority: 1, reason: "No watering recorded yet."))
        }

        // Feeding: season, frequency, fresh soil, dormancy.
        if let s {
            let lastFeed = plant.lastEvent(.feed)?.date
            let freshSoil = plant.lastRepotAt.map { days(from: $0, to: now) < 42 } ?? false
            if isGrowingSeason(now) && !freshSoil {
                if lastFeed == nil || days(from: lastFeed!, to: now) >= s.feedWeeks * 7 {
                    out.append(.init(plantID: plant.id, kind: .feed, priority: 2,
                                     reason: lastFeed.map { "Last fed \(relative($0, now)). Every \(Int(s.feedWeeks)) weeks in the growing season." }
                                        ?? "Growing season, and no feeding recorded yet."))
                }
            }
        }

        // Repot: an assessment, never an order. Not in winter.
        if let s, !isWinter(now) {
            let since = days(from: plant.lastRepotAt ?? plant.acquiredAt, to: now)
            if since > s.repotYears * 365 {
                out.append(.init(plantID: plant.id, kind: .checkRoots, priority: 3,
                                 reason: "About \(Int(since / 365)) year(s) in the same pot. \(s.en) usually needs a bigger pot every \(Int(s.repotYears)) year(s)."))
            }
        }

        // Safety.
        if let s, (s.toxicCats && settings.hasCats) || (s.toxicDogs && settings.hasDogs),
           !(plant.events ?? []).contains(where: { $0.kind == .note && $0.note == "safety-ack" }) {
            out.append(.init(plantID: plant.id, kind: .safety, priority: 1,
                             reason: "\(s.en) is toxic to pets if chewed (ASPCA). Keep it out of reach."))
        }

        // Monthly portrait for the growth timeline.
        let lastPhoto = plant.lastEvent(.photo)?.date ?? plant.createdAt
        if days(from: lastPhoto, to: now) > 30 {
            out.append(.init(plantID: plant.id, kind: .portrait, priority: 3, reason: "Monthly photo for the growth timeline."))
        }
        return out.sorted { $0.priority < $1.priority }
    }

    enum Mood { case thriving, fine, needsYou }
    static func mood(for plant: Plant, now: Date = Date()) -> Mood {
        let r = requests(for: plant, now: now)
        if r.contains(where: { $0.priority == 0 }) { return .needsYou }
        if r.contains(where: { $0.priority <= 1 }) { return .fine }
        return .thriving
    }

    static func relative(_ date: Date, _ now: Date = Date()) -> String {
        let d = Int(days(from: date, to: now).rounded(.down))
        switch d {
        case ..<1: return "today"
        case 1: return "yesterday"
        default: return "\(d) days ago"
        }
    }
}
