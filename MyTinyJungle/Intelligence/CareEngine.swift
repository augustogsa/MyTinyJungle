import SwiftUI

struct PlantRequest: Identifiable, Hashable {
    enum Kind: String { case water, checkSoil, feed, checkRoots, portrait, safety, pauseFeeding, refreshWater, topUp, soak, mist, askDone, quarantine, treatFollowUp }
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
        if let m = mediumInterval(plant, at: date) { return m }
        let s = plant.species
        var base = plant.learnedDryDays ?? ((s?.dryMin ?? 7) + (s?.dryMax ?? 12)) / 2
        base *= plant.potMaterial?.dryingFactor ?? 1
        if plant.learnedDryDays == nil { base *= plant.growingMedium.dryingFactor }
        switch plant.sizeFit { case .tooBig: base *= 1.2; case .tooSmall: base *= 0.85; default: break }
        switch plant.activeLifeStage(date) { case .dormant: base *= 1.6; case .seedling, .cutting: base *= 0.7; default: break }
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

    /// Soilless media follow their own rhythm, not drying soil.
    static func mediumInterval(_ p: Plant, at date: Date = Date()) -> Double? {
        switch p.growingMedium {
        case .water: return 8
        case .leca, .pon: return isWinter(date) ? 10 : 7
        case .sphagnum: return isWinter(date) ? 8 : 6
        case .mounted: return Climate.shared.indoorFactor(date) < 1 ? 2 : 3
        case .terrarium: return 21
        default: return nil
        }
    }

    /// The request that replaces "water me" for this medium, if any.
    static func mediumKind(_ p: Plant) -> PlantRequest.Kind? {
        switch p.growingMedium {
        case .water: .refreshWater
        case .leca, .pon: .topUp
        case .sphagnum, .mounted: .soak
        case .terrarium: .mist
        default: p.potSelfWatering == true && p.growingMedium.inPot ? .topUp : nil
        }
    }

    static func mediumReason(_ p: Plant, kind: PlantRequest.Kind, last: Date?, now: Date) -> String {
        let when = last.map { relative($0, now) }
        switch kind {
        case .refreshWater:
            return when.map { Grammar.pt(String(localized: "Water changed \($0). Fresh water every 7–10 days keeps the roots from rotting.", comment: "Care reason for a plant growing in water. %@ = relative day.")) }
                ?? Grammar.pt(String(localized: "Fresh water every 7–10 days keeps the roots from rotting.", comment: "Care reason for a plant growing in water."))
        case .topUp:
            if p.growingMedium.usesSoil {
                return Grammar.pt(String(localized: "Self-watering pot: refill the reservoir once it's empty.", comment: "Care reason for a self-watering pot."))
            }
            return when.map { Grammar.pt(String(localized: "Topped up \($0). Keep the reservoir about a third of the pot deep, with hydro nutrients.", comment: "Care reason for LECA or pon. %@ = relative day.")) }
                ?? Grammar.pt(String(localized: "Keep the reservoir about a third of the pot deep, with hydro nutrients.", comment: "Care reason for LECA or pon."))
        case .soak:
            return p.growingMedium == .mounted
                ? Grammar.pt(String(localized: "Mounted roots dry fast. Mist or dunk them every 2–3 days.", comment: "Care reason for a mounted plant."))
                : Grammar.pt(String(localized: "Soak the moss when it feels light and crisp, then let it drain.", comment: "Care reason for a plant in sphagnum moss."))
        default:
            return Grammar.pt(String(localized: "Mist lightly only if the morning condensation is gone.", comment: "Care reason for a closed terrarium."))
        }
    }

    static func lastSkip(_ p: Plant) -> Date? { (p.events ?? []).filter { $0.kind == .note && $0.note == "care-skip" }.map(\.date).max() }

    static func notYetKey(_ p: Plant) -> String { "ask.notyet.\(p.id)" }

