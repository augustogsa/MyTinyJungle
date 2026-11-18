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
    struct Crop: Decodable, Identifiable {
        let id, name: String; let aliases: [String]; let sun: String; let potLitres, depthCm: Int
        let start, germDays, harvestDays: String; let spacingCm, minTemp: Int; let companions, avoid: [String]; let tip: String
    }
    struct GroupCare: Decodable { let happy: String; let mistakes, wins: [String] }
    struct Remedy: Decodable, Identifiable { let id, name, forWhat, recipe, how, caution: String }
    struct Family: Decodable, Identifiable { let id, name, common, traits, care, toxic: String; let examples: [String] }
    struct Topic: Decodable, Identifiable {
        struct Step: Decodable { let title, detail: String }
        let id, title, kind, intro: String; let steps: [Step]; let keywords: [String]
    }

    var symptoms: [Symptom] = []
    var diseases: [Disease] = []
    var deficiencies: [Deficiency] = []
    var glossary: [Term] = []
    var calendar: [Month] = []
    var lightLevels: [LightLevel] = []
    var potMaterials: [Named] = []
    var tools: [Named] = []
    var topics: [Topic] = []
    var crops: [Crop] = []
    var families: [Family] = []
    var groups: [String: GroupCare] = [:]
    var remedies: [Remedy] = []
    let soils: [Soil]
    let components: [Component]
    let fertilizers: [Fertilizer]
    let pests: [Pest]
    let sources: [String]

    enum CodingKeys: String, CodingKey { case soils, components, fertilizers, pests, sources, symptoms, diseases, deficiencies, glossary, calendar, lightLevels, potMaterials, tools, topics, crops, families, groups, remedies }
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
        topics = (try? c.decode([Topic].self, forKey: .topics)) ?? []
        crops = (try? c.decode([Crop].self, forKey: .crops)) ?? []
        families = (try? c.decode([Family].self, forKey: .families)) ?? []
        groups = (try? c.decode([String: GroupCare].self, forKey: .groups)) ?? [:]
        remedies = (try? c.decode([Remedy].self, forKey: .remedies)) ?? []
    }
    init(soils: [Soil], components: [Component], fertilizers: [Fertilizer], pests: [Pest], sources: [String]) {
        self.soils = soils; self.components = components; self.fertilizers = fertilizers; self.pests = pests; self.sources = sources
    }

    static let shared: Knowledge = {
        guard let url = Bundle.main.url(forResource: "knowledge", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let k = try? JSONDecoder().decode(Knowledge.self, from: L10nData.localize(data)) else {
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
            return "\((Double(p) / 100).formatted(.percent)) \((component(id)?.name ?? id).lowercased())"
        }.formatted(.list(type: .and))
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
        let sLo = max(1, Int((dryMin * s).rounded())), sHi = max(2, Int((dryMax * s).rounded()))
        if w >= 2.5 {
            return Grammar.pt(String(localized: "In summer about every \(sLo)–\(sHi) days, in winter barely at all, a sip once a month. Always feel the soil first.", comment: "Seasonal watering advice; summer day range"))
        }
        let wLo = Int((dryMin * w).rounded()), wHi = Int((dryMax * w).rounded())
        return Grammar.pt(String(localized: "In summer about every \(sLo)–\(sHi) days, in winter about every \(wLo)–\(wHi) days. Always feel the soil first.", comment: "Seasonal watering advice; summer and winter day ranges"))
    }

    /// Pot-size hint: small pots dry faster, big ones slower.
    func potHint(diameter d: Double?) -> String {
        guard let d else { return Grammar.pt(String(localized: "Small pots (under 12 cm) dry about 15% faster, big ones (over 30 cm) about 20% slower.", comment: "Pot size hint when pot size unknown")) }
        if d < 12 { return Grammar.pt(String(localized: "A \(Int(d)) cm pot dries fast, so check it more often.", comment: "Pot size hint; pot diameter in cm")) }
        if d > 30 { return Grammar.pt(String(localized: "A \(Int(d)) cm pot holds water a long time; check deeper before watering.", comment: "Pot size hint; pot diameter in cm")) }
        return Grammar.pt(String(localized: "A \(Int(d)) cm pot is a comfortable middle size.", comment: "Pot size hint; pot diameter in cm"))
    }

    var feedPlan: String {
        guard let f = fertilizer else { return Grammar.pt(String(localized: "A gentle balanced feed in the growing season.", comment: "Default fertilizer plan")) }
        if feed == "none" { return f.cadence + ". " + f.note }
        return "\(f.name) (\(f.npk)). \(f.cadence), \(f.dilution.lowercased()). \(f.rest)."
    }

    var soilPlan: String {
        guard let s = soil else { return mixLabel }
        let r = Knowledge.shared.recipe(s)
        return r.isEmpty ? "\(s.name). \(s.note)" : "\(s.name): \(r). pH \(s.phMin.formatted())–\(s.phMax.formatted()), \(s.drainage.lowercased()) drainage."
    }

    var difficultyLabel: String {
        switch min(3, max(1, difficulty ?? 2)) {
        case 1: Grammar.pt(String(localized: "Easy-going", comment: "Plant care level"))
        case 2: Grammar.pt(String(localized: "Needs a little attention", comment: "Plant care level"))
        default: Grammar.pt(String(localized: "For experienced plant parents", comment: "Plant care level"))
        }
    }
    var goodFor: String? {
        let c: StaticString = "What a plant is good for, lowercase list item"
        let names = ["beginner": Grammar.pt(String(localized: "beginners", comment: c)), "lowLight": Grammar.pt(String(localized: "lower light", comment: c)),
                     "petSafe": Grammar.pt(String(localized: "homes with pets", comment: c)), "bathroom": Grammar.pt(String(localized: "bathrooms", comment: c)),
                     "drought": Grammar.pt(String(localized: "forgetful waterers", comment: c)), "edible": Grammar.pt(String(localized: "the kitchen", comment: c)),
                     "trailing": Grammar.pt(String(localized: "shelves and hanging pots", comment: c)), "outdoor": Grammar.pt(String(localized: "balconies and gardens", comment: c))]
        let l = (tags ?? []).compactMap { names[$0] }
        return l.isEmpty ? nil : l.formatted(.list(type: .and)).sentenceCased
    }

    var toxicityLine: String {
        switch (toxicCats, toxicDogs) {
        case (true, true): Grammar.pt(String(localized: "Toxic to cats and dogs if chewed (ASPCA)", comment: "Pet toxicity line for a plant"))
        case (true, false): Grammar.pt(String(localized: "Toxic to cats if chewed (ASPCA)", comment: "Pet toxicity line for a plant"))
        case (false, true): Grammar.pt(String(localized: "Toxic to dogs if chewed (ASPCA)", comment: "Pet toxicity line for a plant"))
        default: Grammar.pt(String(localized: "Non-toxic to cats and dogs (ASPCA)", comment: "Pet toxicity line for a plant"))
        }
    }
}

