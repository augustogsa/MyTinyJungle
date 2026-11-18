import Foundation

/// Answers questions from the plant's facts and reviewed species knowledge. No guessing:
/// if we don't know, the plant says so.
enum Answerer {
    static func answer(_ raw: String, plant: Plant?, plants: [Plant], now: Date = Date()) -> (text: String, suggestions: [String]) {
        let q = raw.folded
        func has(_ p: String) -> Bool { ChatParser.matches(p, q) }

        if let general = knowledgeAnswer(q, raw: raw, plant: plant, now: now) { return general }

        // Collection-level questions.
        if plant == nil {
            if has(#"\b(who|which|what|quem|quais|qual).{0,25}(need|thirst|water|attention|precis|sede|regar)"#) || has(#"\btoday\b|\bhoje\b"#) {
                let needing = plants.compactMap { p -> String? in
                    let r = CareEngine.requests(for: p, now: now).filter { $0.priority <= 1 }
                    guard let first = r.first else { return nil }
                    return "• \(p.name): \(label(first.kind))"
                }
                return needing.isEmpty ? ("Everyone is fine right now. Nothing needs you today.", [])
                    : ("Here's who needs you:\n" + needing.joined(separator: "\n"), [])
            }
            if has(#"\b(recommend|suggest|which plant|what plant|should i (get|buy)|best plant|indica|qual planta)"#) {
                return (recommend(q), [])
            }
            if let sp = SpeciesLibrary.shared.mentioned(in: raw) { return (speciesCard(sp), ["Is it pet-safe?", "Recommend a plant"]) }
            if has(#"\b(safe|toxic|poison|pet|cat|dog|gato|cao|toxic)"#) {
                let toxic = plants.filter { ($0.species?.toxicCats ?? false) || ($0.species?.toxicDogs ?? false) }.map(\.name)
                return toxic.isEmpty ? ("None of your plants are on the toxic list for cats or dogs.", [])
                    : ("Keep these away from pets: \(toxic.joined(separator: ", ")). They're irritating or toxic if chewed.", [])
            }
            if plants.isEmpty { return ("Add your first plant and I'll be able to help. Tell me something like \"I have a monstera called Milo\".", []) }
            return ("Which plant is this about? Mention its name, like \"\(plants.first!.name)\".", plants.prefix(3).map(\.name))
        }

        guard let plant else { return ("", []) }
        guard let s = plant.species else {
            return ("I don't know my species yet, so I can't answer that well. Tell me what kind of plant I am, or open my profile and pick it.", ["Set species"])
        }
        let expected = CareEngine.expectedDryDays(for: plant, at: now)
        let lastWater = plant.lastEvent(.water)?.date

        // Symptoms first, because they matter most.
        if has(#"\b(yellow|amarel)"#) {
            var t = "Yellow leaves have a few possible causes. "
            if let lastWater, CareEngine.days(from: lastWater, to: now) < expected * 0.6 {
                t += "I was watered \(CareEngine.relative(lastWater, now)) and I usually take about \(Int(expected)) days to dry, so too much water is the first thing to check. Feel my soil 3–4 cm deep before giving more."
            } else {
                t += "If it's only one old leaf at the bottom, that's normal ageing. If several leaves are yellowing, check whether my soil stays wet for long, and whether my pot drains."
            }
            if let p = s.problems?.first(where: { $0.sign.folded.contains("yellow") }) { t += " For \(s.en) specifically: \(p.cause.lowercased()) is common. \(p.fix)" }
            t += " Can you send a photo of the leaf?"
            return (t, ["Soil is wet", "Soil is dry", "Send photo"])
        }
        if has(#"\b(brown|crisp|castanh|seca nas pontas|pontas)"#) {
            let hum = s.humidityMin >= 50 ? "I like humidity above \(Int(s.humidityMin))%, so dry air is a likely cause. " : ""
            return ("Brown, crispy tips usually come from dry air, uneven watering or salts building up from tap water and fertilizer. \(hum)Flushing my soil with plenty of water every couple of months helps. Brown soft patches are different: they point to too much water.", ["Tips are crispy", "Patches are soft"])
        }
        if has(#"\b(droop|wilt|sad|limp|murch|caid)"#) {
            return ("Drooping can mean thirst or too much water. Both stress my roots. Feel my soil: if it's dry, water me well. If it's wet, the roots may be suffocating, so let me dry out and check that my pot drains.", ["Soil is dry", "Soil is wet"])
        }
        if has(#"\b(curl|enrol)"#) {
            return ("Curling leaves usually mean I'm thirsty, the air is too dry, or I'm getting too much sun. \(s.lightRule)", ["Soil is dry", "It gets direct sun"])
        }
        if has(#"\b(bug|pest|insect|bicho|praga|web|teia|mite|aranha|gnat|mosca|mealy|cochonilha|scale|aphid|pulg|thrip|whitefly)"#) {
            let named = Knowledge.shared.pests.first { p in p.name.folded.split(separator: " ").contains { q.contains($0.prefix(5)) } }
            if let p = named {
                return ("\(p.name): \(p.signs) What helps: \(p.fix) Keep me apart from the others until it's clear.", ["Send photo"])
            }
            let mine = s.pestList.prefix(3)
            if !mine.isEmpty {
                let list = mine.map { "• \($0.name): \($0.signs)" }.joined(separator: "\n")
                return ("The pests that bother \(s.en) most:\n\(list)\nCheck under my leaves and along the stems. A clear photo will help most.", mine.map(\.name) + ["Send photo"])
            }
        }
        if has(#"\b(spot|mancha|bug|pest|insect|bicho|praga|web|teia|mite|aranha|gnat|mosca)"#) {
            return ("Let's look closely. Check under my leaves and along the stems for webbing, white fluff or tiny moving dots. Until we know, keep me a little apart from the other plants. A clear photo of the spot will help most.", ["Send photo", "I see webbing", "White fluff"])
        }

        // Care questions.
        if has(#"\b(water|drink|agua|regar|rega)"#) {
            var t = "\(s.waterRule) \(s.seasonalWater) \(s.potHint(diameter: plant.potDiameterCm)) In my current setup I usually dry in about \(Int(expected.rounded())) days"
            t += plant.learnedDryDays != nil ? ". I learned that from your soil checks." : ". I'll learn my real rhythm from your soil checks."
            if let lastWater { t += " I was last watered \(CareEngine.relative(lastWater, now))." }
            t += " Always feel the soil first. The calendar is only a guess."
            return (t, ["Soil is dry", "Soil is moist"])
        }
        if has(#"\b(light|sun|window|luz|sol|janela|bright|dark|escur)"#) {
            return ("\(s.lightRule) If I stretch toward the window or my new leaves come out small, I need more light. Bleached or scorched patches mean too much direct sun.", [])
        }
        if has(#"\b(fertili|feed|food|adub|nutri|npk)"#) {
            if !CareEngine.isGrowingSeason(now) {
                return ("I'm growing slowly at this time of year, so please pause feeding until spring. Feeding a resting plant just builds up salts in my soil.", [])
            }
            if let r = plant.lastRepotAt, CareEngine.days(from: r, to: now) < 42 {
                return ("My soil is still fresh from repotting and has nutrients. Let's wait about 6 weeks before feeding.", [])
            }
            if s.feed == "none" { return ("Please never feed me. I catch my own food, and fertilizer burns my roots. Rainwater only.", []) }
            return ("\(s.feedPlan) Always water first. Never feed dry roots. Scan any bottle at the shop and I'll tell you if it suits me.", ["Scan a product", "What soil do you like?"])
        }
        if has(#"\b(repot|pot|vaso|transplant|roots|raiz|raize)"#) {
            let size = plant.potDiameterCm.map { "My pot is \(Int($0)) cm, so the next one should be about \(Int($0 + 2))–\(Int($0 + 5)) cm. " } ?? "Go only 2–5 cm wider than my current pot. "
            let season = CareEngine.isWinter(now) ? "It's winter, so unless my roots are rotting, let's wait for spring. " : "Spring and early summer are the best time. "
            return ("Repot me when roots come out of the drainage holes, circle the pot, or water runs straight through. \(size)\(season)\(s.repotNotes.map { $0 + " " } ?? "")For soil: \(s.soilPlan)", ["How do I propagate you?"])
        }
        if has(#"\b(soil|substrate|mix|terra|substrato|perlite|bark)"#) {
            return ("My perfect home is \(s.soilPlan) \(s.soil?.note ?? "") Scan a soil bag and I'll check it against that.", ["Scan a product", "What food do you like?"])
        }
        if has(#"\b(humid|mist|borrif|humidade)"#) {
            return ("I'm happiest above \(Int(s.humidityMin))% humidity. Grouping plants or using a humidifier works better than misting, whose effect lasts only minutes.", [])
        }
        if has(#"\b(cold|hot|temperat|frio|calor|winter|inverno|heater|aquecedor|radiator)"#) {
            return ("I'm comfortable between \(Int(s.tempMin)) and \(Int(s.tempMax)) °C. Keep me away from radiators, AC vents and cold drafts.", [])
        }
        if has(#"\b(toxic|safe|pet|cat|dog|kid|child|gato|cao|crianc)"#) {
            let tox = s.toxicCats || s.toxicDogs
            return (tox ? "\(s.toxicityLine). Keep me out of reach. If a pet chews me and shows symptoms, call a vet." : "I'm on the non-toxic list for cats and dogs (ASPCA). Still, nibbling isn't good for either of us.", [])
        }
        if has(#"\b(how are you|how do you feel|tudo bem|como estas|como esta|how you doing)"#) {
            let reqs = CareEngine.requests(for: plant, now: now)
            if let first = reqs.first(where: { $0.priority <= 1 }) { return (PlantVoice.say(first, plant: plant), suggestions(for: first)) }
            return (PlantVoice.happy(plant), [])
        }
        if has(#"\b(propagat|cutting|estaca|multiplic)"#) {
            let ways = (s.propagation ?? ["Stem cuttings just below a node, in water or moist perlite"]).map { "• \($0)" }.joined(separator: "\n")
            return ("Here's how to make more of me:\n\(ways)\nSpring and early summer are best, in bright, indirect light.", [])
        }
        if has(#"\b(about|story|origin|where.{0,10}from|native|history|historia|origem|de onde|who are you)"#) {
            return ("\(s.about ?? s.tip)\(s.origin.map { " I come from \($0)." } ?? "")\(s.habit.map { " Growth habit: \($0.lowercased())." } ?? "")", ["How do I propagate you?", "Any pests to watch?"])
        }
        if has(#"\b(problem|wrong|issue|sick|doente|ajuda|help)"#), let probs = s.problems, !probs.isEmpty {
            return ("Things that most often trouble \(s.en):\n" + probs.map { "• \($0.sign): \($0.cause.lowercased()). \($0.fix)" }.joined(separator: "\n"), ["Send photo"])
        }
        if let sym = Knowledge.shared.symptom(in: q) {
            let mine = s.problems?.first { p in sym.keywords.contains { p.sign.folded.contains($0.folded) } }
            return ("\(sym.name). Usual causes: \(sym.causes.joined(separator: "; ")). \(sym.fixes.joined(separator: " "))\(mine.map { " For \(s.en) especially: \($0.fix)" } ?? "")", ["Send photo"])
        }
        return ("I'm not sure about that one yet. Here's what I know for certain: \(s.tip) \(s.about ?? "")", ["Tell me your story", "What soil do you like?", "Any pests to watch?"])
    }

