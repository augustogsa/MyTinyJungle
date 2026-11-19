import SwiftUI
import SwiftData

/// What the roots live in. Raw values are the synced `medium` key (same on Android).
enum GrowingMedium: String, CaseIterable, Identifiable, Codable {
    case soil, chunky, cactus, leca, pon, sphagnum, water, mounted, terrarium, ground
    var id: String { rawValue }

    var label: String {
        switch self {
        case .soil: Grammar.pt(String(localized: "Potting soil", comment: "Growing medium option; max 18 chars"))
        case .chunky: Grammar.pt(String(localized: "Chunky aroid mix", comment: "Growing medium option: bark, perlite, coir mix; max 18 chars"))
        case .cactus: Grammar.pt(String(localized: "Cactus mix", comment: "Growing medium option; max 18 chars"))
        case .leca: Grammar.pt(String(localized: "LECA", comment: "Growing medium option: expanded clay balls; keep the acronym"))
        case .pon: Grammar.pt(String(localized: "Pon", comment: "Growing medium option: mineral substrate brand-style name; keep as is"))
        case .sphagnum: Grammar.pt(String(localized: "Sphagnum moss", comment: "Growing medium option; max 18 chars"))
        case .water: Grammar.pt(String(localized: "Just water", comment: "Growing medium option: plant grows in a glass of water, no soil; max 18 chars"))
        case .mounted: Grammar.pt(String(localized: "Mounted", comment: "Growing medium option: tied to bark or a board, like orchids; max 18 chars"))
        case .terrarium: Grammar.pt(String(localized: "Terrarium", comment: "Growing medium option: closed glass container; max 18 chars"))
        case .ground: Grammar.pt(String(localized: "In the ground", comment: "Growing medium option: planted in a garden bed; max 18 chars"))
        }
    }

    var symbol: String {
        switch self {
        case .soil, .chunky, .cactus: "square.stack.3d.down.right.fill"
        case .leca, .pon: "circle.grid.3x3.fill"
        case .sphagnum: "leaf.fill"
        case .water: "drop.fill"
        case .mounted: "rectangle.portrait.fill"
        case .terrarium: "cube.transparent"
        case .ground: "tree.fill"
        }
    }

    /// Roots in something you can feel with a finger.
    var usesSoil: Bool { [.soil, .chunky, .cactus, .ground].contains(self) }
    var inPot: Bool { self != .ground && self != .mounted }

    /// Soil mixes that drain faster than plain potting soil.
    var dryingFactor: Double {
        switch self {
        case .chunky: 0.8
        case .cactus: 0.75
        case .ground: 1.3
        default: 1
        }
    }

    /// From the server's photo scene words.
    init?(scene raw: String) {
        let r = raw.lowercased().replacingOccurrences(of: "-", with: "_")
        if let m = GrowingMedium(rawValue: r) { self = m; return }
        switch r {
        case "potting_soil", "dirt", "earth": self = .soil
        case "aroid", "bark", "chunky_mix", "orchid_bark": self = .chunky
        case "succulent", "cactus_mix", "gritty": self = .cactus
        case "clay_balls", "hydroton", "semi_hydro", "semihydro": self = .leca
        case "pumice", "lechuza_pon", "mineral": self = .pon
        case "moss", "sphagnum_moss": self = .sphagnum
        case "hydro", "glass", "vase", "propagation", "water_culture": self = .water
        case "mount", "board", "cork": self = .mounted
        case "closed_terrarium", "jar": self = .terrarium
        case "garden", "bed", "in_ground": self = .ground
        default: return nil
        }
    }
}

/// Where the plant is in its life. Raw values are the synced `lifeStage` key.
enum LifeStage: String, CaseIterable, Identifiable, Codable {
    case cutting, seedling, acclimating, repotted, dormant, flowering, recovering, unknownHistory = "unknown_history"
    var id: String { rawValue }

