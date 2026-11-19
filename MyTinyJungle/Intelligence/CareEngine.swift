import SwiftUI

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

    static func isGrowingSeason(_ date: Date = Date()) -> Bool { Climate.shared.isGrowing(date) }

    static func isWinter(_ date: Date = Date()) -> Bool { Climate.shared.isWinter(date) }

    static func isPeakSummer(_ date: Date = Date()) -> Bool { Climate.shared.isPeakSummer(date) }

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
        // Species-specific seasonal rhythm: cacti nearly stop drinking in winter, ferns barely change.
        let winter = s?.winterFactor ?? 1.35, summer = s?.summerFactor ?? 1
        let climate = Climate.shared
        if plant.isOutdoor {
            // Outside: the real weather decides, falling back to the season.
            base *= climate.outdoorFactor(date) ?? (isWinter(date) ? max(1.2, winter * 0.9) : 0.75)
            if isWinter(date) { base *= max(1, winter * 0.6) }
        } else {
            if isWinter(date) { base *= winter } else if isPeakSummer(date) { base *= summer }
            base *= climate.indoorFactor(date)
            base *= roomLightFactor(for: plant)
        }
        return max(1, base)
    }

    /// Brighter rooms dry pots faster; dim rooms slower. Uses the light you set for the room.
    static func roomLightFactor(for plant: Plant) -> Double {
        guard let want = plant.species?.light, let room = JungleRooms.light(for: plant.location) else { return 1 }
        let order: [Species.Light] = [.low, .medium, .bright, .direct]
        let diff = (order.firstIndex(of: room) ?? 1) - (order.firstIndex(of: want) ?? 1)
        return diff > 0 ? 0.9 : diff < 0 ? 1.15 : 1
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

    /// Learn from how you actually water: a slow drift toward your real rhythm when there's no soil evidence.
    static func learnFromWatering(plant: Plant, at date: Date = Date()) {
        guard let prev = plant.lastEvent(.water)?.date, prev < date else { return }
        let gap = days(from: prev, to: date)
        guard gap > 0.75 else { return }
        let s = plant.species
        let current = plant.learnedDryDays ?? ((s?.dryMin ?? 7) + (s?.dryMax ?? 12)) / 2
        let blended = current * 0.8 + gap * 0.2
        plant.learnedDryDays = min(max(blended, (s?.dryMin ?? 2) * 0.6), (s?.dryMax ?? 30) * 1.6)
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
                out.append(.init(plantID: plant.id, kind: .water, priority: 0, reason: Grammar.pt(String(localized: "You felt dry soil \(relative(check.date, now)).", comment: "Care reason under a plant request. %@ = relative day (today, yesterday, 3 days ago)."))))
            }
        } else if let lastWater {
            let since = days(from: lastWater, to: now)
            let rained = plant.isOutdoor && Climate.shared.recentRain(now) >= 5
            if since >= expected * 0.9 && !rained {
                let urgent = since >= expected * 1.5 && s?.waterStyle == .moist
                out.append(.init(plantID: plant.id, kind: .checkSoil, priority: urgent ? 0 : 1,
                                 reason: Grammar.pt(String(localized: "Watered \(relative(lastWater, now)). It usually dries in about \(Int(expected.rounded())) days.", comment: "Care reason. Args: relative day, number of days (plural)."))))
            }
        } else {
            out.append(.init(plantID: plant.id, kind: .checkSoil, priority: 1, reason: Grammar.pt(String(localized: "No watering recorded yet.", comment: "Care reason under a plant request."))))
        }

        // Feeding: season, frequency, fresh soil, dormancy.
        if let s {
            let lastFeed = plant.lastEvent(.feed)?.date
            let freshSoil = plant.lastRepotAt.map { days(from: $0, to: now) < 42 } ?? false
            if isGrowingSeason(now) && !freshSoil && s.feed != "none" {
                if lastFeed == nil || days(from: lastFeed!, to: now) >= s.feedWeeks * 7 {
                    out.append(.init(plantID: plant.id, kind: .feed, priority: 2,
                                     reason: lastFeed.map { Grammar.pt(String(localized: "Last fed \(relative($0, now)). \(s.fertilizer?.name ?? String(localized: "Food", comment: "Generic fertilizer name, capitalized, start of a sentence.")) every \(Int(s.feedWeeks)) weeks in the growing season.", comment: "Care reason. Args: relative day, fertilizer name, weeks between feeds (plural).")) }
                                        ?? Grammar.pt(String(localized: "Growing season, and no feeding recorded yet.", comment: "Care reason under a plant request."))))
                }
            }
        }

        // Repot: an assessment, never an order. Not in winter.
        if let s, !isWinter(now) {
            let since = days(from: plant.lastRepotAt ?? plant.acquiredAt, to: now)
            if since > s.repotYears * 365 {
                out.append(.init(plantID: plant.id, kind: .checkRoots, priority: 3,
                                 reason: Grammar.pt(String(localized: "About \(Int(since / 365)) years in the same pot.", comment: "Care reason, first sentence. %lld = years (plural).")) + " " + Grammar.pt(String(localized: "\(s.commonName) usually needs a bigger pot every \(Int(s.repotYears)) years.", comment: "Care reason, second sentence. Args: species common name, years (plural)."))))
            }
        }

        // Safety.
        if let s, (s.toxicCats && settings.hasCats) || (s.toxicDogs && settings.hasDogs),
           !(plant.events ?? []).contains(where: { $0.kind == .note && $0.note == "safety-ack" }) {
            out.append(.init(plantID: plant.id, kind: .safety, priority: 1,
                             reason: Grammar.pt(String(localized: "\(s.commonName) is toxic to pets if chewed (ASPCA). Keep it out of reach.", comment: "Care reason: pet safety. %@ = species common name."))))
        }

        // Monthly portrait for the growth timeline.
        let lastPhoto = plant.lastEvent(.photo)?.date ?? plant.createdAt
        if days(from: lastPhoto, to: now) > 30 {
            out.append(.init(plantID: plant.id, kind: .portrait, priority: 3, reason: Grammar.pt(String(localized: "Monthly photo for the growth timeline.", comment: "Care reason under a plant request."))))
        }
        return out.sorted { $0.priority < $1.priority }
    }

    enum Mood { case thriving, fine, needsYou }
    static func mood(for plant: Plant, now: Date = Date()) -> Mood {
        // Single source of truth shared by every screen.
        if needsYou(plant, now: now) { return .needsYou }
        if status(for: plant, now: now) != .thriving { return .fine }
        return .thriving
    }

    /// A plant needs you when it has a care task for today or its status asks for attention.
    static func needsYou(_ plant: Plant, now: Date = Date()) -> Bool {
        requests(for: plant, now: now).contains { $0.priority <= 2 } || status(for: plant, now: now).needsAttention
    }

    static func relative(_ date: Date, _ now: Date = Date()) -> String {
        let d = Int(days(from: date, to: now).rounded(.down))
        switch d {
        case ..<1: return Grammar.pt(String(localized: "today", comment: "Relative day, lowercase, used inside sentences ('Watered today')."))
        case 1: return Grammar.pt(String(localized: "yesterday", comment: "Relative day, lowercase, used inside sentences."))
        default: return Grammar.pt(String(localized: "\(d) days ago", comment: "Relative day, used inside sentences ('Watered 3 days ago'). %lld = days (plural)."))
        }
    }
}