    /// Questions the knowledge base answers whatever plant we're talking about.
    static func knowledgeAnswer(_ q: String, raw: String, plant: Plant?, now: Date) -> (text: String, suggestions: [String])? {
        func has(_ p: String) -> Bool { ChatParser.matches(p, q) }
        let k = Knowledge.shared
        if has(#"\b(what is|what's|what are|whats|meaning|o que e|significa|define)\b"#), let t = k.term(in: q) {
            return ("\(t.term): \(t.meaning)", [])
        }
        if let d = k.disease(in: q) {
            return ("\(d.name). Signs: \(d.signs) Why: \(d.why) What helps: \(d.fix) Next time: \(d.prevent)", ["Send photo"])
        }
        if has(#"\b(deficien|nutrient|carenc|nitrogen|magnesium|iron|potassium|phosph|calcium)"#) {
            let hit = k.deficiencies.first { q.contains($0.id) || q.contains($0.name.folded) }
            if let n = hit { return ("\(n.name) shortage. Signs: \(n.signs) Fix: \(n.fix)", []) }
            return ("Leaves tell you what's missing:\n" + k.deficiencies.map { "• \($0.name): \($0.signs)" }.joined(separator: "\n"), [])
        }
        if has(#"\b(this month|month|calendar|season tasks|mes|este mes|what should i do)"#), let m = k.month(now) {
            return ("This month indoors: \(m.indoor)\nOutdoors: \(m.outdoor)", [])
        }
        if has(#"\b(lux|how bright|light level|light meter)"#) {
            return (k.lightLevels.map { "• \($0.id.capitalized) (\($0.lux) lux): \($0.where). Think \($0.plants)." }.joined(separator: "\n"), [])
        }
        if has(#"\b(terracotta|plastic pot|ceramic|which pot|pot material|self.?watering|grow bag)"#) {
            return (k.potMaterials.map { "• \($0.name): \($0.note ?? "")" }.joined(separator: "\n"), [])
        }
        if has(#"\b(tools?|equipment|what do i need|kit|ferramenta)"#) {
            return ("A cosy plant kit:\n" + k.tools.map { "• \($0.name): \($0.use ?? "")" }.joined(separator: "\n"), [])
        }
        // A described symptom without a plant to ask about.
        if plant == nil || plant?.species == nil, let sym = k.symptom(in: q) {
            return ("\(sym.name). \(sym.looks)\nUsual causes: \(sym.causes.joined(separator: "; ")).\nWhat helps: \(sym.fixes.joined(separator: " "))", ["Send photo"])
        }
        return nil
    }