    var label: String {
        switch self {
        case .cutting: Grammar.pt(String(localized: "Cutting", comment: "Plant life stage option; max 16 chars"))
        case .seedling: Grammar.pt(String(localized: "Seedling", comment: "Plant life stage option; max 16 chars"))
        case .acclimating: Grammar.pt(String(localized: "Settling in", comment: "Plant life stage option: just arrived, adjusting to the new home; max 16 chars"))
        case .repotted: Grammar.pt(String(localized: "Just repotted", comment: "Plant life stage option; max 16 chars"))
        case .dormant: Grammar.pt(String(localized: "Resting", comment: "Plant life stage option: dormant; max 16 chars"))
        case .flowering: Grammar.pt(String(localized: "Flowering", comment: "Plant life stage option; max 16 chars"))
        case .recovering: Grammar.pt(String(localized: "Recovering", comment: "Plant life stage option: getting better after a problem; max 16 chars"))
        case .unknownHistory: Grammar.pt(String(localized: "Unknown past", comment: "Plant life stage option: rescued or second-hand, care history unknown; max 16 chars"))
        }
    }

    /// Stages that end on their own.
    var lasts: Double? {
        switch self {
        case .acclimating: 28
        case .repotted: 42
        case .unknownHistory: 28
        default: nil
        }
    }

    var noFeeding: Bool { [.cutting, .seedling, .acclimating, .repotted, .dormant, .recovering, .unknownHistory].contains(self) }
    var noRepot: Bool { [.acclimating, .repotted, .flowering, .recovering, .dormant, .cutting].contains(self) }

    init?(scene raw: String) {
        let r = raw.lowercased().replacingOccurrences(of: "-", with: "_")
        if let s = LifeStage(rawValue: r) { self = s; return }
        switch r {
        case "propagation", "rooting": self = .cutting
        case "seedlings", "sprout": self = .seedling
        case "blooming", "in_bloom", "flowers": self = .flowering
        case "dormancy": self = .dormant
        default: return nil
        }
    }
}

enum PotSizeFit: String, CaseIterable, Identifiable, Codable {
    case tooSmall = "too_small", ok, tooBig = "too_big"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .tooSmall: Grammar.pt(String(localized: "Too small", comment: "Pot size fit option; max 12 chars"))
        case .ok: Grammar.pt(String(localized: "Just right", comment: "Pot size fit option; max 12 chars"))
        case .tooBig: Grammar.pt(String(localized: "Too big", comment: "Pot size fit option; max 12 chars"))
        }
    }
}

extension Plant {
    var growingMedium: GrowingMedium {
        get { medium.flatMap(GrowingMedium.init(rawValue:)) ?? .soil }
        set { medium = newValue == .soil ? nil : newValue.rawValue }
    }

    /// The stage that still applies today (settling in and fresh repots end by themselves).
    func activeLifeStage(_ now: Date = Date()) -> LifeStage? {
        guard let s = lifeStage.flatMap(LifeStage.init(rawValue:)) else { return nil }
        if let l = s.lasts, let at = lifeStageAt, now.timeIntervalSince(at) / 86_400 > l { return nil }
        return s
    }
    func setLifeStage(_ s: LifeStage?, at date: Date = Date()) {
        lifeStage = s?.rawValue
        lifeStageAt = s == nil ? nil : date
    }

    var sizeFit: PotSizeFit? {
        get { potSizeFit.flatMap(PotSizeFit.init(rawValue:)) }
        set { potSizeFit = newValue?.rawValue }
    }

    var isToxic: Bool { species.map { $0.toxicCats || $0.toxicDogs } ?? false }

    /// The care event that counts as "watering" for this medium.
    var waterKind: CareKind { [.mounted, .terrarium].contains(growingMedium) ? .mist : .water }
}

extension Climate {
    /// Rain expected in the next day and a half, in mm.
    func comingRain(_ now: Date = Date()) -> Double {
        forecast.filter { $0.date > now.addingTimeInterval(-12 * 3600) && $0.date <= now.addingTimeInterval(36 * 3600) }.map(\.rain).reduce(0, +)
    }
}

/// Facts the plant screen shows under "Good to know": medium, stage, pot setup, shared pot.
enum PlantNotes {
    struct Note: Hashable { let symbol: String; let text: String; let warn: Bool }