/// Extra rows for the plant passport, straight from the knowledge base.
enum PlantKnowledgeRows {
    struct Row { let symbol, title, value: String }
    static func rows(for s: Species, plant: Plant?) -> [Row] {
        var r: [Row] = []
        r.append(.init(symbol: "gauge.with.dots.needle.33percent", title: Grammar.pt(String(localized: "Care level", comment: "Plant passport row title; short")), value: s.difficultyLabel))
        if let b = s.bloom { r.append(.init(symbol: "camera.macro", title: Grammar.pt(String(localized: "Flowers", comment: "Plant passport row title; short")), value: b)) }
        if let g = s.goodFor { r.append(.init(symbol: "hand.thumbsup", title: Grammar.pt(String(localized: "Good for", comment: "Plant passport row title; short")), value: g)) }
        if let fit = Climate.shared.fit(s) { r.append(.init(symbol: "globe.europe.africa", title: Grammar.pt(String(localized: "In your climate", comment: "Plant passport row title; short")), value: fit)) }
        if let g = s.group.flatMap({ Knowledge.shared.groups[$0] }) {
            r.append(.init(symbol: "face.smiling", title: Grammar.pt(String(localized: "A happy one looks like", comment: "Plant passport row title; short")), value: g.happy))
            r.append(.init(symbol: "exclamationmark.triangle", title: Grammar.pt(String(localized: "Common mistakes", comment: "Plant passport row title; short")), value: g.mistakes.joined(separator: ". ") + "."))
            r.append(.init(symbol: "star", title: Grammar.pt(String(localized: "Quick wins", comment: "Plant passport row title; short")), value: g.wins.joined(separator: ". ") + "."))
        }
        if let f = Knowledge.shared.family(named: s.family) { r.append(.init(symbol: "tree", title: Grammar.pt(String(localized: "Family", comment: "Plant passport row title; short")), value: "\(f.name), \(f.common). \(f.traits)")) }
        if let a = s.about { r.append(.init(symbol: "book", title: Grammar.pt(String(localized: "About", comment: "Plant passport row title; short")), value: a)) }
        if let o = s.origin { r.append(.init(symbol: "globe.americas", title: Grammar.pt(String(localized: "Home in the wild", comment: "Plant passport row title; short")), value: o + (s.habit.map { " · \($0)" } ?? ""))) }
        r.append(.init(symbol: "drop", title: Grammar.pt(String(localized: "Water by season", comment: "Plant passport row title; short")), value: s.seasonalWater + " " + s.potHint(diameter: plant?.potDiameterCm)))
        r.append(.init(symbol: "square.stack.3d.down.right", title: Grammar.pt(String(localized: "Ideal soil", comment: "Plant passport row title; short")), value: s.soilPlan))
        r.append(.init(symbol: "leaf.arrow.triangle.circlepath", title: Grammar.pt(String(localized: "Food", comment: "Plant passport row title; short")), value: s.feedPlan))
        if let p = s.propagation, !p.isEmpty { r.append(.init(symbol: "scissors", title: Grammar.pt(String(localized: "More plants", comment: "Plant passport row title; short")), value: p.joined(separator: ". ") + ".")) }
        if let n = s.repotNotes { r.append(.init(symbol: "arrow.up.bin", title: Grammar.pt(String(localized: "Repotting", comment: "Plant passport row title; short")), value: n)) }
        let pests = s.pestList
        if !pests.isEmpty { r.append(.init(symbol: "ant", title: Grammar.pt(String(localized: "Watch for", comment: "Plant passport row title; short")), value: pests.map(\.name).formatted(.list(type: .and)))) }
        if let probs = s.problems, !probs.isEmpty {
            r.append(.init(symbol: "stethoscope", title: Grammar.pt(String(localized: "If something's off", comment: "Plant passport row title; short")), value: probs.map { "\($0.sign): \($0.fix)" }.joined(separator: "\n")))
        }
        return r
    }
}