    /// A short profile of any species in the library, for questions about plants you don't own.
    static func speciesCard(_ s: Species) -> String {
        var t = "\(s.en) (\(s.scientific)). \(s.about ?? s.tip)"
        t += "\n• Light: \(s.lightRule)\n• Water: \(s.waterRule) \(s.seasonalWater)"
        t += "\n• Comfort: \(Int(s.tempMin))–\(Int(s.tempMax)) °C, humidity \(Int(s.humidityMin))%+"
        t += "\n• Soil: \(s.soilPlan)\n• Food: \(s.feedPlan)\n• Pets: \(s.toxicityLine)."
        if let p = s.propagation?.first { t += "\n• More plants: \(p)." }
        t += "\n• Care level: \(s.difficultyLabel)."
        if let b = s.bloom { t += "\n• Flowers: \(b)." }
        return t
    }

    /// Picks plants from the library that match what the person describes.
    static func recommend(_ q: String) -> String {
        func m(_ p: String) -> Bool { ChatParser.matches(p, q) }
        var pool = SpeciesLibrary.shared.all
        var why: [String] = []
        if m(#"\b(pet|cat|dog|gato|cao|safe)"#) { pool = pool.filter(\.isPetSafe); why.append("pet-safe") }
        if m(#"\b(dark|low light|shade|north|escur|pouca luz)"#) { pool = pool.filter { $0.light == .low || $0.light == .medium }; why.append("happy in lower light") }
        if m(#"\b(sun|bright|south|sol)"#) { pool = pool.filter { $0.light == .bright || $0.light == .direct } ; why.append("sun-loving") }
        if m(#"\b(easy|beginner|forget|travel|lazy|facil|iniciante)"#) { pool = pool.filter { ($0.difficulty ?? 2) == 1 }; why.append("easy-going") }
        if m(#"\b(balcony|garden|outdoor|outside|varanda|jardim)"#) { pool = pool.filter { $0.outdoor == true }; why.append("good outdoors") }
        else if m(#"\b(indoor|inside|apartment|room|casa|apartamento)"#) { pool = pool.filter { $0.outdoor != true } }
        if m(#"\b(flower|bloom|flor)"#) { pool = pool.filter { ["flowering","orchid","violet","bulb","epicactus","bromeliad"].contains($0.group ?? "") || $0.feed == "bloom" }; why.append("flowering") }
        if m(#"\b(eat|herb|kitchen|food|erva|cozinha)"#) { pool = pool.filter { ["herb-med","herb-soft","vegetable","citrus"].contains($0.group ?? "") }; why.append("edible") }
        if m(#"\b(hang|trail|shelf|shelves|pendur)"#) { pool = pool.filter { $0.tags?.contains("trailing") == true }; why.append("trailing") }
        if m(#"\b(fast|quick|rapid)"#) { pool = pool.filter { $0.tags?.contains("fastGrowing") == true }; why.append("fast-growing") }
        if m(#"\b(humid|bathroom|banheiro)"#) { pool = pool.filter { $0.humidityMin >= 55 }; why.append("humidity-loving") }
        guard !pool.isEmpty else { return "I couldn't find a plant that ticks every box. Try fewer wishes, like \"easy and pet-safe\"." }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let picks = (0..<min(4, pool.count)).map { pool[(day + $0 * 7) % pool.count] }.uniqued()
        let head = why.isEmpty ? "A few lovely plants to consider:" : "Plants that are \(why.joined(separator: ", ")):"
        return head + "\n" + picks.map { "• \($0.en): \($0.tip)" }.joined(separator: "\n")
    }

    static func label(_ kind: PlantRequest.Kind) -> String {
        switch kind {
        case .water: "water"
        case .checkSoil: "soil check"
        case .feed: "food"
        case .checkRoots: "root check"
        case .portrait: "monthly photo"
        case .safety: "pet safety"
        case .pauseFeeding: "pause feeding"
        }
    }

    static func suggestions(for r: PlantRequest) -> [String] {
        switch r.kind {
        case .checkSoil: ["Dry", "Slightly moist", "Wet"]
        case .water: ["Watered"]
        case .feed: ["Fed"]
        case .portrait: ["Send photo"]
        case .safety: ["Got it"]
        default: []
        }
    }
}
