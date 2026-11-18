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

    struct Symptom: Decodable, Identifiable { let id, name, looks: String; let causes, fixes, keywords: [String] }
    struct Disease: Decodable, Identifiable { let id, name, signs, why, fix, prevent: String }
    struct Deficiency: Decodable, Identifiable { let id, name, signs, fix: String }
    struct Term: Decodable { let term, meaning: String }
    struct Month: Decodable { let month: Int; let indoor, outdoor: String }
    struct LightLevel: Decodable { let id, lux, `where`, plants: String }
    struct Named: Decodable { let name: String; let note: String?; let use: String? }

    var symptoms: [Symptom] = []
    var diseases: [Disease] = []
    var deficiencies: [Deficiency] = []
    var glossary: [Term] = []
    var calendar: [Month] = []
    var lightLevels: [LightLevel] = []
    var potMaterials: [Named] = []
    var tools: [Named] = []
    let soils: [Soil]
    let components: [Component]
    let fertilizers: [Fertilizer]
    let pests: [Pest]
    let sources: [String]

    enum CodingKeys: String, CodingKey { case soils, components, fertilizers, pests, sources, symptoms, diseases, deficiencies, glossary, calendar, lightLevels, potMaterials, tools }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        soils = try c.decode([Soil].self, forKey: .soils)
        components = try c.decode([Component].self, forKey: .components)
        fertilizers = try c.decode([Fertilizer].self, forKey: .fertilizers)
        pests = try c.decode([Pest].self, forKey: .pests)
        sources = try c.decode([String].self, forKey: .sources)
        symptoms = (try? c.decode([Symptom].self, forKey: .symptoms)) ?? []
        diseases = (try? c.decode([Disease].self, forKey: .diseases)) ?? []
        deficiencies = (try? c.decode([Deficiency].self, forKey: .deficiencies)) ?? []
        glossary = (try? c.decode([Term].self, forKey: .glossary)) ?? []
        calendar = (try? c.decode([Month].self, forKey: .calendar)) ?? []
        lightLevels = (try? c.decode([LightLevel].self, forKey: .lightLevels)) ?? []
        potMaterials = (try? c.decode([Named].self, forKey: .potMaterials)) ?? []
        tools = (try? c.decode([Named].self, forKey: .tools)) ?? []
    }
    init(soils: [Soil], components: [Component], fertilizers: [Fertilizer], pests: [Pest], sources: [String]) {
        self.soils = soils; self.components = components; self.fertilizers = fertilizers; self.pests = pests; self.sources = sources
    }

    static let shared: Knowledge = {
        guard let url = Bundle.main.url(forResource: "knowledge", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let k = try? JSONDecoder().decode(Knowledge.self, from: data) else {
            return Knowledge(soils: [], components: [], fertilizers: [], pests: [], sources: [])
        }
        return k
    }()

    /// Best symptom for free text ("my leaves have brown tips").
    func symptom(in text: String) -> Symptom? {
        let t = text.folded
        return symptoms.max { a, b in score(a, t) < score(b, t) }.flatMap { score($0, t) > 0 ? $0 : nil }
    }
    private func score(_ s: Symptom, _ t: String) -> Int { s.keywords.filter { t.contains($0.folded) }.map(\.count).reduce(0, +) }
    func term(in text: String) -> Term? {
        let t = text.folded
        return glossary.filter { g in
            let w = g.term.folded
            return ["is a \(w)", "is an \(w)", "is \(w)", "are \(w)", "\(w) mean", "o que e \(w)", "define \(w)"].contains { t.contains($0) }
        }.max { $0.term.count < $1.term.count }
    }
    func disease(in text: String) -> Disease? {
        let t = text.folded
        return diseases.first { d in t.contains(d.name.folded) || t.contains(d.id.replacingOccurrences(of: "-", with: " ")) }
    }
    func month(_ date: Date = Date(), south: Bool = JungleSettings.shared.southernHemisphere) -> Month? {
        var m = Calendar.current.component(.month, from: date)
        if south { m = (m + 5) % 12 + 1 }
        return calendar.first { $0.month == m }
    }

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

    var difficultyLabel: String { ["", "Easy-going", "Needs a little attention", "For experienced plant parents"][min(3, max(1, difficulty ?? 2))] }
    var goodFor: String? {
        let names = ["beginner": "beginners", "lowLight": "lower light", "petSafe": "homes with pets", "bathroom": "bathrooms",
                     "drought": "forgetful waterers", "edible": "the kitchen", "trailing": "shelves and hanging pots", "outdoor": "balconies and gardens"]
        let l = (tags ?? []).compactMap { names[$0] }
        return l.isEmpty ? nil : l.joined(separator: ", ").sentenceCased
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
        r.append(.init(symbol: "gauge.with.dots.needle.33percent", title: "Care level", value: s.difficultyLabel))
        if let b = s.bloom { r.append(.init(symbol: "camera.macro", title: "Flowers", value: b)) }
        if let g = s.goodFor { r.append(.init(symbol: "hand.thumbsup", title: "Good for", value: g)) }
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

extension String {
    var sentenceCased: String { prefix(1).uppercased() + dropFirst() }
}
