import Foundation

/// Answers questions from the plant's facts and reviewed species knowledge. No guessing:
/// if we don't know, the plant says so.
enum Answerer {
    private static var sendPhoto: String { Grammar.pt(String(localized: "Send photo", comment: "Chat suggestion chip: send a photo of the plant. Max 14 chars.")) }
    private static var soilWet: String { Grammar.pt(String(localized: "Soil is wet", comment: "Chat suggestion chip: user reports the soil is wet (pt: 'A terra está molhada'; the parser understands it).")) }
    private static var soilDry: String { Grammar.pt(String(localized: "Soil is dry", comment: "Chat suggestion chip: user reports the soil is dry (pt: 'A terra está seca').")) }
    private static var soilMoist: String { Grammar.pt(String(localized: "Soil is moist", comment: "Chat suggestion chip: user reports the soil is moist (pt: 'A terra está úmida').")) }
    private static var scanProduct: String { Grammar.pt(String(localized: "Scan a product", comment: "Chat suggestion chip: scan a soil or fertilizer product label.")) }
    private static var askSoil: String { Grammar.pt(String(localized: "What soil do you like?", comment: "Chat suggestion chip: question to the plant about its ideal soil.")) }
    private static var askFood: String { Grammar.pt(String(localized: "What food do you like?", comment: "Chat suggestion chip: question to the plant about its fertilizer.")) }
    private static var askPropagate: String { Grammar.pt(String(localized: "How do I propagate you?", comment: "Chat suggestion chip: question to the plant about making cuttings (pt: 'Como faço mudas de você?').")) }
    private static var askPests: String { Grammar.pt(String(localized: "Any pests to watch?", comment: "Chat suggestion chip: question to the plant about pests to watch for.")) }
    private static func bullets(_ lines: [String]) -> String { lines.map { "• \($0)" }.joined(separator: "\n") }

    // Care topics, matched on folded text, in every shipped language (en, pt, es, fr, de, ja).
    static let WATER = #"\b(water|drink|agua|regar|rega|rego|regue|regad|riego|riega|regarte|arros|giess|gieß|wasser)|水"#
    static let LIGHT = #"\b(light|sun|sunny|window|luz|sol|solzinho|ensolarad|janela|bright|dark|escur|claridade|sombra|lumiere|soleil|licht|sonne|helle?)\b|光|日当|日光"#
    static let FEED = #"\b(fertili|feed|food|adub|nutri|npk|comida|abon|engrais|dunger|düng)|肥料"#
    static let REPOT = #"\b(repot|pot|vaso|transplant|replant|roots|raiz|raize|maceta|trasplant|rempot|umtopf|topf)|植え替え|鉢"#
    static let SOIL = #"\b(soil|substrate|mix|terra|substrato|perlite|perlita|bark|casca|sustrato|tierra|terreau|erde|substrat)\b|用土|土"#
    static let HUMID = #"\b(humid|umid|mist|borrif|humedad|luftfeucht)|湿度"#
    static let TEMP = #"\b(cold|hot|temperat|frio|calor|winter|inverno|heater|aquecedor|radiator|ar.condicionado|froid|chaud|kalt|warm)|温度|寒|暑"#
    static let TOXIC = #"\b(toxic|safe|pet|cat|cats|dog|dogs|kid|child|gato|gatos|cao|cachorro|crianc|venen|faz mal|perro|chien|chat|chats|hund|katze|giftig)|毒|猫|犬"#
    static let PROPAGATE = #"\b(propag|cutting|estaca|muda|multiplic|esqueje|bouture|steckling|vermehr)|増や|挿し木"#
    static let PESTS = #"\b(bug|pest|insect|inset|bicho|praga|web|teia|mite|acaro|aranha|gnat|mosca|mosquit|mealy|cochonilha|scale|aphid|pulg|thrip|tripes|whitefly|lagarta|formiga|plaga|ravageur|parasit|schadling|schädling)|害虫|虫"#
    static let ORIGIN = #"\b(about|story|origin|where.{0,10}from|native|history|historia|origem|de onde|who are you|quem e voce|origen|d'ou|herkunft|woher)|原産|出身|どこ"#
    /// Questions the plant's own facts answer better than a generic how-to.
    static let CARE = [WATER, LIGHT, FEED, REPOT, SOIL, HUMID, TEMP, TOXIC, PROPAGATE, PESTS, ORIGIN].map { "(?:\($0))" }.joined(separator: "|")