    static func all(for p: Plant, now: Date = Date()) -> [Note] {
        if p.isArtificial {
            return [.init(symbol: "sparkles", text: Grammar.pt(String(localized: "A faux plant: no water, no food, no worries. A quick dust now and then keeps it looking real.", comment: "Plant screen note for an artificial plant; warm, playful")), warn: false)]
        }
        var out: [Note] = []
        let m = p.growingMedium
        switch m {
        case .water:
            out.append(.init(symbol: "drop.fill", text: Grammar.pt(String(localized: "Grows in water, so no soil checks. Fresh water every 7–10 days, a top-up in between, and a quarter-strength hydro feed once a month in the growing season.", comment: "Plant screen note for a plant growing in water")), warn: false))
            out.append(.init(symbol: "eye", text: Grammar.pt(String(localized: "Green film on the glass or a sour smell means algae or rot: rinse the roots and the glass. Once roots reach 5–10 cm it can move to soil, or stay in water for good.", comment: "Plant screen note for a plant growing in water")), warn: false))
        case .leca, .pon:
            out.append(.init(symbol: "circle.grid.3x3.fill", text: Grammar.pt(String(localized: "Semi-hydro: keep a reservoir about a third of the pot deep and let it run dry for a day or two before topping up. Feed hydro nutrients at each top-up and flush with plain water monthly.", comment: "Plant screen note for LECA or pon")), warn: false))
        case .sphagnum:
            out.append(.init(symbol: "leaf.fill", text: Grammar.pt(String(localized: "In sphagnum moss: soak it when the moss feels light and crisp, then let it drain fully. Never leave it sitting in water.", comment: "Plant screen note for sphagnum moss")), warn: false))
        case .mounted:
            out.append(.init(symbol: "rectangle.portrait.fill", text: Grammar.pt(String(localized: "Mounted plants dry fast: mist or dunk the roots every 2–3 days, more often when the air is dry.", comment: "Plant screen note for a mounted plant")), warn: false))
        case .terrarium:
            out.append(.init(symbol: "cube.transparent", text: Grammar.pt(String(localized: "A closed terrarium waters itself. Mist lightly only when the morning condensation is gone, and open the lid if it's fogged all day.", comment: "Plant screen note for a terrarium")), warn: false))
        case .ground:
            out.append(.init(symbol: "tree.fill", text: Grammar.pt(String(localized: "In the ground, roots reach deeper, so it needs water less often than a pot. Rain counts.", comment: "Plant screen note for a plant in a garden bed")), warn: false))
        default: break
        }
        if let s = p.activeLifeStage(now) {
            let t: String = switch s {
            case .cutting: Grammar.pt(String(localized: "A cutting: no food and no repotting yet. Bright, indirect light and patience while roots grow.", comment: "Plant screen note for a cutting"))
            case .seedling: Grammar.pt(String(localized: "A seedling: keep it evenly moist, never soggy, with gentle light. Food can wait until its true leaves open.", comment: "Plant screen note for a seedling"))
            case .acclimating: Grammar.pt(String(localized: "Settling in: a few dropped or yellow leaves in the first weeks are normal. No repotting or food for now.", comment: "Plant screen note for a newly arrived plant"))
            case .repotted: Grammar.pt(String(localized: "Fresh soil already has food, so no feeding for 4–6 weeks. A little droop while roots settle is normal.", comment: "Plant screen note for a just repotted plant"))
            case .dormant: Grammar.pt(String(localized: "Resting: it drinks much less and needs no food until it wakes up.", comment: "Plant screen note for a dormant plant"))
            case .flowering: Grammar.pt(String(localized: "Flowering: keep it in the same spot and don't turn it, or buds may drop.", comment: "Plant screen note for a flowering plant"))
            case .recovering: Grammar.pt(String(localized: "Recovering: gentle care only. No food or repotting until new healthy growth shows.", comment: "Plant screen note for a recovering plant"))
            case .unknownHistory: Grammar.pt(String(localized: "Unknown past: let's learn its rhythm. Check before every drink and skip food for the first month.", comment: "Plant screen note for a plant with unknown care history"))
            }
            out.append(.init(symbol: "calendar.badge.clock", text: t, warn: false))
        }
        if m.inPot {
            if p.potCachepot == true {
                out.append(.init(symbol: "exclamationmark.triangle.fill", text: Grammar.pt(String(localized: "It sits in a cachepot: tip out any water that collects there 15 minutes after watering, or the roots will sit wet.", comment: "Plant screen warning: decorative outer pot without holes")), warn: true))
            } else if !p.potHasDrainage && m.usesSoil {
                out.append(.init(symbol: "exclamationmark.triangle.fill", text: Grammar.pt(String(localized: "No drainage holes: water little and often, and tip the pot to pour off extra. A pot with holes is safer.", comment: "Plant screen warning: pot without drainage holes")), warn: true))
            }
            if p.potSelfWatering == true {
                out.append(.init(symbol: "drop.circle", text: Grammar.pt(String(localized: "Self-watering pot: refill the reservoir only once it's empty, and let it stay dry for a day or two so roots get air.", comment: "Plant screen note for a self-watering pot")), warn: false))
            }
            switch p.sizeFit {
            case .tooSmall: out.append(.init(symbol: "arrow.up.bin.fill", text: Grammar.pt(String(localized: "The pot looks tight. It will dry fast; plan a pot 2–5 cm wider in the growing season.", comment: "Plant screen note: pot too small")), warn: false))
            case .tooBig: out.append(.init(symbol: "arrow.down.right.and.arrow.up.left", text: Grammar.pt(String(localized: "The pot looks roomy, so the soil stays wet longer. Water a little less and check before every drink.", comment: "Plant screen note: pot too big")), warn: false))
            default: break
            }
        }
        if p.sharesPot {
            out.append(.init(symbol: "person.3.fill", text: Grammar.pt(String(localized: "Several plants share this pot. They drink together, so care goes by the thirstiest one.", comment: "Plant screen note: several plants in one pot")), warn: false))
        }
        if let s = p.species, s.toxicCats || s.toxicDogs {
            let st = JungleSettings.shared
            out.append(.init(symbol: "pawprint.fill", text: st.hasKids ? Grammar.pt(String(localized: "Not for nibbling: keep it out of reach of pets and little kids.", comment: "Plant screen note: toxic plant, home has kids")) : Grammar.pt(String(localized: "Toxic to pets if chewed. Keep it out of reach.", comment: "Plant screen note: toxic plant")), warn: st.hasCats || st.hasDogs || st.hasKids))
        }
        return out
    }
}

