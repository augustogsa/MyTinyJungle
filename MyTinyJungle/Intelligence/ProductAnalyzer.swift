import Foundation

struct AnalyzedProduct: Equatable {
    enum Category: String { case substrate, fertilizer, pesticide, pot, unknown
        var label: String {
            switch self {
            case .substrate: "Soil / substrate"
            case .fertilizer: "Fertilizer / plant food"
            case .pesticide: "Pest treatment"
            case .pot: "Pot"
            case .unknown: "Unknown product"
            }
        }
    }
    enum FeedType: String { case balanced, highN, bloom, cactus, orchid, acid, citrus, unknown }

    var name: String
    var category: Category
    var barcode: String?
    var npk: (n: Double, p: Double, k: Double)?
    var ingredients: [String]
    var retention: Double?
    var aeration: Double?
    var acidic: Bool
    var limed: Bool
    var feedType: FeedType
    var isSlowRelease: Bool
    var labelTargets: [String]

    static func == (a: Self, b: Self) -> Bool { a.name == b.name && a.barcode == b.barcode && a.ingredients == b.ingredients }
}

struct Compatibility: Identifiable {
    enum Verdict: String { case suitable = "Suitable", conditions = "With conditions", notRecommended = "Not recommended", unknown = "Not enough info" }
    let plantID: UUID
    let plantName: String
    let verdict: Verdict
    let reasons: [String]
    var id: UUID { plantID }
}