    static func answer(_ raw: String, plant: Plant?, plants: [Plant], now: Date = Date()) -> (text: String, suggestions: [String]) {
        let q = raw.folded
        func has(_ p: String) -> Bool { ChatParser.matches(p, q) }

        let species = plant?.species ?? (plant == nil ? SpeciesLibrary.shared.mentioned(in: raw) : nil)
        if let general = knowledgeAnswer(q, raw: raw, plant: plant, plants: plants, now: now, careTopic: species != nil && has(CARE)) { return general }

        // Collection-level questions.
        if plant == nil {
            if has(#"\b(who|which|what|quem|quais|qual).{0,25}(need|thirst|water|attention|precis|sede|regar|agua|atencao)"#) || has(#"\btoday\b|\bhoje\b"#) {
                let needing = plants.compactMap { p -> String? in
                    let r = CareEngine.requests(for: p, now: now).filter { $0.priority <= 1 }
                    guard let first = r.first else { return nil }
                    return Grammar.pt(String(localized: "\(p.name): \(label(first.kind))", comment: "Line in a list of plants needing care. Args: plant name, care need (e.g. 'water')."))
                }
                return needing.isEmpty ? (Grammar.pt(String(localized: "Everyone is fine right now. Nothing needs you today.", comment: "Jungle chat: no plant needs care today.")), [])
                    : (Grammar.pt(String(localized: "Here's who needs you:\n\(bullets(needing))", comment: "Jungle chat: list of plants needing care follows (bulleted lines).")), [])
            }
            if has(#"\b(recommend|suggest|which plant|what plant|should i (get|buy)|best plant|indica|recomend|sugest|qual planta|que planta)"#) {
                return (recommend(q), [])
            }
            if let sp = species {
                // A focused question about a species ("is monstera toxic to cats?") gets that fact first, then the card.
                let focus: String? = has(TOXIC) ? Grammar.pt(String(localized: "Pets: \(sp.toxicityLine).", comment: "Species card bullet: pet toxicity."))
                    : has(WATER) ? Grammar.pt(String(localized: "Water: \(sp.waterRule) \(sp.seasonalWater)", comment: "Species card bullet. Args: watering rule, seasonal watering sentences."))
                    : has(LIGHT) ? Grammar.pt(String(localized: "Light: \(sp.lightRule)", comment: "Species card bullet. %@ = light rule sentence."))
                    : has(TEMP) ? Grammar.pt(String(localized: "Comfort: \(Climate.tempRange(sp.tempMin, sp.tempMax)), humidity \(Int(sp.humidityMin))%+", comment: "Species card bullet. Args: temperature range, minimum humidity percent."))
                    : has(SOIL) ? Grammar.pt(String(localized: "Soil: \(sp.soilPlan)", comment: "Species card bullet."))
                    : has(FEED) ? Grammar.pt(String(localized: "Food: \(sp.feedPlan)", comment: "Species card bullet: fertilizer plan."))
                    : nil
                let card = speciesCard(sp)
                return (focus.map { "\(sp.commonName): \($0)\n\n\(card)" } ?? card, [Grammar.pt(String(localized: "Is it pet-safe?", comment: "Chat suggestion chip: question whether a plant is safe for pets.")),
                                          Grammar.pt(String(localized: "Recommend a plant", comment: "Chat suggestion chip: ask for a plant recommendation."))])
            }
            if has(#"\b(safe|toxic|poison|pet|cat|dog|gato|cao|cachorro|venen|bicho de estimacao)"#) {
                let toxic = plants.filter { ($0.species?.toxicCats ?? false) || ($0.species?.toxicDogs ?? false) }.map(\.name)
                return toxic.isEmpty ? (Grammar.pt(String(localized: "None of your plants are on the toxic list for cats or dogs.", comment: "Jungle chat: pet safety answer.")), [])
                    : (Grammar.pt(String(localized: "Keep these away from pets: \(toxic.formatted(.list(type: .and))). They're irritating or toxic if chewed.", comment: "Jungle chat: pet safety answer. %@ = list of plant names.")), [])
            }
            if plants.isEmpty { return (Grammar.pt(String(localized: "Add your first plant and I'll be able to help. Tell me something like \"I have a monstera called Milo\".", comment: "Jungle chat: no plants yet. Translate the example naturally so the parser understands it, e.g. 'Tenho uma costela-de-adão chamada Milo'.")), []) }
            return (Grammar.pt(String(localized: "Which plant is this about? Mention its name, like \"\(plants.first!.name)\".", comment: "Jungle chat: question needs a plant. %@ = an example plant name.")), plants.prefix(3).map(\.name))
        }

        guard let plant else { return ("", []) }
        guard let s = plant.species else {
            return (Grammar.pt(String(localized: "I don't know my species yet, so I can't answer that well. Tell me what kind of plant I am, or open my profile and pick it.", comment: "Plant chat: plant has no species set.")),
                    [Grammar.pt(String(localized: "Set species", comment: "Chat suggestion chip: set the plant's species."))])
        }
        let name = s.commonName
        let expected = CareEngine.expectedDryDays(for: plant, at: now)
        let expectedDays = Int(expected.rounded())
        let lastWater = plant.lastEvent(.water)?.date

        // Symptoms first, because they matter most.
        if has(#"\b(yellow|amarel)"#) {
            var parts: [String] = []
            if let lastWater, CareEngine.days(from: lastWater, to: now) < expected * 0.6 {
                parts.append(Grammar.pt(String(localized: "Yellow leaves have a few possible causes. I was watered \(CareEngine.relative(lastWater, now)) and I usually take about \(expectedDays) days to dry, so too much water is the first thing to check. Feel my soil 3–4 cm deep before giving more.", comment: "Plant chat: yellow leaves, likely overwatering. Args: relative day ('yesterday', '3 days ago'), number of days to dry (plural).")))
            } else {
                parts.append(Grammar.pt(String(localized: "Yellow leaves have a few possible causes. If it's only one old leaf at the bottom, that's normal ageing. If several leaves are yellowing, check whether my soil stays wet for long, and whether my pot drains.", comment: "Plant chat: yellow leaves explanation.")))
            }
            if let p = s.problems?.first(where: { $0.sign.folded.contains("yellow") || $0.sign.folded.contains("amarel") }) {
                parts.append(Grammar.pt(String(localized: "For \(name) specifically: \(p.cause.lowercased()) is common. \(p.fix)", comment: "Plant chat: species-specific cause of yellow leaves. Args: species common name, cause (lowercase), fix sentence.")))
            }
            parts.append(Grammar.pt(String(localized: "Can you send a photo of the leaf?", comment: "Plant chat: asks for a photo of the leaf.")))
            return (parts.joined(separator: " "), [soilWet, soilDry, sendPhoto])
        }
        if has(#"\b(brown|crisp|castanh|marrom|queimad|seca nas pontas|pontas)"#) {
            let t = s.humidityMin >= 50
                ? Grammar.pt(String(localized: "Brown, crispy tips usually come from dry air, uneven watering or salts building up from tap water and fertilizer. I like humidity above \(Int(s.humidityMin))%, so dry air is a likely cause. Flushing my soil with plenty of water every couple of months helps. Brown soft patches are different: they point to too much water.", comment: "Plant chat: brown tips explanation. %lld = minimum humidity percent."))
                : Grammar.pt(String(localized: "Brown, crispy tips usually come from dry air, uneven watering or salts building up from tap water and fertilizer. Flushing my soil with plenty of water every couple of months helps. Brown soft patches are different: they point to too much water.", comment: "Plant chat: brown tips explanation."))
            return (t, [Grammar.pt(String(localized: "Tips are crispy", comment: "Chat suggestion chip: leaf tips are crispy.")), Grammar.pt(String(localized: "Patches are soft", comment: "Chat suggestion chip: brown patches are soft."))])
        }
        if has(#"\b(droop|wilt|sad|limp|murch|caid|triste|mole)"#) {
            return (Grammar.pt(String(localized: "Drooping can mean thirst or too much water. Both stress my roots. Feel my soil: if it's dry, water me well. If it's wet, the roots may be suffocating, so let me dry out and check that my pot drains.", comment: "Plant chat: drooping leaves explanation.")), [soilDry, soilWet])
        }
        if has(#"\b(curl|enrol|enrug)"#) {
            return (Grammar.pt(String(localized: "Curling leaves usually mean I'm thirsty, the air is too dry, or I'm getting too much sun. \(s.lightRule)", comment: "Plant chat: curling leaves. %@ = species light rule sentence.")),
                    [soilDry, Grammar.pt(String(localized: "It gets direct sun", comment: "Chat suggestion chip: the plant gets direct sun."))])
        }
        if has(PESTS) {
            let named = Knowledge.shared.pests.first { p in p.name.folded.split(separator: " ").contains { q.contains($0.prefix(5)) } }
            if let p = named {
                return (Grammar.pt(String(localized: "\(p.name): \(p.signs) What helps: \(p.fix) Keep me apart from the others until it's clear.", comment: "Plant chat: pest card. Args: pest name, signs sentence, fix sentence.")), [sendPhoto])
            }
            let mine = s.pestList.prefix(3)
            if !mine.isEmpty {
                let list = bullets(mine.map { "\($0.name): \($0.signs)" })
                return (Grammar.pt(String(localized: "The pests that bother \(name) most:\n\(list)\nCheck under my leaves and along the stems. A clear photo will help most.", comment: "Plant chat: likely pests. Args: species common name, bulleted list of pests.")), mine.map(\.name) + [sendPhoto])
            }
        }
        if has(#"\b(spot|mancha|bug|pest|insect|bicho|praga|web|teia|mite|aranha|gnat|mosca)"#) {
            return (Grammar.pt(String(localized: "Let's look closely. Check under my leaves and along the stems for webbing, white fluff or tiny moving dots. Until we know, keep me a little apart from the other plants. A clear photo of the spot will help most.", comment: "Plant chat: unknown spots or pests.")),
                    [sendPhoto, Grammar.pt(String(localized: "I see webbing", comment: "Chat suggestion chip: user sees webbing on the plant.")), Grammar.pt(String(localized: "White fluff", comment: "Chat suggestion chip: user sees white fluff (mealybugs)."))])
        }

        // Care questions.
        if has(WATER), let mk = CareEngine.mediumKind(plant) {
            let last = plant.lastEvent(plant.waterKind)?.date
            var parts = [CareEngine.mediumReason(plant, kind: mk, last: last, now: now)]
            if plant.growingMedium == .water { parts.append(Grammar.pt(String(localized: "No soil, so never mind the finger test. Use room-temperature water and top up when the level drops.", comment: "Plant chat: watering advice for a plant growing in water."))) }
            return (parts.joined(separator: " "), mk == .refreshWater ? [JungleBrain.freshWaterChip] : mk == .topUp ? [JungleBrain.toppedUpChip] : [])
        }
        if has(WATER) {
            var parts = ["\(s.waterRule) \(s.seasonalWater) \(s.potHint(diameter: plant.potDiameterCm))"]
            parts.append(plant.learnedDryDays != nil
                ? Grammar.pt(String(localized: "In my current setup I usually dry in about \(expectedDays) days. I learned that from your soil checks.", comment: "Plant chat: learned drying rhythm. %lld = days (plural)."))
                : Grammar.pt(String(localized: "In my current setup I usually dry in about \(expectedDays) days. I'll learn my real rhythm from your soil checks.", comment: "Plant chat: estimated drying rhythm. %lld = days (plural).")))
            if let lastWater { parts.append(Grammar.pt(String(localized: "I was last watered \(CareEngine.relative(lastWater, now)).", comment: "Plant chat. %@ = relative day like 'today', 'yesterday', '3 days ago'."))) }
            parts.append(Grammar.pt(String(localized: "Always feel the soil first. The calendar is only a guess.", comment: "Plant chat: watering advice closer.")))
            return (parts.joined(separator: " "), [soilDry, soilMoist])
        }
        if has(LIGHT) {
            return (Grammar.pt(String(localized: "\(s.lightRule) If I stretch toward the window or my new leaves come out small, I need more light. Bleached or scorched patches mean too much direct sun.", comment: "Plant chat: light advice. %@ = species light rule sentence.")), [])
        }
        if has(FEED) {
            if !CareEngine.isGrowingSeason(now) {
                return (Grammar.pt(String(localized: "I'm growing slowly at this time of year, so please pause feeding until spring. Feeding a resting plant just builds up salts in my soil.", comment: "Plant chat: no feeding in the resting season.")), [])
            }
            if let r = plant.lastRepotAt, CareEngine.days(from: r, to: now) < 42 {
                return (Grammar.pt(String(localized: "My soil is still fresh from repotting and has nutrients. Let's wait about 6 weeks before feeding.", comment: "Plant chat: recently repotted, no feeding yet.")), [])
            }
            if s.feed == "none" { return (Grammar.pt(String(localized: "Please never feed me. I catch my own food, and fertilizer burns my roots. Rainwater only.", comment: "Plant chat: carnivorous plant, never fertilize.")), []) }
            return (Grammar.pt(String(localized: "\(s.feedPlan) Always water first. Never feed dry roots. Scan any bottle at the shop and I'll tell you if it suits me.", comment: "Plant chat: feeding advice. %@ = species feeding plan sentence.")), [scanProduct, askSoil])
        }
        if has(REPOT) {
            let size = plant.potDiameterCm.map { d in
                Grammar.pt(String(localized: "My pot is \(Int(d)) cm, so the next one should be about \(Int(d + 2))–\(Int(d + 5)) cm.", comment: "Plant chat: next pot size. Args: current pot diameter, min and max next diameter (cm)."))
            } ?? Grammar.pt(String(localized: "Go only 2–5 cm wider than my current pot.", comment: "Plant chat: pot size advice."))
            let season = CareEngine.isWinter(now)
                ? Grammar.pt(String(localized: "It's winter, so unless my roots are rotting, let's wait for spring.", comment: "Plant chat: don't repot in winter."))
                : Grammar.pt(String(localized: "Spring and early summer are the best time.", comment: "Plant chat: best repotting season."))
            let head = Grammar.pt(String(localized: "Repot me when roots come out of the drainage holes, circle the pot, or water runs straight through.", comment: "Plant chat: signs it's time to repot."))
            let soil = Grammar.pt(String(localized: "For soil: \(s.soilPlan)", comment: "Plant chat: soil recommendation. %@ = species soil plan sentence."))
            return ([head, size, season, s.repotNotes, soil].compactMap { $0 }.joined(separator: " "), [askPropagate])
        }
        if has(SOIL) {
            return (Grammar.pt(String(localized: "My perfect home is \(s.soilPlan) \(s.soil?.note ?? "") Scan a soil bag and I'll check it against that.", comment: "Plant chat: ideal soil. Args: species soil plan sentence, optional soil note.")), [scanProduct, askFood])
        }
        if has(HUMID) {
            return (Grammar.pt(String(localized: "I'm happiest above \(Int(s.humidityMin))% humidity. Grouping plants or using a humidifier works better than misting, whose effect lasts only minutes.", comment: "Plant chat: humidity advice. %lld = minimum humidity percent.")), [])
        }
        if has(TEMP) {
            return (Grammar.pt(String(localized: "I'm comfortable between \(Climate.temp(s.tempMin)) and \(Climate.temp(s.tempMax)). Keep me away from radiators, AC vents and cold drafts.", comment: "Plant chat: temperature range. Args: formatted min and max temperatures. In Brazil: 'aquecedor', 'ar-condicionado', 'correntes de ar frio'.")), [])
        }
        if has(TOXIC) {
            let tox = s.toxicCats || s.toxicDogs
            return (tox ? Grammar.pt(String(localized: "\(s.toxicityLine). Keep me out of reach. If a pet chews me and shows symptoms, call a vet.", comment: "Plant chat: plant is toxic. %@ = toxicity sentence without final period."))
                : Grammar.pt(String(localized: "I'm on the non-toxic list for cats and dogs (ASPCA). Still, nibbling isn't good for either of us.", comment: "Plant chat: plant is pet-safe.")), [])
        }
        if has(#"\b(how are you|how do you feel|tudo bem|como estas|como esta|como voce esta|como vai|how you doing)"#) {
            let reqs = CareEngine.requests(for: plant, now: now)
            if let first = reqs.first(where: { $0.priority <= 1 }) { return (PlantVoice.say(first, plant: plant), suggestions(for: first)) }
            return (PlantVoice.happy(plant), [])
        }
        if has(PROPAGATE) {
            let ways = bullets(s.propagation ?? [Grammar.pt(String(localized: "Stem cuttings just below a node, in water or moist perlite", comment: "Default propagation method (bullet item, no final period)."))])
            return (Grammar.pt(String(localized: "Here's how to make more of me:\n\(ways)\nSpring and early summer are best, in bright, indirect light.", comment: "Plant chat: propagation. %@ = bulleted list of methods.")), [])
        }
        if has(ORIGIN) {
            var parts = [s.about ?? s.tip]
            if let o = s.origin { parts.append(Grammar.pt(String(localized: "I come from \(o).", comment: "Plant chat: where the species is native. %@ = region."))) }
            if let h = s.habit { parts.append(Grammar.pt(String(localized: "Growth habit: \(h.lowercased()).", comment: "Plant chat: growth habit. %@ = habit description, lowercase."))) }
            return (parts.joined(separator: " "), [askPropagate, askPests])
        }
        if has(#"\b(problem|wrong|issue|sick|doente|ajuda|help|errado)"#), let probs = s.problems, !probs.isEmpty {
            let list = bullets(probs.map { "\($0.sign): \($0.cause.lowercased()). \($0.fix)" })
            return (Grammar.pt(String(localized: "Things that most often trouble \(name):\n\(list)", comment: "Plant chat: common problems. Args: species common name, bulleted list.")), [sendPhoto])
        }
        if let sym = Knowledge.shared.symptom(in: q) {
            let mine = s.problems?.first { p in sym.keywords.contains { p.sign.folded.contains($0.folded) } }
            var parts = [Grammar.pt(String(localized: "\(sym.name). Usual causes: \(sym.causes.joined(separator: "; ")). \(sym.fixes.joined(separator: " "))", comment: "Plant chat: symptom card. Args: symptom name, causes separated by semicolons, fix sentences."))]
            if let mine { parts.append(Grammar.pt(String(localized: "For \(name) especially: \(mine.fix)", comment: "Plant chat: species-specific fix. Args: species common name, fix sentence."))) }
            return (parts.joined(separator: " "), [sendPhoto])
        }
        return (Grammar.pt(String(localized: "I'm not sure about that one yet. Here's what I know for certain: \(s.tip) \(s.about ?? "")", comment: "Plant chat: fallback when the question isn't understood. Args: species tip, optional about text.")),
                [Grammar.pt(String(localized: "Tell me your story", comment: "Chat suggestion chip: ask the plant about its origin story.")), askSoil, askPests])
    }