/// "Good to know" card on the plant screen.
struct PlantNotesCard: View {
    let plant: Plant
    var body: some View {
        let notes = PlantNotes.all(for: plant)
        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(Grammar.pt(String(localized: "Good to know", comment: "Plant screen section title: notes about medium, pot, life stage; max 24 chars")))
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(notes, id: \.self) { n in
                        Label { Text(n.text).font(.subheadline).fixedSize(horizontal: false, vertical: true) } icon: {
                            Image(systemName: n.symbol).foregroundStyle(n.warn ? Jungle.terracotta : Jungle.accentText).frame(width: 24)
                        }
                        .foregroundStyle(n.warn ? Jungle.warmText : Jungle.text)
                        .padding(n.warn ? 10 : 0)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(n.warn ? Jungle.warmFill : .clear, in: RoundedRectangle(cornerRadius: Jungle.innerRadius, style: .continuous))
                    }
                }
                .padding(14).jungleCard()
            }
        }
    }
}

/// Toxicity capsule from the species: pets, and kids when the home has them.
struct ToxicBadge: View {
    let plant: Plant
    var body: some View {
        if plant.isToxic {
            Label(JungleSettings.shared.hasKids ? Grammar.pt(String(localized: "Pets & kids", comment: "Badge: plant is toxic to pets and kids; max 14 chars")) : Grammar.pt(String(localized: "Toxic to pets", comment: "Badge: plant is toxic to pets; max 14 chars")), systemImage: "pawprint.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Jungle.warmText)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(Jungle.warmFill, in: Capsule())
                .accessibilityLabel(Grammar.pt(String(localized: "Toxic if chewed", comment: "VoiceOver label for the toxicity badge")))
        }
    }
}

/// One-tap answers for medium tasks and the "Did you already?" question.
@MainActor
enum CareAsk {
    static func title(_ k: PlantRequest.Kind, plant: Plant) -> String {
        switch k {
        case .refreshWater: Grammar.pt(String(localized: "Fresh water", comment: "Care task title: change the water of a plant growing in water; max 22 chars"))
        case .topUp: Grammar.pt(String(localized: "Top up the reservoir", comment: "Care task title; max 22 chars"))
        case .soak: plant.growingMedium == .mounted ? Grammar.pt(String(localized: "Mist the roots", comment: "Care task title for a mounted plant; max 22 chars")) : Grammar.pt(String(localized: "Soak the moss", comment: "Care task title; max 22 chars"))
        case .mist: Grammar.pt(String(localized: "A light mist", comment: "Care task title for a terrarium; max 22 chars"))
        case .askDone: plant.waterKind == .mist ? Grammar.pt(String(localized: "Misted already?", comment: "Care task title: asks whether the user already did it; max 22 chars")) : Grammar.pt(String(localized: "Watered already?", comment: "Care task title: asks whether the user already watered; max 22 chars"))
        case .quarantine: Grammar.pt(String(localized: "Keep it apart", comment: "Care task title: quarantine a plant with pests; max 22 chars"))
        case .treatFollowUp: Grammar.pt(String(localized: "Next treatment", comment: "Care task title: repeat pest treatment; max 22 chars"))
        default: Answerer.label(k)
        }
    }

