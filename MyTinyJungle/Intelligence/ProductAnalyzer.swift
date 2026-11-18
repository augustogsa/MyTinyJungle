import Foundation

struct AnalyzedProduct: Equatable {
    enum Category: String { case substrate, fertilizer, pesticide, pot, unknown
        var label: String {
            switch self {
            case .substrate: Grammar.pt(String(localized: "Soil / substrate", comment: "Scanned product category. Max 24 chars."))
            case .fertilizer: Grammar.pt(String(localized: "Fertilizer / plant food", comment: "Scanned product category. Max 24 chars."))
            case .pesticide: Grammar.pt(String(localized: "Pest treatment", comment: "Scanned product category. Max 24 chars."))
            case .pot: Grammar.pt(String(localized: "Pot", comment: "Scanned product category. Max 24 chars."))
            case .unknown: Grammar.pt(String(localized: "Unknown product", comment: "Scanned product category. Max 24 chars."))
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
        ("compost", [#"\bcompost"#, #"\besterco\b"#, #"\bterra vegetal\b"#, #"\bhumus\b"#, #"\bkompost\b"#], 0.7, 0.45),
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
        if has(#"\b(insecticid|inseticid|pesticid|fungicid|neem|pyrethr|piretr|acaricid|spinosad|pest|praga|insect|inset|cochonilha|pulg)"#) { category = .pesticide }
        else if (npk != nil || has(#"\b(fertili[sz]|plant food|adubo|abono|engrais|dunger|nutrient|liquid feed)"#)) && !has(#"\b(potting|compost|substrat|soil|terra|mix)\b"#) && found.count < 2 { category = .fertilizer }
        else if has(#"\b(potting|compost|substrat|soil\b|terra\b|terra vegetal|mix\b|erde\b|terreau|sustrato|bark|perlite|perlita|orchid|orquid)"#) || found.count >= 2 { category = .substrate }
        else if has(#"\b(pot|vaso|planter|maceta|cache-?pot|cachepo|diameter|diametro)\b"#) { category = .pot }

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

        // Product name: first wordy line, cut at the first comma (labels list ingredients after it).
        let line = raw.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.count >= 4 && $0.rangeOfCharacter(from: .letters) != nil } ?? ""
        let head = line.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        let name = head.count >= 3 ? head.prefix(1).uppercased() + head.dropFirst() : (category == .unknown ? Grammar.pt(String(localized: "Scanned product", comment: "Fallback name for a scanned product.")) : category.label)

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
                return .init(plantID: plant.id, plantName: plant.name, verdict: .unknown, reasons: [Grammar.pt(String(localized: "Set \(plant.name)'s species so I can compare.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers."))])
            }
            switch product.category {
            case .substrate: return substrate(product, plant: plant, s: s)
            case .fertilizer: return fertilizer(product, plant: plant, s: s, now: now)
            case .pesticide:
                return .init(plantID: plant.id, plantName: plant.name, verdict: .conditions,
                             reasons: [Grammar.pt(String(localized: "Only use it if you've confirmed a pest on \(plant.name).", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers.")), Grammar.pt(String(localized: "Follow the label exactly: dose, protection, and keep pets away.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers.")), Grammar.pt(String(localized: "Test on one leaf first and wait 48 h.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers."))])
            case .pot, .unknown:
                return .init(plantID: plant.id, plantName: plant.name, verdict: .unknown,
                             reasons: [Grammar.pt(String(localized: "Not enough information on the label. Scan the back with ingredients or NPK.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers."))])
            }
        }
        .sorted { order($0.verdict) < order($1.verdict) }
    }

    private static func order(_ v: Compatibility.Verdict) -> Int {
        switch v { case .suitable: 0; case .conditions: 1; case .notRecommended: 2; case .unknown: 3 }
    }

    private static func substrate(_ p: AnalyzedProduct, plant: Plant, s: Species) -> Compatibility {
        guard let r = p.retention, let a = p.aeration else {
            return .init(plantID: plant.id, plantName: plant.name, verdict: .unknown, reasons: [Grammar.pt(String(localized: "No ingredients found. Scan the composition on the back of the bag.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers."))])
        }
        var reasons: [String] = []
        var score = 0
        let dr = r - s.retention, da = a - s.aeration
        if abs(dr) <= 0.15 { reasons.append(Grammar.pt(String(localized: "Holds water about right for \(s.commonName).", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers."))) } else if dr > 0 {
            reasons.append(dr > 0.3 ? Grammar.pt(String(localized: "Holds far too much water for \(s.commonName). Risk of root rot.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers.")) : Grammar.pt(String(localized: "Holds a bit more water than \(s.commonName) likes.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers.")))
            score += dr > 0.3 ? 2 : 1
        } else {
            reasons.append(dr < -0.3 ? Grammar.pt(String(localized: "Dries much faster than \(s.commonName) wants.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers.")) : Grammar.pt(String(localized: "Dries a little faster than ideal.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers.")))
            score += dr < -0.3 ? 2 : 1
        }
        if da < -0.25 { reasons.append(Grammar.pt(String(localized: "Too dense. Add perlite or bark for air around the roots.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers."))); score += 1 }
        if s.phMax <= 6.0 && p.limed { reasons.append(Grammar.pt(String(localized: "Contains lime, which is bad for acid-loving \(s.commonName).", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers."))); score += 2 }
        if s.phMax <= 6.0 && !p.acidic && !p.limed { reasons.append(Grammar.pt(String(localized: "\(s.commonName) wants acidic soil. Not stated on the label.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers."))); score += 1 }
        if p.ingredients.contains("fertilizer charge") && s.feed == "cactus" { reasons.append(Grammar.pt(String(localized: "Pre-fertilized. Fine, but skip feeding for 6–8 weeks.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers."))) }
        if !plant.potHasDrainage && r > 0.6 { reasons.append(Grammar.pt(String(localized: "\(plant.name)'s pot has no drainage, so a moisture-holding mix is risky.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers."))); score += 1 }
        if s.mix == "carnivorous" { reasons = [Grammar.pt(String(localized: "\(s.commonName) needs nutrient-free sphagnum peat and perlite. Ordinary compost burns its roots.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers."))]; score = 3 }
        if s.mix == "none" { reasons = [Grammar.pt(String(localized: "\(s.commonName) lives without soil.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers."))]; score = 3 }
        if score > 0, let soil = s.soil { reasons.append(Grammar.pt(String(localized: "Ideal recipe: \(Knowledge.shared.recipe(soil)).", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers."))) }
        let verdict: Compatibility.Verdict = score == 0 ? .suitable : score == 1 ? .conditions : .notRecommended
        if verdict == .conditions, da >= -0.25 { reasons.append(Grammar.pt(String(localized: "Mixing in ~30% perlite or bark would fix it.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers."))) }
        return .init(plantID: plant.id, plantName: plant.name, verdict: verdict, reasons: reasons)
    }

    private static func fertilizer(_ p: AnalyzedProduct, plant: Plant, s: Species, now: Date) -> Compatibility {
        guard p.npk != nil || p.feedType != .unknown else {
            return .init(plantID: plant.id, plantName: plant.name, verdict: .unknown, reasons: [Grammar.pt(String(localized: "No NPK found. Scan the back label with the composition.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers."))])
        }
        var reasons: [String] = []
        var verdict: Compatibility.Verdict = .suitable
        let want = s.feed
        switch (want, p.feedType) {
        case ("none", _): verdict = .notRecommended; reasons.append(Grammar.pt(String(localized: "\(s.commonName) catches its own food. Fertilizer burns its roots.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers.")))
        case ("bromeliad", _): verdict = .conditions; reasons.append(Grammar.pt(String(localized: "\(s.commonName) drinks through its leaves. Use at ¼ strength in the soaking water.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers.")))
        case ("orchid", .orchid), ("cactus", .cactus), ("acid", .acid), ("citrus", .citrus): reasons.append(Grammar.pt(String(localized: "Made for this kind of plant.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers.")))
        case ("orchid", _): verdict = .conditions; reasons.append(Grammar.pt(String(localized: "Orchids need weak feeds. Use at ¼ strength.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers.")))
        case ("cactus", .highN): verdict = .notRecommended; reasons.append(Grammar.pt(String(localized: "Too much nitrogen for a succulent. It causes soft, weak growth.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers.")))
        case ("cactus", _): verdict = .conditions; reasons.append(Grammar.pt(String(localized: "Use at half strength, only in spring and summer.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers.")))
        case ("acid", _): verdict = .conditions; reasons.append(Grammar.pt(String(localized: "\(s.commonName) prefers an ericaceous feed. This works, but won't keep the soil acidic.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers.")))
        case ("citrus", _): verdict = .conditions; reasons.append(Grammar.pt(String(localized: "Citrus also needs iron and magnesium. Check the micronutrients.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers.")))
        case ("bloom", .bloom): reasons.append(Grammar.pt(String(localized: "High potassium supports flowering.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers.")))
        case (_, .orchid), (_, .cactus), (_, .acid): verdict = .conditions; reasons.append(Grammar.pt(String(localized: "Made for other plants. It works diluted, but a balanced feed suits \(s.commonName) better.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers.")))
        case ("light", _): verdict = .conditions; reasons.append(Grammar.pt(String(localized: "\(s.commonName) is a light feeder. Use half the label dose.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers.")))
        default: reasons.append(Grammar.pt(String(localized: "Balanced nutrition suits \(s.commonName).", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers.")))
        }
        if verdict != .suitable, let f = s.fertilizer { reasons.append(Grammar.pt(String(localized: "Ideal: \(f.name.lowercased()), \(f.npk). \(f.cadence).", comment: "Product scan reason: ideal fertilizer. Args: fertilizer name lowercase, NPK, how often."))) }
        if let npk = p.npk { reasons.append("NPK \(fmt(npk.n))-\(fmt(npk.p))-\(fmt(npk.k)).") }
        if !CareEngine.isGrowingSeason(now) { reasons.append(Grammar.pt(String(localized: "Not now: pause feeding until spring.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers."))); if verdict == .suitable { verdict = .conditions } }
        if let r = plant.lastRepotAt, CareEngine.days(from: r, to: now) < 42 { reasons.append(Grammar.pt(String(localized: "Recently repotted. Wait until 6 weeks after.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers."))) }
        if p.isSlowRelease && s.waterStyle == .dry { reasons.append(Grammar.pt(String(localized: "Slow-release granules build up salts in dry-kept soil. Liquid feed is safer.", comment: "Product scan verdict reason for one plant. Args are plant or species names, numbers."))) }
        return .init(plantID: plant.id, plantName: plant.name, verdict: verdict, reasons: reasons)
    }

    private static func fmt(_ v: Double) -> String { v.formatted(.number.precision(.fractionLength(0...1))) }
}