    /// Questions the knowledge base answers whatever plant we're talking about.
    static func knowledgeAnswer(_ q: String, raw: String, plant: Plant?, plants: [Plant], now: Date, careTopic: Bool = false) -> (text: String, suggestions: [String])? {
        func has(_ p: String) -> Bool { ChatParser.matches(p, q) }
        let k = Knowledge.shared
        if has(#"\b(what is|what's|what are|whats|meaning|o que e|o que sao|significa|define)\b"#), let t = k.term(in: q) {
            return ("\(t.term): \(t.meaning)", [])
        }
        if let d = k.disease(in: q) {
            return (Grammar.pt(String(localized: "\(d.name). Signs: \(d.signs) Why: \(d.why) What helps: \(d.fix) Next time: \(d.prevent)", comment: "Chat: plant disease card. Args: disease name, signs, cause, fix, prevention sentences.")), [sendPhoto])
        }
        if has(#"\b(deficien|nutrient|carenc|nitrogen|magnesium|magnesio|iron|ferro|potassium|potassio|phosph|fosforo|calcium|calcio)"#) {
            let hit = k.deficiencies.first { q.contains($0.id) || q.contains($0.name.folded) }
            if let n = hit { return (Grammar.pt(String(localized: "\(n.name) shortage. Signs: \(n.signs) Fix: \(n.fix)", comment: "Chat: nutrient deficiency card. Args: nutrient name, signs, fix.")), []) }
            return (Grammar.pt(String(localized: "Leaves tell you what's missing:\n\(bullets(k.deficiencies.map { "\($0.name): \($0.signs)" }))", comment: "Chat: list of nutrient deficiencies follows (bulleted).")), [])
        }
        if has(#"\b(this month|month|calendar|season tasks|mes|este mes|esse mes|what should i do|o que (eu )?faco)"#), let m = k.month(now) {
            return (Grammar.pt(String(localized: "This month indoors: \(m.indoor)\nOutdoors: \(m.outdoor)", comment: "Chat: monthly garden tasks. Args: indoor tasks, outdoor tasks.")), [])
        }
        let c = Climate.shared
        if !careTopic, has(#"\b(weather|forecast|frost|freez|heatwave|heat wave|storm|rain|geada|chuva|previs|como esta o tempo|tempo la fora|tempestade|onda de calor)"#) {
            if c.profile == nil {
                return (Grammar.pt(String(localized: "Tell me where you live (Me › Settings › Where you grow) and I'll watch the weather for your outdoor plants.", comment: "Chat: no location set. Path names must match the app's own labels (Me tab › Settings › Where you grow).")),
                        [Grammar.pt(String(localized: "Open settings", comment: "Chat suggestion chip: open settings."))])
            }
            let alerts = c.alerts(for: plants, now: now)
            if !alerts.isEmpty { return (alerts.map { "\($0.title). \($0.detail)" }.joined(separator: "\n"), []) }
            let days = c.upcoming(now)
            guard let lo = days.map(\.tMin).min(), let hi = days.map(\.tMax).max() else {
                return (Grammar.pt(String(localized: "I don't have a fresh forecast yet. I'll check again soon.", comment: "Chat: weather forecast not available.")), [])
            }
            let rain = days.map(\.rain).reduce(0, +)
            let place = c.profile!.place
            return (rain >= 1
                ? Grammar.pt(String(localized: "Next few days in \(place): \(Climate.tempRange(lo, hi)), about \(Climate.rain(rain)) of rain. Nothing your outdoor plants need to worry about.", comment: "Chat: calm weather forecast. Args: place, temperature range, formatted rain amount."))
                : Grammar.pt(String(localized: "Next few days in \(place): \(Climate.tempRange(lo, hi)), dry. Nothing your outdoor plants need to worry about.", comment: "Chat: calm, dry weather forecast. Args: place, temperature range.")), [])
        }
        if has(#"\b(climate|clima|biome|bioma|koppen|hardiness|zone|zona|hemisphere|hemisferio|where i live|onde moro)"#) {
            return (c.summary, [])
        }
        if has(#"\b(outside|outdoor|balcony|garden|fora|varanda|sacada|jardim|quintal)\b"#), has(#"\b(can|could|survive|live|ok|pode|aguenta|sobrevive|da pra)"#),
           let sp = plant?.species ?? SpeciesLibrary.shared.mentioned(in: raw), let fit = c.fit(sp) {
            return (fit, [])
        }
        if !careTopic, has(#"\b(lux|how bright|light level|light meter|luminosidade|quanta luz|nivel de luz)"#) {
            return (bullets(k.lightLevels.map { Grammar.pt(String(localized: "\($0.id.capitalized) (\($0.lux) lux): \($0.where). Think \($0.plants).", comment: "Chat: light level line. Args: level name, lux range, where in a home, example plants.")) }), [])
        }
        if has(#"\b(terracotta|terracota|barro|plastic pot|vaso de plastico|ceramic|ceramica|which pot|qual vaso|pot material|self.?watering|autoirrig|grow bag)"#) {
            return (bullets(k.potMaterials.map { "\($0.name): \($0.note ?? "")" }), [])
        }
        if has(#"\b(tools?|equipment|what do i need|kit|ferramenta|o que (eu )?preciso)"#) {
            return (Grammar.pt(String(localized: "A cosy plant kit:\n\(bullets(k.tools.map { "\($0.name): \($0.use ?? "")" }))", comment: "Chat: list of plant tools follows (bulleted).")), [])
        }
        // Home remedies with exact mixes.
        if has(#"\b(remed|spray|natural|home ?made|diy|recipe|organic|organico|neem|soap|sabao|receita|caseiro)"#) {
            let list = k.remedies(for: q)
            let pick = list.isEmpty ? Array(k.remedies.prefix(4)) : Array(list.prefix(3))
            let lines = pick.map { Grammar.pt(String(localized: "\($0.name) (for \($0.forWhat)): \($0.recipe) \($0.how) Careful: \($0.caution)", comment: "Chat: home remedy line. Args: remedy name, what it's for, recipe, how to use, caution.")) }
            return (Grammar.pt(String(localized: "Gentle fixes:\n\(bullets(lines))", comment: "Chat: list of home remedies follows (bulleted).")), [])
        }
        // What am I doing wrong, for this plant's kind.
        if has(#"\b(mistake|doing wrong|wrong with|is it happy|happy|errando|erro|feliz)"#), let g = plant?.species?.group.flatMap({ k.groups[$0] }) {
            return (Grammar.pt(String(localized: "A happy one looks like this: \(g.happy)\nCommon mistakes: \(g.mistakes.joined(separator: "; ")).\nQuick wins: \(g.wins.joined(separator: "; ")).", comment: "Chat: plant group care card. Args: what a happy plant looks like, mistakes, quick wins (semicolon separated).")), [])
        }
        // Growing food: sowing, spacing, harvest and neighbours.
        if let crop = k.crop(in: q), has(#"\b(grow|sow|plant (it|them|out)|harvest|pick|seed|companion|pot size|how long|when|plantar|semear|colher|cultivar|semente|quando)"#) {
            return (crop.card, [])
        }
        if has(#"\b(family|familia)\b"#), let f = k.family(in: q) ?? k.family(named: plant?.species?.family) {
            return (Grammar.pt(String(localized: "\(f.name), \(f.common). \(f.traits)\nCare: \(f.care)\nSafety: \(f.toxic)\nRelatives: \(f.examples.formatted(.list(type: .and))).", comment: "Chat: plant family card. Args: family scientific name, common name, traits, care, safety, list of relatives.")), [])
        }
        if has(#"\b(what can i grow|grow food|vegetables?|veggies|kitchen garden|horta|legumes|verduras|hortalicas)\b"#) {
            let easy = k.crops.filter { $0.potLitres <= 10 }.prefix(12).map(\.name)
            return (Grammar.pt(String(localized: "Easy food for pots: \(easy.formatted(.list(type: .and))). Ask me about any of them, like \"how do I grow chillies\".", comment: "Chat: easy edible plants for pots. %@ = list of crop names. Translate the example naturally (e.g. 'como plantar pimenta').")), [])
        }
        // How-to topics: propagation, watering methods, light, holidays, myths and more.
        if !careTopic, let t = k.topic(in: q), (plant == nil && t.kind != "safety") || has(#"\b(how|why|tips?|guide|best way|should i|is it true|myth|como|por que|porque|dicas?|melhor jeito|e verdade|mito)\b"#) {
            let steps = bullets(t.steps.prefix(5).map { "\($0.title): \($0.detail)" })
            return ("\(t.title). \(t.intro)\n\(steps)", [])
        }
        // A described symptom without a plant to ask about.
        if plant == nil || plant?.species == nil, let sym = k.symptom(in: q) {
            return (Grammar.pt(String(localized: "\(sym.name). \(sym.looks)\nUsual causes: \(sym.causes.joined(separator: "; ")).\nWhat helps: \(sym.fixes.joined(separator: " "))", comment: "Chat: symptom card. Args: symptom name, how it looks, causes (semicolon separated), fixes.")), [sendPhoto])
        }
        return nil
    }

    /// A short profile of any species in the library, for questions about plants you don't own.
    static func speciesCard(_ s: Species) -> String {
        var lines = [
            Grammar.pt(String(localized: "Light: \(s.lightRule)", comment: "Species card bullet. %@ = light rule sentence.")),
            Grammar.pt(String(localized: "Water: \(s.waterRule) \(s.seasonalWater)", comment: "Species card bullet. Args: watering rule, seasonal watering sentences.")),
            Grammar.pt(String(localized: "Comfort: \(Climate.tempRange(s.tempMin, s.tempMax)), humidity \(Int(s.humidityMin))%+", comment: "Species card bullet. Args: temperature range, minimum humidity percent.")),
            Grammar.pt(String(localized: "Soil: \(s.soilPlan)", comment: "Species card bullet.")),
            Grammar.pt(String(localized: "Food: \(s.feedPlan)", comment: "Species card bullet: fertilizer plan.")),
            Grammar.pt(String(localized: "Pets: \(s.toxicityLine).", comment: "Species card bullet: pet toxicity.")),
        ]
        if let p = s.propagation?.first { lines.append(Grammar.pt(String(localized: "More plants: \(p).", comment: "Species card bullet: how to propagate."))) }
        lines.append(Grammar.pt(String(localized: "Care level: \(s.difficultyLabel).", comment: "Species card bullet: difficulty.")))
        if let b = s.bloom { lines.append(Grammar.pt(String(localized: "Flowers: \(b).", comment: "Species card bullet: bloom info."))) }
        return "\(s.commonName) (\(s.scientific)). \(s.about ?? s.tip)\n" + bullets(lines)
    }

    /// Picks plants from the library that match what the person describes.
    static func recommend(_ q: String) -> String {
        func m(_ p: String) -> Bool { ChatParser.matches(p, q) }
        var pool = SpeciesLibrary.shared.all
        var why: [String] = []
        let good = Grammar.pt(String(localized: "good outdoors", comment: "Recommendation reason, completes 'Plants that are …'."))
        if m(#"\b(pet|cat|dog|gato|cao|cachorro|safe|segur)"#) { pool = pool.filter(\.isPetSafe); why.append(Grammar.pt(String(localized: "pet-safe", comment: "Recommendation reason, completes 'Plants that are …'."))) }
        if m(#"\b(dark|low light|shade|north|escur|pouca luz|sombra)"#) { pool = pool.filter { $0.light == .low || $0.light == .medium }; why.append(Grammar.pt(String(localized: "happy in lower light", comment: "Recommendation reason, completes 'Plants that are …'."))) }
        if m(#"\b(sun|bright|south|sol|claro|luminos)"#) { pool = pool.filter { $0.light == .bright || $0.light == .direct }; why.append(Grammar.pt(String(localized: "sun-loving", comment: "Recommendation reason, completes 'Plants that are …'."))) }
        if m(#"\b(easy|beginner|forget|travel|lazy|facil|faceis|iniciante|esquec|viajo|preguic)"#) { pool = pool.filter { ($0.difficulty ?? 2) == 1 }; why.append(Grammar.pt(String(localized: "easy-going", comment: "Recommendation reason, completes 'Plants that are …'."))) }
        if m(#"\b(balcony|garden|outdoor|outside|varanda|sacada|jardim|quintal)"#) {
            pool = pool.filter { $0.outdoor == true }
            if let cold = Climate.shared.profile?.coldestNight {
                let hardy = pool.filter { $0.tempMin <= cold }
                if !hardy.isEmpty { pool = hardy; why.append(Grammar.pt(String(localized: "hardy in \(Climate.shared.profile!.place)", comment: "Recommendation reason, completes 'Plants that are …'. %@ = place name."))) } else { why.append(good) }
            } else { why.append(good) }
        }
        else if m(#"\b(indoor|inside|apartment|room|casa|apartamento|quarto|sala|dentro)"#) { pool = pool.filter { $0.outdoor != true } }
        if m(#"\b(flower|bloom|flor)"#) { pool = pool.filter { ["flowering","orchid","violet","bulb","epicactus","bromeliad"].contains($0.group ?? "") || $0.feed == "bloom" }; why.append(Grammar.pt(String(localized: "flowering", comment: "Recommendation reason, completes 'Plants that are …'."))) }
        if m(#"\b(eat|herb|kitchen|food|erva|cozinha|tempero|comer|comestive)"#) { pool = pool.filter { ["herb-med","herb-soft","vegetable","citrus"].contains($0.group ?? "") }; why.append(Grammar.pt(String(localized: "edible", comment: "Recommendation reason, completes 'Plants that are …'."))) }
        if m(#"\b(hang|trail|shelf|shelves|pendur|prateleira|estante)"#) { pool = pool.filter { $0.tags?.contains("trailing") == true }; why.append(Grammar.pt(String(localized: "trailing", comment: "Recommendation reason, completes 'Plants that are …' (hanging plants)."))) }
        if m(#"\b(fast|quick|rapid)"#) { pool = pool.filter { $0.tags?.contains("fastGrowing") == true }; why.append(Grammar.pt(String(localized: "fast-growing", comment: "Recommendation reason, completes 'Plants that are …'."))) }
        if m(#"\b(humid|umid|bathroom|banheiro)"#) { pool = pool.filter { $0.humidityMin >= 55 }; why.append(Grammar.pt(String(localized: "humidity-loving", comment: "Recommendation reason, completes 'Plants that are …'."))) }
        guard !pool.isEmpty else { return Grammar.pt(String(localized: "I couldn't find a plant that ticks every box. Try fewer wishes, like \"easy and pet-safe\".", comment: "Chat: no plant matches all wishes. Translate the example naturally (e.g. 'fácil e segura para pets').")) }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let picks = (0..<min(4, pool.count)).map { pool[(day + $0 * 7) % pool.count] }.uniqued()
        let list = bullets(picks.map { "\($0.commonName): \($0.tip)" })
        return why.isEmpty ? Grammar.pt(String(localized: "A few lovely plants to consider:\n\(list)", comment: "Chat: plant recommendations follow (bulleted)."))
            : Grammar.pt(String(localized: "Plants that are \(why.formatted(.list(type: .and))):\n\(list)", comment: "Chat: plant recommendations. Args: list of qualities (e.g. 'pet-safe and easy-going'), bulleted plant list."))
    }

    static func label(_ kind: PlantRequest.Kind) -> String {
        switch kind {
        case .water: Grammar.pt(String(localized: "water", comment: "Care need shown after a plant name, lowercase."))
        case .checkSoil: Grammar.pt(String(localized: "soil check", comment: "Care need shown after a plant name, lowercase."))
        case .feed: Grammar.pt(String(localized: "food", comment: "Care need shown after a plant name, lowercase (fertilizer)."))
        case .checkRoots: Grammar.pt(String(localized: "root check", comment: "Care need shown after a plant name, lowercase."))
        case .portrait: Grammar.pt(String(localized: "monthly photo", comment: "Care need shown after a plant name, lowercase."))
        case .safety: Grammar.pt(String(localized: "pet safety", comment: "Care need shown after a plant name, lowercase."))
        case .pauseFeeding: Grammar.pt(String(localized: "pause feeding", comment: "Care need shown after a plant name, lowercase."))
        case .refreshWater: Grammar.pt(String(localized: "fresh water", comment: "Care need shown after a plant name, lowercase."))
        case .topUp: Grammar.pt(String(localized: "reservoir top-up", comment: "Care need shown after a plant name, lowercase."))
        case .soak: Grammar.pt(String(localized: "soak", comment: "Care need shown after a plant name, lowercase."))
        case .mist: Grammar.pt(String(localized: "light mist", comment: "Care need shown after a plant name, lowercase."))
        case .askDone: Grammar.pt(String(localized: "did you already?", comment: "Care need shown after a plant name, lowercase. Asks whether the user already did the care."))
        case .quarantine: Grammar.pt(String(localized: "keep apart", comment: "Care need shown after a plant name, lowercase. Quarantine for pests."))
        case .treatFollowUp: Grammar.pt(String(localized: "next treatment round", comment: "Care need shown after a plant name, lowercase."))
        }
    }

    static func suggestions(for r: PlantRequest) -> [String] {
        switch r.kind {
        case .checkSoil: JungleBrain.soilChips
        case .water: [JungleBrain.wateredChip]
        case .refreshWater: [JungleBrain.freshWaterChip]
        case .topUp: [JungleBrain.toppedUpChip]
        case .treatFollowUp: [Grammar.pt(String(localized: "Treated", comment: "Chat suggestion chip: user confirms a pest treatment (pt: 'Tratei'; the parser understands it)."))]
        case .feed: [Grammar.pt(String(localized: "Fed", comment: "Chat suggestion chip: user confirms they fertilized (pt: 'Adubei'; the parser understands it)."))]
        case .portrait: [sendPhoto]
        case .safety: [Grammar.pt(String(localized: "Got it", comment: "Chat suggestion chip: acknowledge a pet safety warning (pt: 'Entendi')."))]
        default: []
        }
    }
}