    static func short(_ k: PlantRequest.Kind, plant: Plant) -> String {
        switch k {
        case .refreshWater: Grammar.pt(String(localized: "Refresh", comment: "Quick action tile: change the water; verb; max 10 chars"))
        case .topUp: Grammar.pt(String(localized: "Top up", comment: "Quick action tile: refill reservoir; verb; max 10 chars"))
        case .soak: plant.growingMedium == .mounted ? Grammar.pt(String(localized: "Mist", comment: "Quick action tile; verb; max 10 chars")) : Grammar.pt(String(localized: "Soak", comment: "Quick action tile; verb; max 10 chars"))
        default: Grammar.pt(String(localized: "Mist", comment: "Quick action tile; verb; max 10 chars"))
        }
    }

    static func done(_ k: PlantRequest.Kind, plant: Plant) -> (label: String, action: RequestCard.Action) {
        switch k {
        case .refreshWater: (Grammar.pt(String(localized: "Changed it", comment: "Button: water changed; max 14 chars")), .careNote(.water, "refresh"))
        case .topUp: (Grammar.pt(String(localized: "Topped up", comment: "Button: reservoir refilled; max 14 chars")), .careNote(.water, "top-up"))
        case .soak: (plant.growingMedium == .mounted ? Grammar.pt(String(localized: "Misted", comment: "Button: roots misted; max 14 chars")) : Grammar.pt(String(localized: "Soaked", comment: "Button: moss soaked; max 14 chars")), plant.growingMedium == .mounted ? .care(.mist) : .careNote(.water, "soak"))
        case .mist: (Grammar.pt(String(localized: "Misted", comment: "Button: roots misted; max 14 chars")), .care(.mist))
        case .quarantine: (Grammar.pt(String(localized: "Done", comment: "Button: plant is now kept apart; max 14 chars")), .careNote(.note, "quarantine"))
        case .treatFollowUp: (Grammar.pt(String(localized: "Treated", comment: "Button: pest treatment done; max 14 chars")), .care(.treat))
        default: (Grammar.pt(String(localized: "Done", comment: "Button: plant is now kept apart; max 14 chars")), .open)
        }
    }

    static func answer(_ a: RequestCard.Action, plant: Plant, in ctx: ModelContext, now: Date = Date()) {
        let last = [plant.lastEvent(plant.waterKind)?.date, CareEngine.lastSkip(plant)].compactMap { $0 }.max()
        switch a {
        case .yes:
            // Logged on the day it was due, so the rhythm learns your real habit.
            let due = last.map { min(now, $0.addingTimeInterval(CareEngine.expectedDryDays(for: plant, at: now) * 86_400)) } ?? now
            JungleBrain.quick(plant.waterKind, note: "asked", plants: [plant], in: ctx, now: due, announce: true)
        case .notYet:
            UserDefaults.standard.set(now, forKey: CareEngine.notYetKey(plant))
        case .skip:
            let e = CareEvent(kind: .note, note: "care-skip", source: "chip"); e.plant = plant; ctx.insert(e); try? ctx.save()
        default: break
        }
    }
}
