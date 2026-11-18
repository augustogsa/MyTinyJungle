import Foundation

/// Bundled plant knowledge: soils, soil components, plant foods and pests.
/// Written in our own words from RHS, ASPCA, university extension services and Kew POWO.
struct Knowledge: Decodable {
    struct Soil: Decodable, Identifiable { let id, name, short: String; let parts: [[Part]]; let phMin, phMax: Double; let drainage, forGroups, note: String }
    enum Part: Decodable {
        case id(String), pct(Int)
        init(from d: Decoder) throws {
            let c = try d.singleValueContainer()
            if let i = try? c.decode(Int.self) { self = .pct(i) } else { self = .id(try c.decode(String.self)) }
        }
    }
    struct Component: Decodable, Identifiable { let id, name, role, note: String }
    struct Fertilizer: Decodable, Identifiable { let id, name, npk, cadence, dilution, rest, note: String }
    struct Pest: Decodable, Identifiable { let id, name, signs, fix, likes: String }

    let soils: [Soil]
    let components: [Component]
    let fertilizers: [Fertilizer]
    let pests: [Pest]
    let sources: [String]

    static let shared: Knowledge = {
        guard let url = Bundle.main.url(forResource: "knowledge", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let k = try? JSONDecoder().decode(Knowledge.self, from: data) else {
            return Knowledge(soils: [], components: [], fertilizers: [], pests: [], sources: [])
        }
        return k
    }()

    func soil(_ id: String) -> Soil? { soils.first { $0.id == id } }
    func fertilizer(_ id: String) -> Fertilizer? { fertilizers.first { $0.id == id } }
    func pest(_ id: String) -> Pest? { pests.first { $0.id == id } }
    func component(_ id: String) -> Component? { components.first { $0.id == id } }

    /// "40% bark, 25% coco coir, 25% perlite…"
    func recipe(_ soil: Soil) -> String {
        soil.parts.compactMap { pair -> String? in
            guard pair.count == 2, case .id(let id) = pair[0], case .pct(let p) = pair[1] else { return nil }
            return "\(p)% \((component(id)?.name ?? id).lowercased())"
        }.joined(separator: ", ")
    }
}

extension Species {
    var soil: Knowledge.Soil? { Knowledge.shared.soil(mix) }
    var fertilizer: Knowledge.Fertilizer? { Knowledge.shared.fertilizer(feed) }
    var pestList: [Knowledge.Pest] { (pests ?? []).compactMap(Knowledge.shared.pest) }
    var isPetSafe: Bool { !toxicCats && !toxicDogs }

    /// Seasonal watering in words, from the species' winter/summer rhythm.
    var seasonalWater: String {
        let w = winterFactor ?? 1.35, s = summerFactor ?? 0.85
        let summer = "In summer about every \(max(1, Int((dryMin * s).rounded())))–\(max(2, Int((dryMax * s).rounded()))) days"
        let winter = w >= 2.5 ? "in winter barely at all, a sip once a month" :
            "in winter about every \(Int((dryMin * w).rounded()))–\(Int((dryMax * w).rounded())) days"
        return "\(summer), \(winter). Always feel the soil first."
    }

    /// Pot-size hint: small pots dry faster, big ones slower.
    func potHint(diameter d: Double?) -> String {
        guard let d else { return "Small pots (under 12 cm) dry about 15% faster, big ones (over 30 cm) about 20% slower." }
        if d < 12 { return "A \(Int(d)) cm pot dries fast, so check it more often." }
        if d > 30 { return "A \(Int(d)) cm pot holds water a long time; check deeper before watering." }
        return "A \(Int(d)) cm pot is a comfortable middle size."
    }

    var feedPlan: String {
        guard let f = fertilizer else { return "A gentle balanced feed in the growing season." }
        if feed == "none" { return f.cadence + ". " + f.note }
        return "\(f.name) (\(f.npk)). \(f.cadence), \(f.dilution.lowercased()). \(f.rest)."
    }

    var soilPlan: String {
        guard let s = soil else { return mixLabel }
        let r = Knowledge.shared.recipe(s)
        return r.isEmpty ? "\(s.name). \(s.note)" : "\(s.name): \(r). pH \(s.phMin.formatted())–\(s.phMax.formatted()), \(s.drainage.lowercased()) drainage."
    }

    var toxicityLine: String {
        switch (toxicCats, toxicDogs) {
        case (true, true): "Toxic to cats and dogs if chewed (ASPCA)"
        case (true, false): "Toxic to cats if chewed (ASPCA)"
        case (false, true): "Toxic to dogs if chewed (ASPCA)"
        default: "Non-toxic to cats and dogs (ASPCA)"
        }
    }
}

/// Extra rows for the plant passport, straight from the knowledge base.
enum PlantKnowledgeRows {
    struct Row { let symbol, title, value: String }
    static func rows(for s: Species, plant: Plant?) -> [Row] {
        var r: [Row] = []
        if let a = s.about { r.append(.init(symbol: "book", title: "About", value: a)) }
        if let o = s.origin { r.append(.init(symbol: "globe.americas", title: "Home in the wild", value: o + (s.habit.map { " · \($0)" } ?? ""))) }
        r.append(.init(symbol: "drop", title: "Water by season", value: s.seasonalWater + " " + s.potHint(diameter: plant?.potDiameterCm)))
        r.append(.init(symbol: "square.stack.3d.down.right", title: "Ideal soil", value: s.soilPlan))
        r.append(.init(symbol: "leaf.arrow.triangle.circlepath", title: "Food", value: s.feedPlan))
        if let p = s.propagation, !p.isEmpty { r.append(.init(symbol: "scissors", title: "More plants", value: p.joined(separator: ". ") + ".")) }
        if let n = s.repotNotes { r.append(.init(symbol: "arrow.up.bin", title: "Repotting", value: n)) }
        let pests = s.pestList
        if !pests.isEmpty { r.append(.init(symbol: "ant", title: "Watch for", value: pests.map(\.name).joined(separator: ", "))) }
        if let probs = s.problems, !probs.isEmpty {
            r.append(.init(symbol: "stethoscope", title: "If something's off", value: probs.map { "\($0.sign): \($0.fix)" }.joined(separator: "\n")))
        }
        return r
    }
}