/// Label text → normalised product → per-plant verdicts. Rules decide; nothing is "suitable" without evidence.
enum ProductAnalyzer {
    /// ingredient key, label patterns (EN/PT/ES/FR/DE), water retention, aeration
    static let components: [(String, [String], Double, Double)] = [
        ("peat", [#"\bpeat\b"#, #"\bturfa\b"#, #"\bturba\b"#, #"\btourbe\b"#, #"\btorf\b"#, #"sphagnum peat"#], 0.85, 0.35),
        ("coco coir", [#"\bcoco"#, #"\bcoir\b"#, #"fibra de coco"#], 0.75, 0.5),
        ("perlite", [#"\bperlit"#], 0.15, 0.95),
        ("pumice", [#"\bpumice\b"#, #"\bpedra-?pomes\b"#, #"\bpome"#, #"\bbims\b"#], 0.25, 0.9),
        ("vermiculite", [#"\bvermiculit"#], 0.8, 0.45),
        ("bark", [#"\bbark\b"#, #"\bcasca de pinh"#, #"\bcasca\b"#, #"\bcorteza\b"#, #"\becorce\b"#, #"\brinde\b"#], 0.3, 0.9),
        ("sphagnum moss", [#"sphagnum moss"#, #"\bmusgo\b"#], 0.95, 0.5),
        ("compost", [#"\bcompost"#, #"\bhumus\b"#, #"\bkompost\b"#], 0.7, 0.45),
        ("worm castings", [#"worm cast"#, #"\bhumus de minhoca\b"#, #"vermicompost"#], 0.65, 0.45),
        ("sand", [#"\bsand\b"#, #"\bareia\b"#, #"\barena\b"#, #"\bsable\b"#], 0.2, 0.6),
        ("grit", [#"\bgrit\b"#, #"\bgravel\b"#, #"\bgravilha\b"#, #"\bakadama\b"#, #"\blava\b"#, #"\bzeolit"#], 0.2, 0.9),
        ("clay pebbles", [#"clay pebble"#, #"\bleca\b"#, #"argila expandida"#, #"\bexpanded clay\b"#], 0.15, 0.95),
        ("charcoal", [#"\bcharcoal\b"#, #"\bcarvao\b"#, #"\bbiochar\b"#], 0.25, 0.85),
        ("wood fibre", [#"wood fib"#, #"fibra de madeira"#, #"holzfaser"#], 0.55, 0.65),
        ("lime", [#"\blime\b"#, #"\bcalcario\b"#, #"\bcal\b"#, #"dolomit"#], 0, 0),
        ("fertilizer charge", [#"\bfertili[sz]er added\b"#, #"\bwith fertili"#, #"\bcom adubo\b"#, #"\bnutrients? for\b"#], 0, 0),
    ]

    static func analyze(text raw: String, barcode: String? = nil) -> AnalyzedProduct {
        let t = raw.folded.replacingOccurrences(of: "\n", with: " ")
        func has(_ p: String) -> Bool { ChatParser.matches(p, t) }

        let found = components.filter { c in c.1.contains(where: has) }
        let npk = parseNPK(t)

        var category: AnalyzedProduct.Category = .unknown
        if has(#"\b(insecticid|pesticid|fungicid|neem|pyrethr|acaricid|spinosad|pest|praga|insect)"#) { category = .pesticide }
        else if npk != nil || has(#"\b(fertili[sz]|plant food|adubo|abono|engrais|dunger|nutrient|liquid feed)"#) && !has(#"\b(potting|compost|substrat|soil|terra|mix)\b"#) { category = .fertilizer }
        else if has(#"\b(potting|compost|substrat|soil\b|terra\b|mix\b|erde\b|terreau|sustrato|bark|perlite|orchid)"#) || found.count >= 2 { category = .substrate }
        else if has(#"\b(pot|vaso|planter|maceta|cache-?pot|diameter|diametro)\b"#) { category = .pot }

        var retention: Double?, aeration: Double?
        let structural = found.filter { $0.2 > 0 }
        if !structural.isEmpty {
            retention = structural.map(\.2).reduce(0, +) / Double(structural.count)
            aeration = structural.map(\.3).reduce(0, +) / Double(structural.count)
        }

        var feedType: AnalyzedProduct.FeedType = .unknown
        if has(#"\b(orchid|orquid)"#) { feedType = .orchid }
        else if has(#"\b(cact|succulent|suculent)"#) { feedType = .cactus }
        else if has(#"\b(ericaceous|acid|acidofil|azalea|rhododendron|hortens|hydrangea|camelia)"#) { feedType = .acid }
        else if has(#"\b(citrus|citrin|lemon|limoeiro)"#) { feedType = .citrus }
        else if let npk {
            if npk.n > (npk.p + npk.k) * 0.8 && npk.n >= 2 * npk.k { feedType = .highN }
            else if npk.k > npk.n * 1.3 || npk.p > npk.n * 1.5 { feedType = .bloom }
            else { feedType = .balanced }
        }

        let targets = ["monstera", "aroid", "cactus", "succulent", "orchid", "tomato", "herb", "citrus", "palm", "fern", "bonsai", "houseplant", "indoor", "vegetable", "flower"]
            .filter { t.contains($0) }

        let name = raw.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.count >= 4 && $0.rangeOfCharacter(from: .letters) != nil } ?? "Scanned product"

        return AnalyzedProduct(name: String(name.prefix(48)), category: category, barcode: barcode, npk: npk,
                               ingredients: found.map(\.0), retention: retention, aeration: aeration,
                               acidic: feedType == .acid || has(#"\b(ericaceous|ph 4|ph 5|acid)"#),
                               limed: found.contains { $0.0 == "lime" }, feedType: feedType,
                               isSlowRelease: has(#"\b(slow.?release|controlled.?release|libertacao lenta|liberacao lenta|granul|sticks?|pellets?)\b"#),
                               labelTargets: targets)
    }

    static func parseNPK(_ t: String) -> (n: Double, p: Double, k: Double)? {
        let num = #"(\d{1,2}(?:[.,]\d{1,2})?)"#
        let sep = #"\s*[-–—:/+]\s*"#
        if let re = try? NSRegularExpression(pattern: #"(?:npk\s*)?"# + num + sep + num + sep + num),
           let m = re.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) {
            let vals = (1...3).compactMap { Range(m.range(at: $0), in: t).flatMap { Double(t[$0].replacingOccurrences(of: ",", with: ".")) } }
            if vals.count == 3, vals.allSatisfy({ $0 <= 60 }), vals.reduce(0, +) > 0, !ChatParser.matches(#"\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}"#, t) || t.contains("npk") {
                return (vals[0], vals[1], vals[2])
            }
        }
        // "N 10% P2O5 5% K2O 8%"
        let n = ChatParser.firstNumber(#"\bn(?:itrogen|itrogenio|itrogeno)?\)?\s*(?:total)?\s*[:=]?\s*(\d{1,2}(?:[.,]\d)?)\s*%"#, t)
        let p = ChatParser.firstNumber(#"p2o5\)?\s*[:=]?\s*(\d{1,2}(?:[.,]\d)?)\s*%"#, t)
        let k = ChatParser.firstNumber(#"k2o\)?\s*[:=]?\s*(\d{1,2}(?:[.,]\d)?)\s*%"#, t)
        if let n, let p, let k { return (n, p, k) }
        return nil
    }

    static func compatibility(_ product: AnalyzedProduct, plants: [Plant], now: Date = Date()) -> [Compatibility] {
        plants.filter { !$0.isArchived }.map { plant in
            guard let s = plant.species else {
                return .init(plantID: plant.id, plantName: plant.name, verdict: .unknown, reasons: ["Set \(plant.name)'s species so I can compare."])
            }
            switch product.category {
            case .substrate: return substrate(product, plant: plant, s: s)
            case .fertilizer: return fertilizer(product, plant: plant, s: s, now: now)
            case .pesticide:
                return .init(plantID: plant.id, plantName: plant.name, verdict: .conditions,
                             reasons: ["Only use it if you've confirmed a pest on \(plant.name).", "Follow the label exactly: dose, protection, and keep pets away.", "Test on one leaf first and wait 48 h."])
            case .pot, .unknown:
                return .init(plantID: plant.id, plantName: plant.name, verdict: .unknown,
                             reasons: ["Not enough information on the label. Scan the back with ingredients or NPK."])
            }
        }
        .sorted { order($0.verdict) < order($1.verdict) }
    }

    private static func order(_ v: Compatibility.Verdict) -> Int {
        switch v { case .suitable: 0; case .conditions: 1; case .notRecommended: 2; case .unknown: 3 }
    }

    private static func substrate(_ p: AnalyzedProduct, plant: Plant, s: Species) -> Compatibility {
        guard let r = p.retention, let a = p.aeration else {
            return .init(plantID: plant.id, plantName: plant.name, verdict: .unknown, reasons: ["No ingredients found. Scan the composition on the back of the bag."])
        }
        var reasons: [String] = []
        var score = 0
        let dr = r - s.retention, da = a - s.aeration
        if abs(dr) <= 0.15 { reasons.append("Holds water about right for \(s.en).") } else if dr > 0 {
            reasons.append(dr > 0.3 ? "Holds far too much water for \(s.en). Risk of root rot." : "Holds a bit more water than \(s.en) likes.")
            score += dr > 0.3 ? 2 : 1
        } else {
            reasons.append(dr < -0.3 ? "Dries much faster than \(s.en) wants." : "Dries a little faster than ideal.")
            score += dr < -0.3 ? 2 : 1
        }
        if da < -0.25 { reasons.append("Too dense. Add perlite or bark for air around the roots."); score += 1 }
        if s.phMax <= 6.0 && p.limed { reasons.append("Contains lime, which is bad for acid-loving \(s.en)."); score += 2 }
        if s.phMax <= 6.0 && !p.acidic && !p.limed { reasons.append("\(s.en) wants acidic soil. Not stated on the label."); score += 1 }
        if p.ingredients.contains("fertilizer charge") && s.feed == "cactus" { reasons.append("Pre-fertilized. Fine, but skip feeding for 6–8 weeks.") }
        if !plant.potHasDrainage && r > 0.6 { reasons.append("\(plant.name)'s pot has no drainage, so a moisture-holding mix is risky."); score += 1 }
        let verdict: Compatibility.Verdict = score == 0 ? .suitable : score == 1 ? .conditions : .notRecommended
        if verdict == .conditions, da >= -0.25 { reasons.append("Mixing in ~30% perlite or bark would fix it.") }
        return .init(plantID: plant.id, plantName: plant.name, verdict: verdict, reasons: reasons)
    }

    private static func fertilizer(_ p: AnalyzedProduct, plant: Plant, s: Species, now: Date) -> Compatibility {
        guard p.npk != nil || p.feedType != .unknown else {
            return .init(plantID: plant.id, plantName: plant.name, verdict: .unknown, reasons: ["No NPK found. Scan the back label with the composition."])
        }
        var reasons: [String] = []
        var verdict: Compatibility.Verdict = .suitable
        let want = s.feed
        switch (want, p.feedType) {
        case ("orchid", .orchid), ("cactus", .cactus), ("acid", .acid), ("citrus", .citrus): reasons.append("Made for this kind of plant.")
        case ("orchid", _): verdict = .conditions; reasons.append("Orchids need weak feeds. Use at ¼ strength.")
        case ("cactus", .highN): verdict = .notRecommended; reasons.append("Too much nitrogen for a succulent. It causes soft, weak growth.")
        case ("cactus", _): verdict = .conditions; reasons.append("Use at half strength, only in spring and summer.")
        case ("acid", _): verdict = .conditions; reasons.append("\(s.en) prefers an ericaceous feed. This works, but won't keep the soil acidic.")
        case ("citrus", _): verdict = .conditions; reasons.append("Citrus also needs iron and magnesium. Check the micronutrients.")
        case ("bloom", .bloom): reasons.append("High potassium supports flowering.")
        case (_, .orchid), (_, .cactus), (_, .acid): verdict = .conditions; reasons.append("Made for other plants. It works diluted, but a balanced feed suits \(s.en) better.")
        case ("light", _): verdict = .conditions; reasons.append("\(s.en) is a light feeder. Use half the label dose.")
        default: reasons.append("Balanced nutrition suits \(s.en).")
        }
        if let npk = p.npk { reasons.append("NPK \(fmt(npk.n))-\(fmt(npk.p))-\(fmt(npk.k)).") }
        if !CareEngine.isGrowingSeason(now) { reasons.append("Not now: pause feeding until spring."); if verdict == .suitable { verdict = .conditions } }
        if let r = plant.lastRepotAt, CareEngine.days(from: r, to: now) < 42 { reasons.append("Recently repotted. Wait until 6 weeks after.") }
        if p.isSlowRelease && s.waterStyle == .dry { reasons.append("Slow-release granules build up salts in dry-kept soil. Liquid feed is safer.") }
        return .init(plantID: plant.id, plantName: plant.name, verdict: verdict, reasons: reasons)
    }

    private static func fmt(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }
}