extension String {
    var sentenceCased: String { prefix(1).uppercased() + dropFirst() }
}

extension Knowledge {
    /// Best how-to topic for a question: longest matching keyword wins.
    func topic(in q: String) -> Topic? {
        let f = q.folded
        var best: (Topic, Int)?
        for t in topics {
            for k in t.keywords {
                let kf = k.folded
                guard kf.count > (best?.1 ?? 2), f.range(of: "\\b\(NSRegularExpression.escapedPattern(for: kf))", options: .regularExpression) != nil else { continue }
                best = (t, kf.count)
            }
        }
        return best?.0
    }
    func topic(id: String) -> Topic? { topics.first { $0.id == id } }
}

extension Knowledge {
    private static func hit(_ f: String, _ word: String) -> Bool {
        f.range(of: "\\b\(NSRegularExpression.escapedPattern(for: word.folded))\\b", options: .regularExpression) != nil
    }
    /// A food crop named in the question (longest name or alias wins).
    func crop(in q: String) -> Crop? {
        let f = q.folded
        return crops.flatMap { c in ([c.name] + c.aliases).map { (c, $0) } }
            .filter { Self.hit(f, $0.1) }.max { $0.1.count < $1.1.count }?.0
    }
    func family(named n: String?) -> Family? {
        guard let n, !n.isEmpty else { return nil }
        return families.first { $0.id == n } ?? (n.hasSuffix("aceae") && ["Polypodiaceae", "Nephrolepidaceae", "Aspleniaceae", "Pteridaceae", "Dryopteridaceae", "Davalliaceae"].contains(n) ? families.first { $0.id == "Polypodiaceae" } : nil)
    }
    func family(in q: String) -> Family? {
        let f = q.folded
        return families.first { Self.hit(f, $0.id) || Self.hit(f, $0.common.components(separatedBy: ",").first ?? $0.common) }
    }
}

extension Knowledge.Crop {
    var card: String {
        let temp = Climate.temp(Double(minTemp))
        var t = Grammar.pt(String(localized: "\(name) in a pot: \(sun). Pot at least \(potLitres) L and \(depthCm) cm deep, \(spacingCm) cm apart.\n• When: \(start)\n• Sprouts in \(germDays) days, harvest in about \(harvestDays) days.\n• Keep above \(temp).\n• \(tip)", comment: "Crop growing card; keep the line breaks and bullets"))
        if !companions.isEmpty { t += Grammar.pt(String(localized: "\n• Good neighbours: \(companions.formatted(.list(type: .and))).", comment: "Crop card line: companion plants list; keep the leading line break and bullet")) }
        if !avoid.isEmpty { t += Grammar.pt(String(localized: " Keep away from: \(avoid.formatted(.list(type: .and))).", comment: "Crop card: plants to keep away; keep the leading space")) }
        return t
    }
}

extension Knowledge {
    /// Remedies that treat a named pest or problem.
    func remedies(for q: String) -> [Remedy] {
        let f = q.folded
        return remedies.filter { r in r.forWhat.folded.components(separatedBy: CharacterSet(charactersIn: ", ")).contains { $0.count > 3 && f.contains(String($0.prefix(max(4, $0.count - 1)))) } }
    }
}