/// What a plant needs right now, in plain words. One state per plant, the most important wins.
enum PlantStatus: Int, Comparable {
    case struggling, thirsty, checkSoil, petRisk, hungry, repot, thriving

    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    var label: String {
        switch self {
        case .struggling: Grammar.pt(String(localized: "Struggling", comment: "Plant status badge. Max 14 chars."))
        case .thirsty: Grammar.pt(String(localized: "Thirsty", comment: "Plant status badge. Max 14 chars."))
        case .checkSoil: Grammar.pt(String(localized: "Check soil", comment: "Plant status badge. Max 14 chars."))
        case .petRisk: Grammar.pt(String(localized: "Pet alert", comment: "Plant status badge. Max 14 chars."))
        case .hungry: Grammar.pt(String(localized: "Hungry", comment: "Plant status badge: needs fertilizer. Max 14 chars."))
        case .repot: Grammar.pt(String(localized: "Root check", comment: "Plant status badge. Max 14 chars."))
        case .thriving: Grammar.pt(String(localized: "Thriving", comment: "Plant status badge. Max 14 chars."))
        }
    }
    var icon: Icon3D {
        switch self {
        case .struggling: .wilted
        case .thirsty: .waterDrops
        case .checkSoil: .soilTest
        case .petRisk: .shieldStar
        case .hungry: .fertilizer
        case .repot: .pot
        case .thriving: .sprout
        }
    }
    var tint: Color {
        switch self {
        case .struggling: Jungle.terracotta
        case .thirsty, .checkSoil: Jungle.sky
        case .petRisk: Jungle.peach
        case .hungry, .repot: Jungle.sun
        case .thriving: Jungle.leaf
        }
    }
    var needsAttention: Bool { self <= .petRisk }
}

extension CareEngine {
    static func status(for plant: Plant, now: Date = Date()) -> PlantStatus {
        let r = requests(for: plant, now: now)
        // Struggling: far past its rhythm, or dry soil left unwatered for days.
        if let w = plant.lastEvent(.water)?.date, days(from: w, to: now) > expectedDryDays(for: plant, at: now) * 2 { return .struggling }
        if let c = plant.lastEvent(.soilCheck), c.soil == .dry, c.date > (plant.lastEvent(.water)?.date ?? .distantPast), days(from: c.date, to: now) >= 3 { return .struggling }
        if r.contains(where: { $0.kind == .water }) { return .thirsty }
        if r.contains(where: { $0.kind == .checkSoil && $0.priority == 0 }) { return .thirsty }
        if r.contains(where: { $0.kind == .checkSoil }) { return .checkSoil }
        if r.contains(where: { $0.kind == .safety }) { return .petRisk }
        if r.contains(where: { $0.kind == .feed }) { return .hungry }
        if r.contains(where: { $0.kind == .checkRoots }) { return .repot }
        return .thriving
    }
}

/// Small capsule showing a plant's state.
struct StatusBadge: View {
    let status: PlantStatus
    var compact = false
    var body: some View {
        HStack(spacing: 5) {
            Icon3DView(status.icon, size: compact ? 16 : 18)
            Text(status.label).foregroundStyle(Jungle.text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Jungle.surface.opacity(0.95), in: Capsule())
        .overlay(Capsule().strokeBorder(status.tint.opacity(0.7), lineWidth: status.needsAttention ? 1.5 : 0))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 1)
        .accessibilityLabel(Grammar.pt(String(localized: "Status: \(status.label)", comment: "VoiceOver label for the plant status badge.")))
    }
}
