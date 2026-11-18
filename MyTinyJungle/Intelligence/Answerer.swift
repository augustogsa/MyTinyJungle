import Foundation

/// Answers questions from the plant's facts and reviewed species knowledge. No guessing:
/// if we don't know, the plant says so.
enum Answerer {
    static func answer(_ raw: String, plant: Plant?, plants: [Plant], now: Date = Date()) -> (text: String, suggestions: [String]) {
        let q = raw.folded
        func has(_ p: String) -> Bool { ChatParser.matches(p, q) }

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
        if has(#"\b(spot|mancha|bug|pest|insect|bicho|praga|web|teia|mite|aranha|gnat|mosca)"#) {
            return ("Let's look closely. Check under my leaves and along the stems for webbing, white fluff or tiny moving dots. Until we know, keep me a little apart from the other plants. A clear photo of the spot will help most.", ["Send photo", "I see webbing", "White fluff"])
        }

        // Care questions.
        if has(#"\b(water|drink|agua|regar|rega)"#) {
            var t = "\(s.waterRule) In my current setup I usually dry in about \(Int(expected.rounded())) days"
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
            let kind: String = switch s.feed {
            case "cactus": "a cactus fertilizer, low in nitrogen, at half strength"
            case "orchid": "an orchid fertilizer, weak and often (\"weakly, weekly\")"
            case "acid": "a fertilizer for acid-loving plants (ericaceous)"
            case "citrus": "a citrus fertilizer with micronutrients (iron, magnesium)"
            case "bloom": "a balanced feed, switching to one higher in potassium when I'm flowering"
            case "light": "a balanced liquid feed at half strength"
            default: "a balanced liquid feed (e.g. NPK 3-1-2 or 10-10-10), diluted as the label says"
            }
            return ("In the growing season I like \(kind), about every \(Int(s.feedWeeks)) weeks. Always water first. Never feed dry roots. Scan any bottle at the shop and I'll tell you if it suits me.", ["Scan a product"])
        }
        if has(#"\b(repot|pot|vaso|transplant|roots|raiz|raize)"#) {
            let size = plant.potDiameterCm.map { "My pot is \(Int($0)) cm, so the next one should be about \(Int($0 + 2))–\(Int($0 + 5)) cm. " } ?? "Go only 2–5 cm wider than my current pot. "
            let season = CareEngine.isWinter(now) ? "It's winter, so unless my roots are rotting, let's wait for spring. " : "Spring and early summer are the best time. "
            return ("Repot me when roots come out of the drainage holes, circle the pot, or water runs straight through. \(size)\(season)For soil, I like \(s.mixLabel).", [])
        }
        if has(#"\b(soil|substrate|mix|terra|substrato|perlite|bark)"#) {
            return ("I like \(s.mixLabel). It should hold about \(Int(s.retention * 100))% of my ideal moisture and stay airy (aeration \(Int(s.aeration * 100))%), with a pH between \(s.phMin) and \(s.phMax). Scan a soil bag and I'll check it against that.", ["Scan a product"])
        }
        if has(#"\b(humid|mist|borrif|humidade)"#) {
            return ("I'm happiest above \(Int(s.humidityMin))% humidity. Grouping plants or using a humidifier works better than misting, whose effect lasts only minutes.", [])
        }
        if has(#"\b(cold|hot|temperat|frio|calor|winter|inverno|heater|aquecedor|radiator)"#) {
            return ("I'm comfortable between \(Int(s.tempMin)) and \(Int(s.tempMax)) °C. Keep me away from radiators, AC vents and cold drafts.", [])
        }
        if has(#"\b(toxic|safe|pet|cat|dog|kid|child|gato|cao|crianc)"#) {
            let tox = s.toxicCats || s.toxicDogs
            return (tox ? "I'm toxic or irritating to cats and dogs if chewed (ASPCA list). Keep me out of reach. If a pet chews me and shows symptoms, call a vet." : "I'm on the non-toxic list for cats and dogs (ASPCA). Still, nibbling isn't good for either of us.", [])
        }
        if has(#"\b(how are you|how do you feel|tudo bem|como estas|como esta|how you doing)"#) {
            let reqs = CareEngine.requests(for: plant, now: now)
            if let first = reqs.first(where: { $0.priority <= 1 }) { return (PlantVoice.say(first, plant: plant), suggestions(for: first)) }
            return (PlantVoice.happy(plant), [])
        }
        if has(#"\b(propagat|cutting|estaca|multiplic)"#) {
            return ("Cut just below a node, the bump where a leaf meets the stem, and put the cutting in water or moist perlite in bright, indirect light. Roots usually show in 2–4 weeks. Spring is best.", [])
        }
        return ("I'm not sure about that one yet. Here's what I know for certain: \(s.tip)", [])
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