    static func requests(for plant: Plant, now: Date = Date(), settings: JungleSettings = .shared) -> [PlantRequest] {
        guard !plant.isArchived, !plant.isArtificial else { return [] }
        var out: [PlantRequest] = []
        let s = plant.species
        let stage = plant.activeLifeStage(now)
        let medium = plant.growingMedium
        let skip = lastSkip(plant)
        let lastWater = [plant.lastEvent(plant.waterKind)?.date, skip].compactMap { $0 }.max()
        let lastCheck = plant.lastEvent(.soilCheck)
        let expected = expectedDryDays(for: plant, at: now)
        var waterReq: PlantRequest?

        if let mk = mediumKind(plant) {
            let since = lastWater.map { days(from: $0, to: now) } ?? .infinity
            let every = mk == .topUp && medium.usesSoil ? expected * 1.5 : expected
            if since >= every * 0.95 {
                waterReq = .init(plantID: plant.id, kind: mk, priority: since >= every * 1.4 && since.isFinite ? 0 : 1, reason: mediumReason(plant, kind: mk, last: lastWater, now: now))
            }
        } else if let check = lastCheck, check.date > (lastWater ?? .distantPast), days(from: check.date, to: now) < 1.5 {
            // Water: evidence first.
            if check.soil == .dry {
                waterReq = .init(plantID: plant.id, kind: .water, priority: 0, reason: Grammar.pt(String(localized: "You felt dry soil \(relative(check.date, now)).", comment: "Care reason under a plant request. %@ = relative day (today, yesterday, 3 days ago).")))
            }
        } else if let lastWater {
            let since = days(from: lastWater, to: now)
            let outside = plant.isOutdoor || medium == .ground
            let rained = outside && (Climate.shared.recentRain(now) >= 5 || Climate.shared.comingRain(now) >= 5)
            if since >= expected * 0.9 && !rained {
                let urgent = since >= expected * 1.5 && s?.waterStyle == .moist
                waterReq = .init(plantID: plant.id, kind: .checkSoil, priority: urgent ? 0 : 1,
                                 reason: Grammar.pt(String(localized: "Watered \(relative(lastWater, now)). It usually dries in about \(Int(expected.rounded())) days.", comment: "Care reason. Args: relative day, number of days (plural).")))
            }
        } else {
            waterReq = .init(plantID: plant.id, kind: .checkSoil, priority: 1, reason: Grammar.pt(String(localized: "No watering recorded yet.", comment: "Care reason under a plant request.")))
        }
        // Long overdue: ask whether it was done instead of nagging again.
        if let r = waterReq, r.kind != .water, let lastWater, days(from: lastWater, to: now) >= expected * 1.6 {
            let notYet = (UserDefaults.standard.object(forKey: notYetKey(plant)) as? Date).map { now.timeIntervalSince($0) < 20 * 3600 } ?? false
            if !notYet {
                waterReq = .init(plantID: plant.id, kind: .askDone, priority: 1, reason: Grammar.pt(String(localized: "Last logged \(relative(lastWater, now)). If you already did it, tap Yes and I'll note it.", comment: "Care reason under 'Did you water X?'. %@ = relative day.")))
            }
        }
        if let waterReq { out.append(waterReq) }

        // Pests: keep it apart, then repeat the treatment every 5–7 days, three rounds.
        let treats = (plant.events ?? []).filter { $0.kind == .treat && days(from: $0.date, to: now) < 25 }.map(\.date).sorted()
        if let first = treats.first, let lastT = treats.last {
            let apart = (plant.events ?? []).contains { $0.kind == .note && $0.note == "quarantine" && $0.date >= first.addingTimeInterval(-86_400) }
            if !apart && days(from: lastT, to: now) < 21 {
                out.append(.init(plantID: plant.id, kind: .quarantine, priority: 1, reason: Grammar.pt(String(localized: "Pests spread fast. Keep it 2–3 weeks away from the others, out of touching distance.", comment: "Care reason: quarantine a plant with pests."))))
            }
            if treats.count < 3, days(from: lastT, to: now) >= 6 {
                out.append(.init(plantID: plant.id, kind: .treatFollowUp, priority: 1, reason: Grammar.pt(String(localized: "Round \(treats.count + 1) of 3. Eggs hatch after the first round, so repeating every 5–7 days breaks the cycle.", comment: "Care reason: pest treatment follow-up. %lld = round number."))))
            }
        }

        // Feeding: season, frequency, fresh soil, dormancy.
        if medium == .water, isGrowingSeason(now), !(stage?.noFeeding ?? false) {
            let lastFeed = plant.lastEvent(.feed)?.date
            if lastFeed == nil || days(from: lastFeed!, to: now) >= 28 {
                out.append(.init(plantID: plant.id, kind: .feed, priority: 2, reason: Grammar.pt(String(localized: "Once a month in the growing season: hydro feed at a quarter strength, mixed into fresh water.", comment: "Care reason: feeding a plant that grows in water."))))
            }
        } else if let s, ![.leca, .pon, .terrarium, .water].contains(medium), !(stage?.noFeeding ?? false) {
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
        if medium == .water {
            let rootsSeen = (plant.events ?? []).filter { $0.kind == .note && $0.note == "roots-ok" }.map(\.date).max()
            let since = days(from: [plant.lastRepotAt, rootsSeen, plant.acquiredAt].compactMap { $0 }.max()!, to: now)
            if since > 42 {
                out.append(.init(plantID: plant.id, kind: .checkRoots, priority: 3, reason: Grammar.pt(String(localized: "Roots 5–10 cm long? It's ready for a pot with soil, or it can stay in water for good.", comment: "Care reason: water-grown plant may be ready for soil."))))
            }
        } else if let s, !isWinter(now), medium.inPot, medium != .terrarium, !(stage?.noRepot ?? false) {
            let since = days(from: plant.lastRepotAt ?? plant.acquiredAt, to: now)
            if plant.sizeFit == .tooSmall && since > 60 {
                out.append(.init(plantID: plant.id, kind: .checkRoots, priority: 2, reason: Grammar.pt(String(localized: "The pot looks too small for it. A pot 2–5 cm wider will help.", comment: "Care reason: pot too small."))))
            } else if since > s.repotYears * 365 {
                out.append(.init(plantID: plant.id, kind: .checkRoots, priority: 3,
                                 reason: Grammar.pt(String(localized: "About \(Int(since / 365)) years in the same pot.", comment: "Care reason, first sentence. %lld = years (plural).")) + " " + Grammar.pt(String(localized: "\(s.commonName) usually needs a bigger pot every \(Int(s.repotYears)) years.", comment: "Care reason, second sentence. Args: species common name, years (plural)."))))
            }
        }

        // Safety.
        if let s, (s.toxicCats && settings.hasCats) || (s.toxicDogs && settings.hasDogs) || ((s.toxicCats || s.toxicDogs) && settings.hasKids),
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
    case struggling, thirsty, checkSoil, tend, petRisk, hungry, repot, thriving

    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    var label: String {
        switch self {
        case .struggling: Grammar.pt(String(localized: "Struggling", comment: "Plant status badge. Max 14 chars."))
        case .thirsty: Grammar.pt(String(localized: "Thirsty", comment: "Plant status badge. Max 14 chars."))
        case .checkSoil: Grammar.pt(String(localized: "Check soil", comment: "Plant status badge. Max 14 chars."))
        case .tend: Grammar.pt(String(localized: "Care day", comment: "Plant status badge: a small care task is due (fresh water, top-up, treatment). Max 14 chars."))
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
        case .tend: .waterDrops
        case .petRisk: .shieldStar
        case .hungry: .fertilizer
        case .repot: .pot
        case .thriving: .sprout
        }
    }
    var tint: Color {
        switch self {
        case .struggling: Jungle.terracotta
        case .thirsty, .checkSoil, .tend: Jungle.sky
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
        if plant.isArtificial || plant.isArchived { return .thriving }
        if r.contains(where: { $0.kind == .askDone }) { return .tend }
        // Struggling: far past its rhythm, or dry soil left unwatered for days.
        if let w = plant.lastEvent(plant.waterKind)?.date, w > (lastSkip(plant) ?? .distantPast), days(from: w, to: now) > expectedDryDays(for: plant, at: now) * 2 { return .struggling }
        if let c = plant.lastEvent(.soilCheck), c.soil == .dry, c.date > (plant.lastEvent(.water)?.date ?? .distantPast), days(from: c.date, to: now) >= 3 { return .struggling }
        if r.contains(where: { $0.kind == .water }) { return .thirsty }
        if r.contains(where: { $0.kind == .checkSoil && $0.priority == 0 }) { return .thirsty }
        if r.contains(where: { $0.kind == .checkSoil }) { return .checkSoil }
        if r.contains(where: { [.refreshWater, .topUp, .soak, .mist, .quarantine, .treatFollowUp].contains($0.kind) }) { return .tend }
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
